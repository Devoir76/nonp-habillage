// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// CaptureInterface.swift — l'interface rendue en image, sans la piloter.
//
// Les contrôles chiffrés du lot 5 disent que l'aperçu réagit et que les
// avertissements tombent au bon moment. Ils ne disent RIEN de la disposition :
// un volet qui déborde, un bouton coupé, une colonne trop étroite passent tous
// les contrôles du monde.
//
// `ImageRenderer` rend la hiérarchie SwiftUI hors écran. On peut donc regarder
// l'interface — et vérifier, mesure à l'appui, que l'accueil tient dans la
// fenêtre sans défilement, ce qui est un critère d'acceptation du lot.
//
// DEUX LIMITES, constatées en s'en servant — les connaître évite de conclure
// de travers :
//
// 1. `ImageRenderer` dessine les contrôles AppKit — menus, curseurs,
//    interrupteurs, sélecteurs de couleur — comme des RECTANGLES VIDES. Ce
//    qu'il rend fidèlement, c'est ce que nous peignons nous-mêmes : l'aperçu,
//    les avertissements, l'enchaînement des blocs. Un rectangle jaune sur une
//    capture n'est donc pas un contrôle cassé.
// 2. Une `ScrollView` n'a pas de taille de contenu hors écran : elle ressort
//    VIDE. D'où la capture nº4, qui rend le volet sans zone défilante.
//
// La mesure de disposition, elle, ne passe pas par ici : `ControlesInterface`
// interroge la vraie disposition AppKit via `NSHostingView.fittingSize`.
//
// Ce n'est pas un test d'interface : cela ne remplace pas le jugement d'Éric.
// C'est de quoi ne pas livrer une fenêtre qu'on n'a jamais vue.

import SwiftUI
import AppKit
import CoreGraphics

enum CaptureInterface {

    /// `--capture <dossier> [--video <fichier>] [--corpus-srt <fichier>]
    ///  [--logo <image>]`
    @MainActor
    static func executer(arguments args: [String]) -> Int32 {
        guard let i = args.firstIndex(of: "--capture"), i + 1 < args.count else { return 2 }
        let dossier = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        // Une application AppKit doit exister pour que les vues se disposent.
        _ = NSApplication.shared

        print("Capture de l'interface — lot 5")
        print(String(repeating: "─", count: 66))

        var ecrites: [String] = []
        let etat = AppState()

        func capturer(_ nom: String, hauteur: CGFloat) {
            let vue = FenetrePrincipaleView.pourCapture(etat: etat)
                .frame(width: 620, height: hauteur)
            let rendu = ImageRenderer(content: vue)
            rendu.scale = 2
            guard let image = rendu.cgImage else {
                print("  ✗ \(nom) : rendu impossible"); return
            }
            let url = dossier.appendingPathComponent("\(nom).png")
            try? ImagesReference.ecrire(image, vers: url)
            ecrites.append(nom)
            print("  ✓ \(nom).png  (\(image.width / 2)×\(image.height / 2) points)")
        }

        // 1. Accueil vide.
        capturer("1-accueil-vide", hauteur: 420)

        // 2 et 3 demandent une vraie vidéo.
        if let v = args.firstIndex(of: "--video"), v + 1 < args.count {
            let video = URL(fileURLWithPath: args[v + 1])
            etat.chargerVideo(video)
            attendre(que: { etat.apercu != nil }, secondes: 20)

            if let s = args.firstIndex(of: "--corpus-srt"), s + 1 < args.count {
                etat.chargerSousTitres(URL(fileURLWithPath: args[s + 1]))
            }
            if let l = args.firstIndex(of: "--logo"), l + 1 < args.count {
                etat.chargerLogo(URL(fileURLWithPath: args[l + 1]))
                // En bas à gauche : la position qui déclenche l'avertissement
                // de zone, pour qu'il soit visible sur la capture.
                etat.profil.logoPosition = .coin(.basGauche)
                etat.profil.logoRecadreEnCercle = true
            }
            etat.rafraichirApercu()
            attendre(que: { etat.apercu != nil }, secondes: 5)

            capturer("2-accueil-charge", hauteur: 420)

            etat.voletOuvert = true
            // Aux dimensions réelles de la fenêtre, volet ouvert.
            let vue = FenetrePrincipaleView.pourCapture(etat: etat)
                .frame(width: Fenetre.largeurIdealeOuverte,
                       height: Fenetre.hauteurIdealeOuverte)
            let renduDeux = ImageRenderer(content: vue)
            renduDeux.scale = 2
            if let image = renduDeux.cgImage {
                try? ImagesReference.ecrire(
                    image, vers: dossier.appendingPathComponent("3-deux-colonnes.png"))
                ecrites.append("3-deux-colonnes")
                print("  ✓ 3-deux-colonnes.png  (\(image.width / 2)×\(image.height / 2) points)")
            }

            // Le volet, rendu SANS ScrollView. `ImageRenderer` ne donne pas de
            // taille de contenu à une zone défilante hors écran et la rend
            // vide : sans cette seconde capture, on prendrait une limite du
            // rendu pour un volet qui ne s'affiche pas.
            let volet = VStack(alignment: .leading, spacing: 16) {
                ApercuView()
                PanneauPersonnaliserView()
            }
            .padding(20)
            .frame(width: 620)
            .environmentObject(etat)
            let renduVolet = ImageRenderer(content: volet)
            renduVolet.scale = 2
            if let image = renduVolet.cgImage {
                try? ImagesReference.ecrire(
                    image, vers: dossier.appendingPathComponent("4-volet-sans-defilement.png"))
                ecrites.append("4-volet-sans-defilement")
                print("  ✓ 4-volet-sans-defilement.png  "
                      + "(\(image.width / 2)×\(image.height / 2) points)")
            }
        } else {
            print("  — captures 2 et 3 : non exécutées (passer --video <fichier>)")
        }

        print("")
        print("  ⚠︎  Les contrôles AppKit (menus, curseurs, interrupteurs) ressortent")
        print("     en rectangles vides : c'est une limite du rendu hors écran, pas")
        print("     un défaut de l'interface. Seul ce que l'app peint elle-même —")
        print("     l'aperçu, les avertissements — est fidèle.")
        print("\n✓ \(ecrites.count) captures dans \(dossier.path)")
        return ecrites.isEmpty ? 1 : 0
    }

    /// Laisse tourner la boucle d'exécution jusqu'à ce qu'une condition soit
    /// remplie. Les chargements d'`AppState` sont asynchrones.
    @MainActor
    private static func attendre(que condition: () -> Bool, secondes: Double) {
        let limite = Date().addingTimeInterval(secondes)
        while !condition() && Date() < limite {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }
}

extension FenetrePrincipaleView {
    /// La même fenêtre, mais adossée à un état fourni.
    ///
    /// La vue crée normalement son propre `AppState` : c'est ce qu'il faut en
    /// usage réel, mais la capture doit pouvoir peupler l'état à l'avance.
    @MainActor
    static func pourCapture(etat: AppState) -> some View {
        ContenuFenetre().environmentObject(etat)
    }
}
