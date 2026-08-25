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

    // MARK: - Sous-titres (lot 2)

    /// Messages d'erreur de lecture des fichiers de sous-titres.
    ///
    /// Ils sont rédigés pour être lus par quelqu'un qui n'a pas écrit le
    /// fichier fautif : ils disent où est le problème et quoi faire, jamais
    /// « parse error ». Le prototype, lui, laissait remonter une trace Python.
    enum SousTitres {

        static func fichierIllisible(_ nom: String) -> String {
            "Impossible de lire le fichier de sous-titres « \(nom) ». "
            + "Vérifiez qu'il existe toujours et qu'il n'est pas ouvert dans un autre logiciel."
        }

        static func encodageNonUTF8(_ nom: String) -> String {
            "Le fichier « \(nom) » n'est pas encodé en UTF-8. "
            + "Réenregistrez-le en UTF-8 depuis votre éditeur de sous-titres, "
            + "puis réessayez."
        }

        static func timecodeIllisible(numeroBloc: Int, ligne: String) -> String {
            "Minutage illisible au bloc \(numeroBloc) : « \(ligne) ». "
            + "Un minutage s'écrit « 00:01:23,400 --> 00:01:26,900 »."
        }

        /// Formule un message pour n'importe quelle erreur du parseur.
        static func message(pour erreur: ErreurSousTitres) -> String {
            switch erreur {
            case .fichierIllisible(let url):
                return fichierIllisible(url.lastPathComponent)
            case .encodageNonUTF8(let url):
                return encodageNonUTF8(url.lastPathComponent)
            case .timecodeIllisible(let numeroBloc, let ligne):
                return timecodeIllisible(numeroBloc: numeroBloc,
                                         ligne: TextePython.rogner(ligne))
            }
        }
    }
}
