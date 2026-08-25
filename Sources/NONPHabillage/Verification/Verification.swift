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
//
// En pratique on passe par `./Scripts/verifier.sh`, qui compile, fabrique la
// référence Python et enchaîne le tout.

import Foundation

enum Verification {

    /// À appeler au tout début du lancement. Sans effet en usage normal.
    static func maybeRun() {
        let args = CommandLine.arguments
        guard args.contains("--verifier") else { return }

        var corpus: [URL] = []
        if let i = args.firstIndex(of: "--corpus"), i + 1 < args.count {
            corpus = fichiersDeSousTitres(dans: URL(fileURLWithPath: args[i + 1], isDirectory: true))
        }
        var reference: URL? = nil
        if let i = args.firstIndex(of: "--or-python"), i + 1 < args.count {
            reference = URL(fileURLWithPath: args[i + 1])
        }

        exit(executer(corpus: corpus, referenceJSON: reference))
    }

    static func executer(corpus: [URL], referenceJSON: URL?) -> Int32 {
        print("Vérification du lot 2 — parseur, segmenteur, mise en page")
        print(String(repeating: "─", count: 66))

        let r = Rapport()
        ControlesParseur.executer(r)
        ControlesSegmenteur.executer(r)
        ControlesMiseEnPage.executer(r)
        ControlesFidelite.executer(r, corpus: corpus)
        ControlesParite.executer(r, referenceJSON: referenceJSON)
        return r.conclure()
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
