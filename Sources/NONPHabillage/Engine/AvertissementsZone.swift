// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// AvertissementsZone.swift — ce qui ne va pas sans pour autant empêcher de graver.
//
// Portage de `avertissements_zone()` de nonp_habille.py. Le prototype les
// imprimait dans un terminal, juste avant un encodage de plusieurs minutes :
// autant dire que personne ne les lisait. L'aperçu du lot 5 les rend enfin
// utiles — on voit le défaut AVANT d'encoder, et on peut déplacer le logo à la
// souris pour le corriger sur-le-champ.
//
// Ce sont des AVERTISSEMENTS, jamais des erreurs : on peut vouloir un logo sur
// le bandeau. Ils informent, ils ne bloquent pas.
//
// Une amélioration sur le prototype : celui-ci comparait seulement le BAS du
// logo au HAUT de la zone des sous-titres, sans regarder l'horizontale. Un logo
// posé bas mais complètement à droite d'un bandeau `ajuste` étroit déclenchait
// donc une alerte pour rien. Ici, c'est un vrai recoupement de rectangles.

import Foundation
import CoreGraphics

/// Un avertissement, avec de quoi le montrer sur l'aperçu.
struct AvertissementZone: Identifiable, Equatable {
    enum Sorte: Equatable {
        /// Le logo empiète sur la zone réservée aux sous-titres.
        case logoSurBandeau
        /// Le logo sort des marges « title-safe » (5 % des bords).
        case logoHorsMargesSures
    }
    let sorte: Sorte
    let message: String
    var id: String { message }
}

enum AvertissementsZone {

    /// Marge « title-safe » : 5 % de chaque bord. En deçà, un élément risque
    /// d'être rogné par un lecteur ou une plateforme.
    static let margeSure = 0.05

    /// Examine un habillage et renvoie ce qui mérite d'être signalé.
    ///
    /// - Parameter avecSousTitres: faux quand aucun sous-titre n'est chargé —
    ///   il n'y a alors pas de zone de sous-titres à protéger.
    static func examiner(
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage,
        police: PoliceSousTitre,
        rectangleLogo: CGRect?,
        avecSousTitres: Bool,
        largeurVideo: Int,
        hauteurVideo: Int
    ) -> [AvertissementZone] {

        guard let rectangleLogo else { return [] }
        var avertissements: [AvertissementZone] = []

        // 1. Recoupement avec la zone des sous-titres.
        //
        // La zone est celle que le bandeau PEUT occuper, pas celle qu'occupe la
        // réplique affichée : une réplique d'une ligne aujourd'hui, deux lignes
        // trois secondes plus tard. On raisonne donc sur `lignesMax`.
        if avecSousTitres && profil.bandeauActif {
            let zone = zoneSousTitres(
                profil: profil, parametres: parametres, police: police,
                largeurVideo: largeurVideo)
            if rectangleLogo.intersects(zone) {
                let conseil = conseilBandeau(
                    profil: profil, parametres: parametres, police: police,
                    rectangleLogo: rectangleLogo,
                    largeurVideo: largeurVideo, hauteurVideo: hauteurVideo)
                avertissements.append(AvertissementZone(
                    sorte: .logoSurBandeau,
                    message: Textes.Avertissements.logoSurBandeau(conseil: conseil)))
            }
        }

        // 2. Marges sûres — seulement pour un placement libre. Les quatre coins
        //    sont réputés sûrs : ils utilisent la marge du profil, qui est là
        //    pour ça. Le prototype fait le même choix.
        if case .libre = profil.logoPosition {
            let mx = Double(largeurVideo) * margeSure
            let my = Double(hauteurVideo) * margeSure
            let sures = CGRect(x: mx, y: my,
                               width: Double(largeurVideo) - 2 * mx,
                               height: Double(hauteurVideo) - 2 * my)
            if !sures.contains(rectangleLogo) {
                avertissements.append(AvertissementZone(
                    sorte: .logoHorsMargesSures,
                    message: Textes.Avertissements.logoHorsMargesSures))
            }
        }

        return avertissements
    }

    // MARK: - Conseil

