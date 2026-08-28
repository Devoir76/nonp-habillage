// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesFidelite.swift — l'invariant nº1, vérifié.
//
// « Aucun mot des sous-titres n'est jamais modifié. » Ce n'est pas une consigne
// de style : c'est la valeur du produit. Un témoignage gravé avec un mot changé
// n'est plus un témoignage.
//
// Le contrôle est direct : on prend les mots du fichier source, on prend les
// mots des répliques gravées, et on exige la MÊME suite — mêmes mots, même
// ordre, aucun ajout, aucune perte, aucune retouche. Comparer des ensembles
// laisserait passer une inversion ; comparer des suites, non.
//
// Il tourne sur les fixtures ci-dessous, et — quand un corpus lui est fourni —
// sur chaque fichier réel de ce corpus, en 16:9 comme en 9:16.

import Foundation

enum ControlesFidelite {

    static func executer(_ r: Rapport, corpus: [URL]) {
        r.section("Fidélité — invariant nº1, fixtures")
        for cas in casDeReference {
            controlerUnTexte(r, intitule: cas.intitule, source: cas.source)
        }

        r.section("Fidélité — invariant nº1, corpus réel")
        if corpus.isEmpty {
            r.nonExecute("corpus de sous-titres réels",
                         motif: "aucun corpus fourni — passer --corpus <dossier>")
            return
        }
        for fichier in corpus {
            controlerUnFichier(r, fichier)
        }
    }

    // MARK: - Cas de référence

    private struct Cas {
        let intitule: String
        let source: String
    }

    private static let casDeReference: [Cas] = [
        Cas(intitule: "accents et apostrophes", source: """
        1
        00:00:01,000 --> 00:00:09,000
        J'étais là, à l'aube, et nous n'avions rien vu venir ; les enfants
        dormaient encore, la maison était calme, tout paraissait normal.
        """),
        Cas(intitule: "chiffres et ponctuation serrée", source: """
        1
        00:00:01,000 --> 00:00:09,000
        En 1942, le 16 juillet exactement, ils sont arrivés à 4 h 30 du matin ;
        ils ont frappé, puis ils ont enfoncé la porte — personne n'a répondu.
        """),
        Cas(intitule: "majuscules et sigles", source: """
        1
        00:00:01,000 --> 00:00:09,000
        La CGT, la CFDT et l'UNEF avaient appelé à manifester ce jour-là,
        place de la RÉPUBLIQUE, dès 14 h.
        """),
        Cas(intitule: "mot plus long que la ligne", source: """
        1
        00:00:01,000 --> 00:00:05,000
        C'était anticonstitutionnellement contestable, disait-il.
        """),
        Cas(intitule: "tirets et guillemets français", source: """
        1
        00:00:01,000 --> 00:00:09,000
        Il m'a dit « nous reviendrons » — et il est reparti sans se retourner,
        laissant derrière lui un silence que personne n'osait rompre.
        """),
    ]

    // MARK: - Contrôle

    private static func controlerUnTexte(_ r: Rapport, intitule: String, source: String) {
        guard let cues = try? ParseurSousTitres.analyser(contenu: source) else {
            r.verifier("\(intitule) : lecture", false)
            return
        }
        // En 16:9 et en 9:16 : la resegmentation n'a pas le droit de perdre un
        // mot parce que le format a changé.
        for (nom, w, h) in [("16:9", 1920, 1080), ("9:16", 1080, 1920)] {
            let p = MoteurMiseEnPage.calculer(
                profil: .bandeauColore, largeur: w, hauteur: h)
            let graves = Segmenteur.segmenter(
                cues, maxCaracteres: p.maxCaracteres,
                lignesMax: ProfilHabillage.bandeauColore.lignesMax)
            r.egal("\(intitule) — \(nom) : mots identiques et dans l'ordre",
                   mots(de: graves), mots(source: cues))
        }
    }

    private static func controlerUnFichier(_ r: Rapport, _ url: URL) {
        let nom = url.lastPathComponent
        let cues: [Cue]
        do {
            cues = try ParseurSousTitres.analyser(fichier: url)
        } catch let e as ErreurSousTitres {
            r.verifier("\(nom) : lecture — \(Textes.SousTitres.message(pour: e))", false)
            return
        } catch {
            r.verifier("\(nom) : lecture", false)
            return
        }

        let attendus = mots(source: cues)
        var toutBon = true
        for (_, w, h) in [("16:9", 1920, 1080), ("9:16", 1080, 1920)] {
            let p = MoteurMiseEnPage.calculer(
                profil: .bandeauColore, largeur: w, hauteur: h)
            let graves = Segmenteur.segmenter(
                cues, maxCaracteres: p.maxCaracteres,
                lignesMax: ProfilHabillage.bandeauColore.lignesMax)
            if mots(de: graves) != attendus { toutBon = false }
        }
        r.verifier("\(nom) : \(attendus.count) mots préservés en 16:9 et en 9:16", toutBon)
    }

    // MARK: - Extraction des mots

    private static func mots(source cues: [Cue]) -> [String] {
        cues.flatMap { TextePython.decouperEnMots($0.texte) }
    }

    private static func mots(de graves: [CueGravee]) -> [String] {
        graves.flatMap { TextePython.decouperEnMots($0.texteContinu) }
    }
}
