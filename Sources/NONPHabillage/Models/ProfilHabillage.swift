// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ProfilHabillage.swift — représentation interne d'un profil.
//
// Miroir de `profil_defaut()` du prototype, augmenté de la partie visuelle au
// lot 3 : des RATIOS, fractions de la hauteur vidéo sauf les marges latérales,
// fractions de la largeur. C'est la représentation que consomme le moteur, pas
// le format de fichier.
//
// PÉRIMÈTRE : ce fichier ne LIT aucun profil et n'en ÉCRIT aucun. La lecture,
// l'écriture et la validation du JSON arrivent au lot 6. Les deux profils
// ci-dessous sont construits en code, comme le prototype construit le sien
// depuis ses constantes.
//
// INVARIANT nº6 : `docs/profil-habillage.schema.json` est un contrat partagé
// avec le prototype Python. Rien ici ne l'amende. Les noms de champs suivent
// le schéma tel qu'il est déjà écrit — y compris `mode`,
// `hauteur_fixe_lignes` et `marge_interieure_pct_largeur`, ajoutés le 23/08 et
// facultatifs, dont les valeurs par défaut reproduisent le comportement
// historique.

import Foundation

/// Une couleur du profil : composantes 0–1, opacité séparée comme dans le
/// schéma (`couleur` + `opacite`, jamais un canal alpha caché dans le #RRGGBB).
struct CouleurProfil: Equatable {
    var rouge: Double
    var vert: Double
    var bleu: Double
    var opacite: Double

    init(rouge: Double, vert: Double, bleu: Double, opacite: Double = 1.0) {
        self.rouge = rouge
        self.vert = vert
        self.bleu = bleu
        self.opacite = opacite
    }

    /// Depuis un `#RRGGBB`, la forme du schéma.
    init(hex: String, opacite: Double = 1.0) {
        var s = Substring(hex)
        if s.hasPrefix("#") { s = s.dropFirst() }
        let v = UInt32(s, radix: 16) ?? 0
        self.rouge = Double((v >> 16) & 0xFF) / 255.0
        self.vert = Double((v >> 8) & 0xFF) / 255.0
        self.bleu = Double(v & 0xFF) / 255.0
        self.opacite = opacite
    }

    static let blanc = CouleurProfil(hex: "#FFFFFF")
    static let noir = CouleurProfil(hex: "#000000")
    /// Le bleu NONP.
    static let bleuNONP = CouleurProfil(hex: "#0067F6")
}

/// Comportement du fond derrière le texte (schéma : `sous_titre.bandeau.mode`).
enum ModeBandeau: String, Equatable {
    /// Le fond épouse la longueur de chaque ligne. Comportement historique,
    /// conservé par le préréglage NONP.
    case ajuste = "ajuste"
    /// Bande de largeur constante sur toute la vidéo, texte centré. Défaut du
    /// profil neutre : masque un sous-titre déjà incrusté dans la source et
    /// évite que la largeur saute d'une réplique à l'autre.
    case pleineLargeur = "pleine-largeur"
}

struct ProfilHabillage: Equatable {

    /// Nom affiché du profil.
    var nom: String

    // MARK: - Logo (géométrie seule — l'incrustation arrive au lot 4)

    /// Le profil pose-t-il un logo ?
    var logoActif: Bool
    /// Diamètre du logo rapporté à la hauteur vidéo. Prototype : `DIAM_RATIO`.
    var logoTailleRatio: Double
    /// Marge de coin du logo rapportée à la hauteur. Prototype : `MARGIN_RATIO`.
    var logoMargeRatio: Double

    // MARK: - Sous-titres, géométrie

    /// Nom de la famille de police. Absente du système, c'est une ERREUR
    /// explicite (invariant nº4) : jamais de substitution silencieuse.
    var police: String
    /// Taille de police rapportée à la hauteur. Prototype : `FONT_RATIO`.
    ///
    /// Attention : depuis l'ADR §5, cette valeur est un **maximum**, plus une
    /// consigne. Voir `MoteurMiseEnPage`.
    var tailleRatio: Double
    /// Marge basse du sous-titre / hauteur. Prototype : `MARGINV_RATIO`.
    var margeBasseRatio: Double
    /// Marge latérale / **largeur**. Prototype : `0.03`.
    var margeLateraleRatioLargeur: Double
    /// Nombre maximal de lignes affichées simultanément. Prototype : `MAXLINES`.
    var lignesMax: Int

