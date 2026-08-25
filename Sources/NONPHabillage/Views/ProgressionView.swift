// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ProgressionView.swift — pendant et après l'encodage.
//
// La progression est RÉELLE : elle vient des images effectivement traitées par
// `ExportateurVideo`, pas d'une animation qui tourne pour faire patienter.
// La durée restante n'apparaît qu'une fois estimable — mieux vaut ne rien
// annoncer que d'annoncer des minutes fantaisistes qui s'effondrent ensuite.

import SwiftUI
import AppKit

struct ProgressionView: View {

    @EnvironmentObject private var etat: AppState

    var body: some View {
        VStack(spacing: 18) {
            Text(Textes.Interface.progression(Int((etat.avancement * 100).rounded())))
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .monospacedDigit()

            ProgressView(value: etat.avancement)
                .progressViewStyle(.linear)

            Text(etat.tempsRestant.map {
                Textes.Interface.tempsRestant(CommandeExport.duree($0))
            } ?? Textes.Interface.estimationEnCours)
                .font(.callout)
                .foregroundStyle(.secondary)

            Button(Textes.Interface.boutonAnnuler) { etat.annulerExport() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// L'écran de fin : le fichier est là, on peut aller le voir.
struct TermineView: View {

    @EnvironmentObject private var etat: AppState
    let sortie: URL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text(Textes.Interface.exportTermine).font(.title2)
            Text(sortie.lastPathComponent)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 12) {
                Button(Textes.Interface.revelerDansFinder) {
                    NSWorkspace.shared.activateFileViewerSelecting([sortie])
                }
                Button(Textes.Interface.recommencer) { etat.recommencer() }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
