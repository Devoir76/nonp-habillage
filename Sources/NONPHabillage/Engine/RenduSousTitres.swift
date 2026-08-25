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
        miseEnPage: MiseEnPageRendu,
        calqueLogo: CGImage? = nil
    ) throws -> CGImage {

        let largeur = fond.width
        let hauteur = fond.height
        let parametres = miseEnPage.parametres
        let police = miseEnPage.police

        let lignesFinales = lignes ?? miseEnPage.decouper(texte ?? "")

        let replique = GeometrieSousTitres.poser(
            lignes: lignesFinales, profil: profil, parametres: parametres,
            police: police, largeurVideo: largeur, hauteurVideo: hauteur)

        let couche = coucheDe(replique: replique, police: police, profil: profil,
                              parametres: parametres, largeur: largeur, hauteur: hauteur)

        guard let ctx = contexte(largeur: largeur, hauteur: hauteur)
        else { throw ErreurRendu.contexteIndisponible }

        ctx.draw(fond, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        // Le logo AVANT les sous-titres, comme dans la composition vidéo : un
        // logo mal placé ne doit jamais masquer une réplique.
        if let calqueLogo {
            ctx.draw(calqueLogo, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        }
        couche.setNeedsDisplay()
        couche.render(in: ctx)

        guard let image = ctx.makeImage() else { throw ErreurRendu.contexteIndisponible }
        return image
    }

    /// Peint l'habillage seul, sur fond TRANSPARENT.
    ///
    /// C'est cette forme qu'attend la composition vidéo du lot 4 : elle superpose
    /// l'habillage à chaque image de la vidéo, sans jamais la redessiner. Une
    /// réplique ne changeant pas pendant qu'elle est à l'écran, l'image produite
    /// ici se calcule UNE fois et sert pour toutes les images de la réplique —
    /// autrement Core Text retracerait les mêmes glyphes trente fois par seconde.
    static func calque(
        lignes: [String],
        profil: ProfilHabillage,
        miseEnPage: MiseEnPageRendu,
        largeur: Int,
        hauteur: Int
    ) throws -> CGImage {
        let replique = GeometrieSousTitres.poser(
            lignes: lignes, profil: profil, parametres: miseEnPage.parametres,
            police: miseEnPage.police, largeurVideo: largeur, hauteurVideo: hauteur)

        let couche = coucheDe(replique: replique, police: miseEnPage.police,
                              profil: profil, parametres: miseEnPage.parametres,
                              largeur: largeur, hauteur: hauteur)

        guard let ctx = contexte(largeur: largeur, hauteur: hauteur)
        else { throw ErreurRendu.contexteIndisponible }
        couche.setNeedsDisplay()
        couche.render(in: ctx)

        guard let image = ctx.makeImage() else { throw ErreurRendu.contexteIndisponible }
        return image
    }

    // MARK: - Fabrique

    private static func coucheDe(
        replique: RepliquePosee, police: PoliceSousTitre, profil: ProfilHabillage,
        parametres: ParametresMiseEnPage, largeur: Int, hauteur: Int
    ) -> CoucheSousTitres {
        let couche = CoucheSousTitres()
        couche.frame = CGRect(x: 0, y: 0, width: largeur, height: hauteur)
        couche.contentsScale = 1
        couche.isGeometryFlipped = false
        couche.replique = replique
        couche.police = police
        couche.profil = profil
        couche.epaisseurContour = Double(parametres.contour)
        return couche
    }

    private static func contexte(largeur: Int, hauteur: Int) -> CGContext? {
        CGContext(
            data: nil, width: largeur, height: hauteur,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
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
