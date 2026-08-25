// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ParseurSousTitres.swift — lecture des fichiers SRT et VTT.
//
// Portage fidèle de `parse_subs()` et `_ms()` de nonp_habille.py. Le prototype
// lit les deux formats avec le MÊME code, sans distinguer l'extension : un bloc
// est une suite de lignes non vides contenant une ligne « --> ». Cette
// souplesse est délibérée — elle accepte les SRT sans numéro, les VTT avec
// en-tête, les fichiers mal terminés — et elle est reprise telle quelle.
//
// INVARIANT nº1 : aucun mot n'est modifié. Ce parseur ne corrige rien, ne
// normalise aucune ponctuation, ne réencode aucun caractère. Il découpe et il
// date, rien d'autre.
//
// UN SEUL ÉCART VOLONTAIRE avec le prototype, sur les entrées invalides :
// `_ms()` en Python laisse remonter une AttributeError quand la ligne « --> »
// ne contient pas de timecode reconnaissable — l'outil s'arrête sur une trace
// Python illisible pour un utilisateur. Ici, la même situation lève une erreur
// explicite en français, portant le numéro du bloc fautif. Sur une entrée
// valide, les deux implémentations produisent exactement les mêmes cues : la
// divergence ne concerne que le cas où le prototype plantait.

import Foundation

enum ErreurSousTitres: Error {
    /// Le fichier n'a pas pu être lu (absent, droits, disque).
    case fichierIllisible(URL)
    /// Le contenu n'est pas de l'UTF-8 valide.
    case encodageNonUTF8(URL)
    /// La ligne de minutage d'un bloc ne contient pas de timecode exploitable.
    case timecodeIllisible(numeroBloc: Int, ligne: String)
}

enum ParseurSousTitres {

    // MARK: - Entrée principale

    /// Lit et analyse un fichier de sous-titres (SRT ou VTT).
    ///
    /// L'extension n'est pas consultée : c'est le contenu qui décide, comme
    /// dans le prototype.
    static func analyser(fichier url: URL) throws -> [Cue] {
        guard let donnees = try? Data(contentsOf: url) else {
            throw ErreurSousTitres.fichierIllisible(url)
        }
        guard let contenu = String(data: donnees, encoding: .utf8) else {
            throw ErreurSousTitres.encodageNonUTF8(url)
        }
        return try analyser(contenu: contenu)
    }

    /// Analyse un contenu déjà en mémoire.
    ///
    /// Une éventuelle marque d'ordre des octets (BOM) est conservée telle
    /// quelle, comme le fait `open(encoding="utf-8")` en Python : elle se
    /// retrouve collée au numéro du premier bloc, qui est de toute façon
    /// ignoré. La retirer serait un écart de comportement gratuit.
    static func analyser(contenu: String) throws -> [Cue] {
        let normalise = TextePython.rogner(contenu)
            .replacingOccurrences(of: "\r\n", with: "\n")

        var cues: [Cue] = []
        for (index, bloc) in decouperEnBlocs(normalise).enumerated() {
            if let cue = try analyserBloc(bloc, numero: index + 1) {
                cues.append(cue)
            }
        }
        return cues
    }

    // MARK: - Découpage en blocs

    /// Équivalent de `re.split(r"\n\s*\n", …)`.
    ///
    /// La classe d'espaces est celle de Python, pas celle d'ICU : voir
    /// `TextePython.classeEspacesICU` pour le pourquoi.
    private static let separateurBlocs: NSRegularExpression = {
        let motif = "\n" + TextePython.classeEspacesICU + "*\n"
        // Le motif est construit ici, à partir d'une liste littérale : il ne
        // peut pas être invalide, et un échec signalerait un bug de programme.
        return try! NSRegularExpression(pattern: motif)
    }()

    private static func decouperEnBlocs(_ texte: String) -> [String] {
        let ns = texte as NSString
        var blocs: [String] = []
        var debut = 0
        separateurBlocs.enumerateMatches(
            in: texte, range: NSRange(location: 0, length: ns.length)
        ) { resultat, _, _ in
            guard let r = resultat?.range else { return }
            blocs.append(ns.substring(with: NSRange(location: debut, length: r.location - debut)))
            debut = r.location + r.length
        }
        blocs.append(ns.substring(from: debut))
        return blocs
    }

    // MARK: - Analyse d'un bloc

    private static func analyserBloc(_ bloc: String, numero: Int) throws -> Cue? {
        var lignes = bloc.components(separatedBy: "\n")
            .filter { !TextePython.rogner($0).isEmpty }
        guard !lignes.isEmpty else { return nil }

        // En-tête d'un fichier VTT : « WEBVTT » éventuellement suivi d'un
        // commentaire sur la même ligne. Il précède le premier bloc.
        if TextePython.rogner(lignes[0]).uppercased().hasPrefix("WEBVTT") {
            lignes.removeFirst()
        }
        // Bloc de commentaire VTT : ignoré en entier, y compris son corps.
        guard let premiere = lignes.first,
              !TextePython.rogner(premiere).uppercased().hasPrefix("NOTE")
        else { return nil }

        // Le numéro de bloc du SRT est facultatif : si la première ligne porte
        // déjà la flèche, il n'y en a pas.
        let i = premiere.contains("-->") ? 0 : 1
        guard i < lignes.count, lignes[i].contains("-->") else { return nil }

        let bornes = lignes[i].components(separatedBy: "-->")
        guard bornes.count >= 2 else { return nil }
        let debut = try millisecondes(bornes[0], numeroBloc: numero, ligne: lignes[i])
        let fin = try millisecondes(bornes[1], numeroBloc: numero, ligne: lignes[i])

        return Cue(
            debutMs: debut,
            finMs: fin,
            texte: lignes[(i + 1)...].joined(separator: " ")
        )
    }

    // MARK: - Timecodes

    /// Équivalent de `_ms()` : cherche `H:MM:SS,mmm` ou `H:MM:SS.mmm` n'importe
    /// où dans le fragment, et le convertit en millisecondes.
    ///
    /// Les chiffres sont volontairement restreints à `[0-9]` là où `\d` en
    /// Python accepterait aussi les chiffres d'autres écritures : un timecode
    /// en chiffres arabes orientaux serait de toute façon refusé par la
    /// conversion qui suit, autant le refuser explicitement ici.
    private static let motifTimecode = try! NSRegularExpression(
        pattern: "([0-9]{1,2}):([0-9]{2}):([0-9]{2})[.,]([0-9]{1,3})")

    private static func millisecondes(
        _ fragment: String, numeroBloc: Int, ligne: String
    ) throws -> Int {
        let ns = fragment as NSString
        guard let m = motifTimecode.firstMatch(
            in: fragment, range: NSRange(location: 0, length: ns.length))
        else {
            throw ErreurSousTitres.timecodeIllisible(numeroBloc: numeroBloc, ligne: ligne)
        }
        let heures = Int(ns.substring(with: m.range(at: 1))) ?? 0
        let minutes = Int(ns.substring(with: m.range(at: 2))) ?? 0
        let secondes = Int(ns.substring(with: m.range(at: 3))) ?? 0
        // « ,5 » vaut 500 ms et non 5 : le prototype complète à droite.
        let fraction = (ns.substring(with: m.range(at: 4)) + "000").prefix(3)
        let ms = Int(fraction) ?? 0
        return ((heures * 60 + minutes) * 60 + secondes) * 1000 + ms
    }
}
