// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// PlancheCoins.swift — DC-1 : la ligne des boutons de coin, avant et après,
// à la largeur réelle de la colonne.
//
// `--planche-coins <dossier> [--seuils | --colonne | --dc2]`
//
// ── Ce qui a été décidé ─────────────────────────────────────────────────────
//
// Le 17/09, cette planche présentait quatre propositions : A, abréviations ;
// B, icônes de coin ; C, grille figurant l'image ; D, mots entiers disposés en
// carré. Toutes tenaient sans troncature à 300 points. Éric a retenu A. Les
// trois autres sont parties avec la décision ; elles restent lisibles au
// commit 352eebb, qui produit la planche des quatre.
//
// Reste la comparaison AVANT / APRÈS, et trois usages qui survivent au choix :
//   --seuils   la preuve par l'image que `LibelleSurveille` voit juste ;
//   --colonne  la vraie colonne capturée, pour prouver qu'un changement ne
//              modifie aucun pixel ;
//   --dc2      la reproduction de DC-2, corrigé.
//
// ── Pourquoi une vraie fenêtre, capturée ────────────────────────────────────
//
// `ImageRenderer` dessine les contrôles AppKit en rectangles vides, et
// `cacheDisplay` comme `CALayer.render(in:)` rendent un volet sans texte : zéro
// pixel sombre, vérifié. Juger une troncature sur une image qui ne montre pas
// les libellés serait absurde. La planche pose donc chaque proposition dans une
// vraie fenêtre et capture CETTE fenêtre — ce que l'utilisateur verra, pixel
// pour pixel, à l'échelle de l'écran.
//
// `CGWindowListCreateImage` est retirée du SDK depuis macOS 15, au profit de
// ScreenCaptureKit, qui exige l'autorisation d'enregistrer l'écran — tout comme
// `screencapture`, refusé ici. Capturer SA PROPRE fenêtre, en revanche, reste
// permis : la fonction est appelée par son symbole. C'est un outil de
// vérification, jamais appelé en usage courant ; s'il cesse de fonctionner,
// la planche le dira et rien d'autre ne cassera.
//
// La fenêtre apparaît un instant à l'écran pendant la capture.

import SwiftUI
import AppKit

enum PlancheCoins {

    // MARK: - Les propositions

    enum Proposition: String, CaseIterable {
        case avant, retenue

        var titre: String {
            switch self {
            case .avant: return "Avant — noms complets (DC-1)"
            case .retenue: return "Après — A, abréviations"
            }
        }

        @MainActor @ViewBuilder
        func vue(position: Binding<PositionLogo>) -> some View {
            switch self {
            case .avant:
                NomsComplets(position: position)
            case .retenue:
                PanneauPersonnaliserView.coinsDuLogo(
                    aide: Textes.Aide.positionLogo, position: position)
            }
        }
    }

    // MARK: - Mesure

    /// Les cinq états que la ligne doit tenir : quatre coins, et la position
    /// libre.
    static let positions: [PositionLogo] =
        CoinLogo.allCases.map { .coin($0) } + [.libre(xPct: 50, yPct: 50)]

    @MainActor
    static func libellesTronques<V: View>(_ vue: V, largeur: CGFloat) -> [String] {
        ControlesInterface.libellesTronques(vue, largeur: largeur)
    }

    /// Ce que la proposition tronque à la largeur de contrôle, tous états
    /// confondus.
    @MainActor
    static func tronquesALaLargeurDeControle(_ p: Proposition) -> [String] {
        var tous: [String] = []
        for position in positions {
            for l in libellesTronques(p.vue(position: .constant(position)),
                                      largeur: Fenetre.largeurDeControleReglages)
            where !tous.contains(l) { tous.append(l) }
        }
        return tous
    }

    /// Ce que la ligne occupe quand rien ne la contraint. Pour information : ce
    /// n'est PAS le seuil de troncature — un bouton comprime sa marge avant son
    /// texte.
    @MainActor
    static func largeurNaturelle<V: View>(_ vue: V) -> CGFloat {
        let hote = NSHostingView(rootView: vue)
        hote.layoutSubtreeIfNeeded()
        return hote.fittingSize.width
    }

    // MARK: - Planche

