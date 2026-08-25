// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesParseur.swift — contrôles de lecture SRT et VTT.
//
// Les fixtures sont des chaînes Swift, pas des fichiers .srt. Ce n'est pas un
// détail de commodité : le `.gitignore` du dépôt exclut `*.srt` et `*.vtt`
// (« sous-titres de test — jamais versionnés »). Des fixtures littérales
// respectent la règle tout en restant exécutables sur un clone neuf, là où des
// fichiers auraient dû être soit versionnés contre la règle, soit absents.
//
// Elles couvrent la forme des fichiers ; le contenu réel, lui, est éprouvé par
// les contrôles de fidélité et de parité, qui tournent sur le vrai corpus.

import Foundation

enum ControlesParseur {

    /// Lit une fixture. Une erreur inattendue devient un échec nommé plutôt
    /// qu'un tableau vide qui ferait échouer le contrôle suivant sans dire
    /// pourquoi.
    private static func lire(_ source: String, _ r: Rapport, _ quoi: String) -> [Cue] {
        do {
            return try ParseurSousTitres.analyser(contenu: source)
        } catch let e as ErreurSousTitres {
            r.verifier("\(quoi) : lecture sans erreur — \(Textes.SousTitres.message(pour: e))", false)
            return []
        } catch {
            r.verifier("\(quoi) : lecture sans erreur", false)
            return []
        }
    }

    static func executer(_ r: Rapport) {
        r.section("Parseur — SRT")
        srtOrdinaire(r)
        srtSansNumero(r)
        srtMultiligne(r)
        srtPonctuationDecimale(r)
        srtMillisecondesCourtes(r)
        srtLignesVidesMultiples(r)
        srtCRLF(r)
        srtAvecBOM(r)

        r.section("Parseur — VTT")
        vttAvecEnTete(r)
        vttAvecNote(r)

        r.section("Parseur — cas limites")
        fichierVide(r)
        blocSansFleche(r)
        timecodeIllisible(r)
    }

    // MARK: - SRT

    private static func srtOrdinaire(_ r: Rapport) {
        let source = """
        1
        00:00:01,000 --> 00:00:03,500
        Bonjour à tous.

        2
        00:00:04,000 --> 00:00:06,250
        Merci d'être venus.
        """
        let cues = lire(source, r, "SRT ordinaire")
        r.egal("deux répliques lues", cues.count, 2)
        r.egal("premier début", cues.first?.debutMs, 1000)
        r.egal("première fin", cues.first?.finMs, 3500)
        r.egal("premier texte", cues.first?.texte, "Bonjour à tous.")
        r.egal("second début", cues.last?.debutMs, 4000)
        r.egal("seconde fin", cues.last?.finMs, 6250)
    }

    private static func srtSansNumero(_ r: Rapport) {
        // Le numéro de bloc est facultatif : c'est la flèche qui fait foi.
        let source = """
        00:00:10,000 --> 00:00:12,000
        Sans numéro de bloc.
        """
        let cues = lire(source, r, "SRT sans numéro")
        r.egal("bloc sans numéro accepté", cues.count, 1)
        r.egal("texte intact", cues.first?.texte, "Sans numéro de bloc.")
    }

    private static func srtMultiligne(_ r: Rapport) {
        // Les lignes du bloc sont jointes par une espace : le découpage en
        // lignes appartient au segmenteur, pas au fichier source.
        let source = """
        1
        00:00:01,000 --> 00:00:04,000
        Première ligne
        deuxième ligne
        troisième ligne
        """
        let cues = lire(source, r, "SRT multiligne")
        r.egal("lignes jointes par une espace",
               cues.first?.texte, "Première ligne deuxième ligne troisième ligne")
    }

    private static func srtPonctuationDecimale(_ r: Rapport) {
        // La virgule est la convention SRT, le point celle du VTT. Le prototype
        // accepte les deux sans regarder l'extension : on fait pareil.
        let source = """
        1
        00:00:01.250 --> 00:00:02.750
        Point décimal.
        """
        let cues = lire(source, r, "SRT point décimal")
        r.egal("point décimal accepté", cues.first?.debutMs, 1250)
        r.egal("fin avec point décimal", cues.first?.finMs, 2750)
    }

