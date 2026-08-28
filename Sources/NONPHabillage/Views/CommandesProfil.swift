// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// CommandesProfil.swift — importer, exporter, revenir aux réglages par défaut.
//
// Ces trois gestes vivaient dans une section « Profil », en tête du volet
// Personnaliser. Ils sont au menu Fichier depuis le 28/08/2026, et c'est leur
// place : ce sont des gestes RARES et DÉLIBÉRÉS. Le volet, lui, sert à régler,
// et on y revient vingt fois par habillage.
//
// C'est aussi la convention macOS — ouvrir et enregistrer un document sont au
// menu Fichier, pas dans la fenêtre —, et la convention a ici une conséquence
// pratique : le menu porte des raccourcis clavier, ce qu'un bouton perdu dans
// une colonne défilante ne peut pas faire.
//
// ── Pourquoi la section a disparu ────────────────────────────────────────────
//
// La notion de « profil » était mise en avant bien au-delà de ce qu'elle sert.
// La plupart des utilisateurs n'auront qu'un seul habillage, et la seule chose
// qu'ils en attendent est qu'il se retrouve d'une session à l'autre — ce que la
// mémorisation fait déjà, sans qu'on ait à nommer quoi que ce soit. « Neutre »
// reste le point de départ à la première ouverture ; ensuite ce sont les
// réglages mémorisés qui prennent le relais, et plus aucun préréglage.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CommandesProfil: Commands {

    @ObservedObject var etat: AppState

    var body: some Commands {
        // `.newItem` : le groupe du haut du menu Fichier, là où se trouvent
        // Ouvrir et Nouveau dans toute application macOS.
        CommandGroup(replacing: .newItem) {
            Button(Textes.Profil.importerUnProfil) { importer() }
                .keyboardShortcut("o")
            Button(Textes.Profil.exporterLeProfil) { exporter() }
                .keyboardShortcut("s")
            Divider()
            Button(Textes.Profil.reglagesParDefaut) { etat.revenirAuxReglagesParDefaut() }
        }
    }

    // MARK: - Importer

    /// Le panneau s'ouvre sur les profils d'EXEMPLE livrés.
    ///
    /// C'est ce qui remplace les boutons de préréglage : un préréglage qui n'est
    /// qu'un exemple n'a pas besoin d'un bouton, il a besoin d'être trouvable.
    private func importer() {
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = [.json]
        panneau.allowsMultipleSelection = false
        panneau.directoryURL = ProfilJSON.dossierExemples
        panneau.message = Textes.Profil.ouExemples
        if panneau.runModal() == .OK, let url = panneau.url {
            etat.importerProfil(url)
        }
    }

    // MARK: - Exporter

    private func exporter() {
        let panneau = NSSavePanel()
        panneau.allowedContentTypes = [.json]
        panneau.nameFieldStringValue = Self.nomDeFichier(etat.profil.nom) + ".json"

        // L'avertissement vit DANS le panneau, pas après : un profil qui
        // emploie le schéma v2 ne sera pas lu par le prototype (décision nº5),
        // et le dire ici c'est le dire avant que le fichier parte.
        // L'enregistrement n'est pas empêché — le profil est juste, c'est
        // l'ancien outil qui ne sait pas le rendre.
        let inconnus = ProfilJSON.champsInconnusDuPrototype(etat.profil)
        if !inconnus.isEmpty {
            panneau.message = Textes.Profil.inconnuDuPrototype(inconnus)
        }
        if panneau.runModal() == .OK, let url = panneau.url {
            etat.exporterProfil(vers: url)
        }
    }

    /// Le nom du profil, rendu utilisable comme nom de fichier.
    static func nomDeFichier(_ nom: String) -> String {
        let propre = nom.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "fr_FR"))
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(propre).split(separator: "-").joined(separator: "-")
    }
}
