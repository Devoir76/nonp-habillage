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

            Stepper(value: Binding(
                get: { etat.profil.lignesMax },
                set: { etat.profil.lignesMax = $0 }), in: 1...4) {
                Text("\(Textes.Interface.lignesMax) : \(etat.profil.lignesMax)")
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
                Picker(Textes.Interface.hauteurFixe, selection: Binding(
                    get: { etat.profil.bandeauHauteurFixeLignes },
                    set: { etat.profil.bandeauHauteurFixeLignes = $0 })) {
                    Text(Textes.Interface.hauteurAutomatique).tag(0)
                    ForEach(1...4, id: \.self) { n in
                        Text(Textes.Interface.hauteurLignes(n)).tag(n)
                    }
                }
                .frame(maxWidth: 280)

                curseurPourcent(Textes.Interface.margeBasse,
                                valeur: $etat.profil.margeBasseRatio, de: 0, a: 0.30)
                if etat.profil.bandeauMode == .pleineLargeur {
                    curseurPourcent(Textes.Interface.margeInterieure,
                                    valeur: $etat.profil.bandeauMargeInterieureRatioLargeur,
                                    de: 0, a: 0.25)
                    // La marge intérieure ne borne le texte que si elle est plus
                    // serrée que la longueur de ligne cible. Le dire, plutôt que
                    // de laisser croire à un curseur cassé.
                    if let mep = etat.miseEnPage {
                        if mep.margeInterieureSansEffet {
                            Text(Textes.Interface.margeSansEffet)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(Textes.Interface.colonneDeTexteLargeur(
                                Int(mep.largeurColonneTexte),
                                sur: Int(etat.tailleVideo?.width ?? 0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
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
