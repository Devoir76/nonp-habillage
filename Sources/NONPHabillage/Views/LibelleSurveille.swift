// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// LibelleSurveille.swift — un libellé qui sait dire s'il est tronqué.
//
// Un titre tronqué ne produit aucune erreur, ne change pas la hauteur de sa
// ligne, et passe tous les contrôles de disposition : « Haut ga… » est resté
// des semaines dans la colonne des réglages (DC-1). Mesurer la largeur NATURELLE
// d'une ligne ne suffit pas non plus : un bouton comprime sa marge intérieure
// avant de tronquer son texte, et la mesure rejette alors des lignes que l'œil
// lit entières.
//
// Ce libellé compare deux largeurs, à même police : celle qu'il REÇOIT, et
// celle de son texte ENTIER. S'il reçoit moins, il est tronqué, et il le publie
// par une préférence que le contrôle de disposition recueille.
//
// Validé contre des captures de vraies fenêtres (voir PlancheCoins, `--seuils`) :
// sept largeurs, deux lignes de boutons, 56 libellés — le détecteur a désigné
// exactement ceux que l'image montrait tronqués, et aucun autre.
//
// Sans effet à l'écran : la copie entière est cachée, et un arrière-plan ne
// compte pas dans la disposition.
//
// Ce qu'il ne voit pas : un libellé qui ne passe pas par lui. Un nom de fichier,
// lui, a le droit de se tronquer — il ne doit pas l'employer.

import SwiftUI

/// Les libellés tronqués d'une hiérarchie, remontés jusqu'à sa racine.
struct LibellesTronques: PreferenceKey {
    static var defaultValue: [String] = []
    static func reduce(value: inout [String], nextValue: () -> [String]) {
        value += nextValue()
    }
}

struct LibelleSurveille: View {
    let texte: String

    init(_ texte: String) {
        self.texte = texte
    }

    var body: some View {
        Text(texte)
            .background(GeometryReader { recu in
                Text(texte)
                    .fixedSize()
                    .hidden()
                    .background(GeometryReader { entier in
                        Color.clear.preference(
                            key: LibellesTronques.self,
                            value: recu.size.width + 0.5 < entier.size.width ? [texte] : [])
                    })
            })
    }
}
