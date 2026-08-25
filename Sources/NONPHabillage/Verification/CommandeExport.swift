// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// CommandeExport.swift — l'export en ligne de commande.
//
// Les lots 1 à 4 doivent produire « un outil utilisable en ligne de commande
// avant toute interface » (ADR, effort estimé). C'est ici que cela se concrétise :
// une vidéo, des sous-titres, un fichier de sortie.
//
// L'interface graphique du lot 5 appellera exactement le même `ExportateurVideo`,
// avec la même progression et la même annulation. Rien de ce qui est écrit ici
// n'aura à être réécrit là-bas.

import Foundation

enum CommandeExport {

    /// `--exporter <vidéo> [<sous-titres>] <sortie> [--profil neutre|nonp]
    ///  [--annuler-apres <secondes>]`
    static func executer(arguments args: [String]) -> Int32 {
        guard let i = args.firstIndex(of: "--exporter") else { return 2 }

        // Les chemins sont les arguments qui suivent, jusqu'à la première option.
        var chemins: [String] = []
        var j = i + 1
        while j < args.count, !args[j].hasPrefix("--") {
            chemins.append(args[j]); j += 1
        }
        guard chemins.count >= 2 else {
            print("Usage : --exporter <vidéo> [<sous-titres>] <sortie> "
                  + "[--profil neutre|nonp] [--annuler-apres <secondes>]")
            return 2
        }

        let video = URL(fileURLWithPath: chemins[0])
        let sortie = URL(fileURLWithPath: chemins[chemins.count - 1])
        let sousTitres = chemins.count >= 3
            ? URL(fileURLWithPath: chemins[1]) : nil

        var profil = ProfilHabillage.nonpHistorique
        if let p = args.firstIndex(of: "--profil"), p + 1 < args.count,
           args[p + 1].lowercased() == "neutre" {
            profil = .neutre
        }
        var annulerApres: Double? = nil
        if let a = args.firstIndex(of: "--annuler-apres"), a + 1 < args.count {
            annulerApres = Double(args[a + 1])
        }

        print("Habillage — export")
        print(String(repeating: "─", count: 66))
        print("  vidéo       : \(video.lastPathComponent)")
        print("  sous-titres : \(sousTitres?.lastPathComponent ?? "aucun (logo seul)")")
        print("  profil      : \(profil.nom)")
        print("  sortie      : \(sortie.path)")
        print("")

        let exportateur = ExportateurVideo()
        if let annulerApres {
            print("  ⏱  annulation programmée après \(annulerApres) s")
            DispatchQueue.global().asyncAfter(deadline: .now() + annulerApres) {
                exportateur.annuler()
            }
        }

        let verrou = DispatchSemaphore(value: 0)
        var code: Int32 = 0
        Task {
            do {
                let bilan = try await exportateur.exporter(
                    video: video, sousTitres: sousTitres, profil: profil, vers: sortie,
                    progression: { avancement in afficher(avancement) })
                effacerLigne()
                print("✓ Export terminé")
                print("  fichier   : \(bilan.sortie.path)")
                print("  taille    : \(octets(bilan.octets))")
                print("  durée     : \(duree(bilan.duree)) pour "
                      + "\(duree(bilan.dureeVideo)) de vidéo")
                print("  vitesse   : ×\(String(format: "%.1f", bilan.facteurTempsReel)) "
                      + "par rapport au temps réel")
                print("  audio     : \(bilan.audioRecopie ? "recopié sans réencodage" : "aucune piste")")
            } catch ErreurExport.annule {
                effacerLigne()
                print("⏹  Export annulé.")
                let reste = FileManager.default.fileExists(atPath: sortie.path)
                print(reste
                      ? "  ✗ un fichier de sortie subsiste : \(sortie.path)"
                      : "  ✓ aucun fichier laissé sur le disque")
                code = reste ? 1 : 0
            } catch {
                effacerLigne()
                print("✗ Export impossible : \(message(pour: error))")
                code = 1
            }
            verrou.signal()
        }
        verrou.wait()
        return code
    }

    // MARK: - Affichage

    private static func afficher(_ a: ExportateurVideo.Avancement) {
        let pourcent = Int((a.fraction * 100).rounded())
        let largeur = 30
        let pleins = Int(a.fraction * Double(largeur))
        let barre = String(repeating: "█", count: pleins)
            + String(repeating: "░", count: largeur - pleins)
        let restant = a.restantEstime.map { "reste ~\(duree($0))" } ?? "estimation en cours"
        // \r plutôt qu'un saut de ligne : une seule ligne qui avance, comme le
        // fera la barre de progression de l'interface.
        FileHandle.standardOutput.write(
            Data("\r  \(barre) \(pourcent) %  \(restant)     ".utf8))
    }

    private static func effacerLigne() {
        FileHandle.standardOutput.write(Data("\r\(String(repeating: " ", count: 78))\r".utf8))
    }

    static func duree(_ secondes: TimeInterval) -> String {
        let s = Int(secondes.rounded())
        if s < 60 { return "\(s) s" }
        let m = s / 60
        if m < 60 { return "\(m) min \(String(format: "%02d", s % 60)) s" }
        return "\(m / 60) h \(String(format: "%02d", m % 60)) min"
    }

    static func octets(_ n: Int64) -> String {
        let mo = Double(n) / 1_048_576
        if mo < 1024 { return String(format: "%.1f Mo", mo) }
        return String(format: "%.2f Go", mo / 1024)
    }

    static func message(pour erreur: Error) -> String {
        switch erreur {
        case let e as ErreurPolice: return Textes.Rendu.message(pour: e)
        case let e as ErreurSousTitres: return Textes.SousTitres.message(pour: e)
        case let e as ErreurExport: return Textes.Export.message(pour: e)
        default: return "\(erreur)"
        }
    }
}