    /// Ce qu'il faut conseiller quand le logo empiète sur la zone des
    /// sous-titres — et SEULEMENT ce qui marche.
    ///
    /// Chaque action candidate est SIMULÉE dans la vraie géométrie, aux bornes
    /// des curseurs : la plus petite taille de logo, la marge basse la plus
    /// haute ou la plus basse, un coin du haut. Une action n'entre dans le
    /// conseil que si elle lève l'avertissement. Rien n'est déduit d'une règle
    /// générale qui aurait ses exceptions — mesuré, « réduire » levait
    /// l'avertissement d'un coin bas à 1–3 % de taille, et un coin haut
    /// empiétait aux extrêmes.
    ///
    /// Le texte suit le placement, comme décidé le 17/09 :
    /// - coin bas : un coin du haut, ou relever la marge basse — jamais
    ///   réduire ;
    /// - placement libre : remonter, ou réduire si la plus petite taille suffit
    ///   — sinon « le réduire ne suffira pas » ; remonter est simulé aussi,
    ///   logo porté tout en haut de l'image ;
    /// - coin haut : réduire, ou abaisser la marge basse.
    static func conseilBandeau(
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage,
        police: PoliceSousTitre,
        rectangleLogo: CGRect,
        largeurVideo: Int,
        hauteurVideo: Int
    ) -> String? {
        /// Le logo empiète-t-il encore, le profil modifié ? Diamètre du logo et
        /// marge basse sont recalculés par le moteur de mise en page lui-même,
        /// sans en recopier les formules.
        func empiete(_ p: ProfilHabillage) -> Bool {
            let recalcul = MoteurMiseEnPage.calculer(
                profil: p, largeur: largeurVideo, hauteur: hauteurVideo,
                tailleForcee: parametres.taille)
            var q = parametres
            q.diametreLogo = recalcul.diametreLogo
            q.margeLogo = recalcul.margeLogo
            q.margeBasse = recalcul.margeBasse
            let rect = GeometrieLogo.rectangle(
                profil: p, parametres: q, tailleSource: rectangleLogo.size,
                largeurVideo: largeurVideo, hauteurVideo: hauteurVideo)
            let zone = zoneSousTitres(profil: p, parametres: q, police: police,
                                      largeurVideo: largeurVideo)
            return rect.intersects(zone)
        }
        var plusPetit = profil
        plusPetit.logoTailleRatio = BornesReglages.tailleLogo.lowerBound
        var margeHaute = profil
        margeHaute.margeBasseRatio = BornesReglages.margeBasse.upperBound
        var margeNulle = profil
        margeNulle.margeBasseRatio = BornesReglages.margeBasse.lowerBound

        let T = Textes.Avertissements.self
        switch profil.logoPosition {
        case .coin(let coin) where coin == .basGauche || coin == .basDroit:
            var enHaut = profil
            enHaut.logoPosition = .coin(coin == .basGauche ? .hautGauche : .hautDroit)
            switch (!empiete(enHaut), !empiete(margeHaute)) {
            case (true, true): return T.conseilCoinHautOuMargeBasse
            case (true, false): return T.conseilCoinHaut
            case (false, true): return T.conseilRelever
            case (false, false): return nil
            }
        case .coin:
            switch (!empiete(plusPetit), !empiete(margeNulle)) {
            case (true, true): return T.conseilReduireOuAbaisserMarge
            case (true, false): return T.conseilReduire
            case (false, true): return T.conseilAbaisserMarge
            case (false, false): return nil
            }
        case .libre(let xPct, _):
            // Remonté tout en haut — la position est bornée à l'image.
            var enHaut = profil
            enHaut.logoPosition = .libre(xPct: xPct, yPct: 0)
            switch (!empiete(enHaut), !empiete(plusPetit)) {
            case (true, true): return T.conseilRemonterOuReduire
            case (true, false): return T.conseilRemonterSeulement
            case (false, true): return T.conseilReduire
            case (false, false): return nil
            }
        }
    }

    /// Le rectangle que les sous-titres peuvent occuper, à `lignesMax` lignes.
    static func zoneSousTitres(
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage,
        police: PoliceSousTitre,
        largeurVideo: Int
    ) -> CGRect {
        let lignes = max(1, max(profil.lignesMax, profil.bandeauHauteurFixeLignes))
        let hauteur = Double(lignes) * police.hauteurLigne
            + 2 * Double(parametres.paddingBandeau)
        // En largeur, on prend toute l'image : en mode `ajuste`, la largeur du
        // fond dépend de la réplique, et une réplique plus longue viendra.
        return CGRect(x: 0, y: Double(parametres.margeBasse),
                      width: Double(largeurVideo), height: hauteur)
    }
}
