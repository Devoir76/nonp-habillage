// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ReglagesInterface.swift — les choix que l'interface propose.
//
// Trois listes, et une raison pour chacune.

import Foundation

// MARK: - Tailles nommées

/// Les quatre tailles de sous-titre proposées à l'utilisateur.
///
/// L'ADR §2 les préfère à un pourcentage à saisir : « l'utilisateur choisit une
/// apparence, le moteur en déduit la taille réelle selon le format de la vidéo.
/// C'est ce qui rend le même profil correct en 16:9 comme en 9:16. »
///
/// Chacune vaut une **longueur de ligne cible**, en caractères. Plus la ligne
/// est longue, plus le texte est petit — d'où l'ordre inversé des valeurs.
enum TailleNommee: String, CaseIterable, Identifiable {
    case petite, normale, grande, tresGrande

    var id: String { rawValue }

    /// Longueur de ligne visée, en caractères (ADR §5 : « 32 à 42, jamais moins
    /// de 28 »). Les quatre valeurs couvrent exactement cet intervalle.
    var longueurLigneCible: Int {
        switch self {
        case .petite: return 42
        case .normale: return 37
        case .grande: return 32
        case .tresGrande: return 28
        }
    }

    /// Taille de police, en fraction de la hauteur vidéo.
    ///
    /// UNE TAILLE NOMMÉE DOIT CHANGER LA TAILLE DU TEXTE. Cela paraît évident ;
    /// ce ne l'était pas dans la première version de ce lot, où les quatre
    /// choix ne pilotaient que la longueur de ligne cible. Sur une vidéo 16:9,
    /// la largeur suffit toujours à tenir 42 caractères : la taille n'était donc
    /// jamais réduite, et les quatre réglages rendaient tous **78 px**. Seule la
    /// césure bougeait — un utilisateur ne voyait rien.
    ///
    /// L'ADR §5 couplait les deux (« la taille du texte est contrainte par une
    /// longueur de ligne cible »), mais son arithmétique reposait sur
    /// l'estimation « 0,72 × taille » : elle calculait 32 caractères là où
    /// Core Text en mesure 55. Une fois la mesure exacte en place, longueur de
    /// ligne et taille de police redeviennent DEUX réglages distincts, et la
    /// taille nommée doit porter les deux.
    ///
    /// « Grande » vaut exactement le 7,2 % du prototype : le préréglage NONP
    /// tombe dessus sans rien changer à l'existant.
    var tailleRatio: Double {
        switch self {
        case .petite: return 0.054
        case .normale: return 0.063
        case .grande: return 0.072
        case .tresGrande: return 0.084
        }
    }

    /// La taille nommée la plus proche d'une longueur de ligne donnée.
    ///
    /// Sert à retrouver le bouton à cocher quand un profil arrive avec une
    /// valeur précise : les tailles nommées sont une commodité d'interface, pas
    /// une contrainte du format de fichier, et un profil réglé finement doit
    /// rester possible.
    static func laPlusProche(de longueur: Int) -> TailleNommee {
        allCases.min {
            abs($0.longueurLigneCible - longueur) < abs($1.longueurLigneCible - longueur)
        } ?? .grande
    }
}

// MARK: - Polices

/// La liste courte de polices proposée par l'interface.
///
/// ADR §2 : « 8 à 10 familles présentes sur tout Mac, choisies pour la
/// lisibilité en sous-titre ». Le motif n'est pas esthétique — un profil partagé
/// doit s'afficher **à l'identique** chez le destinataire, et une police absente
/// casse cette promesse. Un choix « autre police du système » reste accessible,
/// signalé comme risqué pour le partage.
enum PolicesSures {

    /// Les familles proposées en premier. Toutes livrées avec macOS.
    static let recommandees = [
        "Helvetica Neue",
        "Arial",
        "Avenir Next",
        "Futura",
        "Gill Sans",
        "Optima",
        "Verdana",
        "Trebuchet MS",
        "Georgia",
    ]

    /// Celles qui sont réellement installées sur cette machine.
    ///
    /// La liste est filtrée plutôt que supposée : proposer une police absente
    /// mènerait à l'erreur de l'invariant nº4 au moment de graver, alors qu'on
    /// pouvait le savoir en ouvrant le menu.
    static var disponibles: [String] {
        let installees = Set(PoliceSousTitre.famillesDisponibles.map { $0.lowercased() })
        return recommandees.filter { installees.contains($0.lowercased()) }
    }

    /// Toutes les familles du système, pour le choix « autre police ».
    static var toutes: [String] {
        PoliceSousTitre.famillesDisponibles.sorted()
    }

    /// Une famille fait-elle partie de la liste sûre ?
    static func estSure(_ famille: String) -> Bool {
        recommandees.contains { $0.lowercased() == famille.lowercased() }
    }
}

// MARK: - Couleurs proposées

/// Quelques teintes prêtes à l'emploi, dont le bleu NONP (ADR §2).
enum CouleursProposees {
    static let liste: [(nom: String, couleur: CouleurProfil)] = [
        ("Blanc", .blanc),
        ("Noir", .noir),
        ("Bleu NONP", .bleuNONP),
        ("Jaune", CouleurProfil(hex: "#FFD400")),
        ("Rouge", CouleurProfil(hex: "#D0021B")),
        ("Vert", CouleurProfil(hex: "#1B7F3B")),
        ("Gris ardoise", CouleurProfil(hex: "#333333")),
    ]
}

// MARK: - Phrases de référence

/// Ce que l'aperçu affiche quand aucun fichier de sous-titres n'est chargé.
///
/// L'ADR §2 est explicite : « Régler une taille, une couleur ou une police à
/// l'aveugle n'a pas de sens. » L'aperçu montre donc du texte **en permanence**.
/// Sans fichier, une phrase de référence « calibrée sur la longueur de ligne
/// cible de la taille choisie, contenant accents, majuscules, jambages et
/// ponctuation — de quoi juger lisibilité, contraste et césure ».
enum PhrasesDeReference {

    /// LA phrase de référence. Une seule, et toujours la même.
    ///
    /// La première version en choisissait une parmi plusieurs, « la plus longue
    /// qui tient encore ». L'intention était bonne — remplir les lignes
    /// disponibles — mais l'effet était pervers : en réduisant la taille du
    /// texte, on faisait apparaître une phrase PLUS LONGUE, si bien que le bloc
    /// occupait toujours la même place et que le réglage semblait sans effet.
    /// On ne compare pas deux réglages si le texte change entre les deux.
    ///
    /// Longueur choisie pour tenir en deux lignes aux QUATRE tailles nommées :
    /// au-delà de 2 × 28 caractères, elle déborderait à « Très grande ».
    ///
    /// Contenu : accents (é, à), majuscules, jambages descendants (j, g, p),
    /// apostrophe et ponctuation — de quoi juger lisibilité, contraste et césure.
    /// Elle ne porte de ponctuation forte qu'à la fin, et c'est délibéré : un
    /// point-virgule au milieu ferait mordre la règle de coupure à la
    /// ponctuation, qui scinderait la phrase en deux répliques dont l'aperçu ne
    /// montrerait que la première — une seule ligne, là où l'on veut en voir
    /// deux.
    static let reference = "Ce jour-là, PERSONNE n'a bougé avant l'aube grise."

    /// La phrase de référence, quelle que soit la taille.
    ///
    /// La signature garde ses paramètres pour rester lisible côté appelant, mais
    /// le résultat ne dépend plus d'eux : c'est tout l'objet de la correction.
    static func phrase(pourLongueurLigne longueur: Int, lignes: Int) -> String {
        reference
    }
}
