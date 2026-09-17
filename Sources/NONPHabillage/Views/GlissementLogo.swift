// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// GlissementLogo.swift — le logo déplacé à la souris sur l'aperçu.
//
// ADR : « position libre en coordonnées relatives, x/y désignant le centre du
// logo ». Toute la difficulté est de passer d'un geste en points d'écran à une
// fraction de l'image, sans se tromper de repère.
//
// ── Le défaut corrigé le 17/09/2026 ─────────────────────────────────────────
//
// Le geste lisait la POSITION du pointeur dans l'espace de coordonnées nommé
// « apercu » — déclaré sur le contenu entier de la fenêtre —, et la divisait par
// la taille de l'image, comme si elle comptait depuis le coin de l'image. Elle
// comptait depuis le coin de la fenêtre : la barre des dépôts, les marges et le
// centrage s'y ajoutaient. Mesuré, l'image commençait à (16, 371) en 16:9 et à
// (268, 345) en 9:16 dans cet espace :
//
//   · logo en haut à gauche, un pas vers la droite : il tombait à y = 0,94,
//     borné au bas de l'image — « glisser vers la droite le fait descendre » ;
//   · y ne pouvait descendre sous 0,84 en 16:9 : le centre était inatteignable,
//     et tout glissement dérivait vers le bas ;
//   · en 9:16, x partait au-delà de 0,97 : le logo sautait en bas à droite.
//
// ── Ce qui le rend impossible désormais ─────────────────────────────────────
//
// Aucune position absolue n'est lue. Le logo part de SON centre au moment où on
// le saisit, et suit la TRANSLATION du pointeur rapportée à la taille affichée
// de l'image. Une translation ne dépend d'aucune origine : il n'y a plus de
// repère à confondre. Elle se lit dans l'espace GLOBAL, qui ne bouge pas —
// lue dans l'espace de la poignée, qui se déplace avec le logo, elle se
// réduirait à mesure que le logo la suit.
//
// Les calculs sont ici, en fonctions pures, pour que le harnais les éprouve :
// on ne peut pas y simuler un glissement de souris — AppKit ignore les
// événements synthétiques, essayé de six façons.

import CoreGraphics

enum GlissementLogo {

    /// Le centre du logo, en fractions de l'image, origine en HAUT à gauche —
    /// le repère du schéma et de l'écran.
    ///
    /// `rectangle` est dans le repère de Core Graphics (origine en BAS à
    /// gauche), comme le rend `GeometrieLogo` : d'où le retournement de y.
    static func centre(rectangle: CGRect, image: CGSize) -> CGPoint {
        guard image.width > 0, image.height > 0 else { return .zero }
        return CGPoint(x: rectangle.midX / image.width,
                       y: (image.height - rectangle.midY) / image.height)
    }

    /// Où poser le centre du logo : là où il était à la saisie, décalé de la
    /// translation du pointeur. Une translation de toute la largeur affichée
    /// vaut une largeur d'image.
    static func position(centreDepart: CGPoint, translation: CGSize,
                         affichee: CGSize) -> CGPoint {
        guard affichee.width > 0, affichee.height > 0 else { return centreDepart }
        return CGPoint(x: centreDepart.x + translation.width / affichee.width,
                       y: centreDepart.y + translation.height / affichee.height)
    }

    /// Le cadre du logo sur l'image affichée, origine en HAUT à gauche : la
    /// zone que la poignée doit couvrir.
    static func cadreAffiche(rectangle: CGRect, image: CGSize,
                             affichee: CGSize) -> CGRect {
        guard image.width > 0 else { return .zero }
        let echelle = affichee.width / image.width
        return CGRect(x: rectangle.minX * echelle,
                      y: (image.height - rectangle.maxY) * echelle,
                      width: rectangle.width * echelle,
                      height: rectangle.height * echelle)
    }
}
