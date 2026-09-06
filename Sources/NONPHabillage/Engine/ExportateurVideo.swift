// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ExportateurVideo.swift — lit, compose, encode, écrit.
//
// ── Un écart avec le cahier des lots, et pourquoi ────────────────────────────
//
// Le lot 4 demande « AVMutableVideoComposition + AVAssetExportSession » ET
// « audio recopié sans réencodage ». Les deux ne peuvent pas tenir ensemble :
//
// - `AVAssetExportSession` encode l'audio selon son préréglage. Il n'existe
//   aucun réglage qui laisse passer la piste audio intacte tout en composant la
//   vidéo — le seul préréglage qui recopie, `AVAssetExportPresetPassthrough`,
//   interdit précisément toute composition.
// - Réencoder l'audio d'un témoignage, c'est une perte de qualité définitive
//   pour un gain nul : la piste n'est pas modifiée par l'habillage.
//
// Entre le MOYEN nommé et le RÉSULTAT exigé, on garde le résultat.
// `AVAssetReader` + `AVAssetWriter` remplacent donc l'export session :
// `AVMutableVideoComposition` reste, l'audio est recopié échantillon par
// échantillon, et l'on gagne au passage ce que l'export session donnait mal —
// une progression fondée sur les images réellement traitées, et une annulation
// dont on maîtrise le nettoyage.
//
// ── Là où passe VideoToolbox ────────────────────────────────────────────────
//
// `AVAssetWriterInput` configuré en H.264 encode par VideoToolbox, avec
// accélération matérielle sur Apple Silicon. Rien à activer : c'est le chemin
// par défaut. Aucune dépendance non-Apple n'est introduite (invariant nº3).
//
// ── Le disque reste propre ───────────────────────────────────────────────────
//
// L'écriture va dans un fichier temporaire VOISIN du fichier de sortie, déplacé
// à sa place seulement quand tout a réussi. Une annulation, une erreur ou un
// plantage ne laissent donc jamais de fichier de sortie à moitié écrit qu'on
// pourrait prendre pour un export abouti.

import Foundation
import AVFoundation
import CoreMedia

enum ErreurExport: Error {
    case videoIllisible(URL)
    case pisteVideoAbsente(URL)
    case lectureImpossible(String)
    case ecritureImpossible(String)
    /// La destination désigne un fichier d'entrée — la vidéo ou les sous-titres.
    case ecraseraitUneEntree(URL)
    case annule
}

final class ExportateurVideo: @unchecked Sendable {

    // MARK: - Types

    /// Avancement d'un export en cours.
    struct Avancement {
        /// Entre 0 et 1.
        let fraction: Double
        let ecoule: TimeInterval
        /// `nil` tant qu'il est trop tôt pour estimer honnêtement.
        let restantEstime: TimeInterval?
    }

    /// Ce qu'on sait d'un export terminé.
    struct Bilan {
        let sortie: URL
        /// Durée du traitement.
        let duree: TimeInterval
        /// Durée de la vidéo traitée.
        let dureeVideo: Double
        let octets: Int64
        /// Vrai si un logo a été incrusté.
        var logoIncruste: Bool = false
        /// Rapport durée vidéo / durée de traitement. Au-dessus de 1, l'export
        /// va plus vite que le temps réel.
        var facteurTempsReel: Double { duree > 0 ? dureeVideo / duree : 0 }
        let audioRecopie: Bool
    }

    // MARK: - Annulation

    private let verrou = NSLock()
    private var annulationDemandee = false

    /// Demande l'arrêt. L'export en cours s'interrompt et ne laisse rien.
    func annuler() {
        verrou.lock(); annulationDemandee = true; verrou.unlock()
    }

    private var estAnnule: Bool {
        verrou.lock(); defer { verrou.unlock() }
        return annulationDemandee
    }

    // MARK: - Deux chemins, un seul fichier ?

