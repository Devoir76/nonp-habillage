// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesExport.swift — les critères d'acceptation du lot 4.
//
// La vidéo d'essai est FABRIQUÉE ici, image par image, plutôt que lue sur le
// disque : le `.gitignore` exclut `*.mp4` — « médias de test, jamais versionnés »
// — et un contrôle qui ne tournerait que sur la machine d'Éric ne vaudrait pas
// grand-chose. Une vidéo de synthèse de deux secondes suffit à éprouver la
// composition, la progression, l'annulation et la propreté du disque.
//
// Ce qu'elle ne peut PAS éprouver, c'est la recopie de l'audio : il y faut une
// vraie piste. Ce contrôle-là s'active avec `--video <fichier>` et s'annonce
// « non exécuté » sans elle, jamais réussi par défaut.

import Foundation
import AVFoundation
import CoreMedia
import CoreVideo

enum ControlesExport {

    static func executer(_ r: Rapport, videoReelle: URL?) {
        // Table rase : un fichier laissé par une exécution précédente ferait
        // échouer — ou pire, réussir à tort — les contrôles de propreté du
        // disque, qui reposent tous sur l'ABSENCE de fichier.
        try? FileManager.default.removeItem(at: dossierTemporaire())

        r.section("Export — vidéo de synthèse")
        guard let essai = fabriquerVideoDEssai() else {
            r.verifier("fabrication de la vidéo d'essai", false)
            return
        }
        defer { try? FileManager.default.removeItem(at: essai) }

        exportComplet(r, video: essai)
        annulation(r, video: essai)
        sansSousTitres(r, video: essai)

        r.section("Export — entrées refusées")
        entreeInvalide(r)

        r.section("Export — les fichiers d'origine ne sont jamais remplacés")
        jamaisParDessusUneEntree(r, video: essai)

        r.section("Export — audio recopié sans réencodage")
        if let videoReelle {
            audioRecopie(r, video: videoReelle)
        } else {
            r.nonExecute("recopie de l'audio",
                         motif: "aucune vidéo réelle fournie — passer --video <fichier>")
        }
    }

    // MARK: - Export complet

    private static func exportComplet(_ r: Rapport, video: URL) {
        let sortie = dossierTemporaire().appendingPathComponent("export.mp4")
        var avancements: [Double] = []

        do {
            let bilan = try bloquant {
                try await ExportateurVideo().exporter(
                    video: video, sousTitres: fichierSousTitresDEssai(),
                    profil: .bandeauColore, vers: sortie,
                    progression: { avancements.append($0.fraction) })
            }
            r.verifier("l'export aboutit", true)
            r.verifier("le fichier de sortie existe",
                       FileManager.default.fileExists(atPath: sortie.path))
            r.verifier("le fichier n'est pas vide", bilan.octets > 0)
            r.verifier("la durée est conservée (\(String(format: "%.1f", bilan.dureeVideo)) s)",
                       abs(bilan.dureeVideo - dureeEssai) < 0.5)

            // Progression : elle doit avancer, et ne jamais reculer.
            r.verifier("la progression a été signalée (\(avancements.count) fois)",
                       avancements.count >= 2)
            r.verifier("la progression ne recule jamais",
                       zip(avancements, avancements.dropFirst()).allSatisfy { $0 <= $1 })
            r.verifier("la progression atteint 100 %",
                       (avancements.last ?? 0) >= 0.999)

            // Le fichier produit doit être lisible par AVFoundation — c'est le
            // moteur de QuickTime Player.
            let asset = AVURLAsset(url: sortie)
            let jouable = (try? bloquant { try await asset.load(.isPlayable) }) ?? false
            r.verifier("le fichier produit est lisible (AVFoundation)", jouable)

            let pistes = (try? bloquant {
                try await asset.loadTracks(withMediaType: .video) }) ?? []
            r.egal("le fichier produit a une piste vidéo", pistes.count, 1)
        } catch {
            r.verifier("l'export aboutit — \(CommandeExport.message(pour: error))", false)
        }
        try? FileManager.default.removeItem(at: sortie)
    }

    // MARK: - Annulation