    @MainActor
    static func executer(arguments args: [String]) -> Int32 {
        guard let i = args.firstIndex(of: "--planche-coins"), i + 1 < args.count else {
            print("Usage : --planche-coins <dossier>"); return 2
        }
        let dossier = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        _ = NSApplication.shared

        print("Planche DC-1 — boutons de coin, colonne de \(Int(Fenetre.largeurReglages)) points")
        print(String(repeating: "─", count: 66))
        let exigee = Fenetre.largeurDeControleReglages
        // Les verdicts sont établis AVANT de dessiner la planche : mesurés
        // pendant qu'elle se dessine, ils ne recueillaient rien, et la planche
        // déclarait « aucun libellé tronqué » la ligne même de DC-1.
        var verdicts: [Proposition: [String]] = [:]
        for p in Proposition.allCases {
            let tronques = tronquesALaLargeurDeControle(p)
            verdicts[p] = tronques
            let naturelle = largeurNaturelle(p.vue(position: .constant(.coin(.hautGauche))))
            print("  \(tronques.isEmpty ? "✓" : "✗") \(p.titre) : "
                  + (tronques.isEmpty ? "aucun libellé tronqué"
                     : "tronqués — " + tronques.joined(separator: ", "))
                  + " à \(Int(exigee)) points (largeur naturelle "
                  + "\(Int(naturelle.rounded(.up))))")
        }

        // `--colonne` : la vraie colonne des réglages, capturée dans trois
        // états. Sert à prouver qu'une modification ne change rien à l'écran :
        // deux captures, avant et après, comparées pixel à pixel.
        if args.contains("--colonne") {
            let nu = AppState(memoire: false)
            let logo = AppState(memoire: false)
            logo.profil.logoActif = true
            logo.profil.logoFichier = URL(fileURLWithPath: "/x/logo-nonp.png")
            let bandeau = AppState(memoire: false)
            bandeau.profil.bandeauActif = true
            for (nom, etat) in [("nu", nu), ("logo", logo), ("bandeau", bandeau)] {
                for (a, apparence) in [("sombre", NSAppearance.Name.darkAqua), ("clair", .aqua)] {
                    let vue = ColonneReglages { PanneauPersonnaliserView() }
                        .environmentObject(etat)
                        .environment(\.controlActiveState, .key)
                        .frame(height: 900)
                        .background(Color(nsColor: .windowBackgroundColor))
                    _ = capturerFenetre(vue, apparence: NSAppearance(named: apparence),
                                        vers: dossier.appendingPathComponent("colonne-\(nom)-\(a).png"))
                }
            }
            return 0
        }

        // `--dc2` : la reproduction de DC-2. La vraie colonne, deux fois
        // affichée sans mesure préalable, deux fois après un `fittingSize` :
        // dans le second cas, « Taille » restait figé à sa largeur idéale et
        // débordait. Corrigé par 917817b — les quatre captures le montrent
        // désormais entier.
        if args.contains("--dc2") {
            let logo = AppState(memoire: false)
            logo.profil.logoActif = true
            logo.profil.logoFichier = URL(fileURLWithPath: "/x/logo-nonp.png")
            for mesurer in [false, true] { for essai in 1...2 {
                let hote = NSHostingView(rootView: ColonneReglages { PanneauPersonnaliserView() }
                    .environmentObject(logo).frame(height: 760)
                    .background(Color(nsColor: .windowBackgroundColor)))
                if mesurer { hote.layoutSubtreeIfNeeded(); _ = hote.fittingSize }
                let fenetre = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 365, height: 760),
                                       styleMask: [.borderless], backing: .buffered, defer: false)
                fenetre.isReleasedWhenClosed = false
                fenetre.contentView = hote
                fenetre.orderFrontRegardless()
                RunLoop.current.run(until: Date().addingTimeInterval(0.8))
                typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
                let f = unsafeBitCast(dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage")!, to: Capture.self)
                if let img = f(.null, 8, UInt32(fenetre.windowNumber), 1 | 8)?.takeRetainedValue() {
                    try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?
                        .write(to: dossier.appendingPathComponent("h-\(mesurer ? "avec" : "sans")-mesure-\(essai).png"))
                }
                fenetre.orderOut(nil)
            } }
            return 0
        }
        // `--seuils` : la preuve par l'image que le détecteur de troncature voit
        // juste. La ligne retenue et celle d'avant, de 316 à 250 points, capturées
        // ; le détecteur doit désigner exactement les libellés que l'image
        // montre tronqués.
        if args.contains("--seuils") {
            for w in [316, 300, 290, 280, 270, 260, 250] {
                let a = libellesTronques(Proposition.retenue.vue(position: .constant(.coin(.hautGauche))), largeur: CGFloat(w))
                let c = libellesTronques(Proposition.avant.vue(position: .constant(.coin(.hautGauche))), largeur: CGFloat(w))
                print("  \(w) points — après : \(a.isEmpty ? "aucun" : a.joined(separator: ", ")) ; avant : \(c.isEmpty ? "aucun" : c.joined(separator: ", "))")
            }
            for w in [316, 300, 290, 280, 270, 260, 250] {
                let v = VStack(alignment: .leading) {
                    Proposition.retenue.vue(position: .constant(.coin(.hautGauche)))
                        .frame(width: CGFloat(w), alignment: .leading)
                        .overlay(alignment: .leading) { Rectangle().stroke(Color.red).frame(width: CGFloat(w)) }
                    Proposition.avant.vue(position: .constant(.coin(.hautGauche)))
                        .frame(width: CGFloat(w), alignment: .leading)
                }.padding(8).padding(.trailing, 60).background(Color(nsColor: .windowBackgroundColor))
                _ = capturerFenetre(v, apparence: NSAppearance(named: .aqua),
                                    vers: dossier.appendingPathComponent("seuil-\(w).png"))
            }
            return 0
        }
        var ecrites = 0
        for (nom, apparence) in [("sombre", NSAppearance.Name.darkAqua),
                                  ("clair", NSAppearance.Name.aqua)] {
            let planche = VuePlanche(verdicts: verdicts)
                .environment(\.colorScheme, apparence == .darkAqua ? .dark : .light)
                // Comme une fenêtre active. La fenêtre de capture ne l'est pas,
                // et macOS y grise les accents : le coin choisi y paraissait
                // identique aux autres — un défaut qui n'existe pas à l'usage,
                // et qu'une première planche a fait croire réel.
                .environment(\.controlActiveState, .key)
            let url = dossier.appendingPathComponent("planche-coins-\(nom).png")
            if capturerFenetre(planche, apparence: NSAppearance(named: apparence), vers: url) {
                print("  ✓ \(url.lastPathComponent)")
                ecrites += 1
            } else {
                print("  ✗ \(url.lastPathComponent) : capture impossible")
            }
        }
        return ecrites == 2 ? 0 : 1
    }

    /// Pose la vue dans une vraie fenêtre, à sa taille naturelle, et capture
    /// cette fenêtre. Voir l'en-tête : c'est la seule façon d'obtenir les
    /// contrôles AppKit AVEC leurs libellés.
    @MainActor
    static func capturerFenetre<V: View>(_ vue: V, apparence: NSAppearance?,
                                         vers url: URL) -> Bool {
        // La taille se mesure sur une vue SÉPARÉE. Mesurer la vue affichée
        // fige certains contrôles à leur largeur idéale — c'est DC-2 —, et la
        // capture montrerait un débordement qu'elle aurait elle-même causé.
        let mesure = NSHostingView(rootView: vue)
        mesure.layoutSubtreeIfNeeded()
        let taille = mesure.fittingSize
        let hote = NSHostingView(rootView: vue)
        hote.appearance = apparence
        let fenetre = NSWindow(contentRect: NSRect(origin: NSPoint(x: 40, y: 40), size: taille),
                               styleMask: [.borderless], backing: .buffered, defer: false)
        fenetre.appearance = apparence
        fenetre.isReleasedWhenClosed = false
        fenetre.contentView = hote
        fenetre.orderFrontRegardless()
        defer { fenetre.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))

        typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbole = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") else {
            return false
        }
        let capture = unsafeBitCast(symbole, to: Capture.self)
        // 8 : cette fenêtre seule ; 1 | 8 : sans cadre, meilleure résolution.
        guard let image = capture(.null, 8, UInt32(fenetre.windowNumber), 1 | 8)?
                .takeRetainedValue(),
              let png = NSBitmapImageRep(cgImage: image)
                .representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: url)) != nil
    }
}

