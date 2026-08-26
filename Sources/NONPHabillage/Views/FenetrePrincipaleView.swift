// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// FenetrePrincipaleView.swift — l'unique fenêtre.
//
// ADR §2 : « Écran principal minimal : zone de dépôt, un bouton Habiller, une
// barre de progression. Rien d'autre. » Volet fermé, c'est exactement ce qu'on
// voit, et cela tient sans défilement.
//
// ── Volet ouvert : DEUX COLONNES ─────────────────────────────────────────────
//
// L'aperçu à GAUCHE, grand et toujours visible ; les réglages à DROITE, dans
// une colonne défilante. C'est la seule disposition qui permette de régler en
// VOYANT. Empilés en une seule colonne — première version de ce lot —, l'aperçu
// se retrouvait minuscule et les réglages loin en dessous : on réglait à
// l'aveugle, précisément ce que l'ADR reproche au prototype.
//
// L'aperçu occupe toute la place que la fenêtre lui laisse et grandit avec elle.
// L'image y est mise à l'échelle pour tenir ENTIÈRE : jamais recadrée, jamais
// rognée — on ne juge pas un habillage sur un morceau d'image.

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Dimensions de la fenêtre, en points.
///
/// Rassemblées ici pour que le contrôle de disposition mesure exactement ce que
/// l'application applique, plutôt que des valeurs recopiées à côté.
enum Fenetre {
    /// Volet fermé, aucune vidéo : l'écran d'accueil seul.
    static let largeurFermee: CGFloat = 620
    static let hauteurFermee: CGFloat = 420

    /// Volet fermé, une vidéo chargée : la fenêtre grandit pour loger son
    /// image. Une hauteur inchangée n'aurait laissé qu'une vignette, qui ne
    /// confirmerait rien.
    static let hauteurFermeeAvecVideo: CGFloat = 580
    /// En deçà, l'image de l'accueil ne montrerait plus rien de reconnaissable.
    static let hauteurMinimaleImageAccueil: CGFloat = 180

    /// Volet ouvert : il faut la place de deux colonnes.
    static let largeurMinimaleOuverte: CGFloat = 1020
    static let largeurIdealeOuverte: CGFloat = 1180
    static let hauteurMinimaleOuverte: CGFloat = 720
    static let hauteurIdealeOuverte: CGFloat = 860

    /// Largeur de la colonne des réglages : assez pour un curseur et son
    /// libellé sans que le texte se replie ligne à ligne.
    static let largeurReglages: CGFloat = 360
    /// En deçà, l'aperçu ne montrerait plus rien d'utile.
    static let largeurMinimaleApercu: CGFloat = 560
    /// Idem en hauteur.
    static let hauteurMinimaleApercu: CGFloat = 300
}

struct FenetrePrincipaleView: View {

    @StateObject private var etat = AppState()

    var body: some View {
        ContenuFenetre()
            .environmentObject(etat)
    }
}

/// Le contenu proprement dit, adossé à l'état fourni par l'environnement.
///
/// Séparé de `FenetrePrincipaleView` pour que la capture hors écran et le
/// contrôle de disposition puissent peupler l'état à l'avance — la vue
/// principale, elle, crée le sien.
struct ContenuFenetre: View {

    @EnvironmentObject var etat: AppState

    var body: some View {
        Group {
            switch etat.etape {
            case .accueil: accueil
            case .enCours: ProgressionView()
            case .termine(let url): TermineView(sortie: url)
            }
        }
        .frame(
            minWidth: etat.voletOuvert ? Fenetre.largeurMinimaleOuverte : Fenetre.largeurFermee,
            idealWidth: etat.voletOuvert ? Fenetre.largeurIdealeOuverte : Fenetre.largeurFermee,
            maxWidth: .infinity,
            minHeight: hauteurMinimale,
            idealHeight: hauteurIdeale,
            maxHeight: .infinity)
        .coordinateSpace(name: "apercu")
    }

    /// Trois états, dans l'ordre où on les rencontre : l'accueil nu, l'accueil
    /// qui montre une image de la vidéo, le volet ouvert.
    ///
    /// La hauteur MINIMALE augmente quand une vidéo arrive : c'est elle qui fait
    /// grandir la fenêtre, l'idéale ne valant qu'à l'ouverture.
    private var hauteurMinimale: CGFloat {
        if etat.voletOuvert { return Fenetre.hauteurMinimaleOuverte }
        return etat.video != nil ? Fenetre.hauteurFermeeAvecVideo : Fenetre.hauteurFermee
    }

    private var hauteurIdeale: CGFloat {
        if etat.voletOuvert { return Fenetre.hauteurIdealeOuverte }
        return etat.video != nil ? Fenetre.hauteurFermeeAvecVideo : Fenetre.hauteurFermee
    }

