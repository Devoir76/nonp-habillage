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

/// Un des quatre coins où poser le logo (schéma : `logo.position.preset`).
enum CoinLogo: String, Equatable, CaseIterable {
    case hautGauche = "haut-gauche"
    case hautDroit = "haut-droit"
    case basGauche = "bas-gauche"
    case basDroit = "bas-droit"
}

/// Où poser le logo (schéma : `logo.position`).
enum PositionLogo: Equatable {
    /// Un des quatre coins, à la marge du profil.
    case coin(CoinLogo)
    /// Coordonnées libres. `x` et `y` désignent le **CENTRE** du logo, en
    /// pourcentage de la largeur et de la hauteur — c'est la définition du
    /// schéma, et c'est ce qui rend un profil valable quel que soit le format.
    /// L'interface du lot 5 posera le logo à la souris et enregistrera cette
    /// forme relative.
    case libre(xPct: Double, yPct: Double)
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
    ///
    /// Logo et sous-titres sont deux options INDÉPENDANTES (ADR §Décision) :
    /// une vidéo peut n'avoir que le logo, que les sous-titres, ou les deux.
    var logoActif: Bool
    /// Fichier image du logo. Sans lui, aucun logo n'est posé même si
    /// `logoActif` vaut vrai — l'utilisateur n'en a pas forcément fourni.
    var logoFichier: URL?
    /// Plus grande dimension du logo rapportée à la hauteur vidéo, **ratio
    /// préservé**. Prototype : `DIAM_RATIO`.
    var logoTailleRatio: Double
    /// Marge de coin du logo rapportée à la hauteur. Prototype : `MARGIN_RATIO`.
    var logoMargeRatio: Double
    /// Où poser le logo.
    var logoPosition: PositionLogo
    /// Opacité du logo, de 0 (invisible) à 1 (opaque).
    var logoOpacite: Double
    /// Recadrer le logo en cercle, à la volée.
    ///
    /// Le prototype fabriquait un fichier (`--make-logo`) qu'il fallait produire
    /// avant d'habiller. Ici c'est un réglage réversible : on le coche, l'aperçu
    /// montre le résultat, on le décoche. Aucun fichier n'est écrit à côté du
    /// logo de l'utilisateur.
    ///
    /// Comme `longueurLigneCible`, ce champ n'existe pas dans le schéma partagé :
    /// sa persistance est une question du lot 6.
    var logoRecadreEnCercle: Bool = false

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
    /// Longueur de ligne visée, en caractères (ADR §5).
    ///
    /// C'est l'expression interne des quatre tailles nommées de l'interface —
    /// Petite, Normale, Grande, Très grande valent 42, 37, 32 et 28. Le champ
    /// n'existe PAS dans le schéma partagé, qui stocke `taille_pct_hauteur` :
    /// la façon dont les deux se répondent est une question du lot 6, et rien
    /// ne lit ni n'écrit encore ce champ depuis un JSON.
    var longueurLigneCible: Int = MoteurMiseEnPage.longueurLigneCibleParDefaut

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
    /// Marge intérieure VERTICALE du fond / hauteur. Prototype : `BOXPAD_RATIO`.
    ///
    /// Purement verticale depuis le schéma v2 : c'est ce que sa description
    /// disait déjà, et ce qu'elle ne faisait pas — en v1 elle servait aussi de
    /// retrait horizontal, mêlée aux espaces latéraux.
    var bandeauPaddingRatio: Double

    /// **Retrait du texte par rapport au bord de la bande, de chaque côté, en
    /// fraction de la LARGEUR vidéo.**
    ///
    /// L'unique commande de la largeur de la colonne de texte, dans les DEUX
    /// modes de bandeau (schéma v2, décision nº6 tranchée le 28/08/2026). Elle
    /// remplace `espaces_lateraux` — dont l'unité était la largeur d'une
    /// espace, donc une fraction de la taille de police, donc de la HAUTEUR,
    /// pour un réglage qui consomme de la LARGEUR — et
    /// `marge_interieure_pct_largeur`, qui faisait la même chose dans le seul
    /// mode `pleine-largeur`.
    ///
    /// Appliquée en PIXELS ENTIERS, comme toutes les autres grandeurs
    /// géométriques du moteur. Ce n'est pas un détail : c'est ce qui fait que
    /// 5,61 % de 1920 rendent exactement les 108 px que le profil NONP posait
    /// en v1, au lieu de 107,7.
    var bandeauMargeTexteRatioLargeur: Double
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
        logoFichier: nil,                // fourni à l'usage (--logo)
        logoTailleRatio: 0.115,          // DIAM_RATIO
        logoMargeRatio: 0.04,            // MARGIN_RATIO
        logoPosition: .coin(.hautGauche),
        logoOpacite: 1.0,
        logoRecadreEnCercle: false,
        police: "Arial",                 // DEFAULT_FONT
        tailleRatio: 0.072,              // FONT_RATIO
        margeBasseRatio: 0.072,          // MARGINV_RATIO
        margeLateraleRatioLargeur: 0.03,
        lignesMax: 2,                    // MAXLINES
        longueurLigneCible: 32,          // « Grande » — ce que rend le prototype en 16:9
        couleurTexte: .blanc,
        contourCouleur: .noir,
        contourRatio: 0.006,             // OUTLINE_RATIO
        bandeauActif: true,
        bandeauCouleur: .bleuNONP,
        bandeauMode: .ajuste,
        bandeauPaddingRatio: 0.019,      // BOXPAD_RATIO
        // 5,61 % : la valeur mesurée qui reproduit, au pixel entier, le débord
        // que `espaces_lateraux: 4` produisait en 16:9 — 108 px de chaque côté
        // sur 1920. Voir ADR, décision nº6.
        bandeauMargeTexteRatioLargeur: 0.0561,
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
        logoFichier: nil,
        logoTailleRatio: 0.115,
        logoMargeRatio: 0.04,
        logoPosition: .coin(.hautGauche),
        logoOpacite: 1.0,
        logoRecadreEnCercle: false,
        police: "Helvetica Neue",
        tailleRatio: 0.072,
        margeBasseRatio: 0.072,
        margeLateraleRatioLargeur: 0.03,
        lignesMax: 2,
        longueurLigneCible: 32,
        couleurTexte: .blanc,
        contourCouleur: .noir,
        contourRatio: 0.006,
        bandeauActif: true,
        bandeauCouleur: CouleurProfil(hex: "#000000", opacite: 0.6),
        bandeauMode: .pleineLargeur,
        bandeauPaddingRatio: 0.019,
        // Le neutre garde SES 3 %, ceux de sa marge intérieure de v1 : la
        // valeur par défaut du schéma (5,61 %) reproduit le mode `ajuste`, pas
        // le sien. Migrer sa propre valeur est ce qui laisse son rendu intact.
        bandeauMargeTexteRatioLargeur: 0.03,
        bandeauHauteurFixeLignes: 2
    )
}
