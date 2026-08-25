// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// FenetrePrincipaleView.swift — l'unique fenêtre.
//
// ADR §2 : « Écran principal minimal : zone de dépôt (vidéo + sous-titres
// facultatifs), un bouton Habiller, une barre de progression avec durée
// restante estimée. Rien d'autre. »
//
// L'accueil tient donc SANS DÉFILEMENT et ne montre AUCUN réglage tant que le
// volet Personnaliser est fermé — c'est un critère d'acceptation du lot, pas un
// souhait. Le volet, lui, peut défiler : il en a le droit, il est déplié à la
// demande.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FenetrePrincipaleView: View {

    @StateObject private var etat = AppState()

    var body: some View {
        ContenuFenetre()
            .environmentObject(etat)
    }
}

/// Le contenu proprement dit, adossé à l'état fourni par l'environnement.
///
/// Séparé de `FenetrePrincipaleView` pour que la capture hors écran puisse
/// peupler l'état à l'avance — la vue principale, elle, crée le sien.
struct ContenuFenetre: View {

    @EnvironmentObject var etat: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch etat.etape {
            case .accueil: accueil
            case .enCours: ProgressionView()
            case .termine(let url): TermineView(sortie: url)
            }
        }
        .frame(width: 620)
        .frame(minHeight: etat.voletOuvert ? 760 : 420)
        .coordinateSpace(name: "apercu")
    }

    // MARK: - Accueil

    private var accueil: some View {
        VStack(spacing: 0) {
            // ── Partie fixe : elle doit tenir sans défilement ──────────────
            VStack(spacing: 14) {
                ZoneDepotView(
                    titre: Textes.Interface.deposezVotreVideo,
                    sousTitre: Textes.Interface.formatsAcceptes,
                    symbole: "film",
                    typesAcceptes: UTType.videosAcceptees,
                    fichierCharge: descriptionVideo,
                    onFichier: { etat.chargerVideo($0) },
                    onRetirer: nil)

                ZoneDepotView(
                    titre: Textes.Interface.sousTitresFacultatifs,
                    sousTitre: "SRT ou VTT",
                    symbole: "captions.bubble",
                    typesAcceptes: UTType.sousTitresAcceptes,
                    fichierCharge: descriptionSousTitres,
                    onFichier: { etat.chargerSousTitres($0) },
                    onRetirer: etat.sousTitres != nil ? { etat.retirerSousTitres() } : nil)

                if let erreur = etat.erreur {
                    Label(erreur, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture { etat.effacerErreur() }
                }

                if etat.video != nil && !etat.quelqueChoseAGraver {
                    Text(Textes.Interface.rienAGraver)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    // Le volet est FERMÉ par défaut : rien ne se règle tant
                    // qu'on ne l'a pas demandé.
                    DisclosureGroup(isExpanded: $etat.voletOuvert) {
                        EmptyView()
                    } label: {
                        Label(Textes.Interface.personnaliser, systemImage: "slider.horizontal.3")
                    }
                    .disabled(etat.video == nil)

                    Spacer()

                    Button(Textes.Interface.boutonHabiller) { habiller() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!etat.peutHabiller)
                }
            }
            .padding(20)
            // Sans cela, le contenu flotterait au milieu d'une fenêtre haute :
            // constaté sur la capture hors écran, invisible autrement.
            .frame(maxHeight: .infinity, alignment: .top)

            // ── Volet Personnaliser, déplié à la demande ───────────────────
            if etat.voletOuvert {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ApercuView()
                        Text(Textes.Interface.apercuSansEncodage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        PanneauPersonnaliserView()
                    }
                    .padding(20)
                }
            }
        }
    }

    private var descriptionVideo: String? {
        guard let video = etat.video else { return nil }
        guard let taille = etat.tailleVideo else { return video.lastPathComponent }
        return Textes.Interface.videoChargee(
            video.lastPathComponent, largeur: Int(taille.width),
            hauteur: Int(taille.height),
            duree: CommandeExport.duree(etat.dureeVideo))
    }

    private var descriptionSousTitres: String? {
        guard let st = etat.sousTitres else { return nil }
        return Textes.Interface.sousTitresCharges(st.lastPathComponent,
                                                  repliques: etat.cues.count)
    }

    private func habiller() {
        guard let proposee = etat.sortieProposee else { return }
        let panneau = NSSavePanel()
        panneau.allowedContentTypes = [.mpeg4Movie]
        panneau.nameFieldStringValue = proposee.lastPathComponent
        panneau.directoryURL = proposee.deletingLastPathComponent()
        if panneau.runModal() == .OK, let url = panneau.url {
            etat.habiller(vers: url)
        }
    }
}
