// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Segmenteur.swift — découpage en lignes et resegmentation des blocs longs.
//
// Portage fidèle de `wrap()` et `segment()` de nonp_habille.py.
//
// Le problème que ce code résout : un SRT de transcription livre souvent des
// blocs de quatre ou cinq lignes, illisibles une fois gravés. Le segmenteur les
// redécoupe en répliques successives qui tiennent en `lignesMax` lignes, coupe
// de préférence à la ponctuation, et répartit la durée du bloc d'origine entre
// les morceaux au prorata de leur longueur.
//
// DEUX INVARIANTS, tous deux vérifiés par le harnais de vérification :
//
// nº1 — Aucun mot n'est modifié. Le segmenteur ne fait que regrouper des mots
//   issus de `split()` : il ne peut ni corriger, ni substituer, ni réécrire.
//   Il ne coupe jamais À L'INTÉRIEUR d'un mot, même trop long pour la ligne —
//   une ligne peut donc dépasser la limite plutôt que de casser un mot.
//
// nº2 — Les minutages produits ici sont des timecodes de RENDU. Ils diffèrent
//   de ceux du fichier source dès qu'un bloc a été redécoupé, et ne doivent
//   jamais être réinjectés dans un fichier de sous-titres. L'application n'en
//   exporte aucun.

import Foundation

enum Segmenteur {

    /// Ponctuations où une coupure est préférable, reprises de `[\.\!\?:;,]$`.
    private static let ponctuationsDeCoupe: Set<Unicode.Scalar> =
        [".", "!", "?", ":", ";", ","]

    // MARK: - Découpage en lignes

    /// Équivalent de `wrap()` : répartit des mots en lignes d'au plus
    /// `maxCaracteres` caractères, sans jamais couper un mot.
    ///
    /// Un mot plus long que la limite occupe seul une ligne trop large : c'est
    /// le comportement du prototype, et c'est le bon — mieux vaut une ligne qui
    /// dépasse qu'un mot mutilé (invariant nº1).
    static func envelopper(mots: [String], maxCaracteres: Int) -> [String] {
        envelopper(mots: mots) { ligne, mot in
            TextePython.longueur(ligne) + 1 + TextePython.longueur(mot) <= maxCaracteres
        }
    }

    /// La même mécanique, mais c'est l'appelant qui décide si un mot tient
    /// encore sur la ligne courante.
    ///
    /// Deux critères coexistent dans l'application, et il FAUT qu'ils partagent
    /// cet algorithme :
    ///
    /// - **par nombre de caractères** — celui du prototype, seul comparable à
    ///   la sortie Python, donc seul utilisable pour la parité (lot 2) ;
    /// - **par largeur mesurée** — la césure exacte réclamée par l'ADR §5, où
    ///   Core Text mesure le texte réel dans la police réelle (lot 3).
    ///
    /// Écrire deux fois le remplissage aurait laissé les deux versions dériver
    /// l'une de l'autre en silence, et la parité n'aurait plus rien prouvé du
    /// code réellement employé au rendu. Ici, seul le critère change.
    static func envelopper(
        mots: [String], tient: (_ ligne: String, _ mot: String) -> Bool
    ) -> [String] {
        var lignes: [String] = []
        var courante = ""
        for mot in mots {
            if !courante.isEmpty && !tient(courante, mot) {
                lignes.append(courante)
                courante = mot
            } else {
                courante = TextePython.rogner(courante + " " + mot)
            }
        }
        if !courante.isEmpty { lignes.append(courante) }
        return lignes
    }

    // MARK: - Resegmentation