    /// Les deux URL désignent-elles le même fichier ?
    ///
    /// La comparaison de chaînes ne suffit pas : `~/Films/a.mp4` et
    /// `/Users/x/Films/../Films/a.mp4` sont le même fichier, et un dossier
    /// peut être un lien symbolique. On normalise donc d'abord, puis — quand
    /// les deux fichiers existent — on compare les identifiants que le système
    /// leur donne, ce qui attrape aussi les liens durs et les points de montage
    /// atteints par deux chemins différents.
    static func memeFichier(_ a: URL, _ b: URL) -> Bool {
        if a.resolvingSymlinksInPath().standardizedFileURL
            == b.resolvingSymlinksInPath().standardizedFileURL { return true }
        let cle: Set<URLResourceKey> = [.fileResourceIdentifierKey]
        guard let ia = try? a.resourceValues(forKeys: cle).fileResourceIdentifier,
              let ib = try? b.resourceValues(forKeys: cle).fileResourceIdentifier
        else { return false }   // la destination n'existe pas encore : cas normal
        return ia.isEqual(ib)
    }

    // MARK: - Export

    /// Grave les sous-titres sur la vidéo et écrit le résultat.
    ///
    /// - Parameter progression: appelé régulièrement, sur une file interne.
    func exporter(
        video: URL,
        sousTitres: URL?,
        profil: ProfilHabillage,
        vers sortie: URL,
        progression: @escaping (Avancement) -> Void
    ) async throws -> Bilan {

        // AVANT TOUT LE RESTE : la destination ne doit désigner aucune entrée.
        //
        // L'export finit par `removeItem(at: sortie)` puis un déplacement — sur
        // la vidéo source, c'est sa destruction pure et simple, et l'original
        // n'existe nulle part ailleurs. Le nom proposé par l'application ne
        // tombe jamais dessus, mais le champ du panneau d'enregistrement est
        // libre, et la ligne de commande prend n'importe quel chemin. Le refus
        // est donc ici, au seul endroit que les deux traversent.
        for entree in [video, sousTitres].compactMap({ $0 })
        where Self.memeFichier(sortie, entree) {
            throw ErreurExport.ecraseraitUneEntree(entree)
        }

        let debut = Date()
        let asset = AVURLAsset(url: video)

        // Un fichier que le moteur vidéo de macOS ne sait pas ouvrir — MKV, AVI,
        // fichier tronqué — fait échouer le tout premier chargement. Sans cette
        // capture, l'erreur d'AVFoundation remonterait telle quelle : en
        // anglais, technique, et sans marche à suivre. L'ADR §3 exige le
        // contraire (« message explicite assorti d'une marche à suivre »).
        let pistesVideo: [AVAssetTrack]
        let pistesAudio: [AVAssetTrack]
        let dureeTotale: CMTime
        do {
            pistesVideo = try await asset.loadTracks(withMediaType: .video)
            pistesAudio = try await asset.loadTracks(withMediaType: .audio)
            dureeTotale = try await asset.load(.duration)
        } catch {
            throw ErreurExport.videoIllisible(video)
        }
        guard let pisteVideo = pistesVideo.first else {
            throw ErreurExport.pisteVideoAbsente(video)
        }
        let pisteAudio = pistesAudio.first
        let (naturelle, transformation) = try await pisteVideo.load(
            .naturalSize, .preferredTransform)
        let orientee = naturelle.applying(transformation)
        let taille = CGSize(width: abs(orientee.width).rounded(),
                            height: abs(orientee.height).rounded())
        let imagesParSeconde = try await pisteVideo.load(.nominalFrameRate)

        // Sous-titres : lecture, mise en page, resegmentation à la césure du
        // rendu. Sans fichier, la composition ne pose aucun calque — c'est
        // l'usage « logo seul » de l'ADR, qui reste un export valide.
        var cues: [CueGravee] = []
        let miseEnPage = try MiseEnPageRendu.calculer(
            profil: profil,
            largeurVideo: Int(taille.width),
            hauteurVideo: Int(taille.height))
        if let sousTitres {
            let lues = try ParseurSousTitres.analyser(fichier: sousTitres)
            cues = miseEnPage.segmenter(lues, lignesMax: profil.lignesMax)
        }

        // Le logo, s'il y en a un : un seul calque pour toute la vidéo.
        let calqueLogo = try RenduLogo.calque(
            profil: profil, parametres: miseEnPage.parametres,
            largeur: Int(taille.width), hauteur: Int(taille.height))

        let composition = CompositeurVideo.composition(
            pour: asset, cues: cues, profil: profil,
            miseEnPage: miseEnPage, calqueLogo: calqueLogo, taille: taille)

        // --- Lecture ------------------------------------------------------
        let lecteur: AVAssetReader
        do { lecteur = try AVAssetReader(asset: asset) }
        catch { throw ErreurExport.lectureImpossible(error.localizedDescription) }

        let sortieVideo = AVAssetReaderVideoCompositionOutput(
            videoTracks: [pisteVideo],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String:
                                kCVPixelFormatType_32BGRA])
        sortieVideo.videoComposition = composition
        sortieVideo.alwaysCopiesSampleData = false
        guard lecteur.canAdd(sortieVideo) else {
            throw ErreurExport.lectureImpossible("composition vidéo refusée par le lecteur")
        }
        lecteur.add(sortieVideo)

