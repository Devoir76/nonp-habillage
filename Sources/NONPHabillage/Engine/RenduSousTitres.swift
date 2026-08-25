// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// RenduSousTitres.swift — le tracé, dans un CALayer.
//
// Pourquoi un CALayer et pas un simple contexte bitmap ? Parce que c'est la
// couche que le lot 4 donnera à `AVMutableVideoComposition` : une
// `CALayer` d'habillage composée au-dessus de la vidéo. En la construisant dès
// maintenant, le rendu sur image fixe et le rendu sur vidéo partageront le même
// code — le lot 3 se valide donc sur ce qui servira vraiment, pas sur un
// brouillon qu'il faudrait réécrire.
//
// Le contour est tracé à partir du CHEMIN des glyphes, pas de l'attribut
// `strokeWidth` de Core Text : voir `PoliceSousTitre.cheminGlyphes(de:)`.
// L'ordre compte — contour d'abord, remplissage ensuite — sinon le trait
// mordrait sur la lettre et l'amincirait.

import Foundation
import CoreGraphics
import CoreText
import QuartzCore

/// La couche d'habillage : bandeaux et texte d'une réplique.
///
/// Elle se dessine dans le repère pixel de la vidéo, origine en bas à gauche.
final class CoucheSousTitres: CALayer {

    var replique: RepliquePosee?
    var police: PoliceSousTitre?
    var profil: ProfilHabillage = .neutre
    var epaisseurContour: Double = 0

    override func draw(in ctx: CGContext) {
        guard let replique, let police else { return }

        // Les bandeaux d'abord : ils sont sous le texte.
        if !replique.bandeaux.isEmpty {
            ctx.setFillColor(profil.bandeauCouleur.cgColor)
            for rect in replique.bandeaux {
                ctx.fill(rect)
            }
        }

        for ligne in replique.lignes {
            let chemin = police.cheminGlyphes(de: ligne.texte)
            let place = chemin.copy(using: [CGAffineTransform(
                translationX: ligne.baseline.x, y: ligne.baseline.y)]) ?? chemin

            // Contour : le trait est centré sur le bord du glyphe, donc une
            // épaisseur double laisse dehors exactement ce que le profil
            // annonce.
            if epaisseurContour > 0 {
                ctx.saveGState()
                ctx.addPath(place)
                ctx.setStrokeColor(profil.contourCouleur.cgColor)
                ctx.setLineWidth(CGFloat(epaisseurContour * 2))
                ctx.setLineJoin(.round)
                ctx.setLineCap(.round)
                ctx.strokePath()
                ctx.restoreGState()
            }

            ctx.addPath(place)
            ctx.setFillColor(profil.couleurTexte.cgColor)
            ctx.fillPath()
        }
    }
}

enum RenduSousTitres {

    /// Compose une réplique par-dessus une image de fond et rend le tout.
    ///
    /// - Parameter lignes: les lignes déjà découpées. `nil` pour laisser la
    ///   géométrie les découper elle-même, par mesure exacte.
    static func rendre(
        fond: CGImage,
        texte: String? = nil,
        lignes: [String]? = nil,
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage
    ) throws -> CGImage {

        let largeur = fond.width
        let hauteur = fond.height

        // Invariant nº4 : une famille absente arrête ici, avec un message.
        let police = try PoliceSousTitre(famille: profil.police, taille: parametres.taille)

        let largeurUtile = GeometrieSousTitres.largeurUtile(
            profil: profil, parametres: parametres,
            largeurVideo: largeur, police: police)
        let lignesFinales = lignes ?? GeometrieSousTitres.decouper(
            texte: texte ?? "", police: police, largeurUtile: largeurUtile)

        let replique = GeometrieSousTitres.poser(
            lignes: lignesFinales, profil: profil, parametres: parametres,
            police: police, largeurVideo: largeur, hauteurVideo: hauteur)

        let couche = CoucheSousTitres()
        couche.frame = CGRect(x: 0, y: 0, width: largeur, height: hauteur)
        couche.contentsScale = 1
        couche.isGeometryFlipped = false
        couche.replique = replique
        couche.police = police
        couche.profil = profil
        couche.epaisseurContour = Double(parametres.contour)

        guard let ctx = CGContext(
            data: nil, width: largeur, height: hauteur,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ErreurRendu.contexteIndisponible }

        ctx.draw(fond, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        couche.setNeedsDisplay()
        couche.render(in: ctx)

        guard let image = ctx.makeImage() else { throw ErreurRendu.contexteIndisponible }
        return image
    }
}

enum ErreurRendu: Error {
    case contexteIndisponible
}

extension CouleurProfil {
    var cgColor: CGColor {
        CGColor(red: CGFloat(rouge), green: CGFloat(vert), blue: CGFloat(bleu),
                alpha: CGFloat(opacite))
    }
}
