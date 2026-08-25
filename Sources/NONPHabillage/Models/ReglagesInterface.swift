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

    /// Des phrases françaises ordinaires, de plus en plus longues.
    ///
    /// Chacune porte ce qu'il faut pour juger : accents (é, è, à, ç), majuscules,
    /// jambages descendants (p, q, g, j), apostrophes et ponctuation.
    private static let phrases = [
        "Ce jour-là, j'ai vu passer quinze camions.",
        "Il m'a dit qu'il n'avait rien vu, ce jour-là, vers quatre heures.",
        "Je me souviens qu'à l'aube du 16 juillet, PERSONNE n'osait bouger ; "
            + "la place Georges-Pompidou était déjà vide.",
        "Ma grand-mère répétait qu'il ne fallait jamais y retourner ; "
            + "elle ajoutait, chaque fois : « on n'oublie pas, on apprend à vivre avec ».",
    ]

    /// Une phrase calibrée pour remplir environ `lignes` lignes à la longueur
    /// de ligne cible donnée.
    ///
    /// « Calibrée » veut dire ceci : on choisit la phrase dont la longueur
    /// approche le mieux la place disponible. Une phrase trop courte ne
    /// montrerait pas la césure, une phrase trop longue déborderait du nombre
    /// de lignes affichables.
    static func phrase(pourLongueurLigne longueur: Int, lignes: Int) -> String {
        let vise = longueur * max(1, lignes)
        return phrases.min {
            abs(TextePython.longueur($0) - vise) < abs(TextePython.longueur($1) - vise)
        } ?? phrases[1]
    }

    /// La phrase la plus longue qui tient encore en `lignes` lignes.
    ///
    /// `mesure` compte les lignes qu'une phrase occuperait réellement, césure
    /// comprise : c'est le seul moyen d'être calibré plutôt qu'approximatif.
    /// Si aucune ne tient — cas d'une vidéo minuscule —, on rend la plus courte.
    static func laPlusLongueTenantEn(
        _ lignes: Int, mesure: (String) -> Int
    ) -> String {
        let triees = phrases.sorted {
            TextePython.longueur($0) > TextePython.longueur($1)
        }
        return triees.first { mesure($0) <= max(1, lignes) } ?? (triees.last ?? phrases[0])
    }
}
