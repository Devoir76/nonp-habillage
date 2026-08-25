// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Cue.swift — les deux formes d'une réplique de sous-titre.
//
// Le prototype manipule deux choses distinctes sous le même nom de « cue » :
// ce qui a été LU du fichier, et ce qui sera GRAVÉ à l'écran. Les deux ne
// coïncident pas — c'est tout l'objet de la resegmentation. Les distinguer par
// le type évite qu'un timecode de rendu soit pris pour un timecode source.
//
// INVARIANT nº2 (ADR-0001) : les minutages d'une `CueGravee` sont réaffectés au
// prorata et diffèrent de ceux du fichier source. Ils ne sortent JAMAIS du
// rendu. L'application n'exporte aucun fichier de sous-titres — il n'existe
// d'ailleurs, dans tout ce dépôt, aucun code capable d'en écrire un.

import Foundation

/// Une réplique telle qu'elle a été lue du fichier SRT ou VTT.
///
/// `texte` est le texte brut du bloc, lignes du fichier jointes par une espace,
/// exactement comme `parse_subs()` le compose. Aucun mot n'y est modifié
/// (invariant nº1) et aucun découpage n'y est encore appliqué.
struct Cue: Equatable {
    /// Début en millisecondes depuis le début de la vidéo.
    var debutMs: Int
    /// Fin en millisecondes.
    var finMs: Int
    /// Texte brut du bloc.
    var texte: String
}

/// Une réplique telle qu'elle sera incrustée : lignes déjà découpées, minutages
/// réaffectés au prorata si le bloc source a dû être redécoupé.
struct CueGravee: Equatable {
    /// Début en millisecondes — **timecode de rendu**, pas celui du fichier.
    var debutMs: Int
    /// Fin en millisecondes — **timecode de rendu**.
    var finMs: Int
    /// Lignes à afficher, dans l'ordre. Une entrée par ligne à l'écran.
    var lignes: [String]

    /// Les lignes jointes par une espace : la phrase telle qu'on la lit.
    /// Sert au contrôle de fidélité, qui compare les mots au fichier source.
    var texteContinu: String {
        lignes.joined(separator: " ")
    }

    /// Les lignes jointes par le séparateur `\N` de l'ASS.
    ///
    /// Le moteur natif ne produira jamais d'ASS — c'est Core Text qui rendra le
    /// texte, ligne par ligne, au lot 3. Cette représentation n'existe que pour
    /// comparer terme à terme avec la sortie du prototype, qui, elle, passe par
    /// libass.
    var texteStyleASS: String {
        lignes.joined(separator: "\\N")
    }
}
