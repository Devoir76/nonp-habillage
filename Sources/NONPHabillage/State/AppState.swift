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

    @Published private(set) var video: URL?
    @Published private(set) var tailleVideo: CGSize?
    @Published private(set) var dureeVideo: Double = 0
    @Published private(set) var sousTitres: URL?
    @Published private(set) var cues: [Cue] = []
    @Published private(set) var erreur: String?

    // MARK: - Réglages

    @Published var profil: ProfilHabillage = .neutre {
        didSet { if profil != oldValue { rafraichirApercu() } }
    }
    @Published var voletOuvert = false

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

    // MARK: - Aperçu

    /// Les images de fond proposées, du plan le plus sombre au plus clair.
    @Published private(set) var fondsDisponibles: [(instant: Double, image: CGImage,
                                                    luminosite: Double)] = []
    @Published var indexFond = 0 { didSet { rafraichirApercu() } }
    /// Index dans `repliques`, la plus longue en premier.
    @Published var indexReplique = 0 { didSet { rafraichirApercu() } }
    @Published private(set) var repliques: [Cue] = []

    @Published private(set) var apercu: CGImage?
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

    var peutHabiller: Bool {
        video != nil && quelqueChoseAGraver && etape == .accueil
    }

    // MARK: - Chargement des entrées

    func chargerVideo(_ url: URL) {
        Task {
            do {
                let taille = try await ImagesVideo.dimensions(de: url)
                let duree = try await ImagesVideo.duree(de: url)
                video = url
                tailleVideo = taille
                dureeVideo = duree
                erreur = nil
                await preparerFonds()
            } catch {
                erreur = Textes.Export.formatNonPrisEnCharge(url.lastPathComponent)
            }
        }
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

    func retirerSousTitres() {
        sousTitres = nil
        cues = []
        repliques = []
        indexReplique = 0
        rafraichirApercu()
    }

    func effacerErreur() { erreur = nil }

    // MARK: - Aperçu

    private func preparerFonds() async {
        guard let video else { return }
        apercuEnPreparation = true
        let instants = (try? await ImagesVideo.instantsRepresentatifs(de: video)) ?? []
        // Du plus sombre au plus clair : l'utilisateur trouve ainsi tout de
        // suite les deux extrêmes dont l'ADR fait le critère de contraste.
        fondsDisponibles = instants.sorted { $0.luminosite < $1.luminosite }
        indexFond = fondsDisponibles.count / 2
        apercuEnPreparation = false
        rafraichirApercu()
    }

    /// Recalcule l'aperçu. Appelé à chaque réglage — c'est instantané, aucune
    /// vidéo n'est écrite.
    func rafraichirApercu() {
        guard indexFond < fondsDisponibles.count else { apercu = nil; return }
        let fond = fondsDisponibles[indexFond].image

        do {
            let resultat: ResultatApercu
            if repliques.isEmpty {
                // Aucun sous-titre : la phrase de référence, pour ne jamais
                // régler à l'aveugle.
                let mep = try MiseEnPageRendu.calculer(
                    profil: profil,
                    largeurVideo: fond.width, hauteurVideo: fond.height)
                resultat = try Apercu.composer(
                    fond: fond, profil: profil,
                    texte: Apercu.texteDeReference(profil: profil, miseEnPage: mep),
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
