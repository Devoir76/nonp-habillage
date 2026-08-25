// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ZoneDepotView.swift — déposer une vidéo, et éventuellement des sous-titres.
//
// L'écran d'accueil de l'ADR : « zone de dépôt, un bouton Habiller, une barre
// de progression. Rien d'autre. » Les réglages vivent derrière le volet
// Personnaliser, fermé par défaut.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Une zone où déposer un fichier, ou cliquer pour en choisir un.
struct ZoneDepotView: View {

    let titre: String
    let sousTitre: String
    let symbole: String
    let typesAcceptes: [UTType]
    /// Décrit le fichier déjà chargé, s'il y en a un.
    let fichierCharge: String?
    let onFichier: (URL) -> Void
    let onRetirer: (() -> Void)?

    @State private var survole = false

    var body: some View {
        VStack(spacing: 8) {
            if let fichierCharge {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(fichierCharge)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    if let onRetirer {
                        Button(Textes.Interface.retirer, action: onRetirer)
                            .buttonStyle(.link)
                    }
                }
                .padding(.horizontal, 12)
            } else {
                Image(systemName: symbole)
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
                Text(titre).font(.headline)
                Text(sousTitre)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(Textes.Interface.ouChoisir) { choisir() }
                    .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: fichierCharge == nil ? 120 : 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(survole ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    survole ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: survole ? 2 : 1,
                                       dash: fichierCharge == nil ? [6, 4] : []))
        )
        .onDrop(of: [.fileURL], isTargeted: $survole) { fournisseurs in
            recevoir(fournisseurs)
        }
    }

    private func recevoir(_ fournisseurs: [NSItemProvider]) -> Bool {
        guard let fournisseur = fournisseurs.first else { return false }
        _ = fournisseur.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            // Le type est vérifié ici, pas au moment de graver : refuser un MKV
            // après cinq minutes d'attente serait inutilement cruel.
            guard let type = UTType(filenameExtension: url.pathExtension.lowercased()),
                  typesAcceptes.contains(where: { type.conforms(to: $0) || type == $0 })
            else { return }
            Task { @MainActor in onFichier(url) }
        }
        return true
    }

    private func choisir() {
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = typesAcceptes
        panneau.allowsMultipleSelection = false
        panneau.canChooseDirectories = false
        if panneau.runModal() == .OK, let url = panneau.url {
            onFichier(url)
        }
    }
}

extension UTType {
    /// Les formats d'entrée de l'ADR §3 : MP4, MOV, M4V. MKV et AVI sont hors
    /// périmètre — non pas par paresse, mais parce que le moteur vidéo de macOS
    /// ne les lit pas, et qu'embarquer un second FFmpeg est exclu (invariant nº3).
    static var videosAcceptees: [UTType] { [.mpeg4Movie, .quickTimeMovie] }

    /// SRT et VTT n'ont pas de type système déclaré : on les nomme.
    static var sousTitresAcceptes: [UTType] {
        [UTType(filenameExtension: "srt") ?? .plainText,
         UTType(filenameExtension: "vtt") ?? .plainText,
         .plainText]
    }

    static var imagesAcceptees: [UTType] { [.png, .jpeg, .heic, .tiff] }
}
