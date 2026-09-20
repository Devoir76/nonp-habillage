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
import UniformTypeIdentifiers

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

        r.section("Export — la cause annoncée est la vraie")
        causeNommee(r, video: essai)

        r.section("Export — un seul périmètre pour les deux portes")
        perimetreUnique(r, video: essai)

        r.section("Export — un blanc de tête ne rallonge pas la vidéo")
        blancDeTete(r, videoReelle: videoReelle)

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
        r.verifier("le message dit que le contenu est illisible",
                   message?.contains("illisible") == true)
        r.verifier("aucun fichier de sortie n'est créé",
                   !FileManager.default.fileExists(atPath: sortie.path))
    }

    // MARK: - Le blanc de tête

    /// Certains MP4 ouvrent leurs pistes sur un MONTAGE VIDE — 80 ms et 66 ms
    /// de rien avant la première image, sur les deux vidéos rapportées d'un
    /// réseau social le 06/09. Le fichier produit en sortait plus long que sa
    /// source, de deux images exactement, et les minutages des sous-titres,
    /// qui comptent depuis la première image, paraissaient d'autant plus tôt
    /// qu'elle. Trouvé par la campagne de parité.
    ///
    /// **Ce qui se contrôle ici est la MESURE du vide**, pas l'export de bout
    /// en bout — et il faut dire pourquoi. Fabriquer un MP4 porteur d'un
    /// montage vide n'a pas été possible avec les seuls outils d'Apple :
    /// `AVAssetExportSession` l'aplatit en images noires, y compris en
    /// `Passthrough`. Une `AVMutableComposition`, elle, en porte un vrai. Le
    /// bout en bout attend donc une vidéo réelle qui en ait un, et s'annonce
    /// non exécuté à défaut — jamais réussi par défaut.
    private static func blancDeTete(_ r: Rapport, videoReelle: URL?) {
        let blanc = CMTime(seconds: 0.5, preferredTimescale: 600)

        // Une piste ordinaire n'ouvre sur rien.
        guard let ordinaire = pisteDeComposition(blancDeTete: .zero) else {
            r.verifier("fabrication d'une piste sans blanc", false); return
        }
        r.egal("une piste qui commence à sa première image ne déclare aucun vide",
               (try? bloquant { try await ExportateurVideo.blancDeTete(ordinaire) })?.seconds,
               0)

        // Une piste ouverte sur un vide le déclare, à la milliseconde.
        guard let avecVide = pisteDeComposition(blancDeTete: blanc) else {
            r.verifier("fabrication d'une piste à blanc de tête", false); return
        }
        let mesure = (try? bloquant {
            try await ExportateurVideo.blancDeTete(avecVide) })?.seconds ?? -1
        r.verifier("un vide de 0,5 s en tête est mesuré à 0,5 s "
                   + "(\(String(format: "%.3f", mesure)))",
                   abs(mesure - 0.5) < 0.005)

        // Un trou AU MILIEU n'est pas un blanc de tête : c'est un choix de
        // montage, et le refermer raccourcirait la vidéo de quelqu'un.
        guard let trouAuMilieu = pisteDeComposition(blancDeTete: .zero, trouApres: blanc) else {
            r.verifier("fabrication d'une piste à trou central", false); return
        }
        r.egal("un vide au milieu de la piste n'est pas retiré",
               (try? bloquant { try await ExportateurVideo.blancDeTete(trouAuMilieu) })?.seconds,
               0)

        // Bout en bout : le compte d'images de la sortie doit être celui de la
        // source. Il faut pour cela une vidéo réelle qui porte un blanc.
        guard let videoReelle else {
            r.nonExecute("le compte d'images sur une source à blanc de tête",
                         motif: "aucune vidéo réelle fournie — passer --video <fichier>")
            return
        }
        // ⚠️ LE MÊME MIN QUE L'EXPORTATEUR, et pour la même raison.
        //
        // `ExportateurVideo` ne retire que `min(blancVidéo, blancAudio)` : retirer
        // d'une piste ce que l'autre n'a pas désynchroniserait le son, qu'il
        // recopie échantillon par échantillon sans y toucher. Un attendu calculé
        // sur le seul blanc vidéo contredisait donc l'exportateur dès que les
        // deux pistes ne s'ouvrent pas sur le même vide — et le contrôle échouait
        // en accusant un comportement voulu. Mesuré le 20/09 sur une source à
        // blanc vidéo seul : 0,5 s d'écart, imputés à tort au moteur.
        let vide = (try? bloquant {
            let asset = AVURLAsset(url: videoReelle)
            guard let pisteVideo = try await asset
                .loadTracks(withMediaType: .video).first else { return 0.0 }
            var v = try await ExportateurVideo.blancDeTete(pisteVideo).seconds
            if let pisteAudio = try await asset
                .loadTracks(withMediaType: .audio).first {
                v = min(v, try await ExportateurVideo.blancDeTete(pisteAudio).seconds)
            }
            return v
        }) ?? 0
        guard vide > 0 else {
            r.nonExecute("le compte d'images sur une source à blanc de tête",
                         motif: "« \(videoReelle.lastPathComponent) » n'en porte pas — "
                              + "passer une vidéo qui ouvre sur un montage vide")
            return
        }

        // La DURÉE, et non le compte d'images : `AVAssetReaderTrackOutput` rend
        // les échantillons du média, montage vide compris, et son compte ne
        // s'accorde ni avec celui d'un lecteur ni avec celui de la source. La
        // durée, elle, est celle du montage — la seule chose que les deux
        // moteurs et un lecteur voient pareil.
        let sortie = dossierTemporaire().appendingPathComponent("blanc.mp4")
        let dureeSource = (try? bloquant {
            try await AVURLAsset(url: videoReelle).load(.duration) })?.seconds ?? 0
        let attendue = dureeSource - vide
        do {
            let bilan = try bloquant {
                try await ExportateurVideo().exporter(
                    video: videoReelle, sousTitres: nil, profil: .bandeauColore,
                    vers: sortie, progression: { _ in })
            }
            let obtenue = (try? bloquant {
                try await AVURLAsset(url: sortie).load(.duration) })?.seconds ?? 0
            // TOLÉRANCE : UNE IMAGE, pas un nombre de secondes en dur.
            //
            // Campagne du 20/09 — 16 sources, offsets 0,3 / 0,5 / 0,7 / 1,0 s
            // croisés avec 24, 25, 30 et 60 i/s. Le résidu mesuré vaut 0,000 à
            // 0,001 s, soit 0,06 image au pire, et il NE CROÎT NI avec l'offset
            // NI avec la cadence. C'est donc un arrondi de frontière, pas une
            // dérive du moteur : une tolérance proportionnelle à la granularité
            // du média la décrit, un seuil en secondes la masquerait.
            //
            // Une image laisse 16× la marge du pire résidu mesuré à 60 i/s, et
            // resserre le contrôle par rapport aux 0,05 s d'avant — 16,7 ms à
            // 60 i/s, 41,7 ms à 24. Un écart d'une image entière, lui, serait
            // une vraie image perdue ou gagnée : c'est exactement ce qu'on veut
            // voir échouer.
            let cadence = (try? bloquant {
                guard let piste = try await AVURLAsset(url: videoReelle)
                    .loadTracks(withMediaType: .video).first else { return 0.0 }
                return Double(try await piste.load(.nominalFrameRate))
            }) ?? 0
            let uneImage = cadence > 0 ? 1.0 / cadence : 0.05
            r.verifier("un blanc de tête de \(String(format: "%.3f", vide)) s ne "
                       + "rallonge pas la vidéo produite "
                       + "(\(String(format: "%.3f", obtenue)) s pour "
                       + "\(String(format: "%.3f", attendue)) s attendues, "
                       + "tolérance 1 image = \(String(format: "%.3f", uneImage)) s)",
                       abs(obtenue - attendue) < uneImage)
            r.verifier("et le bilan annonce la durée du fichier produit, pas "
                       + "celle qu'il a lue "
                       + "(\(String(format: "%.3f", bilan.dureeVideo)) s)",
                       abs(bilan.dureeVideo - attendue) < uneImage)
        } catch {
            r.verifier("export d'une source à blanc de tête — "
                       + "\(CommandeExport.message(pour: error))", false)
        }
        try? FileManager.default.removeItem(at: sortie)
    }

    /// Une piste de montage, éventuellement ouverte sur un vide, ou trouée
    /// après `trouApres`. Le vide y est RÉEL — c'est ce qu'un fichier exporté
    /// ne sait pas porter.
    private static func pisteDeComposition(
        blancDeTete blanc: CMTime, trouApres: CMTime? = nil) -> AVAssetTrack? {
        guard let essai = fabriquerVideoDEssai() else { return nil }
        defer { try? FileManager.default.removeItem(at: essai) }
        let source = AVURLAsset(url: essai)
        let montage = AVMutableComposition()
        guard let cible = montage.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let piste = (try? bloquant {
                  try await source.loadTracks(withMediaType: .video) })?.first,
              let duree = try? bloquant({ try await source.load(.duration) })
        else { return nil }
        do {
            if blanc > .zero {
                montage.insertEmptyTimeRange(CMTimeRange(start: .zero, duration: blanc))
            }
            try cible.insertTimeRange(CMTimeRange(start: .zero, duration: duree),
                                      of: piste, at: blanc)
            if let trouApres {
                montage.insertEmptyTimeRange(
                    CMTimeRange(start: trouApres, duration: trouApres))
            }
        } catch { return nil }
        return cible
    }

    // MARK: - Un seul périmètre pour les deux portes

    /// L'ADR §3 met MKV et AVI hors périmètre. La zone de dépôt les refusait,
    /// la ligne de commande les acceptait : l'application avait deux
    /// périmètres. Le contrôle éprouve la règle sur une vidéo **parfaitement
    /// lisible**, seulement renommée — c'est le conteneur annoncé qui est
    /// refusé, pas un contenu illisible, et rien d'autre ne peut expliquer le
    /// refus.
    private static func perimetreUnique(_ r: Rapport, video: URL) {
        let dossier = dossierTemporaire()
        let sortie = dossier.appendingPathComponent("jamais-perimetre.mp4")

        func copie(_ nom: String) -> URL {
            let url = dossier.appendingPathComponent(nom)
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.copyItem(at: video, to: url)
            return url
        }

        for nom in ["renommee.avi", "renommee.mkv", "renommee.webm"] {
            let url = copie(nom)
            let message = messageDuRefus(video: url, vers: sortie)
            r.verifier("une vidéo lisible nommée « \(nom) » est refusée",
                       message != nil)
            r.verifier("le refus de « \(nom) » nomme les formats acceptés",
                       message?.contains("MP4, MOV et M4V") == true)
            try? FileManager.default.removeItem(at: url)
        }

        let sansPoint = copie("sans-extension")
        let mSansPoint = messageDuRefus(video: sansPoint, vers: sortie)
        r.verifier("un fichier sans extension est refusé", mSansPoint != nil)
        r.verifier("le refus dit de le renommer, pas de le convertir",
                   mSansPoint?.contains("renommez") == true
                   && mSansPoint?.contains("Convertissez") == false)
        try? FileManager.default.removeItem(at: sansPoint)

        // Le périmètre ne doit pas voler la vedette au disque : un dossier n'a
        // pas d'extension, et « renommez-le en .mp4 » serait exact et inutile.
        r.egal("un dossier reste annoncé comme un dossier",
               FormatsVideo.refus(dossier), .pasUnFichier(dossier))
        r.egal("un .mkv qui n'existe pas est annoncé introuvable",
               FormatsVideo.refus(dossier.appendingPathComponent("fantome.mkv")),
               .introuvable(dossier.appendingPathComponent("fantome.mkv")))

        r.verifier("aucun de ces refus ne laisse de fichier de sortie",
                   !FileManager.default.fileExists(atPath: sortie.path))

        // Le revers : les trois conteneurs de l'ADR passent, y compris sous une
        // extension que la règle accepte mais qu'on rencontre rarement.
        for nom in ["accepte.mov", "accepte.m4v"] {
            let url = copie(nom)
            let destination = dossier.appendingPathComponent("sortie-\(nom).mp4")
            r.verifier("« \(nom) » est accepté",
                       messageDuRefus(video: url, vers: destination) == nil)
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: destination)
        }

        // Et la règle est bien UNE : la liste que présente le sélecteur de
        // fichiers est celle du moteur, pas une seconde liste à tenir à jour.
        r.egal("la zone de dépôt lit la règle du moteur",
               UTType.videosAcceptees, FormatsVideo.typesAcceptes)
    }

    // MARK: - La cause annoncée est la vraie

    /// Le défaut du 06/09 : « format non pris en charge — convertissez la
    /// vidéo » sortait pour TOUTE erreur de chargement. Un fichier introuvable,
    /// un dossier, des droits refusés : l'utilisateur partait convertir un
    /// fichier qui n'avait aucun problème de format, et le vrai problème
    /// restait entier. Chaque cause doit désormais se nommer elle-même.
    private static func causeNommee(_ r: Rapport, video: URL) {
        let dossier = dossierTemporaire()
        let sortie = dossier.appendingPathComponent("jamais-cause.mp4")

        // --- De bout en bout : ce que le DISQUE dit du fichier -------------

        let absent = dossier.appendingPathComponent("jamais-existe.mp4")
        try? FileManager.default.removeItem(at: absent)
        let mIntrouvable = messageDuRefus(video: absent, vers: sortie)
        r.verifier("un fichier introuvable est annoncé introuvable",
                   mIntrouvable?.contains("introuvable") == true)
        r.verifier("un fichier introuvable ne parle pas de format",
                   mIntrouvable?.contains("Convertissez") == false)

        let mDossier = messageDuRefus(video: dossier, vers: sortie)
        r.verifier("un dossier est annoncé comme un dossier",
                   mDossier?.contains("dossier, pas une vidéo") == true)

        let interdit = dossier.appendingPathComponent("interdit.mp4")
        try? FileManager.default.removeItem(at: interdit)
        try? FileManager.default.copyItem(at: video, to: interdit)
        try? FileManager.default.setAttributes([.posixPermissions: 0],
                                               ofItemAtPath: interdit.path)
        // Sous un compte administrateur qui contourne les droits POSIX, le
        // fichier resterait lisible : le contrôle ne vaut que si macOS refuse
        // vraiment l'accès. Mieux vaut l'annoncer non exécuté que le faire
        // passer pour éprouvé.
        if FileManager.default.isReadableFile(atPath: interdit.path) {
            r.nonExecute("droits refusés",
                         motif: "ce compte lit le fichier malgré des droits à 000")
        } else {
            let mDroits = messageDuRefus(video: interdit, vers: sortie)
            r.verifier("un accès refusé est annoncé comme un problème de droits",
                       mDroits?.contains("droits") == true)
            r.verifier("un accès refusé écarte explicitement le format",
                       mDroits?.contains("format n'est pas en cause") == true)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o644],
                                               ofItemAtPath: interdit.path)
        try? FileManager.default.removeItem(at: interdit)

        let vide = dossier.appendingPathComponent("vide.mp4")
        try? Data().write(to: vide)
        let mVide = messageDuRefus(video: vide, vers: sortie)
        r.verifier("un fichier de 0 octet est annoncé vide",
                   mVide?.contains("vide") == true)
        try? FileManager.default.removeItem(at: vide)

        r.verifier("aucun de ces refus ne laisse de fichier de sortie",
                   !FileManager.default.fileExists(atPath: sortie.path))

        // --- La table de classement, cas par cas --------------------------
        //
        // Les deux codes qui comptent ne se distinguent QUE par leur numéro :
        // un MKV et un MP4 tronqué échouent tous deux à `loadTracks`, l'un en
        // −11828, l'autre en −11829, et ils appellent deux gestes opposés
        // (convertir / retrouver une copie intacte). Fabriquer un MKV exigerait
        // un outil tiers — invariant nº3 : c'est l'erreur qu'on fabrique, sur
        // un fichier par ailleurs valide, pour que seul le classement soit
        // éprouvé.
        func refus(_ domaine: String, _ code: Int) -> RefusVideo {
            DiagnosticVideo.refus(
                video: video,
                erreur: NSError(domain: domaine, code: code,
                                userInfo: [NSLocalizedDescriptionKey: "raison de macOS"]))
        }
        r.egal("un format non reconnu (−11828) reste un problème de format",
               refus(AVFoundationErrorDomain, -11828), .formatNonPrisEnCharge(video))
        r.egal("un contenu illisible (−11829) n'est pas un problème de format",
               refus(AVFoundationErrorDomain, -11829), .endommagee(video))
        r.egal("un refus d'accès (Cocoa 257) est un problème de droits",
               refus(NSCocoaErrorDomain, NSFileReadNoPermissionError),
               .droitsRefuses(video))
        r.egal("une erreur inconnue cite la raison réelle de macOS",
               refus("UnDomaineInconnu", 42),
               .chargementImpossible(video, "raison de macOS"))

        // Le conseil de conversion est réservé au seul cas où il aide.
        let tous: [RefusVideo] = [
            .introuvable(video), .pasUnFichier(video), .droitsRefuses(video),
            .vide(video), .endommagee(video), .chargementImpossible(video, "x"),
        ]
        r.verifier("seul un vrai problème de format conseille une conversion",
                   tous.allSatisfy { !Textes.Export.message(pour: $0).contains("Convertissez") }
                   && Textes.Export.message(pour: .formatNonPrisEnCharge(video))
                        .contains("Convertissez"))

        // Chaque message nomme le fichier en cause : sans cela, l'utilisateur
        // qui en a déposé plusieurs ne sait pas lequel est refusé.
        r.verifier("chaque refus nomme le fichier",
                   (tous + [.formatNonPrisEnCharge(video)]).allSatisfy {
                       Textes.Export.message(pour: $0).contains(video.lastPathComponent)
                   })
    }

    /// Tente l'export et rend le message affiché en cas de refus — nil si
    /// l'export a, contre toute attente, abouti.
    private static func messageDuRefus(video: URL, vers sortie: URL) -> String? {
        do {
            _ = try bloquant {
                try await ExportateurVideo().exporter(
                    video: video, sousTitres: nil, profil: .bandeauColore,
                    vers: sortie, progression: { _ in })
            }
            return nil
        } catch {
            return CommandeExport.message(pour: error)
        }
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
