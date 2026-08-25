// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ProfilHabillage.swift — représentation interne d'un profil, partie géométrique.
//
// Miroir de `profil_defaut()` du prototype : des RATIOS, fractions de la hauteur
// vidéo sauf `margeLateraleRatioLargeur`, seule exception, fraction de la
// largeur. C'est la représentation que consomme le moteur, pas le format de
// fichier.
//
// PÉRIMÈTRE AU LOT 2 : seuls les champs dont le calcul de mise en page a besoin
// sont portés. Couleurs, contour, bandeau et logo dans leur dimension visuelle
// arrivent au lot 3 (rendu) ; la lecture, l'écriture et la validation du JSON
// arrivent au lot 6. Ce fichier ne lit aucun profil et n'en écrit aucun.
//
// INVARIANT nº6 : `docs/profil-habillage.schema.json` est un contrat partagé
// avec le prototype Python. Rien ici ne l'amende — les valeurs par défaut sont
// reprises telles quelles des constantes du prototype, pour que le portage
// parte du même point que l'original.

import Foundation

struct ProfilHabillage: Equatable {

    /// Nom affiché du profil.
    var nom: String

    // MARK: - Logo (géométrie seule)

    /// Diamètre du logo rapporté à la hauteur vidéo. Prototype : `DIAM_RATIO`.
    var logoTailleRatio: Double
    /// Marge de coin du logo rapportée à la hauteur. Prototype : `MARGIN_RATIO`.
    var logoMargeRatio: Double

    // MARK: - Sous-titres (géométrie seule)

    /// Taille de police rapportée à la hauteur. Prototype : `FONT_RATIO`.
    ///
    /// Attention : depuis l'ADR §5, cette valeur est un **maximum**, plus une
    /// consigne. Voir `MoteurMiseEnPage`.
    var tailleRatio: Double
    /// Marge basse du sous-titre / hauteur. Prototype : `MARGINV_RATIO`.
    var margeBasseRatio: Double
    /// Marge latérale / **largeur** — l'unique ratio qui ne se rapporte pas à
    /// la hauteur. Prototype : `0.03`.
    var margeLateraleRatioLargeur: Double
    /// Épaisseur du contour noir / hauteur. Prototype : `OUTLINE_RATIO`.
    var contourRatio: Double
    /// Marge intérieure du bandeau / hauteur. Prototype : `BOXPAD_RATIO`.
    var bandeauPaddingRatio: Double
    /// Nombre maximal de lignes affichées simultanément. Prototype : `MAXLINES`.
    var lignesMax: Int

    /// Le profil NONP historique, repris des constantes de `nonp_habille.py`.
    ///
    /// C'est le profil de référence des tests de parité : c'est celui que le
    /// prototype applique quand on ne lui passe pas de `--profil`. Le profil
    /// **neutre** décrit par l'ADR (sans logo, bandeau pleine largeur) est un
    /// sujet du lot 6 et n'existe pas encore.
    static let nonpHistorique = ProfilHabillage(
        nom: "NONP (défaut)",
        logoTailleRatio: 0.115,          // DIAM_RATIO
        logoMargeRatio: 0.04,            // MARGIN_RATIO
        tailleRatio: 0.072,              // FONT_RATIO
        margeBasseRatio: 0.072,          // MARGINV_RATIO
        margeLateraleRatioLargeur: 0.03,
        contourRatio: 0.006,             // OUTLINE_RATIO
        bandeauPaddingRatio: 0.019,      // BOXPAD_RATIO
        lignesMax: 2                     // MAXLINES
    )
}
