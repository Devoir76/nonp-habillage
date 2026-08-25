// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesSegmenteur.swift — contrôles du découpage en lignes et de la
// resegmentation des blocs longs.

import Foundation

enum ControlesSegmenteur {

    static func executer(_ r: Rapport) {
        r.section("Segmenteur — découpage en lignes")
        motsJamaisCoupes(r)
        motTropLongSeul(r)
        limiteRespectee(r)

        r.section("Segmenteur — resegmentation")
        blocCourtInchange(r)
        coupureALaPonctuation(r)
        pasDeFragmentOrphelin(r)

        r.section("Segmenteur — minutages")
        prorataDesDurees(r)
        continuiteDesMorceaux(r)
        blocVideDisparait(r)
    }

    // MARK: - Découpage en lignes

    private static func motsJamaisCoupes(_ r: Rapport) {
        let mots = ["Bonjour", "à", "toutes", "et", "à", "tous", "aujourd'hui"]
        let lignes = Segmenteur.envelopper(mots: mots, maxCaracteres: 20)
        let motsRessortis = lignes.flatMap { TextePython.decouperEnMots($0) }
        r.egal("aucun mot coupé ni perdu", motsRessortis, mots)
    }

    private static func motTropLongSeul(_ r: Rapport) {
        // Invariant nº1 : plutôt une ligne trop large qu'un mot mutilé.
        let mots = ["anticonstitutionnellement"]
        let lignes = Segmenteur.envelopper(mots: mots, maxCaracteres: 10)
        r.egal("un mot plus long que la ligne reste entier",
               lignes, ["anticonstitutionnellement"])
    }

    private static func limiteRespectee(_ r: Rapport) {
        let mots = TextePython.decouperEnMots(
            "Le témoin raconte ce qu'il a vu ce jour-là sans rien omettre")
        let lignes = Segmenteur.envelopper(mots: mots, maxCaracteres: 20)
        let debordantes = lignes.filter { TextePython.longueur($0) > 20 }
        r.egal("aucune ligne ne dépasse la limite", debordantes, [])
    }

    // MARK: - Resegmentation

    private static func blocCourtInchange(_ r: Rapport) {
        // Un bloc qui tient déjà doit ressortir tel quel, minutages compris :
        // la resegmentation ne doit pas remuer ce qui allait bien.
        let cues = [Cue(debutMs: 1000, finMs: 3000, texte: "Une phrase courte.")]
        let graves = Segmenteur.segmenter(cues, maxCaracteres: 32, lignesMax: 2)
        r.egal("une réplique en entrée, une en sortie", graves.count, 1)
        r.egal("texte inchangé", graves.first?.lignes, ["Une phrase courte."])
        r.egal("début inchangé", graves.first?.debutMs, 1000)
        r.egal("fin inchangée", graves.first?.finMs, 3000)
    }

    private static func coupureALaPonctuation(_ r: Rapport) {
        // Le bloc dépasse deux lignes de 20 caractères : il doit être coupé, et
        // de préférence après un point.
        let texte = "Il est arrivé le matin. Nous avons parlé longtemps ce jour-là."
        let cues = [Cue(debutMs: 0, finMs: 10_000, texte: texte)]
        let graves = Segmenteur.segmenter(cues, maxCaracteres: 20, lignesMax: 2)
        r.verifier("bloc long redécoupé", graves.count > 1)
        r.verifier("la première coupure tombe après une ponctuation",
                   graves.first?.texteContinu.hasSuffix(".") == true)
    }

    private static func pasDeFragmentOrphelin(_ r: Rapport) {
        // Une ponctuation trop précoce ne doit pas être retenue : reculer
        // jusqu'à elle fabriquerait un morceau de deux mots suivi d'un pavé.
        let texte = "Oui. Le témoignage complet occupe ensuite plusieurs lignes entières"
        let cues = [Cue(debutMs: 0, finMs: 10_000, texte: texte)]
        let graves = Segmenteur.segmenter(cues, maxCaracteres: 20, lignesMax: 2)
        let premier = TextePython.decouperEnMots(graves.first?.texteContinu ?? "")
        r.verifier("le premier morceau n'est pas réduit à « Oui. »", premier.count > 1)
    }

    // MARK: - Minutages

    private static func prorataDesDurees(_ r: Rapport) {
        // Invariant nº2 : la durée du bloc est répartie entre les morceaux, et
        // le total est conservé exactement.
        let texte = "Première partie de la phrase. Seconde partie de la phrase. "
            + "Troisième partie de la phrase."
        let cues = [Cue(debutMs: 2000, finMs: 12_000, texte: texte)]
        let graves = Segmenteur.segmenter(cues, maxCaracteres: 20, lignesMax: 2)
        r.verifier("plusieurs morceaux produits", graves.count > 1)
        r.egal("le premier morceau part du début du bloc",
               graves.first?.debutMs, 2000)
        r.egal("le dernier morceau finit à la fin du bloc",
               graves.last?.finMs, 12_000)
        let durees = graves.map { $0.finMs - $0.debutMs }
        r.verifier("aucune durée négative", durees.allSatisfy { $0 >= 0 })
    }

    private static func continuiteDesMorceaux(_ r: Rapport) {
        // Pas de trou ni de chevauchement : chaque morceau commence là où le
        // précédent s'arrête.
        let texte = "Une phrase assez longue pour être coupée en plusieurs morceaux "
            + "successifs, avec de la ponctuation, afin de vérifier la continuité."
        let cues = [Cue(debutMs: 5000, finMs: 25_000, texte: texte)]
        let graves = Segmenteur.segmenter(cues, maxCaracteres: 24, lignesMax: 2)
        var continu = true
        for (a, b) in zip(graves, graves.dropFirst()) where a.finMs != b.debutMs {
            continu = false
        }
        r.verifier("les morceaux s'enchaînent sans trou ni recouvrement", continu)
    }

    private static func blocVideDisparait(_ r: Rapport) {
        // Comportement du prototype : un bloc sans mot ne produit aucune
        // réplique, plutôt qu'une réplique vide affichée à l'écran.
        let cues = [
            Cue(debutMs: 0, finMs: 1000, texte: "   "),
            Cue(debutMs: 1000, finMs: 2000, texte: "Du texte."),
        ]
        let graves = Segmenteur.segmenter(cues, maxCaracteres: 32, lignesMax: 2)
        r.egal("le bloc vide ne produit rien", graves.count, 1)
        r.egal("le bloc suivant est intact", graves.first?.lignes, ["Du texte."])
    }
}
