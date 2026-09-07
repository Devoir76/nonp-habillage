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

/// L'écran de fin : le fichier est là, et TROIS issues s'offrent.
///
/// Il n'en avait que deux — le Finder, et « Habiller une autre vidéo ». Un
/// doute sur le rendu obligeait donc à tout redéposer pour vérifier, alors
/// qu'il ne manquait qu'un aller-retour. La troisième issue, ajoutée sur
/// retour d'usage après un export réel, ramène à l'écran quitté sans rien
/// perdre (voir `AppState.reprendreCetteVideo()`).
///
/// ── POURQUOI DEUX RANGS, ET DEUX LÉGENDES ────────────────────────────────
///
/// Les deux nouvelles voisines font le CONTRAIRE l'une de l'autre : « Revenir
/// aux réglages » garde tout, « Habiller une autre vidéo » vide le document.
/// Alignées en un seul rang avec le Finder, trois boutons de même poids, rien
/// n'aurait dit laquelle efface — et se tromper coûte un redépôt complet.
///
/// D'où la disposition : le Finder EN HAUT, seul, parce qu'il ne quitte pas
/// l'écran de fin et n'appartient donc pas au même choix. Les deux issues en
/// dessous, côte à côte, à égalité, chacune sous sa légende. Les légendes se
/// répondent mot pour mot — « restent chargés » contre « sont retirés » — et
/// c'est cette symétrie qui fait qu'on les lit sans hésiter.
struct TermineView: View {

    @EnvironmentObject private var etat: AppState
    let sortie: URL

    /// Largeur d'une des deux issues, légende comprise.
    ///
    /// Fixe, et la MÊME pour les deux : c'est ce qui aligne les légendes et
    /// donne au choix son allure de balance. Deux colonnes libres se seraient
    /// dimensionnées sur la longueur de leur texte, et la plus bavarde aurait
    /// paru la plus lourde. 2 × 250 + 24 tiennent dans les 620 points de la
    /// fenêtre fermée, marges de 40 comprises (voir `Fenetre.largeurFermee`).
    private static let largeurIssue: CGFloat = 250

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

            // Ce qu'on fait du fichier produit — on ne quitte pas cet écran.
            Button(Textes.Interface.revelerDansFinder) {
                NSWorkspace.shared.activateFileViewerSelecting([sortie])
            }

            Divider().frame(width: 2 * Self.largeurIssue + 24)

            // Ce qu'on fait ENSUITE. Les deux seules sorties de cet écran, à
            // égalité de poids et chacune annonçant son effet.
            HStack(alignment: .top, spacing: 24) {
                issue(Textes.Interface.reprendreCetteVideo,
                      effet: Textes.Interface.reprendreCetteVideoEffet,
                      action: { etat.reprendreCetteVideo() })
                issue(Textes.Interface.recommencer,
                      effet: Textes.Interface.recommencerEffet,
                      action: { etat.recommencer() })
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Un bouton et, dessous, la phrase qui dit ce qu'il advient des fichiers
    /// chargés. La phrase n'est pas un ornement : c'est elle qui distingue les
    /// deux issues, les libellés seuls ne pouvant pas tout porter.
    private func issue(_ titre: String, effet: String,
                       action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(titre, action: action)
            Text(effet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: Self.largeurIssue)
    }
}
