// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// FenetrePrincipaleView.swift — contenu de l'unique fenêtre.
//
// Lot 1 : fenêtre vide. Elle ne porte volontairement aucun réglage, aucun
// texte d'accueil, aucun bouton — le socle se vérifie au fait que l'app se
// lance et présente une fenêtre, rien de plus.
//
// La taille explicite n'est pas décorative : `Color.clear` est infiniment
// souple, et sans dimension imposée la fenêtre prendrait la taille arbitraire
// par défaut de SwiftUI. Avec `.windowResizability(.contentSize)`, ce cadre
// donne au contraire une fenêtre de dimensions connues — donc vérifiables.
// Il disparaîtra au lot 5, quand l'écran d'accueil réel (zone de dépôt, bouton
// « Habiller », progression) déterminera lui-même la taille de la fenêtre.

import SwiftUI

struct FenetrePrincipaleView: View {

    var body: some View {
        Color.clear
            .frame(width: 520, height: 360)
    }
}
