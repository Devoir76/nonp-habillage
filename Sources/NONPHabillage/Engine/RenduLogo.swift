// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// RenduLogo.swift — le logo, chargé et posé sur un calque.
//
// Le logo ne bouge pas d'une image à l'autre : son calque se calcule UNE fois
// pour toute la vidéo. C'est la différence avec les sous-titres, dont le calque
// change à chaque réplique.
//
// Comme pour la police (invariant nº4), un fichier absent ou illisible est une
// ERREUR EXPLICITE. Poser un habillage sans le logo qu'on a demandé, en
// silence, produirait une vidéo fausse que l'on ne découvrirait qu'après
// l'encodage — ou pire, après diffusion.

import Foundation
import CoreGraphics
import ImageIO

enum ErreurLogo: Error {
    case fichierIntrouvable(URL)
    case imageIllisible(URL)
}

enum RenduLogo {

    /// Charge l'image d'un logo.
    static func charger(_ url: URL) throws -> CGImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ErreurLogo.fichierIntrouvable(url)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ErreurLogo.imageIllisible(url)
        }
        return image
    }

    /// Peint le logo sur un calque transparent aux dimensions de la vidéo.
    ///
    /// Renvoie `nil` quand il n'y a rien à poser — profil sans logo, ou aucun
    /// fichier fourni. Ce n'est pas une erreur : « vidéo + sous-titres seuls »
    /// est un usage de premier rang de l'ADR.
    static func calque(
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage,
        largeur: Int,
        hauteur: Int
    ) throws -> CGImage? {
        guard profil.logoActif, let fichier = profil.logoFichier else { return nil }

        let source = try charger(fichier)
        let rect = GeometrieLogo.rectangle(
            profil: profil, parametres: parametres,
            tailleSource: CGSize(width: source.width, height: source.height),
            largeurVideo: largeur, hauteurVideo: hauteur)

        guard let ctx = CGContext(
            data: nil, width: largeur, height: hauteur,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ErreurRendu.contexteIndisponible }

        // L'opacité s'applique à la couche entière, pas au fichier : un PNG à
        // fond transparent garde ses bords nets, et le réglage du profil reste
        // réversible.
        ctx.setAlpha(CGFloat(max(0, min(1, profil.logoOpacite))))
        // Interpolation haute : le logo est presque toujours réduit, et un
        // rééchantillonnage grossier se voit immédiatement sur un cercle.
        ctx.interpolationQuality = .high
        ctx.draw(source, in: rect)

        guard let image = ctx.makeImage() else { throw ErreurRendu.contexteIndisponible }
        return image
    }
}
