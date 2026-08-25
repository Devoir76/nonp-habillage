// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Textes.swift — tous les textes affichés à l'utilisateur, en un seul endroit.
//
// Pourquoi centraliser dès le socle ? L'interface est en français uniquement
// (ADR-0001 §2), mais l'anglais doit pouvoir s'ajouter plus tard « sans
// refonte ». Ce n'est vrai que si aucune chaîne visible n'est écrite en dur
// dans une vue. La règle vaut aussi pour les messages d'erreur : un format
// refusé, une police manquante (invariant nº4) se formulent ici, pas au fil du
// code qui les détecte.
//
// Règle : toute chaîne vue par l'utilisateur passe par ce fichier. Les
// nouvelles entrées se rangent sous la rubrique du lot qui les introduit.

import Foundation

enum Textes {

    // MARK: - Identité de l'application

    /// Nom affiché — titre de la fenêtre. Nom définitif, arrêté le 24/08
    /// (ADR-0001, décision nº1).
    static let nomApplication = "NONP Habillage"
}
