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

    // Il y avait ici une section « Profil » : le nom du profil courant, deux
    // boutons de préréglage, Importer et Exporter. Elle est partie le
    // 28/08/2026, et le volet ne contient plus que des RÉGLAGES.
    //
    // Motif : la notion de profil était mise en avant bien au-delà de ce
    // qu'elle sert. La plupart des utilisateurs n'auront qu'un seul habillage,
    // et la seule chose qu'ils en attendent est qu'il se retrouve d'une
    // session à l'autre — ce que la mémorisation fait déjà, sans qu'on ait à
    // nommer quoi que ce soit. Une section en tête de colonne demandait de
    // comprendre un concept pour se servir de réglages qui n'en avaient pas
    // besoin.
    //
    // Les trois gestes qui restent — importer, exporter, revenir aux réglages
    // par défaut — sont rares et délibérés : ils vivent au menu Fichier, qui
    // est fait pour ça (`CommandesProfil`). Et les deux préréglages sont
    // devenus des fichiers d'exemple : un préréglage qui n'est qu'un exemple
    // n'a pas besoin d'un bouton, il a besoin d'être trouvable.

    // MARK: - Sous-titres

    /// Les réglages de sous-titre, GRISÉS tant qu'aucun fichier n'est chargé.
    ///
    /// On ne règle pas l'apparence d'un texte qu'on n'a pas. L'aperçu affichait
    /// autrefois une phrase à nous pour combler ce vide ; elle a disparu au lot
    /// 6, parce qu'un texte qui n'est pas le sien, posé sur sa propre vidéo, se
    /// lit comme un sous-titre qui va être gravé. Les réglages étant désormais
    /// mémorisés d'une session à l'autre, on règle UNE FOIS avec son vrai
    /// texte, et le besoin disparaît avec la phrase.
    ///
    /// Grisés, et non cachés : la colonne ne saute pas d'une hauteur à l'autre
    /// quand un fichier arrive, et l'on voit ce qu'on obtiendrait en en
    /// ajoutant un. Le message dit quoi faire.
    private var sectionSousTitres: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Textes.Interface.sousTitres).font(.headline)

            if !etat.aSousTitres {
                Text(Textes.Interface.ajoutezDesSousTitres)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
            // Tailles NOMMÉES plutôt qu'un pourcentage : l'utilisateur choisit
            // une apparence, le moteur en déduit la taille selon le format.
            Self.choixSegmente(Textes.Interface.taille, selection: Binding(
                get: { etat.tailleNommee },
                set: { etat.tailleNommee = $0 })) {
                ForEach(TailleNommee.allCases) { t in
                    Text(Textes.Interface.nomTaille(t)).tag(t)
                }
            }

            if let mep = etat.miseEnPage {
                Text(Textes.Interface.tailleEtLongueurLigne(
                    mep.parametres.taille, caracteres: mep.longueurLigneCible))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Self.choixPolice(selection: Binding(
                get: { etat.profil.police },
                set: { etat.profil.police = $0 }))

            if !PolicesSures.estSure(etat.profil.police) {
                Label(Textes.Interface.policeRisquee, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Self.selecteurCouleur(Textes.Interface.couleurTexte,
                                  valeur: $etat.profil.couleurTexte)
            Self.selecteurCouleur(Textes.Interface.couleurContour,
                                  valeur: $etat.profil.contourCouleur)

            // Passe par `etat.lignesMax`, pas par `etat.profil.lignesMax` : la
            // case « Hauteur constante » du bandeau reprend cette valeur, et
            // doit la suivre quand elle change.
            Self.pasAPas(Textes.Interface.lignesMax, valeur: Binding(
                get: { etat.lignesMax },
                set: { etat.lignesMax = $0 }), de: 1, a: 4)
            }
            .modifier(SansSousTitres(actif: etat.aSousTitres))
        }
    }

    // MARK: - Bandeau

    /// Le fond derrière le texte — grisé avec le reste, et pour la même raison.
    ///
    /// Le schéma partagé le range sous `sous_titre.bandeau` : c'est un réglage
    /// de sous-titre, pas une section indépendante. Sans fichier, il n'a pas
    /// plus de sens que la couleur du texte, et le chemin « logo seul » ne doit
    /// pas laisser croire qu'un bandeau sera gravé.
    private var sectionBandeau: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Textes.Interface.bandeau).font(.headline)

            VStack(alignment: .leading, spacing: 10) {
            Self.interrupteur(Textes.Interface.bandeauActif, actif: Binding(
                get: { etat.profil.bandeauActif },
                set: { etat.profil.bandeauActif = $0 }))

            if etat.profil.bandeauActif {
                Self.choixSegmente(Textes.Interface.modeBandeau, selection: Binding(
                    get: { etat.profil.bandeauMode },
                    set: { etat.profil.bandeauMode = $0 })) {
                    Text(Textes.Interface.modePleineLargeur).tag(ModeBandeau.pleineLargeur)
                    Text(Textes.Interface.modeAjuste).tag(ModeBandeau.ajuste)
                }

                Self.selecteurCouleur(Textes.Interface.couleurBandeau,
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
                    Self.interrupteur(Textes.Interface.hauteurFixe, actif: Binding(
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

                Self.curseurPourcent(Textes.Interface.margeBasse,
                                     valeur: $etat.profil.margeBasseRatio,
                                     de: 0, a: 0.30)

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
            .modifier(SansSousTitres(actif: etat.aSousTitres))
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
                Self.coinsDuLogo(position: $etat.profil.logoPosition)

                Text(Textes.Interface.deplacerLogo)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Le `--make-logo` du prototype, devenu un réglage réversible :
                // on coche, l'aperçu montre le rond, on décoche. Inutile si le
                // PNG fourni est déjà détouré.
                VStack(alignment: .leading, spacing: 2) {
                    Self.interrupteur(Textes.Interface.logoRond, actif: Binding(
                        get: { etat.profil.logoRecadreEnCercle },
                        set: { etat.profil.logoRecadreEnCercle = $0 }))
                    Text(Textes.Interface.logoRondExplication)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Self.curseurPourcent(Textes.Interface.tailleLogo,
                                     valeur: $etat.profil.logoTailleRatio,
                                     de: 0.01, a: 0.50)
                Self.curseurPourcent(Textes.Interface.opaciteLogo,
                                     valeur: $etat.profil.logoOpacite, de: 0, a: 1)
            } else {
                Button(Textes.Interface.choisirLogo) { choisirLogo() }
            }
        }
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

    /// Un choix segmenté : le libellé AU-DESSUS du sélecteur, jamais à sa
    /// gauche.
    ///
    /// `Picker(titre, …)` range son libellé à GAUCHE du contrôle et lui donne
    /// ce qui reste une fois le sélecteur servi. Dans une colonne de 360 points
    /// dont l'ascenseur prend sa part, il ne restait presque rien : « Taille »
    /// se cassait en « Ta / ill / e », trois lignes verticales à côté d'un
    /// sélecteur qui, lui, tenait très bien. Le seuil est net — le sélecteur
    /// tient sur une ligne à 328 points, se casse en deux à 313, en quatre à
    /// 300 —, et la colonne se tenait juste au-dessus.
    ///
    /// Élargir la colonne n'aurait fait que repousser le seuil. Le libellé
    /// au-dessus le supprime : il a toute la largeur de la colonne, le
    /// sélecteur aussi, et aucun des deux ne prend sa place sur l'autre. C'est
    /// aussi la disposition la plus lisible pour un choix segmenté, qui se lit
    /// comme une rangée d'options et non comme la valeur d'un champ.
    ///
    /// `static` : le contrôle de disposition mesure CETTE fonction, pas une
    /// copie de sa disposition écrite à côté.
    @MainActor
    static func choixSegmente<Valeur: Hashable, Options: View>(
        _ titre: String,
        selection: Binding<Valeur>,
        @ViewBuilder options: () -> Options) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titre)
            Picker("", selection: selection, content: options)
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }

    /// Le choix de la police. Libellé à gauche, comme tout menu déroulant.
    @MainActor
    static func choixPolice(selection: Binding<String>) -> some View {
        Picker(Textes.Interface.police, selection: selection) {
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

    /// Sélecteur macOS, avec opacité — le schéma sépare couleur et opacité, et
    /// l'interface doit rester capable d'un fond semi-transparent.
    ///
    /// Les deux couleurs des sous-titres étaient côte à côte sur une même ligne :
    /// 313 points partagés en deux, moins deux pastilles, ne laissaient pas de
    /// quoi écrire « Couleur du texte ». L'une sous l'autre, chacune a la
    /// colonne entière.
    @MainActor
    static func selecteurCouleur(_ titre: String,
                                 valeur: Binding<CouleurProfil>) -> some View {
        ColorPicker(titre, selection: Binding(
            get: { valeur.wrappedValue.couleurSwiftUI },
            set: { valeur.wrappedValue = CouleurProfil(couleurSwiftUI: $0) }),
            supportsOpacity: true)
        .frame(maxWidth: 210)
    }

    /// Une case à cocher.
    @MainActor
    static func interrupteur(_ titre: String, actif: Binding<Bool>) -> some View {
        Toggle(titre, isOn: actif)
    }

    /// Un pas-à-pas dont le libellé porte la valeur : « Lignes maximum : 2 ».
    @MainActor
    static func pasAPas(_ titre: String, valeur: Binding<Int>,
                        de min: Int, a max: Int) -> some View {
        Stepper(value: valeur, in: min...max) {
            Text("\(titre) : \(valeur.wrappedValue)")
        }
        .frame(maxWidth: 220)
    }

    /// Les quatre coins, en un clic.
    ///
    /// Libellé en ligne, et il y reste : mesuré, il tient. Les boutons bordés
    /// se compriment sans que le texte se replie — c'est la dégradation
    /// acceptable, et le contrôle de disposition la distingue d'un repli.
    @MainActor
    static func coinsDuLogo(position: Binding<PositionLogo>) -> some View {
        HStack(spacing: 6) {
            Text(Textes.Interface.positionLogo)
            ForEach(CoinLogo.allCases, id: \.self) { coin in
                Button(Textes.Interface.nomCoin(coin)) {
                    position.wrappedValue = .coin(coin)
                }
                .buttonStyle(.bordered)
                .tint(position.wrappedValue == .coin(coin) ? .accentColor : nil)
            }
        }
        .font(.caption)
    }

    /// Un curseur en pourcentage : libellé, course, valeur.
    ///
    /// Le libellé a une colonne À LUI, de largeur fixe — c'est ce qui le met à
    /// l'abri : la course du curseur prend ce qui reste, jamais sa place. Cette
    /// largeur doit rester supérieure au plus long libellé de curseur, et le
    /// contrôle de disposition le vérifie.
    @MainActor
    static func curseurPourcent(_ titre: String, valeur: Binding<Double>,
                                de min: Double, a max: Double) -> some View {
        HStack {
            Text(titre).frame(width: Fenetre.largeurLibelleCurseur, alignment: .leading)
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

/// Ce qui grise une section faute de sous-titres.
///
/// Un seul endroit pour les deux sections concernées, et pour l'opacité comme
/// pour le `disabled` : les deux doivent aller ensemble, sinon on obtient soit
/// des commandes mortes qui n'en ont pas l'air, soit des commandes pâles qui
/// répondent quand même.
struct SansSousTitres: ViewModifier {
    let actif: Bool

    func body(content: Content) -> some View {
        content
            .disabled(!actif)
            .opacity(actif ? 1 : 0.45)
    }
}
