// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Verification.swift — harnais headless, sur le modèle de NONP Transcription.
//
// Appelé au tout début du lancement. Sans argument de vérification, il ne fait
// rien et l'application démarre normalement : le harnais est invisible en usage
// courant. Avec `--verifier`, il exécute les contrôles, imprime son rapport et
// quitte le processus avec 0 (tout passe) ou 1 (au moins un échec) — de quoi
// enchaîner dans un script.
//
// Usages :
//   NONPHabillage --verifier
//   NONPHabillage --verifier --corpus <dossier>
//   NONPHabillage --verifier --or-python <fichier.json>
//   NONPHabillage --verifier --video <fichier.mp4>
//   NONPHabillage --profils <dossier>
//
// En pratique on passe par `./Scripts/verifier.sh`, qui compile, fabrique la
// référence Python et enchaîne le tout.

import Foundation

enum Verification {

    /// À appeler au tout début du lancement. Sans effet en usage normal.
    static func maybeRun() {
        let args = CommandLine.arguments

        // Capture de l'interface (lot 5).
        if args.contains("--capture") {
            exit(MainActor.assumeIsolated { CaptureInterface.executer(arguments: args) })
        }

        // Profils écrits pour relecture par le prototype (lot 6).
        if args.contains("--profils") {
            exit(CommandeProfils.executer(arguments: args))
        }

        // Export vidéo en ligne de commande (lot 4).
        if args.contains("--exporter") {
            exit(CommandeExport.executer(arguments: args))
        }

        // Production des images de référence du lot 3.
        if let i = args.firstIndex(of: "--images"), i + 1 < args.count {
            exit(ProductionImages.executer(
                sorties: URL(fileURLWithPath: args[i + 1], isDirectory: true),
                sources: sources(depuis: args)))
        }

        guard args.contains("--verifier") else { return }

        var corpus: [URL] = []
        if let i = args.firstIndex(of: "--corpus"), i + 1 < args.count {
            corpus = fichiersDeSousTitres(dans: URL(fileURLWithPath: args[i + 1], isDirectory: true))
        }
        var reference: URL? = nil
        if let i = args.firstIndex(of: "--or-python"), i + 1 < args.count {
            reference = URL(fileURLWithPath: args[i + 1])
        }
        var videoReelle: URL? = nil
        if let i = args.firstIndex(of: "--video"), i + 1 < args.count {
            videoReelle = URL(fileURLWithPath: args[i + 1])
        }

        exit(executer(corpus: corpus, referenceJSON: reference, videoReelle: videoReelle))
    }

    static func executer(
        corpus: [URL], referenceJSON: URL?, videoReelle: URL? = nil
    ) -> Int32 {
        print("Vérification — parseur, segmenteur, mise en page, rendu, export")
        print(String(repeating: "─", count: 66))

        let r = Rapport()
        ControlesParseur.executer(r)
        ControlesSegmenteur.executer(r)
        ControlesMiseEnPage.executer(r)
        ControlesFidelite.executer(r, corpus: corpus)
        ControlesRendu.executer(r, corpus: corpus)
        ControlesLogo.executer(r)
        ControlesInterface.executer(r)
        ControlesProfils.executer(r)
        ControlesRegressionV2.executer(r, corpus: corpus)
        ControlesExport.executer(r, videoReelle: videoReelle)
        ControlesParite.executer(r, referenceJSON: referenceJSON)
        return r.conclure()
    }

    /// Lit les sources d'images de la ligne de commande.
    ///
    /// Chaque source s'écrit `--source <étiquette> <vidéo> <sous-titres>`, et
    /// se complète éventuellement de `--prototype-rendu <vidéo habillée>`, qui
    /// s'applique à la source qui précède.
    private static func sources(depuis args: [String]) -> [ProductionImages.Source] {
        var sources: [ProductionImages.Source] = []
        var i = 0
        while i < args.count {
            if args[i] == "--source", i + 3 < args.count {
                sources.append(ProductionImages.Source(
                    etiquette: args[i + 1],
                    video: URL(fileURLWithPath: args[i + 2]),
                    sousTitres: URL(fileURLWithPath: args[i + 3]),
                    rendueParLePrototype: nil))
                i += 4
                continue
            }
            if args[i] == "--prototype-rendu", i + 1 < args.count, let derniere = sources.last {
                sources[sources.count - 1] = ProductionImages.Source(
                    etiquette: derniere.etiquette,
                    video: derniere.video,
                    sousTitres: derniere.sousTitres,
                    rendueParLePrototype: URL(fileURLWithPath: args[i + 1]))
                i += 2
                continue
            }
            i += 1
        }
        return sources
    }

    /// Liste les `.srt` et `.vtt` d'un dossier, triés pour que deux exécutions
    /// donnent le même rapport dans le même ordre.
    private static func fichiersDeSousTitres(dans dossier: URL) -> [URL] {
        let contenu = (try? FileManager.default.contentsOfDirectory(
            at: dossier, includingPropertiesForKeys: nil)) ?? []
        return contenu
            .filter { ["srt", "vtt"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
