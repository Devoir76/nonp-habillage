// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesMiseEnPage.swift — contrôles du calcul des paramètres, et
// DOCUMENTATION EXÉCUTABLE de la divergence 9:16 voulue par l'ADR §5.
//
// La divergence avec le prototype n'est pas décrite ici, elle est mesurée :
// les deux calculs tournent côte à côte sur les mêmes résolutions, et les
// contrôles disent exactement où ils se rejoignent et où ils se séparent. Une
// régression qui rétablirait le plancher de 16 caractères ferait tomber ces
// contrôles, pas seulement mentir un commentaire.

import Foundation

enum ControlesMiseEnPage {

    private static let profil = ProfilHabillage.bandeauColore

    static func executer(_ r: Rapport) {
        r.section("Mise en page — 16:9, parité avec le prototype")
        format16x9(r)

        r.section("Mise en page — 9:16, divergence voulue (ADR §5)")
        format9x16(r)

        r.section("Mise en page — un même profil sur quatre formats")
        tousFormats(r)

        r.section("Mise en page — la géométrie prime sur le plancher")
        aucunPlancherContraireALaGeometrie(r)
        tailleForceeReduiteSiNecessaire(r)
    }

    // MARK: - 16:9

    private static func format16x9(_ r: Rapport) {
        // Les valeurs attendues sont celles du tableau de l'ADR §5.
        let p = MoteurMiseEnPage.calculer(profil: profil, largeur: 1920, hauteur: 1080)
        r.egal("taille de police", p.taille, 78)
        r.egal("largeur utile", p.largeurUtile, 1804)
        r.egal("capacité de ligne", p.maxCaracteres, 32)
        r.verifier("aucune réduction nécessaire", !p.reduitePourTenir)

        let proto = MoteurMiseEnPage.calculerCommeLePrototype(
            profil: profil, largeur: 1920, hauteur: 1080)
        r.egal("même taille que le prototype", p.taille, proto.taille)
        r.egal("même capacité que le prototype", p.maxCaracteres, proto.maxCaracteres)
    }

    // MARK: - 9:16

    private static func format9x16(_ r: Rapport) {
        let p = MoteurMiseEnPage.calculer(profil: profil, largeur: 1080, hauteur: 1920)
        let proto = MoteurMiseEnPage.calculerCommeLePrototype(
            profil: profil, largeur: 1080, hauteur: 1920)

        // Ce que faisait le prototype, et pourquoi c'était faux.
        r.egal("le prototype demandait 138 px", proto.taille, 138)
        r.egal("le prototype imposait 16 caractères", proto.maxCaracteres, 16)
        let capaciteReelle = TextePython.tronquer(
            Double(proto.largeurUtile) / (138.0 * MesureurHistorique.facteur))
        r.egal("or 10 seulement tenaient", capaciteReelle, 10)
        r.verifier("le plancher du prototype contredisait la géométrie",
                   proto.maxCaracteres > capaciteReelle)

        // Ce que fait le moteur natif.
        r.egal("la taille est réduite à 44 px", p.taille, 44)
        r.egal("la taille demandée reste consignée", p.tailleDemandee, 138)
        r.verifier("la réduction est signalée", p.reduitePourTenir)
        r.egal("la capacité atteint la cible", p.maxCaracteres, 32)
        r.verifier("la capacité annoncée est tenable",
                   p.maxCaracteres <= TextePython.tronquer(
                       Double(p.largeurUtile) / (Double(p.taille) * MesureurHistorique.facteur)))
    }

    // MARK: - Quatre formats

    private static func tousFormats(_ r: Rapport) {
        // Exigence de l'ADR §5 : « Un même profil doit pouvoir servir en 16:9,
        // 9:16, 1:1 et 4:5 sans retouche. »
        let formats: [(String, Int, Int)] = [
            ("16:9 1080p", 1920, 1080),
            ("9:16", 1080, 1920),
            ("1:1", 1080, 1080),
            ("4:5", 1080, 1350),
            ("16:9 4K", 3840, 2160),
        ]
        for (nom, w, h) in formats {
            let p = MoteurMiseEnPage.calculer(profil: profil, largeur: w, hauteur: h)
            let capaciteReelle = TextePython.tronquer(
                Double(p.largeurUtile) / (Double(p.taille) * MesureurHistorique.facteur))
            r.verifier("\(nom) : la capacité annoncée tient dans la largeur",
                       p.maxCaracteres <= capaciteReelle)
            r.verifier("\(nom) : au moins \(MoteurMiseEnPage.longueurLigneMinimale) caractères par ligne",
                       p.maxCaracteres >= MoteurMiseEnPage.longueurLigneMinimale)
            r.verifier("\(nom) : la taille n'excède jamais celle du profil",
                       p.taille <= p.tailleDemandee)
        }
    }

    // MARK: - Géométrie

    private static func aucunPlancherContraireALaGeometrie(_ r: Rapport) {
        // Balayage large : sur aucune résolution plausible la capacité annoncée
        // ne doit dépasser ce que la largeur permet réellement. C'est la
        // formulation testable de « aucun plancher ne contredit la géométrie ».
        var fautives: [String] = []
        for largeur in stride(from: 320, through: 3840, by: 40) {
            for hauteur in stride(from: 240, through: 2160, by: 120) {
                let p = MoteurMiseEnPage.calculer(
                    profil: profil, largeur: largeur, hauteur: hauteur)
                let capaciteReelle = TextePython.tronquer(
                    Double(p.largeurUtile) / (Double(p.taille) * MesureurHistorique.facteur))
                if p.maxCaracteres > max(1, capaciteReelle) {
                    fautives.append("\(largeur)×\(hauteur)")
                }
            }
        }
        r.egal("balayage de résolutions : aucune capacité intenable",
               fautives.prefix(5).joined(separator: ", "), "")

        // Le prototype, lui, en produit — c'est le défaut constaté le 23/08.
        var fautivesPrototype = 0
        for largeur in stride(from: 320, through: 3840, by: 40) {
            for hauteur in stride(from: 240, through: 2160, by: 120) {
                let q = MoteurMiseEnPage.calculerCommeLePrototype(
                    profil: profil, largeur: largeur, hauteur: hauteur)
                let capaciteReelle = TextePython.tronquer(
                    Double(q.largeurUtile) / (Double(q.taille) * MesureurHistorique.facteur))
                if q.maxCaracteres > capaciteReelle { fautivesPrototype += 1 }
            }
        }
        r.verifier("le même balayage met bien le prototype en défaut "
                   + "(\(fautivesPrototype) résolutions)", fautivesPrototype > 0)
    }

    private static func tailleForceeReduiteSiNecessaire(_ r: Rapport) {
        // Même une taille imposée à la main reste soumise à la largeur : la
        // règle est « jamais le texte débordé », sans exception.
        let p = MoteurMiseEnPage.calculer(
            profil: profil, largeur: 1080, hauteur: 1920, tailleForcee: 200)
        r.egal("taille demandée conservée dans le rapport", p.tailleDemandee, 200)
        r.verifier("taille imposée mais réduite pour tenir", p.taille < 200)
        r.verifier("la cible est atteinte",
                   p.maxCaracteres >= MoteurMiseEnPage.longueurLigneCibleParDefaut)
    }
}
