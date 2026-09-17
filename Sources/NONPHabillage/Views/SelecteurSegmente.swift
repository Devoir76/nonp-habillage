// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// SelecteurSegmente.swift — un choix segmenté dont les segments ont la largeur
// de leur libellé.
//
// ── Pourquoi pas `Picker(…).pickerStyle(.segmented)` : DC-2 ──────────────────
//
// Le sélecteur segmenté de SwiftUI donne à tous ses segments la même largeur :
// celle du plus long libellé. Pour « Taille », quatre fois « Très grande », soit
// 386 points — plus que les 316 de la colonne. Tant que SwiftUI lui impose la
// largeur de la colonne, il se comprime et tient. Mais dès que la taille de la
// fenêtre est CALCULÉE — ce que font `.windowResizability(.contentMinSize)` et
// `CadreAuContenu` —, AppKit le remet à sa largeur idéale, et SwiftUI ne la
// corrige plus : « Très grande » s'affichait « Très gra », coupé au bord de la
// colonne. Confirmé à l'usage le 17/09/2026.
//
// Aucun cadre SwiftUI n'y peut rien : un sélecteur segmenté choisit lui-même sa
// largeur à l'intérieur du cadre qu'on lui donne. Largeur fixe, maximale,
// minimale nulle, flexible : essayées, mesurées, sans effet.
//
// Ce qui règle le défaut, c'est la largeur IDÉALE elle-même. Un
// `NSSegmentedControl` en répartition `.fit` taille chaque segment à son
// libellé : « Taille » réclame 300 points, moins que la colonne. Remis à sa
// largeur idéale, il tient quand même. Mesuré dans les mêmes conditions : le
// même contrôle en répartition égale déborde exactement comme le `Picker`.
//
// Il épouse son contenu (priorité de maintien requise) : « Largeur du fond »
// garde sa largeur, et « Taille » en prend 300 au lieu de s'étirer à 316.

import SwiftUI
import AppKit

struct SelecteurSegmente<Valeur: Hashable>: NSViewRepresentable {
    let options: [(valeur: Valeur, libelle: String)]
    @Binding var selection: Valeur

    func makeNSView(context: Context) -> NSSegmentedControl {
        let controle = NSSegmentedControl(
            labels: options.map(\.libelle), trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinateur.changement(_:)))
        controle.segmentDistribution = .fit
        controle.setContentHuggingPriority(.required, for: .horizontal)
        return controle
    }

    func updateNSView(_ controle: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        controle.selectedSegment = options.firstIndex { $0.valeur == selection } ?? -1
        // Le grisé de SwiftUI (`.disabled`) n'atteint pas un contrôle AppKit
        // de lui-même : sans cette ligne, « Taille » resterait cliquable sans
        // sous-titres, sous une opacité qui le dit inactif.
        controle.isEnabled = context.environment.isEnabled
    }

    func makeCoordinator() -> Coordinateur { Coordinateur(parent: self) }

    final class Coordinateur: NSObject {
        var parent: SelecteurSegmente

        init(parent: SelecteurSegmente) { self.parent = parent }

        @objc func changement(_ controle: NSSegmentedControl) {
            let i = controle.selectedSegment
            guard parent.options.indices.contains(i) else { return }
            parent.selection = parent.options[i].valeur
        }
    }
}
