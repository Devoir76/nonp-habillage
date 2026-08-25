// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// TextePython.swift — sémantique de chaîne du prototype, reproduite à l'exact.
//
// Le parseur et le segmenteur sont des PORTAGES FIDÈLES de nonp_habille.py, et
// leur parité se mesure au caractère près. Or Swift et Python ne comptent ni ne
// découpent les chaînes de la même façon. Trois écarts suffiraient à faire
// diverger le découpage des lignes sur des sous-titres français ordinaires :
//
// 1. `len()` en Python compte des POINTS DE CODE ; `String.count` en Swift
//    compte des grappes de graphèmes. Un « é » décomposé (e + U+0301) vaut 2
//    pour Python et 1 pour Swift. Comme `wrap()` compare cette longueur à une
//    limite de caractères, l'écart déplace une césure — donc une réplique
//    entière. D'où `longueur()`, qui compte les scalaires Unicode.
//
// 2. `str.split()` et `str.strip()` sans argument utilisent `str.isspace()`,
//    dont l'ensemble ne coïncide avec aucun `CharacterSet` de Foundation :
//    `.whitespacesAndNewlines` ignore U+001C à U+001F, que Python considère
//    comme des espaces. L'ensemble est donc énuméré ici, une fois, plutôt que
//    supposé.
//
// 3. `round()` en Python arrondit au PAIR le plus proche (round(2.5) == 2) là
//    où `.rounded()` en Swift s'éloigne de zéro (2.5 → 3). Les tailles de
//    police se calculent par arrondi : sur un balayage de résolutions, une
//    valeur à .5 exact suffirait à décaler la police d'un pixel et, par
//    ricochet, la capacité de ligne. D'où `arrondi()`.
//
// Ces fonctions n'ont pas vocation à survivre au-delà du moteur : elles
// existent pour que la parité soit une propriété du code, pas une coïncidence.

import Foundation

enum TextePython {

    // MARK: - Espaces

    /// Les caractères pour lesquels `str.isspace()` répond vrai en Python 3.
    ///
    /// Énumérés plutôt que dérivés d'un `CharacterSet` de Foundation : aucun
    /// ensemble prédéfini ne correspond exactement, et une approximation ne se
    /// verrait qu'au moment où un sous-titre exotique la déclenche.
    static let scalairesEspaces: [Unicode.Scalar] = [
        "\u{0009}", "\u{000A}", "\u{000B}", "\u{000C}", "\u{000D}",
        "\u{001C}", "\u{001D}", "\u{001E}", "\u{001F}",
        "\u{0020}", "\u{0085}", "\u{00A0}", "\u{1680}",
        "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}", "\u{2005}",
        "\u{2006}", "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}",
        "\u{2028}", "\u{2029}", "\u{202F}", "\u{205F}", "\u{3000}",
    ]

    /// Le même ensemble sous forme de `CharacterSet`, pour rogner et découper.
    static let espaces: CharacterSet = {
        var jeu = CharacterSet()
        for s in scalairesEspaces { jeu.insert(s) }
        return jeu
    }()

    /// Le même ensemble sous forme de classe de caractères pour ICU, afin que
    /// les expressions régulières découpent les blocs exactement comme `\s`
    /// côté Python. `\s` d'ICU ne couvre pas U+000B ni U+001C à U+001F : s'en
    /// contenter rouvrirait l'écart nº2 par la porte des expressions régulières.
    static let classeEspacesICU: String = {
        let corps = scalairesEspaces
            .map { String(format: "\\u%04X", $0.value) }
            .joined()
        return "[" + corps + "]"
    }()

    // MARK: - Opérations

    /// Équivalent de `str.strip()` : rogne les espaces aux deux extrémités.
    static func rogner(_ texte: String) -> String {
        texte.trimmingCharacters(in: espaces)
    }

    /// Équivalent de `str.split()` sans argument : découpe sur des suites
    /// d'espaces, sans produire de fragment vide.
    static func decouperEnMots(_ texte: String) -> [String] {
        texte.components(separatedBy: espaces).filter { !$0.isEmpty }
    }

    /// Équivalent de `len()` : nombre de points de code, pas de graphèmes.
    static func longueur(_ texte: String) -> Int {
        texte.unicodeScalars.count
    }

    /// Équivalent de `round()` : arrondi au pair le plus proche.
    static func arrondi(_ valeur: Double) -> Int {
        Int(valeur.rounded(.toNearestOrEven))
    }

    /// Équivalent de `int()` sur un flottant : troncature vers zéro.
    static func tronquer(_ valeur: Double) -> Int {
        Int(valeur)
    }
}