    private static func annulation(_ r: Rapport, video: URL) {
        let sortie = dossierTemporaire().appendingPathComponent("annule.mp4")
        let exportateur = ExportateurVideo()
        var annulé = false

        do {
            _ = try bloquant {
                // L'annulation part au PREMIER signal de progression. Une
                // minuterie serait à la merci de la vitesse d'encodage : sur
                // cette vidéo de synthèse, l'export se termine parfois avant
                // qu'elle n'expire, et le contrôle passerait alors sans rien
                // avoir éprouvé. Ici, l'interruption tombe forcément en cours
                // de route.
                return try await exportateur.exporter(
                    video: video, sousTitres: nil, profil: .bandeauColore,
                    vers: sortie, progression: { _ in exportateur.annuler() })
            }
        } catch ErreurExport.annule {
            annulé = true
        } catch {
            r.verifier("l'annulation lève bien ErreurExport.annule — "
                       + "reçu \(error)", false)
        }
        r.verifier("l'annulation interrompt l'export", annulé)

        // « L'annulation laisse le disque propre » : ni sortie, ni temporaire.
        r.verifier("aucun fichier de sortie n'est laissé",
                   !FileManager.default.fileExists(atPath: sortie.path))
        let temporaire = sortie.deletingLastPathComponent()
            .appendingPathComponent(".\(sortie.lastPathComponent).en-cours")
        r.verifier("aucun fichier temporaire n'est laissé",
                   !FileManager.default.fileExists(atPath: temporaire.path))
        r.verifier("le message d'annulation dit que rien n'est resté",
                   Textes.Export.annule.contains("Aucun fichier"))
    }

    // MARK: - Sans sous-titres

    private static func sansSousTitres(_ r: Rapport, video: URL) {
        // Usage « logo seul » de l'ADR : une vidéo sans fichier de sous-titres
        // reste un export valide, pas une erreur.
        let sortie = dossierTemporaire().appendingPathComponent("sans-st.mp4")
        do {
            let bilan = try bloquant {
                try await ExportateurVideo().exporter(
                    video: video, sousTitres: nil, profil: .bandeauColore,
                    vers: sortie, progression: { _ in })
            }
            r.verifier("un export sans sous-titres aboutit", bilan.octets > 0)
        } catch {
            r.verifier("un export sans sous-titres aboutit — "
                       + "\(CommandeExport.message(pour: error))", false)
        }
        try? FileManager.default.removeItem(at: sortie)
    }

    // MARK: - Entrées refusées

    private static func entreeInvalide(_ r: Rapport) {
        // ADR §3 : un fichier refusé produit un message explicite assorti d'une
        // marche à suivre — jamais un échec silencieux ni un plantage.
        let bidon = dossierTemporaire().appendingPathComponent("pas-une-video.mp4")
        try? Data("ceci n'est pas une vidéo".utf8).write(to: bidon)
        defer { try? FileManager.default.removeItem(at: bidon) }

        let sortie = dossierTemporaire().appendingPathComponent("jamais.mp4")
        var message: String? = nil
        do {
            _ = try bloquant {
                try await ExportateurVideo().exporter(
                    video: bidon, sousTitres: nil, profil: .bandeauColore,
                    vers: sortie, progression: { _ in })
            }
        } catch {
            message = CommandeExport.message(pour: error)
        }
        r.verifier("un fichier qui n'est pas une vidéo est refusé", message != nil)
        r.verifier("le message nomme les formats acceptés",
                   message?.contains("MP4") == true || message?.contains("piste vidéo") == true)
        r.verifier("aucun fichier de sortie n'est créé",
                   !FileManager.default.fileExists(atPath: sortie.path))
    }

    // MARK: - Ne jamais écraser une entrée

