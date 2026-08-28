// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// AppState.swift — ce que l'application sait à un instant donné.
//
// Un seul objet observable pour toute la fenêtre. Les vues n'ont aucune logique :
// elles lisent cet état et lui envoient des intentions. Tout ce qui calcule vit
// dans `Engine/`.
//
// L'APERÇU EST RECALCULÉ À CHAQUE RÉGLAGE, jamais encodé. Il passe par le même
// code que l'export, ce qui est la seule façon d'être sûr que ce qu'on voit est
// ce qu'on obtiendra.

import Foundation
import SwiftUI
import CoreGraphics

@MainActor
final class AppState: ObservableObject {

    // MARK: - Étape

    enum Etape: Equatable {
        case accueil
        case enCours
        case termine(URL)
    }

    @Published private(set) var etape: Etape = .accueil

    // MARK: - Entrées

    /// Au lancement, le profil de la DERNIÈRE SESSION — logo compris.
    ///
    /// À défaut, le profil neutre, comme l'ADR §2 le prévoit pour un premier
    /// lancement. Un fichier de mémoire abîmé retombe sur le même cas : mieux
    /// vaut ouvrir sur des réglages sobres que refuser de s'ouvrir.
    init() {
        if let memorise = MemoireProfil.relire() {
            profil = memorise
        }
    }

    @Published private(set) var video: URL?
    @Published private(set) var tailleVideo: CGSize?
    @Published private(set) var dureeVideo: Double = 0
    @Published private(set) var sousTitres: URL?
    @Published private(set) var cues: [Cue] = []
    @Published private(set) var erreur: String?
    /// Ce qui s'est bien passé, et mérite d'être dit une fois — un profil
    /// importé, un profil écrit. Séparé de `erreur` : les deux ne se lisent pas
    /// de la même façon et ne doivent pas se chasser l'un l'autre.
    @Published var message: String?

    // MARK: - Réglages

    @Published var profil: ProfilHabillage = .neutre {
        didSet {
            guard profil != oldValue else { return }
            rafraichirApercu()
            memoriserProfil()
        }
    }
    @Published var voletOuvert = false {
        didSet { if voletOuvert != oldValue { rafraichirApercu() } }
    }

    /// La taille nommée cochée dans l'interface, dérivée du profil.
    var tailleNommee: TailleNommee {
        get { TailleNommee.laPlusProche(de: profil.longueurLigneCible) }
        set {
            // LES DEUX : la longueur de ligne ET la taille de police. Ne poser
            // que la première ne changeait rien à l'œil sur une vidéo 16:9,
            // dont la largeur suffit toujours à tenir 42 caractères.
            profil.longueurLigneCible = newValue.longueurLigneCible
            profil.tailleRatio = newValue.tailleRatio
        }
    }

    /// « Lignes maximum », vue par l'interface — et non `profil.lignesMax` en
    /// direct.
    ///
    /// La case « Hauteur constante » reprend la valeur de « Lignes maximum » :
    /// elle doit donc la SUIVRE quand elle change, sans quoi on cocherait une
    /// hauteur de deux lignes puis on passerait le texte à trois, et le fond
    /// resterait figé sur l'ancienne valeur sans que rien ne le dise.
    ///
    /// Un seul remplacement de `profil`, pas deux : deux écritures
    /// successives déclencheraient deux compositions d'aperçu pour un seul clic.
    var lignesMax: Int {
        get { profil.lignesMax }
        set {
            var p = profil
            let suivait = p.bandeauHauteurFixeLignes > 0
            p.lignesMax = newValue
            if suivait { p.bandeauHauteurFixeLignes = newValue }
            profil = p
        }
    }

    /// La case « Hauteur constante » du volet, projection booléenne du champ
    /// `bandeau.hauteur_fixe_lignes`.
    ///
    /// Le champ, lui, garde sa valeur LIBRE de 0 à 4 — c'est le contrat du
    /// schéma partagé (invariant nº6), et le schéma recommande déjà « même
    /// valeur que lignes_max ». Un profil venu du prototype qui fixerait 3
    /// lignes là où le texte en autorise 2 reste donc lu, appliqué et rendu tel
    /// quel : la case se contente d'afficher qu'une hauteur est figée. Cocher,
    /// décocher, ou toucher à « Lignes maximum » réaligne la valeur — c'est
    /// alors une décision de l'utilisateur, pas un écrasement silencieux.
    var hauteurConstante: Bool {
        get { profil.bandeauHauteurFixeLignes > 0 }
        set { profil.bandeauHauteurFixeLignes = newValue ? profil.lignesMax : 0 }
    }

