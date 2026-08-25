// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ImagesReference.swift — production des images que regarde Éric.
//
// Le lot 3 se termine sur une validation VISUELLE, et elle conditionne le lot
// suivant. Ce fichier fabrique de quoi la rendre possible : des rendus sur de
// vraies images extraites de vraies vidéos, aux quatre formats exigés, pour les
// deux profils livrés — et, quand une vidéo source est fournie, une planche
// côte à côte avec le rendu du prototype sur LA MÊME réplique.
//
// Le choix des répliques n'est pas laissé au hasard : on prend les plus
// longues, celles que la resegmentation découpe le plus. Si elles passent,
// le reste passe.
//
// L'extraction d'image se fait par AVFoundation — invariant nº3, aucune
// dépendance non-Apple. Le prototype, lui, a besoin de son ffmpeg : c'est
// `Scripts/images_reference.sh` qui l'appelle, jamais ce code.

import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ErreurImages: Error {
    case videoIllisible(URL)
    case extractionImpossible(URL, String)
    case ecritureImpossible(URL)
}

enum ImagesReference {

    // MARK: - Extraction d'une image de la vidéo

    /// Exécute un travail asynchrone depuis ce harnais synchrone.
    ///
    /// AVFoundation n'expose plus que des accès `async` depuis macOS 13, et le
    /// harnais de vérification, lui, est une suite d'appels bloquants qui se
    /// termine par un `exit()`. Ce pont fait la jonction, sans réintroduire les
    /// API dépréciées.
    private static func bloquant<T>(_ travail: @escaping () async throws -> T) throws -> T {
        let verrou = DispatchSemaphore(value: 0)
        var resultat: Result<T, Error>!
        Task {
            do { resultat = .success(try await travail()) }
            catch { resultat = .failure(error) }
            verrou.signal()
        }
        verrou.wait()
        return try resultat.get()
    }

    /// Dimensions en pixels de la piste vidéo, orientation appliquée.
    static func dimensions(de video: URL) throws -> (largeur: Int, hauteur: Int) {
        let asset = AVURLAsset(url: video)
        let taille: CGSize = try bloquant {
            guard let piste = try await asset.loadTracks(withMediaType: .video).first else {
                throw ErreurImages.videoIllisible(video)
            }
            // La taille naturelle ignore la rotation : une vidéo filmée au
            // téléphone ressortirait en 1920×1080 alors qu'elle s'affiche en
            // 1080×1920. La transformation la remet d'aplomb — c'est exactement
            // le piège du format vertical que l'ADR §5 corrige, il serait
            // absurde de le rouvrir en extrayant les images.
            let (naturelle, transformation) = try await piste.load(
                .naturalSize, .preferredTransform)
            return naturelle.applying(transformation)
        }
        return (Int(abs(taille.width).rounded()), Int(abs(taille.height).rounded()))
    }

    /// Extrait une image à un instant donné, orientation appliquée.
    static func image(de video: URL, a secondes: Double) throws -> CGImage {
        let asset = AVURLAsset(url: video)
        let generateur = AVAssetImageGenerator(asset: asset)
        generateur.appliesPreferredTrackTransform = true
        generateur.requestedTimeToleranceBefore = .zero
        generateur.requestedTimeToleranceAfter = .zero
        do {
            return try bloquant {
                try await generateur.image(
                    at: CMTime(seconds: secondes, preferredTimescale: 600)).image
            }
        } catch {
            throw ErreurImages.extractionImpossible(video, error.localizedDescription)
        }
    }

    /// Un fond uni, pour les contrôles internes seulement — jamais pour les
    /// images de référence, qui doivent être jugées sur de vraies images.
    static func fondUni(largeur: Int, hauteur: Int, gris: Double) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: largeur, height: hauteur, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: CGFloat(gris), green: CGFloat(gris),
                                 blue: CGFloat(gris), alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        return ctx.makeImage()
    }

    // MARK: - Choix des répliques

    /// Les répliques les plus longues d'un fichier — celles que la
    /// resegmentation découpe le plus, donc le pire cas.
    static func repliquesLesPlusLongues(_ cues: [Cue], combien: Int) -> [Cue] {
        cues.sorted { TextePython.longueur($0.texte) > TextePython.longueur($1.texte) }
            .prefix(combien)
            .map { $0 }
    }

    // MARK: - Recadrage vers un format

    /// Recadre une image au centre pour atteindre un rapport donné.
    ///
    /// Les formats 1:1 et 4:5 exigés par le lot n'existent pas tels quels dans
    /// les vidéos fournies : plutôt que d'inventer un fond, on recadre une
    /// vraie image. Ce que juge Éric reste une image réelle.
    static func recadrer(_ image: CGImage, versRapport rapport: Double) -> CGImage {
        let l = Double(image.width)
        let h = Double(image.height)
        var largeur = l
        var hauteur = h
        if l / h > rapport {
            largeur = h * rapport
        } else {
            hauteur = l / rapport
        }
        let rect = CGRect(
            x: ((l - largeur) / 2).rounded(),
            y: ((h - hauteur) / 2).rounded(),
            width: largeur.rounded(),
            height: hauteur.rounded())
        return image.cropping(to: rect) ?? image
    }

    // MARK: - Écriture

    static func ecrire(_ image: CGImage, vers url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ErreurImages.ecritureImpossible(url)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ErreurImages.ecritureImpossible(url)
        }
    }

    /// Assemble deux images côte à côte, avec un filet de séparation.
    ///
    /// La comparaison doit être immédiate : deux fichiers à ouvrir tour à tour
    /// ne montrent pas les mêmes écarts qu'une planche unique.
    static func cote(_ gauche: CGImage, _ droite: CGImage) -> CGImage? {
        let hauteur = max(gauche.height, droite.height)
        let filet = 4
        let largeur = gauche.width + filet + droite.width
        guard let ctx = CGContext(
            data: nil, width: largeur, height: hauteur, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        ctx.draw(gauche, in: CGRect(x: 0, y: hauteur - gauche.height,
                                    width: gauche.width, height: gauche.height))
        ctx.draw(droite, in: CGRect(x: gauche.width + filet, y: hauteur - droite.height,
                                    width: droite.width, height: droite.height))
        return ctx.makeImage()
    }

    /// Deux images diffèrent-elles ? Sert à vérifier qu'un rendu a bien peint
    /// quelque chose.
    static func differe(_ a: CGImage, de b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height else { return true }
        guard let da = a.dataProvider?.data as Data?,
              let db = b.dataProvider?.data as Data? else { return true }
        return da != db
    }
}