    /// L'export finit par effacer sa destination puis y déplacer son résultat.
    /// Pointée sur la vidéo source, cette destination est l'original — et il
    /// n'existe nulle part ailleurs. Le nom proposé par l'application ne tombe
    /// jamais dessus, mais le champ du panneau d'enregistrement est libre et la
    /// ligne de commande prend n'importe quel chemin : le refus doit donc venir
    /// du moteur, que les deux traversent.
    private static func jamaisParDessusUneEntree(_ r: Rapport, video: URL) {
        guard let srt = fichierSousTitresDEssai() else {
            r.verifier("fichier de sous-titres d'essai", false); return
        }
        defer { try? FileManager.default.removeItem(at: srt) }

        let avant = octets(de: video)
        let empreinteSRT = try? String(contentsOf: srt, encoding: .utf8)

        // Le même chemin, mot pour mot.
        r.verifier("exporter par-dessus la vidéo source est refusé",
                   refuse(video: video, sousTitres: srt, vers: video, r: r,
                          intitule: "la vidéo source"))

        // Le même fichier atteint autrement : un détour par « .. ». La
        // comparaison de chaînes ne suffirait pas.
        let detour = video.deletingLastPathComponent()
            .appendingPathComponent("..")
            .appendingPathComponent(video.deletingLastPathComponent().lastPathComponent)
            .appendingPathComponent(video.lastPathComponent)
        r.verifier("un chemin détourné vers la vidéo source est refusé aussi",
                   refuse(video: video, sousTitres: srt, vers: detour, r: r,
                          intitule: "la vidéo source par un détour"))

        // Le fichier de sous-titres est une entrée lui aussi.
        r.verifier("exporter par-dessus le fichier de sous-titres est refusé",
                   refuse(video: video, sousTitres: srt, vers: srt, r: r,
                          intitule: "les sous-titres"))

        r.egal("la vidéo source est intacte", octets(de: video), avant)
        r.egal("le fichier de sous-titres est intact",
               try? String(contentsOf: srt, encoding: .utf8), empreinteSRT)

        // Et le refus se lit : il nomme le fichier et dit quoi faire.
        let message = Textes.Export.ecraseraitUneEntree(video.lastPathComponent)
        r.verifier("le refus nomme le fichier menacé",
                   message.contains(video.lastPathComponent))
        r.verifier("le refus dit quoi faire",
                   message.contains("autre nom") || message.contains("autre dossier"))
    }

    /// Tente l'export vers `destination` et rend vrai si le moteur l'a refusé
    /// pour la bonne raison — sans rien écrire au passage.
    private static func refuse(video: URL, sousTitres: URL, vers destination: URL,
                               r: Rapport, intitule: String) -> Bool {
        do {
            _ = try bloquant {
                try await ExportateurVideo().exporter(
                    video: video, sousTitres: sousTitres, profil: .bandeauColore,
                    vers: destination, progression: { _ in })
            }
            return false
        } catch ErreurExport.ecraseraitUneEntree {
            return true
        } catch {
            r.verifier("refus de \(intitule) : la raison attendue "
                       + "(obtenu : \(error))", false)
            return false
        }
    }

