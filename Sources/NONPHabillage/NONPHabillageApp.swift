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

    var body: some Scene {
        WindowGroup(Textes.nomApplication) {
            FenetrePrincipaleView()
        }
        // La fenêtre s'ajuste au contenu : esprit sobre du cahier des charges.
        .windowResizability(.contentSize)
    }
}
