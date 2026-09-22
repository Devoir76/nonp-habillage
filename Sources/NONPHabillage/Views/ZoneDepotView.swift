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
    /// L'infobulle de la zone. Obligatoire, comme pour les réglages du volet :
    /// une zone de dépôt est le premier contrôle que l'on rencontre, et c'est
    /// là que les deux promesses du produit se disent — le fichier d'origine
    /// n'est jamais touché, et aucun mot des sous-titres ne bouge.
    let aide: String
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
        .help(aide)
    }

    private func recevoir(_ fournisseurs: [NSItemProvider]) -> Bool {
        guard let fournisseur = fournisseurs.first else { return false }
        let types = typesAcceptes
        let transmettreA = onFichier
        _ = fournisseur.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                Self.transmettre(url, typesAcceptes: types, onFichier: transmettreA)
            }
        }
        return true
    }

    /// Ce que la zone fait d'un fichier reçu — isolé de SwiftUI pour que le
    /// harnais le traverse : un glisser-déposer ne se simule pas sans écran.
    ///
    /// La zone ne décide RIEN : elle transmet tout. Mesuré le 22/09 — elle
    /// écartait elle-même ce qui n'avait pas la bonne extension, par un
    /// `return` silencieux, et un dossier ou un `.mkv` déposés ne produisaient
    /// aucun message. Les bons messages existaient pourtant, dans le chargeur,
    /// que la zone court-circuitait. Refuser n'est pas le rôle de la vue ;
    /// c'est celui du chargeur, qui SAIT dire pourquoi.
    ///
    /// Le refus reste immédiat : `chargerVideo` refuse avant tout chargement,
    /// personne n'attend cinq minutes pour apprendre qu'un MKV est refusé.
    /// `typesAcceptes` ne sert plus qu'au sélecteur de fichiers, qui grise.
    @MainActor
    static func transmettre(_ url: URL, typesAcceptes: [UTType],
                            onFichier: (URL) -> Void) {
        onFichier(url)
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
    /// Les formats d'entrée de l'ADR §3 : MP4, MOV, M4V.
    ///
    /// La règle elle-même vit dans le MOTEUR (`FormatsVideo`), que la ligne de
    /// commande traverse aussi : deux listes auraient fini par diverger, et
    /// elles avaient commencé. Ici, seule la présentation — ce que le sélecteur
    /// de fichiers laisse choisir.
    ///
    /// MKV et AVI sont hors périmètre par DÉCISION, pas par impuissance :
    /// AVFoundation ouvre un AVI sans difficulté. Trois conteneurs éprouvés
    /// valent mieux qu'une couverture partielle dépendante du codec (ADR §3).
    static var videosAcceptees: [UTType] { FormatsVideo.typesAcceptes }

    /// SRT et VTT n'ont pas de type système déclaré : on les nomme.
    static var sousTitresAcceptes: [UTType] {
        [UTType(filenameExtension: "srt") ?? .plainText,
         UTType(filenameExtension: "vtt") ?? .plainText,
         .plainText]
    }

    static var imagesAcceptees: [UTType] { [.png, .jpeg, .heic, .tiff] }
}
