// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// DiagnosticVideo.swift — pourquoi, exactement, cette vidéo ne s'ouvre pas.
//
// ── Le défaut que ce fichier corrige (06/09) ────────────────────────────────
//
// Le moteur enveloppait TOUTE erreur de chargement dans un seul message :
// « format non pris en charge […] convertissez la vidéo ». Un fichier
// introuvable, un dossier passé pour une vidéo, un fichier dont macOS refuse
// l'accès, un fichier tronqué : tous recevaient la même explication, et elle
// était fausse dans trois cas sur quatre. Dans une application destinée au
// public, c'est un défaut à part entière — l'utilisateur convertit un fichier
// qui n'a aucun problème de format, et le vrai problème reste entier.
//
// ── Pourquoi le diagnostic ne peut pas venir d'AVFoundation seule ───────────
//
// Ses codes ne distinguent pas ce qui compte. Relevé sur macOS 15, à
// `loadTracks` :
//
//   fichier introuvable   → AVFoundationErrorDomain −11800 « unknown error »
//   dossier               → AVFoundationErrorDomain −11828 « format not supported »
//   fichier de 0 octet    → AVFoundationErrorDomain −11828, le même
//   fichier tronqué       → AVFoundationErrorDomain −11829 « may be damaged »
//   droits refusés        → NSCocoaErrorDomain 257
//
// Le cas le plus banal — le fichier n'est plus là — ressort en « erreur
// inconnue », et le dossier ressort en « format non pris en charge ». L'état du
// FICHIER, lui, est sans ambiguïté : c'est donc lui qu'on interroge d'abord, et
// le code d'AVFoundation ne sert qu'ensuite, pour ce que le disque ne dit pas.
//
// Le diagnostic ne tourne qu'APRÈS un échec. Un chargement qui réussit ne paie
// rien, et le disque n'est jamais interrogé pour rien.

import Foundation
import AVFoundation

/// Ce que le moteur vidéo de macOS reproche vraiment à un fichier.
///
/// Un cas par marche à suivre : deux causes qui appellent le même geste de
/// l'utilisateur n'ont pas à être distinguées, deux causes qui en appellent
/// deux différents ne doivent jamais être confondues.
enum RefusVideo: Error, Equatable {
    /// Le chemin ne désigne plus rien : déplacé, renommé, effacé.
    case introuvable(URL)
    /// Un dossier — ou un paquet — passé pour une vidéo.
    case pasUnFichier(URL)
    /// Le fichier est là, macOS en refuse la lecture.
    case droitsRefuses(URL)
    /// Zéro octet : un transfert ou un export qui ne s'est pas terminé.
    case vide(URL)
    /// Le seul cas où « convertissez la vidéo » est le bon conseil.
    case formatNonPrisEnCharge(URL)
    /// Aucune extension : l'application reconnaît les vidéos à la leur.
    case sansExtension(URL)
    /// Un conteneur reconnu, mais un contenu illisible : troncature, corruption.
    case endommagee(URL)
    /// Tout le reste, avec la raison réelle citée plutôt que travestie.
    case chargementImpossible(URL, String)
}

enum DiagnosticVideo {

    /// Classe l'échec d'ouverture de `video`, en interrogeant d'abord le
    /// fichier lui-même, puis l'erreur rendue par AVFoundation.
    static func refus(video: URL, erreur: Error) -> RefusVideo {
        let fm = FileManager.default

        // 1. L'état du fichier — la seule source qui ne se trompe pas.
        var estDossier: ObjCBool = false
        guard fm.fileExists(atPath: video.path, isDirectory: &estDossier) else {
            return .introuvable(video)
        }
        if estDossier.boolValue { return .pasUnFichier(video) }
        if !fm.isReadableFile(atPath: video.path) { return .droitsRefuses(video) }
        if let taille = try? fm.attributesOfItem(atPath: video.path)[.size] as? Int64,
           taille == 0 {
            return .vide(video)
        }

        // 2. Ce que le disque ne dit pas : le code d'AVFoundation.
        let ns = erreur as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileReadNoPermissionError:  return .droitsRefuses(video)
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return .introuvable(video)
            default: break
            }
        }
        if ns.domain == AVFoundationErrorDomain {
            switch ns.code {
            case AVError.Code.fileFormatNotRecognized.rawValue:
                return .formatNonPrisEnCharge(video)
            case AVError.Code.fileFailedToParse.rawValue,
                 AVError.Code.failedToParse.rawValue:
                return .endommagee(video)
            default: break
            }
        }

        // 3. Faute de mieux, la raison réelle — jamais une cause inventée.
        return .chargementImpossible(video, ns.localizedDescription)
    }
}
