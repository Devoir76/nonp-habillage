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
// `amende-*`  : il doit les REFUSER, et seulement pour les trois champs ajoutés
//               au schéma le 23/08 — `mode`, `hauteur_fixe_lignes`,
//               `marge_interieure_pct_largeur`. Ce refus est exact : le
//               prototype ne sait pas rendre un bandeau pleine largeur, et un
//               fichier qui tairait le mode lui ferait rendre autre chose que
//               ce qu'il décrit. Le jour où le prototype recevra l'amendement,
//               ces fichiers passeront dans l'autre catégorie sans changer
//               d'une virgule.

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
        regle.bandeauEspacesLateraux = 7
        regle.logoPosition = .libre(xPct: 12.5, yPct: 87.5)

        let aEcrire: [(String, ProfilHabillage)] = [
            ("accepte-nonp.json", nonpAvecLogo),
            ("accepte-nonp-sans-logo.json", .nonpHistorique),
            ("accepte-regle-a-la-main.json", regle),
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