    private static func octets(de url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64)
            .flatMap { $0 } ?? -1
    }

    // MARK: - Audio

    private static func audioRecopie(_ r: Rapport, video: URL) {
        let sortie = dossierTemporaire().appendingPathComponent("audio.mp4")
        do {
            let bilan = try bloquant {
                try await ExportateurVideo().exporter(
                    video: video, sousTitres: nil, profil: .bandeauColore,
                    vers: sortie, progression: { _ in })
            }
            r.verifier("l'export déclare l'audio recopié", bilan.audioRecopie)

            // La preuve : la description de format de la piste audio produite
            // est IDENTIQUE à celle de la source. Un réencodage la changerait.
            let source = try formatAudio(de: video)
            let produite = try formatAudio(de: sortie)
            r.verifier("la source a bien une piste audio", source != nil)
            r.egal("le format audio est inchangé", descriptionCourte(produite),
                   descriptionCourte(source))
        } catch {
            r.verifier("export de la vidéo réelle — "
                       + "\(CommandeExport.message(pour: error))", false)
        }
        try? FileManager.default.removeItem(at: sortie)
    }

    private static func formatAudio(de url: URL) throws -> AudioStreamBasicDescription? {
        let asset = AVURLAsset(url: url)
        return try bloquant {
            guard let piste = try await asset.loadTracks(withMediaType: .audio).first,
                  let format = try await piste.load(.formatDescriptions).first
            else { return nil }
            return CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee
        }
    }

    private static func descriptionCourte(_ d: AudioStreamBasicDescription?) -> String {
        guard let d else { return "aucune" }
        return "id=\(d.mFormatID) taux=\(Int(d.mSampleRate)) canaux=\(d.mChannelsPerFrame) "
            + "bits=\(d.mBitsPerChannel) parPaquet=\(d.mFramesPerPacket)"
    }

    // MARK: - Vidéo de synthèse

    private static let dureeEssai = 2.0
    private static let imagesParSecondeEssai: Int32 = 10

    /// Fabrique une petite vidéo muette : un dégradé qui se déplace, pour que
    /// les images ne soient pas toutes identiques.
    /// Non privée : `ControlesInterface` s'en sert pour charger une vraie
    /// vidéo dans l'`AppState` — le seul moyen d'éprouver « Habiller une autre
    /// vidéo », qui doit précisément la décharger.
    static func fabriquerVideoDEssai() -> URL? {
        let url = dossierTemporaire().appendingPathComponent("essai-source.mp4")
        try? FileManager.default.removeItem(at: url)

        let largeur = 320, hauteur = 240
        guard let redacteur = try? AVAssetWriter(outputURL: url, fileType: .mp4)
        else { return nil }

        let entree = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: largeur,
            AVVideoHeightKey: hauteur,
        ])
        entree.expectsMediaDataInRealTime = false
        let adaptateur = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: entree,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: largeur,
                kCVPixelBufferHeightKey as String: hauteur,
            ])
        guard redacteur.canAdd(entree) else { return nil }
        redacteur.add(entree)
        guard redacteur.startWriting() else { return nil }
        redacteur.startSession(atSourceTime: .zero)

        let total = Int(dureeEssai * Double(imagesParSecondeEssai))
        for i in 0..<total {
            guard let reservoir = adaptateur.pixelBufferPool,
                  let tampon = pixelBuffer(dans: reservoir, teinte: Double(i) / Double(total))
            else { return nil }
            while !entree.isReadyForMoreMediaData { usleep(1000) }
            adaptateur.append(tampon, withPresentationTime: CMTime(
                value: CMTimeValue(i), timescale: imagesParSecondeEssai))
        }
        entree.markAsFinished()

        let verrou = DispatchSemaphore(value: 0)
        redacteur.finishWriting { verrou.signal() }
        verrou.wait()
        return redacteur.status == .completed ? url : nil
    }

    private static func pixelBuffer(
        dans reservoir: CVPixelBufferPool, teinte: Double
    ) -> CVPixelBuffer? {
        var tampon: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, reservoir, &tampon) == kCVReturnSuccess,
              let tampon else { return nil }
        CVPixelBufferLockBaseAddress(tampon, [])
        defer { CVPixelBufferUnlockBaseAddress(tampon, []) }
        guard let base = CVPixelBufferGetBaseAddress(tampon) else { return nil }
        let octets = CVPixelBufferGetBytesPerRow(tampon)
        let hauteur = CVPixelBufferGetHeight(tampon)
        let valeur = UInt8(40 + teinte * 150)
        memset(base, Int32(valeur), octets * hauteur)
        return tampon
    }

    /// Un petit SRT écrit sur le disque, le temps du contrôle.
    private static func fichierSousTitresDEssai() -> URL? {
        let url = dossierTemporaire().appendingPathComponent("essai.srt")
        let contenu = """
        1
        00:00:00,100 --> 00:00:01,000
        Première réplique de contrôle.

        2
        00:00:01,000 --> 00:00:02,000
        Seconde réplique, plus longue, pour forcer un découpage en deux lignes.
        """
        try? contenu.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Utilitaires

    static func dossierTemporaire() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonp-habillage-controles", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Exécute un travail asynchrone depuis le harnais synchrone.
    private static func bloquant<T>(_ travail: @escaping () async throws -> T) throws -> T {
        let verrou = DispatchSemaphore(value: 0)
        var resultat: Result<T, Error>!
        Task {
            do { resultat = .success(try await travail()) }
            catch { resultat = .failure(error) }
            verrou.signal()
        }
        verrou.wait()
        return try resultat.get()
    }
}
