// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Rapport.swift — le strict minimum pour écrire des contrôles lisibles.
//
// Pourquoi pas XCTest ? Parce qu'il n'est pas là. Sur une machine équipée des
// seuls Command Line Tools — la configuration de ce poste — la chaîne Swift ne
// livre ni XCTest ni swift-testing, et `swift test` échoue avant de compiler
// quoi que ce soit. NONP Transcription a rencontré exactement ce mur et y a
// répondu par un harnais headless embarqué dans l'exécutable (`SelfTest.swift`,
// lancé par `--selftest`). On reprend le procédé, sans le réinventer.
//
// Le harnais reste volontairement pauvre : un compteur, un verdict, un écart
// affiché quand il y en a un. Tout ce qu'il n'a pas — sélection de tests,
// parallélisme, rapports XML — ne manquerait qu'à une suite qu'on n'écrira pas.

import Foundation

final class Rapport {

    private(set) var reussis = 0
    private(set) var echecs: [String] = []
    private var sectionCourante = ""

    /// Ouvre une rubrique dans la sortie.
    func section(_ titre: String) {
        sectionCourante = titre
        print("\n▸ \(titre)")
    }

    /// Contrôle booléen.
    func verifier(_ intitule: String, _ condition: Bool) {
        if condition {
            reussis += 1
            print("  ✓ \(intitule)")
        } else {
            let ligne = "\(sectionCourante) — \(intitule)"
            echecs.append(ligne)
            print("  ✗ \(intitule)")
        }
    }

    /// Contrôle d'égalité, avec affichage de l'écart en cas de divergence.
    func egal<T: Equatable>(_ intitule: String, _ obtenu: T, _ attendu: T) {
        if obtenu == attendu {
            reussis += 1
            print("  ✓ \(intitule)")
        } else {
            let ligne = "\(sectionCourante) — \(intitule)"
            echecs.append(ligne)
            print("  ✗ \(intitule)")
            print("      attendu : \(attendu)")
            print("      obtenu  : \(obtenu)")
        }
    }

    /// Signale une rubrique non exécutée faute de matériel (corpus absent,
    /// prototype introuvable). Ce n'est ni un succès ni un échec : c'est un
    /// contrôle qui n'a pas eu lieu, et le rapport le dit — un contrôle sauté
    /// en silence se lirait comme un contrôle réussi.
    func nonExecute(_ intitule: String, motif: String) {
        print("  — \(intitule) : non exécuté (\(motif))")
        nonExecutes.append("\(sectionCourante) — \(intitule) : \(motif)")
    }

    private(set) var nonExecutes: [String] = []

    /// Affiche la synthèse et renvoie le code de sortie du processus.
    func conclure() -> Int32 {
        print("\n" + String(repeating: "─", count: 66))
        if echecs.isEmpty {
            print("✓ \(reussis) contrôles réussis, aucun échec.")
        } else {
            print("✗ \(echecs.count) échec(s) sur \(reussis + echecs.count) contrôles :")
            for e in echecs { print("   • \(e)") }
        }
        if !nonExecutes.isEmpty {
            print("\n⚠︎  \(nonExecutes.count) rubrique(s) non exécutée(s) :")
            for s in nonExecutes { print("   • \(s)") }
            print("   Ces contrôles ne sont ni réussis ni échoués — ils n'ont pas eu lieu.")
        }
        return echecs.isEmpty ? 0 : 1
    }
}