    // MARK: - Aperçu

    /// Les images de fond proposées, du plan le plus sombre au plus clair.
    @Published private(set) var fondsDisponibles: [(instant: Double, image: CGImage,
                                                    luminosite: Double)] = []
    @Published var indexFond = 0 { didSet { rafraichirApercu() } }
    /// Index dans `repliques`, la plus longue en premier.
    @Published var indexReplique = 0 { didSet { rafraichirApercu() } }
    @Published private(set) var repliques: [Cue] = []

    @Published private(set) var apercu: CGImage?
    /// L'image de l'écran d'accueil, volet fermé — voir `Apercu.composerAccueil`.
    /// Calculée seulement quand elle est visible : volet ouvert, elle ne sert à
    /// personne et ferait une composition de plus à chaque coup de curseur.
    @Published private(set) var imageAccueil: CGImage?
    @Published private(set) var avertissements: [AvertissementZone] = []
    @Published private(set) var rectangleLogo: CGRect?
    @Published private(set) var miseEnPage: MiseEnPageRendu?
    @Published private(set) var apercuEnPreparation = false

    // MARK: - Export

    @Published private(set) var avancement: Double = 0
    @Published private(set) var tempsRestant: TimeInterval?
    private var exportateur: ExportateurVideo?

    // MARK: - Usages

    /// Y a-t-il quelque chose à graver ? Logo et sous-titres sont indépendants.
    var quelqueChoseAGraver: Bool {
        sousTitres != nil || (profil.logoActif && profil.logoFichier != nil)
    }

    /// Un fichier de sous-titres est-il chargé ?
    ///
    /// Ce qui commande l'accès aux réglages de sous-titre : sans texte à soi,
    /// on ne règle pas l'apparence d'un texte.
    var aSousTitres: Bool { sousTitres != nil }

    /// **Le profil pose un logo, et ce logo a disparu.**
    ///
    /// PIÈGE Nº1 du lot 6. Le chemin mémorisé — ou celui d'un profil importé —
    /// est absolu : il casse dès que l'image change de dossier. Le laisser
    /// passer graverait la vidéo SANS logo, sans que rien ne l'ait dit. C'est
    /// exactement ce que l'invariant nº4 refuse pour une police, et pour la
    /// même raison : une substitution muette part chez le destinataire.
    ///
    /// L'état est donc bloquant, comme une police absente, et le message
    /// propose d'en choisir un autre.
    var logoIntrouvable: Bool {
        guard profil.logoActif, let f = profil.logoFichier else { return false }
        return !FileManager.default.fileExists(atPath: f.path)
    }

    var peutHabiller: Bool {
        video != nil && quelqueChoseAGraver && !logoIntrouvable && etape == .accueil
    }

    // MARK: - Chargement des entrées

    /// Le chargement de vidéo en cours.
    ///
    /// Analyser une vidéo prend un instant. Sans ce jeton, une vidéo retirée —
    /// ou remplacée par une autre — pendant l'analyse reparaissait quand
    /// celle-ci s'achevait : le bouton « Retirer » semblait n'avoir rien fait.
    private var chargementCourant = UUID()

    func chargerVideo(_ url: URL) {
        let jeton = UUID()
        chargementCourant = jeton
        Task {
            do {
                let taille = try await ImagesVideo.dimensions(de: url)
                let duree = try await ImagesVideo.duree(de: url)
                guard chargementCourant == jeton else { return }
                video = url
                tailleVideo = taille
                dureeVideo = duree
                erreur = nil
                await preparerFonds(jeton: jeton)
            } catch {
                guard chargementCourant == jeton else { return }
                erreur = Textes.Export.formatNonPrisEnCharge(url.lastPathComponent)
            }
        }
    }

