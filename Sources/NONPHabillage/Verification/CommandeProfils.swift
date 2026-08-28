// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// CommandeProfils.swift — `--profils <dossier>` : écrire des profils à faire
// relire par le prototype.
//
// « Un profil produit par l'app est accepté par le prototype » — second volet
// du critère d'acceptation du lot 6. Il ne se contrôle pas en Swift : seul le
// prototype sait ce que le prototype accepte, et un contrôle qui relirait ses
// propres écrits ne prouverait rien. L'application écrit donc, et
// `Scripts/verifier.sh` fait relire par `charger_profil()`.
//
// ── Le nom des fichiers PORTE l'attente ──────────────────────────────────────
//
// `accepte-*` : le prototype doit les lire sans une remarque.
// `amende-*`  : il doit les REFUSER, et seulement pour ce que la version 2 du
//               schéma a changé — la version elle-même, qu'il vérifie avant
//               tout le reste, et les champs qui n'existent qu'en v2.
//
// Depuis la décision nº6 du 28/08, TOUS les profils écrits par l'app sont dans
// la seconde catégorie. Ce refus est exact : le prototype ne sait rendre ni un
// bandeau pleine largeur, ni une marge de texte en pourcentage de largeur. Un
// fichier qui le tairait lui ferait rendre autre chose que ce qu'il décrit.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum CommandeProfils {

    static func executer(arguments args: [String]) -> Int32 {
        guard let i = args.firstIndex(of: "--profils"), i + 1 < args.count else {
            FileHandle.standardError.write(Data("usage : --profils <dossier>\n".utf8))
            return 2
        }
        let dossier = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        // Un logo réel : le prototype vérifie que le fichier existe.
        let logo = dossier.appendingPathComponent("logo-de-controle.png")
        guard ecrireLogo(vers: logo) else {
            FileHandle.standardError.write(Data("logo de contrôle illisible\n".utf8))
            return 1
        }

        var nonpAvecLogo = ProfilHabillage.nonpHistorique
        nonpAvecLogo.logoActif = true
        nonpAvecLogo.logoFichier = logo

        // Un profil réglé à la main, mais qui reste dans ce que le prototype
        // sait rendre : c'est le cas d'usage courant, et le plus exigeant sur
        // l'écriture des nombres.
        var regle = ProfilHabillage.nonpHistorique
        regle.nom = "Réglé à la main"
        regle.police = "Georgia"
        regle.tailleRatio = 0.0567
        regle.margeBasseRatio = 0.123
        regle.margeLateraleRatioLargeur = 0.075
        regle.lignesMax = 3
        regle.couleurTexte = CouleurProfil(hex: "#FFD400")
        regle.contourRatio = 0.011
        regle.bandeauCouleur = CouleurProfil(hex: "#0067F6", opacite: 0.42)
        regle.bandeauMargeTexteRatioLargeur = 0.07
        regle.logoPosition = .libre(xPct: 12.5, yPct: 87.5)

        // TOUS « amende- » depuis la version 2 du schéma : le prototype
        // vérifie `schema_version == 1` avant tout le reste et refuse donc
        // n'importe quel profil écrit par l'app. C'est le coût accepté de
        // l'option C (décision nº6), pesé par la décision nº5 — le prototype
        // prend sa retraite avec l'app native, et le sens qui compte, ses
        // profils lus par l'app, reste sans restriction.
        let aEcrire: [(String, ProfilHabillage)] = [
            ("amende-nonp.json", nonpAvecLogo),
            ("amende-nonp-sans-logo.json", .nonpHistorique),
            ("amende-regle-a-la-main.json", regle),
            ("amende-neutre.json", .neutre),
        ]

        var ecrits = 0
        for (nom, profil) in aEcrire {
            do {
                try ProfilJSON.ecrire(profil, vers: dossier.appendingPathComponent(nom))
                print("  ✓ \(nom)")
                ecrits += 1
            } catch let e as ErreurProfil {
                print("  ✗ \(nom) : \(e.anomalies.joined(separator: " ; "))")
            } catch {
                print("  ✗ \(nom) : \(error)")
            }
        }
        return ecrits == aEcrire.count ? 0 : 1
    }

    /// Un PNG minuscule, mais un vrai PNG.
    private static func ecrireLogo(vers url: URL) -> Bool {
        guard let ctx = CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.setFillColor(CGColor(red: 0, green: 0.4, blue: 0.96, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 32, height: 32))
        guard let image = ctx.makeImage(),
              let sortie = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(sortie, image, nil)
        return CGImageDestinationFinalize(sortie)
    }
}
