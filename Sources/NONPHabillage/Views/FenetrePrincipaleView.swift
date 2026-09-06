// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// FenetrePrincipaleView.swift — l'unique fenêtre.
//
// ADR §2 : « Écran principal minimal : zone de dépôt, un bouton Habiller, une
// barre de progression. Rien d'autre. » Volet fermé, c'est exactement ce qu'on
// voit, et cela tient sans défilement.
//
// ── Le bouton « Habiller » vit EN BAS ────────────────────────────────────────
//
// Barre d'action fixe au pied de la fenêtre, aligné à droite, toujours visible :
// c'est la convention macOS, et la seule place qui tienne dans les trois états.
// Il était en haut à droite de la barre des dépôts, où l'action finale se lisait
// comme un accessoire du dépôt. Surtout pas dans la colonne des réglages : elle
// défile, et un bouton qui disparaît au défilement n'est plus une action, c'est
// une trouvaille.
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
    /// Place réservée à la barre d'action du bas.
    ///
    /// Elle s'ajoute à chacune des hauteurs de fenêtre : la barre est arrivée au
    /// lot 5, et la fenêtre lui rend sa hauteur plutôt que de la prendre sur
    /// l'accueil ou sur l'aperçu. Écrite en clair, et non fondue dans les
    /// totaux, pour qu'on voie ce que le déplacement du bouton a coûté — et pour
    /// que le contrôle de disposition puisse comparer cette réserve à la hauteur
    /// que la barre occupe RÉELLEMENT.
    static let hauteurBarreAction: CGFloat = 50

    /// Volet fermé, aucune vidéo : l'écran d'accueil seul.
    ///
    /// `hauteurFermee` est la hauteur NATURELLE de cet écran — deux zones de
    /// dépôt et la barre d'action —, pas une hauteur choisie. Elle sert de
    /// taille d'ouverture, et de rien d'autre : aucune hauteur minimale n'est
    /// imposée dans cet état (voir `ContenuFenetre.hauteurMinimale`), de sorte
    /// que le contenu ne peut pas être étiré. Elle valait 470 points pour 377
    /// de contenu : 93 points de vide, imposés par la fenêtre elle-même.
    ///
    /// Le contrôle de disposition la compare à la hauteur MESURÉE du contenu :
    /// si une zone de dépôt grandit, ce nombre doit suivre, et le contrôle le
    /// dira. Le viser légèrement bas est sans danger — `.contentMinSize` relève
    /// la fenêtre à la hauteur du contenu ; le viser haut rouvre le vide.
    static let largeurFermee: CGFloat = 620
    static let hauteurFermee: CGFloat = 380

    /// Volet fermé, une vidéo chargée : la fenêtre grandit pour loger son
    /// image. Une hauteur inchangée n'aurait laissé qu'une vignette, qui ne
    /// confirmerait rien.
    static let hauteurFermeeAvecVideo: CGFloat = 580 + hauteurBarreAction
    /// En deçà, l'image de l'accueil ne montrerait plus rien de reconnaissable.
    static let hauteurMinimaleImageAccueil: CGFloat = 180

    /// Volet ouvert : il faut la place de deux colonnes.
    static let largeurMinimaleOuverte: CGFloat = 1020
    static let largeurIdealeOuverte: CGFloat = 1180
    static let hauteurMinimaleOuverte: CGFloat = 720 + hauteurBarreAction
    static let hauteurIdealeOuverte: CGFloat = 860 + hauteurBarreAction

    /// Largeur de la colonne des réglages : assez pour un curseur et son
    /// libellé sans que le texte se replie ligne à ligne.
    static let largeurReglages: CGFloat = 360
    /// Marge intérieure de cette colonne, de chaque côté.
    static let margeReglages: CGFloat = 16
    /// Place que prend l'ascenseur quand le système affiche des barres de
    /// défilement permanentes (Réglages Système › Apparence). La colonne DÉFILE :
    /// cette place lui est prise, et les réglages doivent tenir sans elle.
    ///
    /// C'est ce qui manquait aux contrôles : ils mesuraient à 328 points, la
    /// colonne moins ses marges, en oubliant l'ascenseur. Or « Taille » se
    /// cassait précisément entre les deux.
    static let largeurBarreDefilement: CGFloat = 15
    /// La largeur la plus étroite qu'un réglage puisse recevoir. C'est à
    /// celle-ci que se mesure la disposition de la colonne.
    static let largeurUtileReglages: CGFloat =
        largeurReglages - 2 * margeReglages - largeurBarreDefilement
    /// Colonne réservée au libellé d'un curseur, à gauche de sa course.
    static let largeurLibelleCurseur: CGFloat = 130
    /// En deçà, l'aperçu ne montrerait plus rien d'utile.
    static let largeurMinimaleApercu: CGFloat = 560
    /// Idem en hauteur.
    static let hauteurMinimaleApercu: CGFloat = 300
}

