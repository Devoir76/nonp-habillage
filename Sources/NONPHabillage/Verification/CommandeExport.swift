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

    /// `--exporter <vidéo> [<sous-titres>] <sortie> [--profil neutre|nonp|<fichier.json>]`
    ///
    /// Logo : `--logo <image>` `--logo-position haut-gauche|haut-droit|
    /// bas-gauche|bas-droit|<x>,<y>` `--logo-taille <% hauteur>`
    /// `--logo-marge <% hauteur>` `--logo-opacite <0–1>` `--logo-rond`
    ///
    /// Les trois usages de l'ADR s'obtiennent par la présence ou l'absence des
    /// deux options, qui sont indépendantes :
    ///   sous-titres seuls  : donner le .srt, pas de --logo
    ///   logo seul          : donner --logo, pas de .srt
    ///   les deux           : donner les deux
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

        // `--profil` prend un des deux préréglages, ou un FICHIER de profil.
        //
        // Le fichier est ce qui rend la campagne de parité possible : les deux
        // moteurs doivent partir du même profil, au champ près, et le seul qui
        // fasse foi est celui que le prototype emploie en production. Un
        // préréglage de l'app en serait une transcription — donc une source de
        // divergence, et précisément celle qu'on cherche à mesurer.
        var profil = ProfilHabillage.bandeauColore
        var messageMigration: String? = nil
        if let p = args.firstIndex(of: "--profil"), p + 1 < args.count {
            let valeur = args[p + 1]
            switch valeur.lowercased() {
            case "neutre": profil = .neutre
            case "nonp":   profil = .bandeauColore
            default:
                do {
                    // `lireDetaille`, et non `lire` : la seconde rend le profil
                    // converti sans dire qu'elle l'a converti. En interface, le
                    // message est affiché ; ici il se perdait, et un profil v1
                    // passait en v2 en silence — l'invariant nº6 l'interdit,
                    // une conversion silencieuse étant une modification
                    // silencieuse.
                    let lecture = try ProfilJSON.lireDetaille(
                        URL(fileURLWithPath: valeur))
                    profil = lecture.profil
                    if let migration = lecture.migration { messageMigration = migration }
                } catch let e as ErreurProfil {
                    print("✗ Profil refusé : "
                          + Textes.Profil.refus(
                              URL(fileURLWithPath: valeur).lastPathComponent,
                              e.anomalies))
                    return 2
                } catch {
                    print("✗ Profil illisible : \(error)")
                    return 2
                }
            }
        }
        var annulerApres: Double? = nil
        if let a = args.firstIndex(of: "--annuler-apres"), a + 1 < args.count {
            annulerApres = Double(args[a + 1])
        }

        // --- Logo ---------------------------------------------------------
        // Aucun logo n'est posé que l'utilisateur n'ait fourni : ni les
        // préréglages ni l'application n'en apportent un.
        //
        // Un profil FICHIER, lui, en nomme un — c'est son rôle. L'ignorer
        // reviendrait à rendre un habillage amputé sans le dire, alors que le
        // profil a été donné pour être appliqué. `--logo` reste plus fort que
        // le profil : la ligne de commande a le dernier mot sur ce qu'elle
        // désigne explicitement.
        if let l = args.firstIndex(of: "--logo"), l + 1 < args.count {
            profil.logoFichier = URL(fileURLWithPath: args[l + 1])
            profil.logoActif = true
        } else if profil.logoFichier == nil {
            profil.logoActif = false
        }
        if let p = args.firstIndex(of: "--logo-position"), p + 1 < args.count {
            guard let position = lirePosition(args[p + 1]) else {
                print("Position de logo inconnue : « \(args[p + 1]) ».")
                print("Attendu : haut-gauche, haut-droit, bas-gauche, bas-droit, "
                      + "ou deux pourcentages « x,y » désignant le centre du logo.")
                return 2
            }
            profil.logoPosition = position
        }
        if let t = args.firstIndex(of: "--logo-taille"), t + 1 < args.count,
           let v = Double(args[t + 1]) {
            profil.logoTailleRatio = v / 100.0
        }
        if let m = args.firstIndex(of: "--logo-marge"), m + 1 < args.count,
           let v = Double(args[m + 1]) {
            profil.logoMargeRatio = v / 100.0
        }
        if let o = args.firstIndex(of: "--logo-opacite"), o + 1 < args.count,
           let v = Double(args[o + 1]) {
            profil.logoOpacite = v
        }
        if args.contains("--logo-rond") {
            profil.logoRecadreEnCercle = true
        }

        print("Habillage — export")
        print(String(repeating: "─", count: 66))
        print("  vidéo       : \(video.lastPathComponent)")
        print("  sous-titres : \(sousTitres?.lastPathComponent ?? "aucun")")
        var descriptionLogo = "aucun"
        if profil.logoActif {
            descriptionLogo = (profil.logoFichier?.lastPathComponent ?? "?")
                + " — " + descriptionPosition(profil.logoPosition)
                + ", " + arrondi(profil.logoTailleRatio * 100) + " % de la hauteur"
                + ", opacité " + arrondi(profil.logoOpacite * 100) + " %"
                + (profil.logoRecadreEnCercle ? ", recadré en cercle" : "")
        }
        print("  logo        : \(descriptionLogo)")
        print("  usage       : \(usage(sousTitres: sousTitres, profil: profil))")
        print("  profil      : \(profil.nom)")
        if let messageMigration {
            print(Textes.Profil.migrationEnLignes(messageMigration))
        }
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
                print("  logo      : \(bilan.logoIncruste ? "incrusté" : "aucun")")
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

    // MARK: - Options du logo

    /// « haut-gauche »… ou « 50,80 » : deux pourcentages désignant le CENTRE.
    static func lirePosition(_ texte: String) -> PositionLogo? {
        if let coin = CoinLogo(rawValue: texte) { return .coin(coin) }
        let parts = texte.split(separator: ",")
        guard parts.count == 2,
              let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let y = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              (0...100).contains(x), (0...100).contains(y) else { return nil }
        return .libre(xPct: x, yPct: y)
    }

    static func descriptionPosition(_ p: PositionLogo) -> String {
        switch p {
        case .coin(let c): return c.rawValue
        case .libre(let x, let y):
            return "centre à \(arrondi(x)) % × \(arrondi(y)) %"
        }
    }

    /// Lequel des trois usages de l'ADR est en train de s'exécuter.
    static func usage(sousTitres: URL?, profil: ProfilHabillage) -> String {
        switch (sousTitres != nil, profil.logoActif) {
        case (true, true): return "sous-titres + logo"
        case (true, false): return "sous-titres seuls"
        case (false, true): return "logo seul"
        case (false, false): return "ni sous-titres ni logo — rien à graver"
        }
    }

    private static func arrondi(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
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
        case let e as ErreurLogo: return Textes.Logo.message(pour: e)
        default: return "\(erreur)"
        }
    }
}