    /// Équivalent de `segment()`.
    ///
    /// Les blocs qui tiennent déjà en `lignesMax` lignes ressortent inchangés,
    /// minutages compris. Les autres sont découpés, et la durée du bloc est
    /// répartie entre les morceaux **au prorata du nombre de caractères**.
    ///
    /// Une cue dont le texte ne contient aucun mot disparaît — elle ne produit
    /// aucun morceau. C'est le comportement du prototype : un bloc vide n'a
    /// rien à afficher.
    static func segmenter(
        _ cues: [Cue], maxCaracteres: Int, lignesMax: Int
    ) -> [CueGravee] {
        segmenter(cues, lignesMax: lignesMax) { ligne, mot in
            TextePython.longueur(ligne) + 1 + TextePython.longueur(mot) <= maxCaracteres
        }
    }

    /// La même resegmentation, avec un critère de tenue de ligne fourni par
    /// l'appelant. Voir `envelopper(mots:tient:)` pour le pourquoi.
    static func segmenter(
        _ cues: [Cue], lignesMax: Int, tient: (_ ligne: String, _ mot: String) -> Bool
    ) -> [CueGravee] {
        var resultat: [CueGravee] = []

        for cue in cues {
            let mots = TextePython.decouperEnMots(cue.texte)
            let morceaux = decouperEnMorceaux(
                mots: mots, lignesMax: lignesMax, tient: tient)

            // Longueur de référence pour le prorata : le morceau relu d'un
            // trait, les sauts de ligne comptant pour une espace.
            let longueurs = morceaux.map {
                TextePython.longueur($0.joined(separator: " "))
            }
            // `or 1` du prototype : évite une division par zéro quand tous les
            // morceaux sont vides. Sans morceau, la boucle ne tourne pas.
            let total = longueurs.reduce(0, +) == 0 ? 1 : longueurs.reduce(0, +)

            var instant = cue.debutMs
            for (k, morceau) in morceaux.enumerated() {
                let duree = TextePython.tronquer(
                    Double(cue.finMs - cue.debutMs) * (Double(longueurs[k]) / Double(total)))
                // Le dernier morceau va jusqu'à la fin du bloc d'origine : la
                // troncature ne doit pas raboter la fin de la réplique.
                let fin = (k == morceaux.count - 1)
                    ? cue.finMs
                    : min(cue.finMs, instant + duree)
                resultat.append(CueGravee(debutMs: instant, finMs: fin, lignes: morceau))
                instant = fin
            }
        }
        return resultat
    }

    // MARK: - Détail du découpage

    /// Découpe une suite de mots en morceaux tenant chacun en `lignesMax`
    /// lignes, en reculant jusqu'à une ponctuation quand c'est possible.
    private static func decouperEnMorceaux(
        mots: [String], lignesMax: Int, tient: (_ ligne: String, _ mot: String) -> Bool
    ) -> [[String]] {
        var morceaux: [[String]] = []
        let n = mots.count
        var i = 0

        while i < n {
            // Remplit tant que l'ensemble tient en `lignesMax` lignes.
            var dernier = i
            var j = i
            while j < n,
                  envelopper(mots: Array(mots[i...j]), tient: tient).count <= lignesMax {
                dernier = j
                j += 1
            }

            // Coupé par débordement : reculer jusqu'à une ponctuation, mais
            // seulement si elle tombe dans la seconde moitié du morceau —
            // sinon on fabriquerait un fragment orphelin de deux mots.
            if dernier < n - 1 {
                var k = dernier
                while k >= i {
                    if finitParUnePonctuation(mots[k]) {
                        if (k - i + 1) >= max(1, (dernier - i + 1) / 2) {
                            dernier = k
                        }
                        break   // on s'arrête à la première ponctuation trouvée,
                                // qu'on l'ait retenue ou non — comme le prototype
                    }
                    k -= 1
                }
            }

            morceaux.append(envelopper(mots: Array(mots[i...dernier]), tient: tient))
            i = dernier + 1
        }
        return morceaux
    }

    private static func finitParUnePonctuation(_ mot: String) -> Bool {
        guard let dernier = mot.unicodeScalars.last else { return false }
        return ponctuationsDeCoupe.contains(dernier)
    }
}
