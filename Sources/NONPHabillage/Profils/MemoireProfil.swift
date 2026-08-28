// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// MemoireProfil.swift — le dernier profil utilisé, retrouvé au lancement.
//
// « On ne redépose pas son logo à chaque lancement » (cahier des lots, lot 6).
//
// ── Pourquoi ce fichier n'est PAS un profil partagé ──────────────────────────
//
// Un profil exporté et un profil mémorisé n'ont pas les mêmes besoins, et c'est
// le second piège du lot :
//
// | | mémoire locale | profil exporté |
// |---|---|---|
// | chemin du logo | ABSOLU — il désigne un fichier de CETTE machine | RELATIF, à côté du profil |
// | réglages hors schéma | conservés | absents — le schéma partagé ne les nomme pas |
// | destinataire | cette installation | n'importe qui |
//
// D'où un fichier d'enveloppe : un profil au schéma v1 EXACT, plus une section
// `reglages_app` pour ce que l'interface sait faire et que le contrat partagé
// ne nomme pas encore — la longueur de ligne cible et le recadrage rond du
// logo. Les mêler au profil ferait un document que le prototype refuserait, et
// surtout ce serait amender le schéma en douce (invariant nº6). Séparés, ils
// attendent la décision nº6 sans rien préjuger : si Éric leur donne un champ,
// ils déménagent d'une section à l'autre, et rien d'autre ne bouge.

import Foundation

enum MemoireProfil {

    /// Version de l'ENVELOPPE, distincte de celle du schéma partagé : ce
    /// fichier-ci est privé à l'application et peut évoluer sans toucher au
    /// contrat.
    static let versionEnveloppe = 1

    /// `~/Library/Application Support/NONP Habillage/dernier-profil.json`.
    ///
    /// Un fichier, pas les préférences système : on peut l'ouvrir, le lire, le
    /// corriger et le supprimer sans outil. C'est aussi ce qui permet au
    /// contrôle de vérifier ce qui a réellement été écrit.
    static var fichier: URL {
        dossier.appendingPathComponent("dernier-profil.json")
    }

    static var dossier: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent(Textes.nomApplication, isDirectory: true)
    }

    // MARK: - Écriture

    /// Enregistre le profil courant. Silencieux : perdre la mémoire d'une
    /// session ne doit jamais interrompre un travail en cours.
    static func enregistrer(_ profil: ProfilHabillage, vers url: URL? = nil) {
        let destination = url ?? fichier
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try donnees(profil).write(to: destination, options: .atomic)
        } catch {
            // Rien à dire à l'utilisateur : il n'a rien demandé.
        }
    }

    /// L'enveloppe, en octets.
    static func donnees(_ profil: ProfilHabillage) throws -> Data {
        // Le chemin du logo est ABSOLU ici, et c'est le seul endroit où il a le
        // droit de l'être : ce fichier ne quitte pas la machine. Le schéma
        // l'autorise explicitement — « absolu, ou relatif au fichier de
        // profil » —, donc l'objet reste un profil v1 valide.
        let json = try ProfilJSON.encoder(
            profil,
            cheminLogo: profil.logoActif ? profil.logoFichier?.path : nil)
        guard let profilObjet = try JSONSerialization.jsonObject(with: json)
                as? [String: Any] else {
            throw ErreurProfil(anomalies: [Textes.Profil.pasUnObjet])
        }

        let enveloppe: [String: Any] = [
            "version_enveloppe": versionEnveloppe,
            "profil": profilObjet,
            // PLUS DE « reglages_app ». La section portait les deux réglages
            // que le contrat partagé ne nommait pas — longueur de ligne cible
            // et recadrage rond. La version 2 du schéma leur a donné un champ
            // (décision nº6), et l'enveloppe n'a plus rien à transporter à
            // côté du profil. Elle reste pour sa version à elle : ce fichier
            // est privé à l'application et pourra évoluer sans toucher au
            // contrat.
        ]
        return try JSONSerialization.data(
            withJSONObject: enveloppe, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Lecture

    /// Le profil de la dernière session, ou `nil` s'il n'y en a pas.
    ///
    /// Ne lève rien : au premier lancement il n'y a pas de fichier, et un
    /// fichier abîmé ne doit pas empêcher l'application de s'ouvrir. Le profil
    /// neutre prend alors le relais — c'est ce que l'ADR §2 prévoit déjà pour
    /// le premier lancement.
    static func relire(depuis url: URL? = nil) -> ProfilHabillage? {
        let source = url ?? fichier
        guard let donnees = try? Data(contentsOf: source) else { return nil }
        return try? decoder(donnees)
    }

    static func decoder(_ donnees: Data) throws -> ProfilHabillage {
        guard let enveloppe = try JSONSerialization.jsonObject(with: donnees)
                as? [String: Any],
              let profilObjet = enveloppe["profil"],
              let corps = try? JSONSerialization.data(withJSONObject: profilObjet) else {
            throw ErreurProfil(anomalies: [Textes.Profil.pasUnObjet])
        }
        // Le profil passe par le MÊME validateur que n'importe quel fichier
        // partagé : la mémoire locale n'a aucun passe-droit. Un champ inconnu
        // écrit par une version future y sera refusé comme ailleurs, et
        // l'application repartira du profil neutre plutôt que d'appliquer un
        // réglage qu'elle ne comprend pas.
        return try ProfilJSON.decoder(corps, base: nil)
    }

    /// Oublier. Sert au contrôle, et à repartir de zéro.
    static func effacer(_ url: URL? = nil) {
        try? FileManager.default.removeItem(at: url ?? fichier)
    }
}
