// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// LogoRond.swift — recadrer un logo en cercle, proprement.
//
// Portage de `make_logo()` de nonp_habille.py, qui fabriquait le
// `logo_circle.png` du prototype :
//
//     scale=iw*4:ih*4, masque alpha circulaire, scale=iw/4:ih/4
//
// C'est du SUR-ÉCHANTILLONNAGE : on agrandit quatre fois, on découpe le cercle
// sur cette grande image — où l'escalier des pixels est quatre fois plus fin —,
// puis on réduit. La réduction moyenne les pixels du bord et lisse le contour.
// Le procédé est repris tel quel : il donne un bord franc mais sans dentelure,
// et il ne dépend d'aucun réglage d'anticrénelage.
//
// DEUX DIFFÉRENCES avec le prototype, toutes deux voulues :
//
// 1. Le prototype prend `W/2` comme rayon quel que soit le format : sur une
//    image plus haute que large, le cercle déborde et se fait couper. Ici,
//    l'image est d'abord recadrée sur son CARRÉ CENTRAL, puis le cercle y est
//    inscrit. Un logo rectangulaire donne donc un vrai rond.
// 2. Le prototype écrivait un fichier, qu'il fallait fabriquer avant d'habiller.
//    Ici le recadrage est un RÉGLAGE, appliqué au vol et réversible : on le
//    coche, on voit le résultat dans l'aperçu, on le décoche. Aucun fichier
//    n'est écrit à côté du logo de l'utilisateur.

import Foundation
import CoreGraphics

enum LogoRond {

    /// Facteur de sur-échantillonnage. Quatre, comme le prototype.
    static let surEchantillonnage = 4

    /// Renvoie l'image recadrée en cercle, fond transparent.
    ///
    /// L'image est d'abord ramenée à son carré central, puis le disque inscrit
    /// est conservé et le reste rendu transparent.
    static func recadrerEnCercle(_ image: CGImage) -> CGImage? {
        let carre = carreCentral(de: image)
        let cote = carre.width
        let grand = cote * surEchantillonnage

        guard let ctx = CGContext(
            data: nil, width: grand, height: grand, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        // Découpe du disque sur la grande image : l'escalier des pixels y est
        // quatre fois plus fin que sur l'image finale.
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        let cadre = CGRect(x: 0, y: 0, width: grand, height: grand)
        ctx.addEllipse(in: cadre)
        ctx.clip()
        ctx.draw(carre, in: cadre)

        guard let agrandie = ctx.makeImage() else { return nil }

        // Réduction : c'est elle qui moyenne les pixels du bord et lisse le
        // contour. Sans cette étape, le cercle serait dentelé.
        guard let reduction = CGContext(
            data: nil, width: cote, height: cote, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        reduction.interpolationQuality = .high
        reduction.draw(agrandie, in: CGRect(x: 0, y: 0, width: cote, height: cote))
        return reduction.makeImage()
    }

    /// Le carré central d'une image, pour que le cercle soit inscrit et non coupé.
    static func carreCentral(de image: CGImage) -> CGImage {
        let cote = min(image.width, image.height)
        guard image.width != image.height else { return image }
        let rect = CGRect(
            x: (image.width - cote) / 2, y: (image.height - cote) / 2,
            width: cote, height: cote)
        return image.cropping(to: rect) ?? image
    }
}