        // `outputSettings: nil` = les échantillons sortent tels qu'ils sont
        // stockés, sans décodage. C'est la recopie de l'audio.
        var sortieAudio: AVAssetReaderTrackOutput?
        if let pisteAudio {
            let s = AVAssetReaderTrackOutput(track: pisteAudio, outputSettings: nil)
            s.alwaysCopiesSampleData = false
            if lecteur.canAdd(s) { lecteur.add(s); sortieAudio = s }
        }

        // --- Écriture -----------------------------------------------------
        // Fichier temporaire voisin : même volume, donc déplacement atomique.
        let temporaire = sortie.deletingLastPathComponent()
            .appendingPathComponent(".\(sortie.lastPathComponent).en-cours")
        try? FileManager.default.removeItem(at: temporaire)

        let redacteur: AVAssetWriter
        do { redacteur = try AVAssetWriter(outputURL: temporaire, fileType: .mp4) }
        catch { throw ErreurExport.ecritureImpossible(error.localizedDescription) }

        let entreeVideo = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: reglagesH264(taille: taille, imagesParSeconde: imagesParSeconde))
        entreeVideo.expectsMediaDataInRealTime = false
        entreeVideo.transform = .identity   // la composition a déjà redressé l'image
        guard redacteur.canAdd(entreeVideo) else {
            throw ErreurExport.ecritureImpossible("entrée vidéo refusée")
        }
        redacteur.add(entreeVideo)

        var entreeAudio: AVAssetWriterInput?
        if let pisteAudio, sortieAudio != nil {
            let formats = try await pisteAudio.load(.formatDescriptions)
            let e = AVAssetWriterInput(mediaType: .audio, outputSettings: nil,
                                       sourceFormatHint: formats.first)
            e.expectsMediaDataInRealTime = false
            if redacteur.canAdd(e) { redacteur.add(e); entreeAudio = e }
        }

        guard lecteur.startReading() else {
            throw ErreurExport.lectureImpossible(
                lecteur.error?.localizedDescription ?? "lecture refusée")
        }
        guard redacteur.startWriting() else {
            throw ErreurExport.ecritureImpossible(
                redacteur.error?.localizedDescription ?? "écriture refusée")
        }
        redacteur.startSession(atSourceTime: .zero)

        let nettoyer = {
            lecteur.cancelReading()
            redacteur.cancelWriting()
            try? FileManager.default.removeItem(at: temporaire)
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { groupe in
                groupe.addTask { [self] in
                    try await pomper(
                        sortie: sortieVideo, vers: entreeVideo,
                        file: DispatchQueue(label: "nonp.habillage.video"),
                        dureeTotale: dureeTotale.seconds, debut: debut,
                        progression: progression)
                }
                if let sortieAudio, let entreeAudio {
                    groupe.addTask { [self] in
                        try await pomper(
                            sortie: sortieAudio, vers: entreeAudio,
                            file: DispatchQueue(label: "nonp.habillage.audio"),
                            dureeTotale: nil, debut: debut, progression: nil)
                    }
                }
                try await groupe.waitForAll()
            }
        } catch {
            nettoyer()
            throw error
        }

        if estAnnule { nettoyer(); throw ErreurExport.annule }

        await redacteur.finishWriting()
        guard redacteur.status == .completed else {
            nettoyer()
            throw ErreurExport.ecritureImpossible(
                redacteur.error?.localizedDescription ?? "écriture inachevée")
        }

        // Mise en place seulement maintenant : jusqu'ici, aucun fichier de
        // sortie n'existait qu'on aurait pu confondre avec un export abouti.
        try? FileManager.default.removeItem(at: sortie)
        do { try FileManager.default.moveItem(at: temporaire, to: sortie) }
        catch {
            try? FileManager.default.removeItem(at: temporaire)
            throw ErreurExport.ecritureImpossible(error.localizedDescription)
        }

        let octets = (try? FileManager.default.attributesOfItem(
            atPath: sortie.path)[.size] as? Int64) ?? 0
        return Bilan(
            sortie: sortie,
            duree: Date().timeIntervalSince(debut),
            dureeVideo: dureeTotale.seconds,
            octets: octets ?? 0,
            logoIncruste: calqueLogo != nil,
            audioRecopie: entreeAudio != nil)
    }

    // MARK: - Pompe

    /// Transfère les échantillons d'une sortie de lecture vers une entrée
    /// d'écriture, jusqu'à épuisement ou annulation.
    private func pomper(
        sortie: AVAssetReaderOutput,
        vers entree: AVAssetWriterInput,
        file: DispatchQueue,
        dureeTotale: Double?,
        debut: Date,
        progression: ((Avancement) -> Void)?
    ) async throws {
        try await withCheckedThrowingContinuation { (suite: CheckedContinuation<Void, Error>) in
            entree.requestMediaDataWhenReady(on: file) { [self] in
                while entree.isReadyForMoreMediaData {
                    if estAnnule {
                        entree.markAsFinished()
                        suite.resume(throwing: ErreurExport.annule)
                        return
                    }
                    guard let echantillon = sortie.copyNextSampleBuffer() else {
                        entree.markAsFinished()
                        progression?(Avancement(
                            fraction: 1, ecoule: Date().timeIntervalSince(debut),
                            restantEstime: 0))
                        suite.resume()
                        return
                    }
                    if !entree.append(echantillon) {
                        entree.markAsFinished()
                        suite.resume(throwing: ErreurExport.ecritureImpossible(
                            "échantillon refusé à l'écriture"))
                        return
                    }
                    if let dureeTotale, dureeTotale > 0, let progression {
                        let instant = CMSampleBufferGetPresentationTimeStamp(
                            echantillon).seconds
                        signaler(instant: instant, sur: dureeTotale,
                                 debut: debut, progression: progression)
                    }
                }
            }
        }
    }

    /// Émet un avancement, au plus dix fois par seconde.
    ///
    /// La durée restante n'est annoncée qu'au-delà de 2 % : plus tôt, elle
    /// reposerait sur trop peu d'images et afficherait des minutes fantaisistes
    /// que l'utilisateur verrait s'effondrer. Mieux vaut ne rien annoncer que
    /// d'annoncer faux.
    private var dernierSignal = Date.distantPast
    private func signaler(
        instant: Double, sur dureeTotale: Double, debut: Date,
        progression: (Avancement) -> Void
    ) {
        let maintenant = Date()
        guard maintenant.timeIntervalSince(dernierSignal) > 0.1 else { return }
        dernierSignal = maintenant

        let fraction = min(1, max(0, instant / dureeTotale))
        let ecoule = maintenant.timeIntervalSince(debut)
        let restant = fraction > 0.02 ? ecoule / fraction - ecoule : nil
        progression(Avancement(fraction: fraction, ecoule: ecoule, restantEstime: restant))
    }

    // MARK: - Réglages d'encodage

    /// H.264, encodé par VideoToolbox.
    ///
    /// Le débit est proportionnel au nombre de pixels par seconde : un même
    /// réglage doit donner une qualité comparable en 1080p et en 4K, en 30 et en
    /// 60 images. Le coefficient vise la qualité d'un `crf 18` de libx264 — le
    /// réglage du prototype —, quitte à produire des fichiers un peu lourds :
    /// pour du témoignage, la qualité prime sur la taille.
    private func reglagesH264(taille: CGSize, imagesParSeconde: Float) -> [String: Any] {
        let ips = imagesParSeconde > 0 ? Double(imagesParSeconde) : 30
        let pixelsParSeconde = Double(taille.width) * Double(taille.height) * ips
        let debit = Int(min(max(pixelsParSeconde * 0.12, 2_000_000), 80_000_000))

        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(taille.width),
            AVVideoHeightKey: Int(taille.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: debit,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: true,
                // Une image-clé toutes les deux secondes : navigation fluide
                // dans le fichier produit, sans gonfler le débit.
                AVVideoMaxKeyFrameIntervalDurationKey: 2,
            ],
        ]
    }
}