    /// Retirer la vidéo, comme on retire les sous-titres.
    ///
    /// Le fichier de sous-titres avait son bouton, la vidéo non : on ne pouvait
    /// changer de vidéo qu'en relançant l'application. Les sous-titres déjà
    /// chargés, eux, SURVIVENT — ce sont deux dépôts distincts, et on change
    /// souvent de vidéo en gardant le même habillage. Les réglages aussi : ils
    /// vivent dans le profil, pas dans le fichier.
    func retirerVideo() {
        chargementCourant = UUID()      // une analyse en vol ne la fera pas reparaître
        video = nil
        tailleVideo = nil
        dureeVideo = 0
        fondsDisponibles = []
        indexFond = 0                   // recalcule l'aperçu, qui n'a plus de fond
        apercuEnPreparation = false
        // Le volet se referme : sans vidéo son bouton est désactivé, et le
        // laisser ouvert figerait la fenêtre en deux colonnes vides.
        voletOuvert = false
        erreur = nil
    }

    func chargerSousTitres(_ url: URL) {
        do {
            let lues = try ParseurSousTitres.analyser(fichier: url)
            sousTitres = url
            cues = lues
            // La plus longue d'abord : c'est le pire cas, et s'il passe, tout passe.
            repliques = Apercu.repliquesParPireCas(lues)
            indexReplique = 0
            erreur = nil
            rafraichirApercu()
        } catch let e as ErreurSousTitres {
            erreur = Textes.SousTitres.message(pour: e)
        } catch {
            erreur = "\(error)"
        }
    }

    func chargerLogo(_ url: URL) {
        do {
            _ = try RenduLogo.charger(url)   // échoue tout de suite si l'image est illisible
            profil.logoFichier = url
            profil.logoActif = true
            erreur = nil
        } catch let e as ErreurLogo {
            erreur = Textes.Logo.message(pour: e)
        } catch {
            erreur = "\(error)"
        }
    }

    func retirerLogo() {
        profil.logoActif = false
        profil.logoFichier = nil
    }

    // MARK: - Profils

    /// Revenir aux réglages par défaut — le profil neutre.
    ///
    /// Le LOGO est conservé. C'est un fichier de l'utilisateur, pas un réglage :
    /// « revenir aux réglages par défaut » ne doit pas obliger à le redéposer.
    /// Le retirer a d'ailleurs son propre bouton, dans le volet, à côté de lui.
    ///
    /// C'est la seule commande qui remplace les réglages en bloc depuis que les
    /// boutons de préréglage ont disparu (28/08/2026) : les autres apparences
    /// livrées sont des fichiers d'exemple, qu'on importe.
    func revenirAuxReglagesParDefaut() {
        var p = ProfilHabillage.neutre
        p.logoFichier = profil.logoFichier
        p.logoActif = profil.logoActif && profil.logoFichier != nil
        p.logoRecadreEnCercle = profil.logoRecadreEnCercle
        profil = p
        erreur = nil
        message = Textes.Profil.revenusAuxReglagesParDefaut
    }

    /// Importe un profil `.json`.
    ///
    /// Le fichier passe par le validateur strict : champs inconnus refusés,
    /// toutes les anomalies d'un coup. Un profil refusé ne change RIEN aux
    /// réglages en cours — on ne remplace pas un état correct par un état
    /// partiel.
    func importerProfil(_ url: URL) {
        do {
            let lecture = try ProfilJSON.lireDetaille(url)
            profil = lecture.profil
            erreur = nil
            // Une conversion est une MODIFICATION : la taire reviendrait à
            // changer les réglages de quelqu'un sans le lui dire.
            message = lecture.migration.map {
                Textes.Profil.importe(profil.nom) + "\n" + $0
            } ?? Textes.Profil.importe(profil.nom)
        } catch let e as ErreurProfil {
            erreur = Textes.Profil.refus(url.lastPathComponent, e.anomalies)
        } catch {
            erreur = "\(error)"
        }
    }

    /// Exporte le profil courant, avec une copie du logo à côté.
    func exporterProfil(vers url: URL) {
        do {
            let copie = try ProfilJSON.ecrire(profil, vers: url)
            message = Textes.Profil.exporte(url.lastPathComponent,
                                            logo: copie?.lastPathComponent)
            erreur = nil
        } catch let e as ErreurProfil {
            erreur = e.anomalies.joined(separator: "\n")
        } catch {
            erreur = "\(error)"
        }
    }