    // MARK: - Accueil

    private var accueil: some View {
        VStack(spacing: 0) {
            BarreEntrees(habiller: habiller)
            if etat.voletOuvert {
                Divider()
                deuxColonnes
            } else if etat.video != nil {
                // Volet fermé mais vidéo chargée : son image, et rien d'autre.
                Divider()
                ImageAccueilView()
            } else {
                // Rien à montrer sous les zones de dépôt — mais la place vide
                // doit rester EN DESSOUS. Sans ce ressort, une fenêtre agrandie
                // centrait la barre verticalement et la laissait flotter au
                // milieu de nulle part : c'est ce qui faisait croire à une
                // application cassée. Le cas se rencontre en agrandissant la
                // fenêtre, et désormais aussi en retirant la vidéo.
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Deux colonnes

    private var deuxColonnes: some View {
        HStack(spacing: 0) {
            // Gauche : l'aperçu, qui prend toute la place restante.
            //
            // Fond sombre volontaire, comme dans un lecteur vidéo : l'image ne
            // remplit jamais exactement un volet rectangulaire — une vidéo
            // verticale y laisse forcément deux bandes —, et cette place vide
            // doit se lire comme un passe-partout, pas comme un trou.
            ApercuView()
                .padding(16)
                .frame(minWidth: Fenetre.largeurMinimaleApercu,
                       maxWidth: .infinity,
                       minHeight: Fenetre.hauteurMinimaleApercu,
                       maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            // Droite : les réglages, en colonne défilante de largeur constante.
            // Défilante, donc TOUS atteignables quelle que soit la hauteur.
            ScrollView {
                PanneauPersonnaliserView()
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: Fenetre.largeurReglages)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Lancement

    private func habiller() {
        guard let proposee = etat.sortieProposee else { return }
        let panneau = NSSavePanel()
        panneau.allowedContentTypes = [.mpeg4Movie]
        panneau.nameFieldStringValue = proposee.lastPathComponent
        panneau.directoryURL = proposee.deletingLastPathComponent()
        if panneau.runModal() == .OK, let url = panneau.url {
            etat.habiller(vers: url)
        }
    }
}

/// La barre du haut : ce qu'on dépose, et ce qu'on lance.
///
/// Hauteur NATURELLE, jamais étirée. C'est son étirement qui creusait, dans la
/// première version, un grand vide entre elle et l'aperçu.
///
/// Vue à part entière, et pas un simple `var` de la fenêtre : le contrôle de
/// disposition a besoin de MESURER sa hauteur réelle pour savoir ce qui reste à
/// l'aperçu. L'estimer à la hausse donnait une place minimale bien plus
/// pessimiste que la vraie.
struct BarreEntrees: View {

    @EnvironmentObject var etat: AppState
    var habiller: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            ZoneDepotView(
                titre: Textes.Interface.deposezVotreVideo,
                sousTitre: Textes.Interface.formatsAcceptes,
                symbole: "film",
                typesAcceptes: UTType.videosAcceptees,
                fichierCharge: descriptionVideo,
                onFichier: { etat.chargerVideo($0) },
                onRetirer: etat.video != nil ? { etat.retirerVideo() } : nil)

            ZoneDepotView(
                titre: Textes.Interface.sousTitresFacultatifs,
                sousTitre: "SRT ou VTT",
                symbole: "captions.bubble",
                typesAcceptes: UTType.sousTitresAcceptes,
                fichierCharge: descriptionSousTitres,
                onFichier: { etat.chargerSousTitres($0) },
                onRetirer: etat.sousTitres != nil ? { etat.retirerSousTitres() } : nil)

            if let erreur = etat.erreur {
                Label(erreur, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { etat.effacerErreur() }
            }

            if etat.video != nil && !etat.quelqueChoseAGraver {
                Text(Textes.Interface.rienAGraver)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Toggle(isOn: $etat.voletOuvert) {
                    Label(Textes.Interface.personnaliser,
                          systemImage: "slider.horizontal.3")
                }
                .toggleStyle(.button)
                .disabled(etat.video == nil)

                Spacer()

                Button(Textes.Interface.boutonHabiller) { habiller() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!etat.peutHabiller)
            }
        }
        .padding(20)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var descriptionVideo: String? {
        guard let video = etat.video else { return nil }
        guard let taille = etat.tailleVideo else { return video.lastPathComponent }
        return Textes.Interface.videoChargee(
            video.lastPathComponent, largeur: Int(taille.width),
            hauteur: Int(taille.height),
            duree: CommandeExport.duree(etat.dureeVideo))
    }

    private var descriptionSousTitres: String? {
        guard let st = etat.sousTitres else { return nil }
        return Textes.Interface.sousTitresCharges(st.lastPathComponent,
                                                  repliques: etat.cues.count)
    }
}