    private static func srtMillisecondesCourtes(_ r: Rapport) {
        // « ,5 » vaut 500 ms, pas 5 ms : le prototype complète à droite.
        let source = """
        1
        00:00:01,5 --> 00:00:02,25
        Millisecondes tronquées.
        """
        let cues = lire(source, r, "SRT millisecondes courtes")
        r.egal("« ,5 » vaut 500 ms", cues.first?.debutMs, 1500)
        r.egal("« ,25 » vaut 250 ms", cues.first?.finMs, 2250)
    }

    private static func srtLignesVidesMultiples(_ r: Rapport) {
        let source = "1\n00:00:01,000 --> 00:00:02,000\nUn.\n\n\n \n\n2\n"
            + "00:00:03,000 --> 00:00:04,000\nDeux."
        let cues = lire(source, r, "SRT lignes vides multiples")
        r.egal("séparateurs multiples absorbés", cues.count, 2)
        r.egal("texte du second bloc", cues.last?.texte, "Deux.")
    }

    private static func srtCRLF(_ r: Rapport) {
        let source = "1\r\n00:00:01,000 --> 00:00:02,000\r\nFins de ligne Windows.\r\n"
        let cues = lire(source, r, "SRT CRLF")
        r.egal("CRLF accepté", cues.count, 1)
        r.egal("aucun retour chariot résiduel",
               cues.first?.texte, "Fins de ligne Windows.")
    }

    private static func srtAvecBOM(_ r: Rapport) {
        // Le BOM reste collé au numéro de bloc, qui est ignoré : il ne gêne
        // pas. Le prototype se comporte exactement ainsi.
        let source = "\u{FEFF}1\n00:00:01,000 --> 00:00:02,000\nAvec BOM."
        let cues = lire(source, r, "SRT avec BOM")
        r.egal("BOM sans effet sur la lecture", cues.count, 1)
        r.egal("texte non pollué par le BOM", cues.first?.texte, "Avec BOM.")
    }

    // MARK: - VTT

    private static func vttAvecEnTete(_ r: Rapport) {
        let source = """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        Première réplique.

        00:00:03.000 --> 00:00:04.000
        Seconde réplique.
        """
        let cues = lire(source, r, "VTT avec en-tête")
        r.egal("en-tête WEBVTT retiré", cues.count, 2)
        r.egal("première réplique VTT", cues.first?.texte, "Première réplique.")
    }

    private static func vttAvecNote(_ r: Rapport) {
        let source = """
        WEBVTT

        NOTE
        Ceci est un commentaire, pas un sous-titre.

        00:00:01.000 --> 00:00:02.000
        Vrai sous-titre.
        """
        let cues = lire(source, r, "VTT avec NOTE")
        r.egal("bloc NOTE ignoré en entier", cues.count, 1)
        r.egal("seul le vrai sous-titre subsiste",
               cues.first?.texte, "Vrai sous-titre.")
    }

    // MARK: - Cas limites

    private static func fichierVide(_ r: Rapport) {
        let cues = lire("   \n\n  ", r, "fichier vide")
        r.egal("fichier vide → aucune réplique", cues.count, 0)
    }

    private static func blocSansFleche(_ r: Rapport) {
        // Un bloc sans minutage est ignoré, pas fatal : c'est ainsi que le
        // prototype absorbe les en-têtes et les scories de fin de fichier.
        let source = """
        Ceci n'est pas un bloc de sous-titre.

        1
        00:00:01,000 --> 00:00:02,000
        Celui-ci l'est.
        """
        let cues = lire(source, r, "bloc sans flèche")
        r.egal("bloc sans minutage ignoré", cues.count, 1)
        r.egal("le bloc valide passe", cues.first?.texte, "Celui-ci l'est.")
    }

    private static func timecodeIllisible(_ r: Rapport) {
        // Écart assumé avec le prototype : là où Python remontait une
        // AttributeError, on lève une erreur nommée, en français.
        let source = """
        1
        00:00:01,000 --> 00:00:02,000
        Bloc bien formé.

        2
        00:00:03 --> pas un minutage
        Texte.
        """
        var messageObtenu: String? = nil
        do {
            _ = try ParseurSousTitres.analyser(contenu: source)
        } catch let e as ErreurSousTitres {
            messageObtenu = Textes.SousTitres.message(pour: e)
        } catch {
            messageObtenu = nil
        }
        r.verifier("minutage invalide → erreur explicite", messageObtenu != nil)
        r.verifier("le message cite le bloc fautif",
                   messageObtenu?.contains("bloc 2") == true)
        r.verifier("le message montre la forme attendue",
                   messageObtenu?.contains("00:01:23,400") == true)
    }
}
