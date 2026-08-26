// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ImageAccueilView.swift — l'image de la vidéo, volet fermé.
//
// Deux services rendus d'un coup, tous deux relevés à l'usage :
//
// 1. **Confirmer.** Une ligne de texte — nom, définition, durée — dit qu'un
//    fichier est chargé, pas QUEL film. Une image le dit d'un regard.
// 2. **Occuper la place.** L'accueil n'avait rien sous les zones de dépôt : la
//    fenêtre agrandie s'ouvrait sur un grand vide, qui se lisait comme une
//    application cassée plutôt que comme une application au repos.
//
// Ce n'est PAS l'aperçu de réglage : pas de poignée de logo, pas de choix de
// plan, pas d'avertissements. Ces outils-là appartiennent au volet, et les
// sortir ici rouvrirait ce que l'ADR §2 ferme — « zone de dépôt, un bouton
// Habiller, une barre de progression. Rien d'autre. » Ce qu'on ajoute est une
// image de la vidéo déposée, pas un réglage.

import SwiftUI
import CoreGraphics

struct ImageAccueilView: View {

    @EnvironmentObject private var etat: AppState

    var body: some View {
        VStack(spacing: 8) {
            image
            Text(etat.repliques.isEmpty
                 ? Textes.Interface.imageAccueilSansSousTitres
                 : Textes.Interface.imageAccueilAvecSousTitres)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        // Même fond sombre que la colonne d'aperçu : une vidéo verticale laisse
        // forcément deux bandes, et cette place doit se lire comme un
        // passe-partout, pas comme un trou.
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private var image: some View {
        GeometryReader { geo in
            ZStack {
                if let image = etat.imageAccueil {
                    // Entière et jamais rognée, comme l'aperçu : un logo posé
                    // dans un coin serait le premier à disparaître.
                    let taille = Apercu.tailleAffichee(
                        image: CGSize(width: image.width, height: image.height),
                        dans: geo.size)
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .frame(width: taille.width, height: taille.height)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ProgressView(Textes.Interface.chargementApercu)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, minHeight: Fenetre.hauteurMinimaleImageAccueil,
               maxHeight: .infinity)
    }
}