struct FenetrePrincipaleView: View {

    /// Fourni par l'application, et non créé ici : le menu Fichier doit
    /// atteindre le même état que la fenêtre (voir `CommandesProfil`).
    @ObservedObject var etat: AppState

    var body: some View {
        ContenuFenetre()
            .environmentObject(etat)
            .background(CadreAuContenu())
    }
}

/// Ouvre la fenêtre à la taille NATURELLE de son contenu.
///
/// macOS mémorise le cadre de chaque fenêtre et le restaure au lancement
/// suivant ; SwiftUI l'y aide, sous la clé `NSWindow Frame …` des préférences.
/// C'est en général bienvenu — ici c'était le défaut. Une fenêtre agrandie une
/// fois, volet ouvert, revenait telle quelle au lancement suivant : 1080 × 1094
/// points pour un accueil qui en occupe 377. Les deux zones de dépôt en haut,
/// et sept cents points de vide jusqu'à la barre d'action.
///
/// `.contentMinSize` ne pouvait rien y faire : elle pose un PLANCHER, pas une
/// taille. Elle fait bien grandir la fenêtre quand une vidéo arrive — c'est son
/// rôle et il est intact — mais rien ne lui a jamais demandé de la faire
/// rétrécir, et le cadre mémorisé passait avant `.defaultSize`.
///
/// D'où ce rappel à l'ordre, UNE FOIS, à l'ouverture : la fenêtre reprend la
/// taille naturelle de son contenu, quelle que soit celle qu'on lui a laissée.
/// La POSITION, elle, n'est pas touchée, et le bord SUPÉRIEUR ne bouge pas :
/// c'était la taille qui était fausse, pas l'endroit. Redimensionner à la main
/// reste évidemment possible — la fenêtre n'est contrainte à rien.
struct CadreAuContenu: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let temoin = NSView(frame: .zero)
        // La vue n'est pas encore dans une fenêtre, et la mise en page SwiftUI
        // pas encore faite : on repasse au tour de boucle suivant.
        DispatchQueue.main.async { ajuster(temoin.window) }
        return temoin
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func ajuster(_ fenetre: NSWindow?) {
        guard let fenetre else { return }
        // `minSize` EST la taille naturelle du contenu : c'est ce que
        // `.windowResizability(.contentMinSize)` vient d'y inscrire, à partir
        // de la mise en page réelle. Rien n'est deviné ni recopié — et comme
        // l'accueil nu n'impose aucune hauteur, cette taille est exactement
        // celle que réclament les deux zones de dépôt et la barre d'action.
        let naturelle = fenetre.minSize
        guard naturelle.width > 0, naturelle.height > 0 else { return }

        var cadre = fenetre.frame
        let bordSuperieur = cadre.maxY
        cadre.size = naturelle
        cadre.origin.y = bordSuperieur - naturelle.height
        fenetre.setFrame(cadre, display: true)
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
    ///
    /// **Accueil nu : AUCUNE hauteur imposée**, ni minimale ni idéale. Deux
    /// zones de dépôt et une barre d'action ont une hauteur naturelle, et c'est
    /// elle qui doit faire la fenêtre. Un minimum de 470 points y ajoutait 93
    /// points de vide que rien ne remplissait — la fenêtre imposait sa hauteur
    /// à un contenu qui n'en demandait pas tant. Ne rien imposer laisse
    /// `.contentMinSize` faire ce qu'elle sait faire : suivre le contenu.
    private var hauteurMinimale: CGFloat? {
        if etat.voletOuvert { return Fenetre.hauteurMinimaleOuverte }
        return etat.video != nil ? Fenetre.hauteurFermeeAvecVideo : nil
    }

    private var hauteurIdeale: CGFloat? {
        if etat.voletOuvert { return Fenetre.hauteurIdealeOuverte }
        return etat.video != nil ? Fenetre.hauteurFermeeAvecVideo : nil
    }

    // MARK: - Accueil

    private var accueil: some View {
        VStack(spacing: 0) {
            BarreEntrees()
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

            // LA BARRE D'ACTION, au pied de la fenêtre et hors de tout ce qui
            // défile : dernier élément de la pile, elle est sous l'aperçu ET
            // sous la colonne des réglages, jamais dedans.
            BarreAction(habiller: habiller)
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
                    .padding(Fenetre.margeReglages)
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

/// La barre du haut : ce qu'on dépose. Rien de plus depuis le lot 5 — ce qu'on
/// LANCE est descendu dans `BarreAction`.
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

    var body: some View {
        VStack(spacing: 12) {
            ZoneDepotView(
                titre: Textes.Interface.deposezVotreVideo,
                sousTitre: Textes.Interface.formatsAcceptes,
                aide: Textes.Aide.depotVideo,
                symbole: "film",
                typesAcceptes: UTType.videosAcceptees,
                fichierCharge: descriptionVideo,
                onFichier: { etat.chargerVideo($0) },
                onRetirer: etat.video != nil ? { etat.retirerVideo() } : nil)

            ZoneDepotView(
                titre: Textes.Interface.sousTitresFacultatifs,
                sousTitre: "SRT ou VTT",
                aide: Textes.Aide.depotSousTitres,
                symbole: "captions.bubble",
                typesAcceptes: UTType.sousTitresAcceptes,
                fichierCharge: descriptionSousTitres,
                onFichier: { etat.chargerSousTitres($0) },
                onRetirer: etat.sousTitres != nil ? { etat.retirerSousTitres() } : nil)

            if let erreur = etat.erreur {
                Label(erreur, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { etat.effacerErreur() }
            }

            // Ce qui s'est bien passé — un profil importé, un profil écrit,
            // les réglages rétablis. Il s'affichait dans la section « Profil »
            // du volet ; celle-ci a disparu le 28/08, et le message a suivi
            // ici : les commandes qui le produisent sont désormais au menu
            // Fichier, donc leur réponse doit être visible depuis n'importe
            // quel état de la fenêtre, volet ouvert ou fermé.
            if let message = etat.message {
                Label(message, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { etat.effacerMessage() }
            }

            // LE LOGO DU PROFIL A DISPARU. Piège nº1 du lot 6 : le chemin
            // mémorisé est absolu, il casse dès que l'image change de dossier.
            //
            // L'avertissement n'est pas une erreur qu'on chasse d'un clic : il
            // est DÉRIVÉ de l'état et reste tant que le fichier manque. « Habiller »
            // est bloqué avec lui — jamais de gravure silencieuse sans le logo
            // qu'on croyait poser, c'est l'esprit de l'invariant nº4.
            if let manquant = etat.messageLogoIntrouvable {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Label(manquant, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(Textes.Profil.choisirUnAutreLogo) { choisirUnAutreLogo() }
                        .buttonStyle(.bordered)
                        .fixedSize()
                }
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
            }
        }
        .padding(20)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func choisirUnAutreLogo() {
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = UTType.imagesAcceptees
        panneau.allowsMultipleSelection = false
        if panneau.runModal() == .OK, let url = panneau.url {
            etat.chargerLogo(url)
        }
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

/// Le pied de la fenêtre : l'action, et ce qui l'empêche.
///
/// Convention macOS — une barre d'action au bas de la fenêtre, l'action
/// principale à droite. C'est là qu'on la cherche, et c'est la seule place qui
/// ne bouge pas : la barre est hors de la zone défilante, sa hauteur est
/// naturelle et fixe, elle ne dépend ni du volet ni de la longueur des réglages.
///
/// « Il n'y a rien à graver » DESCEND AVEC LE BOUTON. La phrase n'existe que
/// pour expliquer un bouton grisé ; la laisser en haut de la fenêtre pendant que
/// le bouton part en bas, c'est refaire exactement ce qu'on reproche à une
/// explication posée loin de son contrôle.
struct BarreAction: View {

    @EnvironmentObject var etat: AppState
    var habiller: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if etat.video != nil && !etat.quelqueChoseAGraver {
                    Text(Textes.Interface.rienAGraver)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(Textes.Interface.boutonHabiller) { habiller() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!etat.peutHabiller)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fixedSize(horizontal: false, vertical: true)
    }
}