    /// Le message à afficher quand le logo du profil a disparu.
    ///
    /// DÉRIVÉ de l'état, jamais posé une fois dans `erreur` : une erreur
    /// s'efface — au premier clic, en retirant la vidéo — alors que le fichier,
    /// lui, est toujours absent. Un avertissement qui disparaît avant le
    /// problème qu'il décrit est pire que pas d'avertissement.
    var messageLogoIntrouvable: String? {
        guard logoIntrouvable, let f = profil.logoFichier else { return nil }
        return Textes.Profil.logoIntrouvable(f.path)
    }

    /// Enregistre le profil courant, sans bloquer la frappe.
    ///
    /// Un coup de curseur produit des dizaines de changements : écrire à chaque
    /// fois ferait autant d'accès disque pour un seul geste. Le dernier gagne,
    /// une demi-seconde après le dernier changement.
    private var memorisation: Task<Void, Never>?

    private func memoriserProfil() {
        memorisation?.cancel()
        let aEnregistrer = profil
        memorisation = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            MemoireProfil.enregistrer(aEnregistrer)
            _ = self
        }
    }

    func retirerSousTitres() {
        sousTitres = nil
        cues = []
        repliques = []
        indexReplique = 0
        rafraichirApercu()
    }

    func effacerErreur() { erreur = nil }
    func effacerMessage() { message = nil }

    // MARK: - Aperçu

    private func preparerFonds(jeton: UUID) async {
        guard let video else { return }
        apercuEnPreparation = true
        let instants = (try? await ImagesVideo.instantsRepresentatifs(de: video)) ?? []
        guard chargementCourant == jeton else { return }
        // Du plus sombre au plus clair : l'utilisateur trouve ainsi tout de
        // suite les deux extrêmes dont l'ADR fait le critère de contraste.
        fondsDisponibles = instants.sorted { $0.luminosite < $1.luminosite }
        indexFond = fondsDisponibles.count / 2
        apercuEnPreparation = false
        rafraichirApercu()
    }

    /// Pose des images de fond sans passer par une vidéo.
    ///
    /// Réservé à la VÉRIFICATION et à la capture d'interface : `fondsDisponibles`
    /// est en lecture seule pour les vues, et le seul chemin normal passe par
    /// `chargerVideo`, qui est asynchrone et exige un vrai fichier. Sans cette
    /// porte, la barre de choix du fond — menu, libellés, réserve « aperçu
    /// seulement » — ne pourrait pas être MESURÉE : elle ne s'affiche qu'à
    /// partir de deux fonds.
    func poserFondsDeControle(
        _ fonds: [(instant: Double, image: CGImage, luminosite: Double)]
    ) {
        fondsDisponibles = fonds
        indexFond = fonds.isEmpty ? 0 : fonds.count / 2
        rafraichirApercu()
    }

    /// Pose une vidéo sans l'analyser.
    ///
    /// Même porte que les deux suivantes, et pour la même raison : `video` est
    /// en lecture seule pour les vues, et `chargerVideo` est asynchrone et exige
    /// un vrai fichier. Sans elle, `peutHabiller` — donc le blocage du logo
    /// disparu — ne pourrait pas être éprouvé, faute de vidéo.
    func poserVideoDeControle(_ url: URL) {
        video = url
    }

    /// Pose des répliques sans passer par un fichier.
    ///
    /// Même porte, et même raison, que `poserFondsDeControle` : `repliques` est
    /// en lecture seule pour les vues, et le seul chemin normal —
    /// `chargerSousTitres` — est asynchrone et exige un vrai fichier. Sans
    /// cette porte, la barre de choix ne pourrait être MESURÉE que dans son
    /// état sans sous-titres, alors que l'état COURANT est l'autre : un fichier
    /// chargé, la navigation entre répliques affichée.
    func poserRepliquesDeControle(_ cues: [Cue]) {
        repliques = cues
        indexReplique = 0
    }

    /// Recalcule l'aperçu. Appelé à chaque réglage — c'est instantané, aucune
    /// vidéo n'est écrite.
    func rafraichirApercu() {
        // Plus de fond, donc plus rien de dérivé. Tout est remis à zéro, pas
        // seulement l'image : un avertissement de zone ou une mise en page
        // laissés là décriraient la vidéo PRÉCÉDENTE, et se rattacheraient en
        // silence à la suivante le temps que son aperçu arrive.
        guard indexFond < fondsDisponibles.count else {
            apercu = nil
            imageAccueil = nil
            avertissements = []
            rectangleLogo = nil
            miseEnPage = nil
            return
        }
        let fond = fondsDisponibles[indexFond].image

        do {
            let resultat: ResultatApercu
            if repliques.isEmpty {
                // Aucun sous-titre : le plan NU, avec le logo s'il y en a un.
                //
                // Il y avait là une phrase de référence, pour ne pas régler à
                // l'aveugle. Elle était un pis-aller de l'époque où rien
                // n'était mémorisé : un texte qui n'est pas le sien, affiché
                // sur sa propre vidéo, se lit comme un sous-titre qui va être
                // gravé. Les réglages étant désormais retrouvés d'une session à
                // l'autre, on règle UNE FOIS, avec son vrai texte, et le besoin
                // disparaît. Le chemin « logo seul » y gagne aussi : il ne
                // montre plus un bandeau et une phrase dont il n'a que faire.
                resultat = try Apercu.composer(
                    fond: fond, profil: profil, lignes: [],
                    avecSousTitres: false)
            } else {
                let index = min(max(0, indexReplique), repliques.count - 1)
                resultat = try Apercu.composer(
                    fond: fond, profil: profil,
                    texte: repliques[index].texte, avecSousTitres: true)
            }
            apercu = resultat.image
            avertissements = resultat.avertissements
            rectangleLogo = resultat.rectangleLogo
            miseEnPage = resultat.miseEnPage
            erreur = nil

            // L'image de l'accueil. Avec un fichier de sous-titres, c'est
            // exactement l'aperçu — le texte affiché est réel, il sera gravé.
            // Sans fichier, elle se recompose sans texte : voir
            // `Apercu.composerAccueil`.
            if voletOuvert {
                imageAccueil = nil
            } else if repliques.isEmpty {
                imageAccueil = try Apercu.composerAccueil(
                    fond: fond, profil: profil, replique: nil).image
            } else {
                imageAccueil = resultat.image
            }
        } catch let e as ErreurPolice {
            erreur = Textes.Rendu.message(pour: e)
        } catch let e as ErreurLogo {
            erreur = Textes.Logo.message(pour: e)
        } catch {
            erreur = "\(error)"
        }
    }

    /// Déplace le logo à une position exprimée en fraction de l'image (0–1),
    /// le point désignant son CENTRE — la définition du schéma.
    func deplacerLogo(versFraction point: CGPoint) {
        profil.logoPosition = .libre(
            xPct: min(100, max(0, Double(point.x) * 100)),
            yPct: min(100, max(0, Double(point.y) * 100)))
    }

    // MARK: - Export

    func habiller(vers sortie: URL) {
        guard let video else { return }
        let exportateur = ExportateurVideo()
        self.exportateur = exportateur
        etape = .enCours
        avancement = 0
        tempsRestant = nil

        Task {
            do {
                let bilan = try await exportateur.exporter(
                    video: video, sousTitres: sousTitres, profil: profil, vers: sortie,
                    progression: { [weak self] a in
                        Task { @MainActor in
                            self?.avancement = a.fraction
                            self?.tempsRestant = a.restantEstime
                        }
                    })
                etape = .termine(bilan.sortie)
            } catch ErreurExport.annule {
                etape = .accueil
                avancement = 0
            } catch {
                erreur = CommandeExport.message(pour: error)
                etape = .accueil
                avancement = 0
            }
            self.exportateur = nil
        }
    }

    func annulerExport() { exportateur?.annuler() }

    func recommencer() {
        etape = .accueil
        avancement = 0
        tempsRestant = nil
    }

    /// Nom de sortie proposé : `<vidéo>_habillee.mp4`, à côté de la source.
    var sortieProposee: URL? {
        guard let video else { return nil }
        let base = video.deletingPathExtension().lastPathComponent
        return video.deletingLastPathComponent()
            .appendingPathComponent("\(base)_habillee.mp4")
    }
}
