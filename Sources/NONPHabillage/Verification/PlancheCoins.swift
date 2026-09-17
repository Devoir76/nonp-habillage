// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// PlancheCoins.swift — DC-1 : les propositions pour les boutons de coin, côte à
// côte, à la largeur réelle de la colonne.
//
// `--planche-coins <dossier>`
//
// Rien n'est choisi ici : Éric choisit sur la planche. La proposition retenue
// ira remplacer `PanneauPersonnaliserView.coinsDuLogo`, ses textes rejoindront
// `Textes` — ceux des propositions vivent ici tant qu'elles ne sont que des
// propositions, et partiront avec elles.
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
        case actuelle, abreviations, icones, grille169, grille916, motsEnCarre

        var titre: String {
            switch self {
            case .actuelle: return "Actuelle — DC-1"
            case .abreviations: return "A — Abréviations"
            case .icones: return "B — Icônes de coin"
            case .grille169: return "C — Grille, vidéo 16:9"
            case .grille916: return "C — Grille, vidéo 9:16"
            case .motsEnCarre: return "D — Mots entiers, en carré"
            }
        }

        @MainActor @ViewBuilder
        func vue(position: Binding<PositionLogo>) -> some View {
            switch self {
            case .actuelle:
                PanneauPersonnaliserView.coinsDuLogo(
                    aide: Textes.Aide.positionLogo, position: position)
            case .abreviations:
                CoinsAbreges(position: position)
            case .icones:
                CoinsIcones(position: position)
            case .grille169:
                CoinsGrille(position: position, rapport: 16.0 / 9.0)
            case .grille916:
                CoinsGrille(position: position, rapport: 9.0 / 16.0)
            case .motsEnCarre:
                CoinsMotsEnCarre(position: position)
            }
        }
    }

    // MARK: - Mesure

    /// Les cinq états que la ligne doit tenir : quatre coins, et la position
    /// libre — dont le nom, dans la grille, est le plus long.
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
        // dans le second cas, « Taille » reste figé à sa largeur idéale et
        // déborde. Voir docs/defauts-connus.md.
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
        // juste. La ligne A et la ligne actuelle, de 316 à 250 points, capturées
        // ; le détecteur doit désigner exactement les libellés que l'image
        // montre tronqués.
        if args.contains("--seuils") {
            for w in [316, 300, 290, 280, 270, 260, 250] {
                let a = libellesTronques(Proposition.abreviations.vue(position: .constant(.coin(.hautGauche))), largeur: CGFloat(w))
                let c = libellesTronques(Proposition.actuelle.vue(position: .constant(.coin(.hautGauche))), largeur: CGFloat(w))
                print("  \(w) points — A : \(a.isEmpty ? "aucun" : a.joined(separator: ", ")) ; actuelle : \(c.isEmpty ? "aucun" : c.joined(separator: ", "))")
            }
            for w in [316, 300, 290, 280, 270, 260, 250] {
                let v = VStack(alignment: .leading) {
                    Proposition.abreviations.vue(position: .constant(.coin(.hautGauche)))
                        .frame(width: CGFloat(w), alignment: .leading)
                        .overlay(alignment: .leading) { Rectangle().stroke(Color.red).frame(width: CGFloat(w)) }
                    Proposition.actuelle.vue(position: .constant(.coin(.hautGauche)))
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

// MARK: - Le bouton choisi se voit

/// `.tint(.accentColor)` sur un bouton `.bordered` — ce que fait la ligne
/// actuelle — ne change RIEN à l'écran, en clair comme en sombre : la planche
/// l'a montré. Le coin retenu n'est signalé nulle part. Les propositions à
/// boutons le montrent en style proéminent, sans quoi on les comparerait à la
/// grille, qui, elle, le montre.
private struct BoutonCoin<Etiquette: View>: View {
    let choisi: Bool
    let action: () -> Void
    @ViewBuilder let etiquette: () -> Etiquette

    var body: some View {
        if choisi {
            Button(action: action, label: etiquette).buttonStyle(.borderedProminent)
        } else {
            Button(action: action, label: etiquette).buttonStyle(.bordered)
        }
    }
}

// MARK: - A — Abréviations

/// Le changement le plus léger : on garde des mots, raccourcis. Le nom complet
/// en infobulle.
private struct CoinsAbreges: View {
    @Binding var position: PositionLogo

    static func abrege(_ coin: CoinLogo) -> String {
        switch coin {
        case .hautGauche: return "Haut G."
        case .hautDroit: return "Haut D."
        case .basGauche: return "Bas G."
        case .basDroit: return "Bas D."
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            LibelleSurveille(Textes.Interface.positionLogo)
            ForEach(CoinLogo.allCases, id: \.self) { coin in
                BoutonCoin(choisi: position == .coin(coin),
                           action: { position = .coin(coin) }) {
                    LibelleSurveille(Self.abrege(coin))
                }
                .help(Textes.Interface.nomCoin(coin))
            }
        }
        .font(.caption)
    }
}

// MARK: - B — Icônes de coin

/// Un symbole système par coin — un rectangle dont le coin est plein. Le nom
/// complet en infobulle et pour VoiceOver.
private struct CoinsIcones: View {
    @Binding var position: PositionLogo

    static func symbole(_ coin: CoinLogo) -> String {
        switch coin {
        case .hautGauche: return "rectangle.inset.topleft.filled"
        case .hautDroit: return "rectangle.inset.topright.filled"
        case .basGauche: return "rectangle.inset.bottomleft.filled"
        case .basDroit: return "rectangle.inset.bottomright.filled"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            LibelleSurveille(Textes.Interface.positionLogo)
            ForEach(CoinLogo.allCases, id: \.self) { coin in
                BoutonCoin(choisi: position == .coin(coin),
                           action: { position = .coin(coin) }) {
                    Image(systemName: Self.symbole(coin)).font(.body)
                }
                .help(Textes.Interface.nomCoin(coin))
                .accessibilityLabel(Textes.Interface.nomCoin(coin))
            }
        }
        .font(.caption)
    }
}

// MARK: - C — Grille figurant l'image

/// Une vignette aux proportions de la vidéo, dont on clique le coin. Elle
/// montre ce qu'on choisit au lieu de le nommer, et fait écho au glisser-déposer
/// du logo sur l'aperçu. Le coin retenu est nommé à côté : c'est ce qui la rend
/// lisible sans infobulle.
private struct CoinsGrille: View {
    @Binding var position: PositionLogo
    /// Largeur sur hauteur de la vidéo.
    let rapport: CGFloat

    private var taille: CGSize {
        rapport >= 1
            ? CGSize(width: 40 * rapport, height: 40)
            : CGSize(width: 56 * rapport, height: 56)
    }

    var body: some View {
        HStack(spacing: 10) {
            LibelleSurveille(Textes.Interface.positionLogo)
            vignette
            LibelleSurveille(nomChoisi).foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var nomChoisi: String {
        if case .coin(let c) = position { return Textes.Interface.nomCoin(c) }
        return "Position libre"
    }

    private var vignette: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) { zone(.hautGauche); zone(.hautDroit) }
            HStack(spacing: 0) { zone(.basGauche); zone(.basDroit) }
        }
        .frame(width: taille.width, height: taille.height)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.secondary.opacity(0.6)))
    }

    private func zone(_ coin: CoinLogo) -> some View {
        let choisi = position == .coin(coin)
        let alignement: Alignment = {
            switch coin {
            case .hautGauche: return .topLeading
            case .hautDroit: return .topTrailing
            case .basGauche: return .bottomLeading
            case .basDroit: return .bottomTrailing
            }
        }()
        return Button { position = .coin(coin) } label: {
            RoundedRectangle(cornerRadius: 2)
                .fill(choisi ? Color.accentColor : Color.secondary.opacity(0.45))
                .frame(width: 9, height: 9)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignement)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Textes.Interface.nomCoin(coin))
        .accessibilityLabel(Textes.Interface.nomCoin(coin))
    }
}

// MARK: - D — Mots entiers, en carré

/// Ma proposition : les noms COMPLETS, disposés comme les coins qu'ils
/// désignent. Rien n'est abrégé ni caché dans une infobulle, et la disposition
/// dit la même chose que les mots. Elle coûte une ligne de hauteur.
private struct CoinsMotsEnCarre: View {
    @Binding var position: PositionLogo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LibelleSurveille(Textes.Interface.positionLogo)
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow { bouton(.hautGauche); bouton(.hautDroit) }
                GridRow { bouton(.basGauche); bouton(.basDroit) }
            }
        }
        .font(.caption)
    }

    private func bouton(_ coin: CoinLogo) -> some View {
        BoutonCoin(choisi: position == .coin(coin), action: { position = .coin(coin) }) {
            LibelleSurveille(Textes.Interface.nomCoin(coin)).frame(minWidth: 84)
        }
    }
}
