// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// NONPHabillageApp.swift — point d'entrée de l'application.
//
// Cycle de vie SwiftUI moderne (@main + App), une seule fenêtre. Au lot 1 cette
// fenêtre est délibérément vide : le socle se prouve en se lançant, pas en
// affichant des réglages qui n'existent pas encore. L'écran d'accueil (zone de
// dépôt, bouton « Habiller », progression) arrive au lot 5.

import SwiftUI

@main
struct NONPHabillageApp: App {

    /// L'état vit ICI, et non plus dans `FenetrePrincipaleView`.
    ///
    /// Le menu Fichier a besoin de l'atteindre : importer un profil, l'exporter
    /// et revenir aux réglages par défaut sont des commandes de menu depuis le
    /// 28/08/2026, et une `Commands` ne voit pas l'environnement d'une vue. La
    /// fenêtre le reçoit désormais au lieu de le créer.
    @StateObject private var etat = AppState()

    init() {
        // Harnais de vérification headless (--verifier …) : exécute les
        // contrôles et quitte. Sans effet en usage normal.
        Verification.maybeRun()
    }

    var body: some Scene {
        WindowGroup(Textes.nomApplication) {
            FenetrePrincipaleView(etat: etat)
        }
        .commands { CommandesProfil(etat: etat) }
        // `.contentMinSize` et non `.contentSize` : la fenêtre respecte la
        // taille MINIMALE du contenu — elle s'agrandit donc quand le volet
        // s'ouvre — mais reste librement redimensionnable. Avec `.contentSize`,
        // elle était clouée à la taille du contenu, impossible à agrandir pour
        // voir l'aperçu en grand.
        .windowResizability(.contentMinSize)
        .defaultSize(width: Fenetre.largeurFermee, height: Fenetre.hauteurFermee)
    }
}
