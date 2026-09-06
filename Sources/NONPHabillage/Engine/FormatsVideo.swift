// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// FormatsVideo.swift — MP4, MOV, M4V. Une seule règle, les deux portes.
//
// ── L'écart que ce fichier ferme (06/09) ────────────────────────────────────
//
// L'ADR §3 met MKV et AVI hors périmètre. La zone de dépôt les refusait ; la
// ligne de commande, elle, les passait au moteur — et un AVI y aboutissait,
// parce qu'AVFoundation le lit très bien, contrairement à ce qu'affirmait le
// commentaire de la zone de dépôt. L'application avait donc deux périmètres :
// celui qu'elle annonce, et celui qu'elle accepte par une autre porte.
//
// Ce que le moteur de macOS SAIT lire et ce que l'application ACCEPTE sont deux
// questions distinctes. La seconde est une décision d'architecture, pas une
// limite technique : trois conteneurs éprouvés, pas de couverture partielle
// dépendante du codec (ADR §3, « pas de remux automatique »). Elle vit donc
// ici, en un seul endroit, et les deux portes la lisent.
//
// ── Pourquoi l'extension, et pas le contenu ─────────────────────────────────
//
// Parce que le refus doit tomber AVANT le chargement : la zone de dépôt refuse
// au dépôt plutôt qu'après cinq minutes de gravure, et la ligne de commande
// doit refuser à la même seconde. C'est aussi la règle que l'utilisateur voit —
// le sélecteur de fichiers grise les autres extensions.
//
// Le type est déduit de l'extension par le système, jamais comparé à la main :
// `.qt` désigne le même conteneur que `.mov`, et une table écrite à la main
// l'aurait manqué.

import Foundation
import UniformTypeIdentifiers

enum FormatsVideo {

    /// Les conteneurs d'entrée de l'ADR §3.
    ///
    /// `.mpeg4Movie` couvre MP4 et M4V, `.quickTimeMovie` couvre MOV et QT.
    /// MKV, AVI, WebM et MPEG-1/2 n'y conforment pas — c'est le refus voulu.
    static let typesAcceptes: [UTType] = [.mpeg4Movie, .quickTimeMovie]

    /// Ce que l'application accepte d'habiller. La seule règle, pour toutes
    /// les portes d'entrée.
    static func accepte(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased())
        else { return false }
        return typesAcceptes.contains { type.conforms(to: $0) || type == $0 }
    }

    /// Le refus à opposer à un fichier que `accepte` écarte — sans jamais
    /// toucher au fichier, qui n'a pas encore été ouvert.
    ///
    /// Deux formulations, parce que deux gestes : convertir un MKV, renommer
    /// un fichier qui n'a pas d'extension du tout.
    static func refus(_ url: URL) -> RefusVideo {
        url.pathExtension.isEmpty ? .sansExtension(url) : .formatNonPrisEnCharge(url)
    }
}
