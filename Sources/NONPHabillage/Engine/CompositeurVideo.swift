// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// CompositeurVideo.swift — l'habillage posé sur chaque image de la vidéo.
//
// Une `AVMutableVideoComposition` qui, pour chaque image, superpose le calque de
// sous-titres correspondant à l'instant demandé. Rien d'autre : la vidéo n'est
// ni redessinée, ni redimensionnée, ni retouchée.
//
// UNE RÉPLIQUE NE CHANGE PAS PENDANT QU'ELLE EST À L'ÉCRAN. Le calque se calcule
// donc une fois par réplique et sert pour toutes ses images. Sans ce cache, Core
// Text retracerait les mêmes glyphes trente fois par seconde — sur une vidéo de
// dix minutes, c'est 18 000 tracés au lieu d'une centaine.
//
// Le choix de `applyingCIFiltersWithHandler` plutôt qu'un compositeur sur mesure
// tient à une contrainte du lot 4 : l'export passe par un `AVAssetWriter` (voir
// `ExportateurVideo` pour le pourquoi), et `AVVideoCompositionCoreAnimationTool`
// — la voie CALayer habituelle — ne fonctionne QU'AVEC `AVAssetExportSession`.
// Le calque reste néanmoins peint par le `CALayer` du lot 3 : c'est le même code
// de rendu, simplement rasterisé en amont.

import Foundation
import AVFoundation
import CoreImage
import CoreGraphics

enum CompositeurVideo {

    /// Construit la composition qui grave les sous-titres sur la vidéo.
    ///
    /// - Parameters:
    ///   - cues: les répliques déjà resegmentées, avec leurs minutages de rendu.
    ///   - taille: dimensions de rendu, orientation appliquée.
    static func composition(
        pour asset: AVAsset,
        cues: [CueGravee],
        profil: ProfilHabillage,
        miseEnPage: MiseEnPageRendu,
        taille: CGSize
    ) -> AVMutableVideoComposition {

        let largeur = Int(taille.width)
        let hauteur = Int(taille.height)

        // Les calques, calculés à la demande et gardés : un par réplique.
        let cache = CacheCalques(
            cues: cues, profil: profil, miseEnPage: miseEnPage,
            largeur: largeur, hauteur: hauteur)

        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { requete in
                let source = requete.sourceImage
                guard let calque = cache.calque(
                    aSecondes: requete.compositionTime.seconds) else {
                    requete.finish(with: source, context: nil)
                    return
                }
                // Le calque est fabriqué aux dimensions de rendu ; l'image
                // source peut avoir une autre origine selon la piste. On aligne
                // sur son étendue réelle plutôt que de supposer (0, 0).
                let ciCalque = CIImage(cgImage: calque)
                    .transformed(by: CGAffineTransform(
                        translationX: source.extent.origin.x,
                        y: source.extent.origin.y))
                requete.finish(with: ciCalque.composited(over: source), context: nil)
            })

        composition.renderSize = taille
        return composition
    }
}

/// Garde le calque de la réplique en cours, et ne le recalcule qu'au changement.
///
/// Une classe, et non une structure : le gestionnaire de la composition est
/// appelé image par image et doit retrouver l'état d'un appel à l'autre.
private final class CacheCalques: @unchecked Sendable {

    private let cues: [CueGravee]
    private let profil: ProfilHabillage
    private let miseEnPage: MiseEnPageRendu
    private let largeur: Int
    private let hauteur: Int

    private let verrou = NSLock()
    private var indexEnCache: Int?
    private var calqueEnCache: CGImage?

    init(cues: [CueGravee], profil: ProfilHabillage, miseEnPage: MiseEnPageRendu,
         largeur: Int, hauteur: Int) {
        self.cues = cues
        self.profil = profil
        self.miseEnPage = miseEnPage
        self.largeur = largeur
        self.hauteur = hauteur
    }

    /// Le calque à afficher à cet instant, ou `nil` s'il n'y a pas de réplique.
    func calque(aSecondes secondes: Double) -> CGImage? {
        let ms = Int((secondes * 1000).rounded())
        guard let index = indexDeLaReplique(aMs: ms) else { return nil }

        verrou.lock()
        defer { verrou.unlock() }
        if indexEnCache == index, let calque = calqueEnCache { return calque }

        let calque = try? RenduSousTitres.calque(
            lignes: cues[index].lignes, profil: profil, miseEnPage: miseEnPage,
            largeur: largeur, hauteur: hauteur)
        indexEnCache = index
        calqueEnCache = calque
        return calque
    }

    /// Recherche dichotomique : les répliques sont triées et ne se recouvrent
    /// pas. Un balayage linéaire coûterait, sur une heure de vidéo, autant de
    /// comparaisons que d'images multipliées par le nombre de répliques.
    private func indexDeLaReplique(aMs ms: Int) -> Int? {
        var bas = 0
        var haut = cues.count - 1
        while bas <= haut {
            let milieu = (bas + haut) / 2
            let cue = cues[milieu]
            if ms < cue.debutMs {
                haut = milieu - 1
            } else if ms >= cue.finMs {
                bas = milieu + 1
            } else {
                return milieu
            }
        }
        return nil
    }
}
