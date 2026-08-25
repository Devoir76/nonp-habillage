// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ImagesVideo.swift — lire une vidéo : ses dimensions, sa durée, ses images.
//
// Ce code servait au lot 3 depuis le harnais de vérification. L'aperçu du lot 5
// en a besoin lui aussi, et c'est un service du MOTEUR, pas de la vérification :
// il vit donc ici, et le harnais l'appelle comme le reste de l'application.
//
// Tout passe par AVFoundation — invariant nº3, aucune dépendance non-Apple.

import Foundation
import AVFoundation
import CoreGraphics

enum ErreurVideo: Error {
    case pisteVideoAbsente(URL)
    case extractionImpossible(URL, String)
}

enum ImagesVideo {

    /// Dimensions en pixels, **orientation appliquée**.
    ///
    /// La taille naturelle ignore la rotation : une vidéo filmée au téléphone
    /// ressortirait en 1920×1080 alors qu'elle s'affiche en 1080×1920. La
    /// transformation la remet d'aplomb — c'est exactement le piège du format
    /// vertical que l'ADR §5 corrige, il serait absurde de le rouvrir ici.
    static func dimensions(de video: URL) async throws -> CGSize {
        let asset = AVURLAsset(url: video)
        guard let piste = try await asset.loadTracks(withMediaType: .video).first else {
            throw ErreurVideo.pisteVideoAbsente(video)
        }
        let (naturelle, transformation) = try await piste.load(
            .naturalSize, .preferredTransform)
        let orientee = naturelle.applying(transformation)
        return CGSize(width: abs(orientee.width).rounded(),
                      height: abs(orientee.height).rounded())
    }

    /// Durée en secondes.
    static func duree(de video: URL) async throws -> Double {
        try await AVURLAsset(url: video).load(.duration).seconds
    }

    /// Extrait une image à un instant donné, orientation appliquée.
    static func image(de video: URL, a secondes: Double) async throws -> CGImage {
        let generateur = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generateur.appliesPreferredTrackTransform = true
        generateur.requestedTimeToleranceBefore = .zero
        generateur.requestedTimeToleranceAfter = .zero
        do {
            return try await generateur.image(
                at: CMTime(seconds: secondes, preferredTimescale: 600)).image
        } catch {
            throw ErreurVideo.extractionImpossible(video, error.localizedDescription)
        }
    }

    /// Plusieurs instants répartis dans la vidéo, avec leur luminosité moyenne.
    ///
    /// L'ADR veut que le fond de l'aperçu soit choisissable « parmi plusieurs
    /// instants de la vidéo — au moins un plan clair et un plan sombre ». C'est
    /// « le seul moyen honnête de choisir une couleur de texte ou de bandeau » :
    /// un blanc à contour noir qui convient sur un plan sombre peut devenir
    /// illisible sur un plan clair.
    ///
    /// Les extrémités sont évitées : beaucoup de vidéos commencent ou finissent
    /// sur du noir, et deux fonds noirs n'apprennent rien.
    static func instantsRepresentatifs(
        de video: URL, combien: Int = 6
    ) async throws -> [(instant: Double, image: CGImage, luminosite: Double)] {
        let duree = try await duree(de: video)
        guard duree > 0 else { return [] }

        var resultats: [(Double, CGImage, Double)] = []
        for i in 0..<combien {
            let fraction = (Double(i) + 0.5) / Double(combien)
            let instant = min(duree - 0.05, max(0, duree * fraction))
            guard let image = try? await image(de: video, a: instant) else { continue }
            resultats.append((instant, image, luminositeMoyenne(image)))
        }
        return resultats
    }

    /// Luminosité moyenne d'une image, de 0 (noir) à 1 (blanc).
    ///
    /// Échantillonnée sur une grille : parcourir tous les pixels d'une image 4K
    /// pour un simple classement clair/sombre serait du gaspillage.
    static func luminositeMoyenne(_ image: CGImage) -> Double {
        let cote = 32
        guard let ctx = CGContext(
            data: nil, width: cote, height: cote, bitsPerComponent: 8,
            bytesPerRow: cote * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let base = ctx.data else { return 0.5 }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: cote, height: cote))
        let pixels = base.bindMemory(to: UInt8.self, capacity: cote * cote * 4)
        var somme = 0.0
        for i in stride(from: 0, to: cote * cote * 4, by: 4) {
            // Pondération perceptuelle : l'œil est bien plus sensible au vert
            // qu'au bleu. Une moyenne brute classerait mal un plan très bleu.
            somme += 0.2126 * Double(pixels[i])
                + 0.7152 * Double(pixels[i + 1])
                + 0.0722 * Double(pixels[i + 2])
        }
        return somme / Double(cote * cote) / 255.0
    }
}
