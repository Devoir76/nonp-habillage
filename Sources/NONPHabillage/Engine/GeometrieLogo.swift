// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// GeometrieLogo.swift — où se pose le logo, et quelle taille il occupe.
//
// Portage de `position_logo()` de nonp_habille.py, avec une correction imposée
// par le schéma partagé.
//
// ── Deux repères qui ne sont pas le même ─────────────────────────────────────
//
// Le prototype calcule dans le repère de `ffmpeg overlay` : origine en HAUT à
// gauche, y qui descend. Core Graphics compte à l'envers : origine en BAS à
// gauche, y qui monte. Les formules sont donc reprises telles quelles, puis
// converties en un seul endroit — plutôt que de retourner chaque calcul, ce qui
// aurait fini par produire un logo « bas-gauche » en haut de l'image sans que
// personne ne sache où l'erreur s'était glissée.
//
// ── Le ratio est préservé ────────────────────────────────────────────────────
//
// Le prototype impose `scale=diam:diam` : un logo rectangulaire est ÉCRASÉ en
// carré. Le schéma partagé, lui, dit « plus grande dimension du logo en % de la
// HAUTEUR vidéo, ratio préservé ». C'est le schéma qui fait foi (invariant nº6),
// donc le ratio est préservé ici. Sur le logo NONP, qui est un disque dans une
// image carrée, les deux donnent exactement le même résultat — la divergence ne
// se voit que sur un logo non carré, où le prototype le déformait.

import Foundation
import CoreGraphics

enum GeometrieLogo {

    /// Calcule le rectangle du logo, dans le repère de Core Graphics
    /// (origine en bas à gauche).
    ///
    /// - Parameters:
    ///   - tailleSource: dimensions en pixels de l'image du logo.
    ///   - parametres: fournit le diamètre et la marge, déjà dérivés de la
    ///     hauteur vidéo avec les minima du prototype (24 px et 6 px).
    static func rectangle(
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage,
        tailleSource: CGSize,
        largeurVideo: Int,
        hauteurVideo: Int
    ) -> CGRect {

        let (largeur, hauteur) = dimensions(
            tailleSource: tailleSource, plusGrandeDimension: parametres.diametreLogo)

        // Coin supérieur gauche, dans le repère du prototype (y vers le bas).
        let hautGaucheY: Double
        let x: Double
        let marge = Double(parametres.margeLogo)
        let lv = Double(largeurVideo)
        let hv = Double(hauteurVideo)

        switch profil.logoPosition {
        case .coin(let coin):
            switch coin {
            case .hautGauche: x = marge;                 hautGaucheY = marge
            case .hautDroit:  x = lv - largeur - marge;  hautGaucheY = marge
            case .basGauche:  x = marge;                 hautGaucheY = hv - hauteur - marge
            case .basDroit:   x = lv - largeur - marge;  hautGaucheY = hv - hauteur - marge
            }
        case .libre(let xPct, let yPct):
            // x_pct / y_pct désignent le CENTRE du logo.
            let brutX = Double(TextePython.arrondi(lv * xPct / 100.0 - largeur / 2.0))
            let brutY = Double(TextePython.arrondi(hv * yPct / 100.0 - hauteur / 2.0))
            // Bornés pour rester dans l'image, comme le prototype.
            x = max(0, min(brutX, lv - largeur))
            hautGaucheY = max(0, min(brutY, hv - hauteur))
        }

        // Conversion vers Core Graphics : le bas du logo est à la hauteur de
        // l'image moins son sommet, moins sa propre hauteur.
        let y = hv - hautGaucheY - hauteur
        return CGRect(x: x, y: y, width: largeur, height: hauteur)
    }

    /// Dimensions du logo, ratio préservé, la plus grande dimension valant
    /// `plusGrandeDimension`.
    static func dimensions(
        tailleSource: CGSize, plusGrandeDimension: Int
    ) -> (largeur: Double, hauteur: Double) {
        let cible = Double(plusGrandeDimension)
        guard tailleSource.width > 0, tailleSource.height > 0 else {
            return (cible, cible)
        }
        let l = Double(tailleSource.width)
        let h = Double(tailleSource.height)
        if l >= h {
            return (cible, (cible * h / l).rounded())
        }
        return ((cible * l / h).rounded(), cible)
    }

    /// La position que calculerait le prototype, dans SON repère (origine en
    /// haut à gauche) et avec SA contrainte de logo carré.
    ///
    /// Présent pour rendre la parité mesurable, comme
    /// `MoteurMiseEnPage.calculerCommeLePrototype`. Rien dans l'application ne
    /// l'appelle.
    static func positionCommeLePrototype(
        profil: ProfilHabillage, parametres: ParametresMiseEnPage,
        largeurVideo: Int, hauteurVideo: Int
    ) -> (x: Int, y: Int) {
        let diam = parametres.diametreLogo
        let marge = parametres.margeLogo
        switch profil.logoPosition {
        case .coin(let coin):
            switch coin {
            case .hautGauche: return (marge, marge)
            case .hautDroit:  return (largeurVideo - diam - marge, marge)
            case .basGauche:  return (marge, hauteurVideo - diam - marge)
            case .basDroit:   return (largeurVideo - diam - marge, hauteurVideo - diam - marge)
            }
        case .libre(let xPct, let yPct):
            let x = TextePython.arrondi(Double(largeurVideo) * xPct / 100.0 - Double(diam) / 2.0)
            let y = TextePython.arrondi(Double(hauteurVideo) * yPct / 100.0 - Double(diam) / 2.0)
            return (max(0, min(x, largeurVideo - diam)),
                    max(0, min(y, hauteurVideo - diam)))
        }
    }
}
