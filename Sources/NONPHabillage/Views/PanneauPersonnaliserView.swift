// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// PanneauPersonnaliserView.swift — le volet repliable, fermé par défaut.
//
// ADR §2 : l'écran principal reste minimal, et tout ce qui se règle vit ici.
// Chaque réglage repasse par l'aperçu, sans encoder.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct PanneauPersonnaliserView: View {

    @EnvironmentObject private var etat: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionSousTitres
            Divider()
            sectionBandeau
            Divider()
            sectionLogo
        }
        .padding(.top, 4)
    }

    // MARK: - Sous-titres

    private var sectionSousTitres: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Textes.Interface.sousTitres).font(.headline)

            // Tailles NOMMÉES plutôt qu'un pourcentage : l'utilisateur choisit
            // une apparence, le moteur en déduit la taille selon le format.
            Picker(Textes.Interface.taille, selection: Binding(
                get: { etat.tailleNommee },
                set: { etat.tailleNommee = $0 })) {
                ForEach(TailleNommee.allCases) { t in
                    Text(Textes.Interface.nomTaille(t)).tag(t)
                }
            }
            .pickerStyle(.segmented)

            if let mep = etat.miseEnPage {
                Text(Textes.Interface.tailleEtLongueurLigne(
                    mep.parametres.taille, caracteres: mep.longueurLigneCible))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Picker(Textes.Interface.police, selection: Binding(
                    get: { etat.profil.police },
                    set: { etat.profil.police = $0 })) {
                    ForEach(PolicesSures.disponibles, id: \.self) { f in
                        Text(f).font(.custom(f, size: 13)).tag(f)
                    }
                    Divider()
                    // « Autre police du système » reste accessible, signalée
                    // comme risquée pour le partage (ADR §2).
                    ForEach(PolicesSures.toutes, id: \.self) { f in
                        Text(f).tag(f)
                    }
                }
                .frame(maxWidth: 280)
            }

            if !PolicesSures.estSure(etat.profil.police) {
                Label(Textes.Interface.policeRisquee, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 18) {
                selecteurCouleur(Textes.Interface.couleurTexte,
                                 valeur: $etat.profil.couleurTexte)
                selecteurCouleur(Textes.Interface.couleurContour,
                                 valeur: $etat.profil.contourCouleur)
            }

            // Passe par `etat.lignesMax`, pas par `etat.profil.lignesMax` : la
            // case « Hauteur constante » du bandeau reprend cette valeur, et
            // doit la suivre quand elle change.
            Stepper(value: Binding(
                get: { etat.lignesMax },
                set: { etat.lignesMax = $0 }), in: 1...4) {
                Text("\(Textes.Interface.lignesMax) : \(etat.lignesMax)")
            }
            .frame(maxWidth: 220)
        }
    }

    // MARK: - Bandeau

    private var sectionBandeau: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Textes.Interface.bandeau).font(.headline)

            Toggle(Textes.Interface.bandeauActif, isOn: Binding(
                get: { etat.profil.bandeauActif },
                set: { etat.profil.bandeauActif = $0 }))

            if etat.profil.bandeauActif {
                Picker(Textes.Interface.modeBandeau, selection: Binding(
                    get: { etat.profil.bandeauMode },
                    set: { etat.profil.bandeauMode = $0 })) {
                    Text(Textes.Interface.modePleineLargeur).tag(ModeBandeau.pleineLargeur)
                    Text(Textes.Interface.modeAjuste).tag(ModeBandeau.ajuste)
                }
                .pickerStyle(.segmented)

                selecteurCouleur(Textes.Interface.couleurBandeau,
                                 valeur: $etat.profil.bandeauCouleur)

                // Hauteur constante : ce qui empêche la bande de sauter entre
                // une réplique d'une ligne et une réplique de deux.
                //
                // UNE CASE À COCHER, plus un menu « N lignes ». Le menu et le
                // pas-à-pas « Lignes maximum » affichaient tous deux « 2 » et
                // paraissaient faire double emploi ; ils ne le font pas — l'un
                // borne le TEXTE, l'autre fige la HAUTEUR DU FOND —, mais rien
                // dans l'interface ne le disait. Choisir deux fois le même
                // nombre n'apportait rien : la case reprend celui de « Lignes
                // maximum » et le suit, et la phrase en dessous nomme la valeur
                // reprise, de sorte que les deux réglages se distinguent enfin.
                //
                // Le champ `bandeau.hauteur_fixe_lignes` RESTE au schéma
                // partagé avec sa valeur libre de 0 à 4, comme
                // `marge_interieure_pct_largeur` avant lui : seule la commande
                // disparaît. Un profil du prototype qui fixerait 3 lignes est
                // lu, appliqué et rendu tel quel — la case l'affiche comme
                // « hauteur figée », sans y toucher tant qu'on ne clique pas.
                // C'est exactement ce que le schéma recommandait déjà : « même
                // valeur que lignes_max ».
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(Textes.Interface.hauteurFixe, isOn: Binding(
                        get: { etat.hauteurConstante },
                        set: { etat.hauteurConstante = $0 }))
                    Text(etat.hauteurConstante
                         ? Textes.Interface.hauteurFixeActive(
                             etat.profil.bandeauHauteurFixeLignes)
                         : Textes.Interface.hauteurFixeInactive)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                curseurPourcent(Textes.Interface.margeBasse,
                                valeur: $etat.profil.margeBasseRatio, de: 0, a: 0.30)

                // PAS de curseur « Marge intérieure » ici, et c'est délibéré.
                // Mesuré au lot 5 : sur une 16:9, la marge doit atteindre 22,3 %
                // pour changer quoi que ce soit — 89 % de la course d'un curseur
                // allant de 0 à 25 % sans le moindre effet, parce que la longueur
                // de ligne cible coupe le texte bien avant que la marge ne le
                // touche. Il avait d'abord reçu un
                // avertissement expliquant pourquoi il ne faisait rien —
                // c'était s'excuser d'un réglage inutile plutôt que le retirer.
                //
                // Le champ `bandeau.marge_interieure_pct_largeur` RESTE : au
                // schéma partagé, dans le profil, et dans la géométrie, qui
                // continue de l'appliquer. Rien ne change pour un fichier de
                // profil, et un profil du prototype rend à l'identique. Seule
                // la commande disparaît de l'interface.
                //
                // Elle pourra revenir au lot 6 : la décision nº6 de l'ADR doit
                // trancher qui, de `espaces_lateraux`, de la marge intérieure ou
                // de la longueur de ligne cible, gouverne la largeur de la
                // colonne de texte. Si l'arbitrage lui rend un effet, le curseur
                // reviendra avec.
            }
        }
    }

    // MARK: - Logo

    private var sectionLogo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Textes.Interface.logo).font(.headline)

            if etat.profil.logoActif, let fichier = etat.profil.logoFichier {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(fichier.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button(Textes.Interface.retirerLogo) { etat.retirerLogo() }
                        .buttonStyle(.link)
                }

                // Les quatre coins en UN clic, comme le veut l'ADR — le
                // placement libre à la souris ne doit pas rendre les coins
                // pénibles à retrouver.
                HStack(spacing: 6) {
                    Text(Textes.Interface.positionLogo)
                    ForEach(CoinLogo.allCases, id: \.self) { coin in
                        Button(Textes.Interface.nomCoin(coin)) {
                            etat.profil.logoPosition = .coin(coin)
                        }
                        .buttonStyle(.bordered)
                        .tint(estCoinChoisi(coin) ? .accentColor : nil)
                    }
                }
                .font(.caption)

                Text(Textes.Interface.deplacerLogo)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Le `--make-logo` du prototype, devenu un réglage réversible :
                // on coche, l'aperçu montre le rond, on décoche. Inutile si le
                // PNG fourni est déjà détouré.
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(Textes.Interface.logoRond, isOn: Binding(
                        get: { etat.profil.logoRecadreEnCercle },
                        set: { etat.profil.logoRecadreEnCercle = $0 }))
                    Text(Textes.Interface.logoRondExplication)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                curseurPourcent(Textes.Interface.tailleLogo,
                                valeur: $etat.profil.logoTailleRatio, de: 0.01, a: 0.50)
                curseurPourcent(Textes.Interface.opaciteLogo,
                                valeur: $etat.profil.logoOpacite, de: 0, a: 1)
            } else {
                Button(Textes.Interface.choisirLogo) { choisirLogo() }
            }
        }
    }

    private func estCoinChoisi(_ coin: CoinLogo) -> Bool {
        if case .coin(let c) = etat.profil.logoPosition { return c == coin }
        return false
    }

    private func choisirLogo() {
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = UTType.imagesAcceptees
        panneau.allowsMultipleSelection = false
        if panneau.runModal() == .OK, let url = panneau.url {
            etat.chargerLogo(url)
        }
    }

    // MARK: - Petits contrôles

    /// Sélecteur macOS, avec opacité — le schéma sépare couleur et opacité, et
    /// l'interface doit rester capable d'un fond semi-transparent.
    private func selecteurCouleur(_ titre: String,
                                  valeur: Binding<CouleurProfil>) -> some View {
        ColorPicker(titre, selection: Binding(
            get: { valeur.wrappedValue.couleurSwiftUI },
            set: { valeur.wrappedValue = CouleurProfil(couleurSwiftUI: $0) }),
            supportsOpacity: true)
        .frame(maxWidth: 210)
    }

    private func curseurPourcent(_ titre: String, valeur: Binding<Double>,
                                 de min: Double, a max: Double) -> some View {
        HStack {
            Text(titre).frame(width: 130, alignment: .leading)
            Slider(value: valeur, in: min...max)
            Text("\(Int((valeur.wrappedValue * 100).rounded())) %")
                .font(.caption.monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
        .frame(maxWidth: 420)
    }
}

// MARK: - Ponts de couleur

extension CouleurProfil {
    var couleurSwiftUI: Color {
        Color(.sRGB, red: rouge, green: vert, blue: bleu, opacity: opacite)
    }

    init(couleurSwiftUI couleur: Color) {
        let ns = NSColor(couleur).usingColorSpace(.sRGB) ?? .white
        self.init(rouge: Double(ns.redComponent), vert: Double(ns.greenComponent),
                  bleu: Double(ns.blueComponent), opacite: Double(ns.alphaComponent))
    }
}