// MARK: - La planche elle-même

/// Chaque proposition dans la section Logo complète, à la largeur exacte de la
/// colonne : on juge une ligne à côté de ses voisines, pas seule sur du blanc.
private struct VuePlanche: View {
    let verdicts: [PlancheCoins.Proposition: [String]]

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach(PlancheCoins.Proposition.allCases, id: \.self) { p in
                PanneauPlanche(proposition: p, tronques: verdicts[p] ?? [])
            }
        }
        .padding(24)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct PanneauPlanche: View {
    let proposition: PlancheCoins.Proposition
    let tronques: [String]
    // Cliquable si l'on ouvre la planche en fenêtre ; figé au coin par défaut
    // du profil pour la capture.
    @State private var position: PositionLogo = .coin(.hautGauche)

    var body: some View {
        let exigee = Fenetre.largeurDeControleReglages
        VStack(alignment: .leading, spacing: 8) {
            Text(proposition.titre).font(.headline)
            Text(tronques.isEmpty
                 ? "À \(Int(exigee)) points : aucun libellé tronqué"
                 : "À \(Int(exigee)) points : " + tronques.joined(separator: ", ") + " tronqués")
                .font(.caption)
                .foregroundStyle(tronques.isEmpty ? Color.secondary : Color.red)

            // La colonne, à sa largeur réelle : contenu + marges + réserve de
            // l'ascenseur.
            sectionLogo
                .frame(width: Fenetre.largeurUtileReglages, alignment: .leading)
                .padding(Fenetre.margeReglages)
                .frame(width: Fenetre.largeurReglages, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
                .overlay(Rectangle().stroke(Color.secondary.opacity(0.3)))

            // L'exigence, montrée : la ligne seule, à la largeur de contrôle —
            // les 316 points reçus moins la marge de 16. Un cadre marque la
            // limite ; ce qui dépasse ou se tronque ici ne tient pas.
            Text("Seule, à \(Int(exigee)) points :")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 6)
            proposition.vue(position: .constant(.coin(.hautGauche)))
                .frame(width: exigee, alignment: .leading)
                .overlay(alignment: .leading) {
                    Rectangle().stroke(Color.red.opacity(0.6), lineWidth: 1)
                        .frame(width: exigee)
                }
                .padding(Fenetre.margeReglages)
                .frame(width: Fenetre.largeurReglages, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var sectionLogo: some View {
        typealias V = PanneauPersonnaliserView
        let T = Textes.Interface.self
        let A = Textes.Aide.self
        return VStack(alignment: .leading, spacing: 10) {
            Text(T.logo).font(.headline)
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("logo-nonp.png").lineLimit(1).truncationMode(.middle)
                Spacer()
                Button(T.retirerLogo) {}.buttonStyle(.link)
            }
            proposition.vue(position: $position)
            Text(T.deplacerLogo).font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                V.interrupteur(T.logoRond, aide: A.logoRond, actif: .constant(false))
                Text(T.logoRondExplication)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            V.curseurPourcent(T.tailleLogo, aide: A.tailleLogo,
                              valeur: .constant(0.12), de: 0.01, a: 0.50)
            V.curseurPourcent(T.opaciteLogo, aide: A.opaciteLogo,
                              valeur: .constant(1), de: 0, a: 1)
        }
    }
}

// MARK: - Avant

/// La ligne telle qu'elle était jusqu'au 17/09 : noms complets, coin choisi
/// signalé par la seule couleur du texte. Gardée pour la comparaison, et pour
/// `--seuils` : c'est sur elle que le détecteur de troncature a été validé.
private struct NomsComplets: View {
    @Binding var position: PositionLogo

    var body: some View {
        HStack(spacing: 6) {
            LibelleSurveille(Textes.Interface.positionLogo)
            ForEach(CoinLogo.allCases, id: \.self) { coin in
                Button { position = .coin(coin) } label: {
                    LibelleSurveille(Textes.Interface.nomCoin(coin))
                }
                .buttonStyle(.bordered)
                .tint(position == .coin(coin) ? .accentColor : nil)
            }
        }
        .font(.caption)
    }
}