    // MARK: - Sous-titres, apparence

    /// Couleur du texte.
    var couleurTexte: CouleurProfil
    /// Couleur du contour.
    var contourCouleur: CouleurProfil
    /// Épaisseur du contour / hauteur. Prototype : `OUTLINE_RATIO`.
    var contourRatio: Double

    /// Fond plein derrière le texte.
    var bandeauActif: Bool
    var bandeauCouleur: CouleurProfil
    var bandeauMode: ModeBandeau
    /// Marge intérieure verticale du fond / hauteur. Prototype : `BOXPAD_RATIO`.
    var bandeauPaddingRatio: Double
    /// Espaces durs de chaque côté, en mode `ajuste`. Prototype : `SIDEPAD`.
    var bandeauEspacesLateraux: Int
    /// Retrait du texte par rapport aux bords de la bande, en mode
    /// `pleine-largeur`, / **largeur**. Ignoré en mode `ajuste`.
    var bandeauMargeInterieureRatioLargeur: Double
    /// 0 = hauteur automatique. 1 à 4 = hauteur constante correspondant à ce
    /// nombre de lignes, pour que la bande ne saute pas entre une réplique
    /// d'une ligne et une réplique de deux.
    var bandeauHauteurFixeLignes: Int

    // MARK: - Préréglages livrés

    /// Le profil **NONP**, repris des constantes de `nonp_habille.py`.
    ///
    /// C'est le profil de référence des tests de parité : celui que le
    /// prototype applique quand on ne lui passe pas de `--profil`. Il conserve
    /// le bandeau `ajuste`, pour ne rien changer à l'existant (ADR §4).
    static let nonpHistorique = ProfilHabillage(
        nom: "NONP",
        logoActif: true,
        logoTailleRatio: 0.115,          // DIAM_RATIO
        logoMargeRatio: 0.04,            // MARGIN_RATIO
        police: "Arial",                 // DEFAULT_FONT
        tailleRatio: 0.072,              // FONT_RATIO
        margeBasseRatio: 0.072,          // MARGINV_RATIO
        margeLateraleRatioLargeur: 0.03,
        lignesMax: 2,                    // MAXLINES
        couleurTexte: .blanc,
        contourCouleur: .noir,
        contourRatio: 0.006,             // OUTLINE_RATIO
        bandeauActif: true,
        bandeauCouleur: .bleuNONP,
        bandeauMode: .ajuste,
        bandeauPaddingRatio: 0.019,      // BOXPAD_RATIO
        bandeauEspacesLateraux: 4,       // SIDEPAD
        bandeauMargeInterieureRatioLargeur: 0.03,
        bandeauHauteurFixeLignes: 0
    )

    /// Le profil **neutre**, appliqué au premier lancement (ADR §2).
    ///
    /// Aucun logo — l'utilisateur n'en a pas encore fourni — et un habillage
    /// sobre : texte blanc, contour noir, bandeau noir **pleine largeur**, de
    /// hauteur fixée à deux lignes pour qu'elle ne saute pas d'une réplique à
    /// l'autre. L'app s'adressant à tous, imposer le logo d'une association à
    /// l'ouverture serait déroutant.
    static let neutre = ProfilHabillage(
        nom: "Neutre",
        logoActif: false,
        logoTailleRatio: 0.115,
        logoMargeRatio: 0.04,
        police: "Helvetica Neue",
        tailleRatio: 0.072,
        margeBasseRatio: 0.072,
        margeLateraleRatioLargeur: 0.03,
        lignesMax: 2,
        couleurTexte: .blanc,
        contourCouleur: .noir,
        contourRatio: 0.006,
        bandeauActif: true,
        bandeauCouleur: CouleurProfil(hex: "#000000", opacite: 0.6),
        bandeauMode: .pleineLargeur,
        bandeauPaddingRatio: 0.019,
        bandeauEspacesLateraux: 0,
        bandeauMargeInterieureRatioLargeur: 0.03,
        bandeauHauteurFixeLignes: 2
    )
}
