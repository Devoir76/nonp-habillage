// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// GeometrieSousTitres.swift — où se posent les lignes et les bandeaux.
//
// Ce fichier ne dessine rien. Il calcule des rectangles et des lignes de base,
// et c'est délibéré : les critères d'acceptation du lot 3 portent tous sur des
// GRANDEURS — « aucune ligne ne déborde de la largeur utile », « la bande
// couvre exactement la largeur », « sa hauteur ne varie pas d'une réplique à
// l'autre ». Séparer le calcul du tracé permet de les vérifier par des nombres
// plutôt qu'en scrutant des pixels.
//
// Repère : celui de Core Graphics, origine en BAS à gauche, en pixels vidéo.

import Foundation
import CoreGraphics

/// Une ligne de texte, prête à tracer.
struct LignePosee: Equatable {
    let texte: String
    /// Origine de la ligne de base, extrémité gauche du texte.
    let baseline: CGPoint
    /// Largeur mesurée du texte.
    let largeur: Double
}

/// Tout ce qu'il faut pour tracer une réplique.
struct RepliquePosee {
    /// Les fonds à peindre sous le texte. Vide si le bandeau est inactif.
    /// En mode `pleine-largeur` il y en a exactement un ; en mode `ajuste`,
    /// un par ligne, chacun épousant sa ligne.
    let bandeaux: [CGRect]
    /// Les lignes de texte, de haut en bas.
    let lignes: [LignePosee]
    /// Largeur disponible pour le texte, dans laquelle aucune ligne ne déborde.
    let largeurUtile: Double
}

enum GeometrieSousTitres {

    /// Découpe le texte d'une réplique en lignes qui TIENNENT, par mesure
    /// exacte, puis les positionne.
    ///
    /// La césure est ici pilotée par la largeur mesurée, pas par un nombre de
    /// caractères : c'est la correction demandée par l'ADR §5. L'algorithme de
    /// remplissage, lui, reste celui du prototype — seul le critère change
    /// (voir `Segmenteur.envelopper(mots:tient:)`).
    static func decouper(
        texte: String, police: PoliceSousTitre, largeurUtile: Double
    ) -> [String] {
        Segmenteur.envelopper(mots: TextePython.decouperEnMots(texte)) { ligne, mot in
            police.largeur(de: ligne + " " + mot) <= largeurUtile
        }
    }

    /// De combien le fond déborde de chaque côté de sa ligne, en mode `ajuste`.
    ///
    /// Le prototype obtenait cet élargissement en collant `espaces_lateraux`
    /// espaces durs au texte lui-même. Ici c'est le rectangle qui s'élargit :
    /// la chaîne gravée n'est pas touchée (invariant nº1).
    static func debordDuFond(
        profil: ProfilHabillage, parametres: ParametresMiseEnPage, police: PoliceSousTitre
    ) -> Double {
        guard profil.bandeauActif, profil.bandeauMode == .ajuste else { return 0 }
        return Double(parametres.paddingBandeau)
            + Double(profil.bandeauEspacesLateraux) * police.largeurEspace
    }

    /// Largeur dans laquelle le texte doit tenir, selon le mode de bandeau.
    static func largeurUtile(
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage,
        largeurVideo: Int,
        police: PoliceSousTitre
    ) -> Double {
        switch profil.bandeauMode {
        case .ajuste:
            // Les marges latérales du profil, MOINS le débord du fond.
            //
            // Sans cette soustraction, une ligne remplissant la largeur utile
            // pousse son fond hors du cadre : mesuré à 2002 px de fond pour une
            // vidéo de 1920. Le prototype avait le défaut, masqué par le fait
            // qu'il élargissait le fond avec des espaces DANS le texte — donc
            // après le découpage, quand plus rien ne pouvait le rattraper.
            // Ici la contrainte est prise en compte AVANT la césure : le texte
            // se coupe un mot plus tôt, et le fond reste dans ses marges.
            return Double(parametres.largeurUtile)
                - 2 * debordDuFond(profil: profil, parametres: parametres, police: police)
        case .pleineLargeur:
            // La bande occupe toute la largeur ; c'est sa marge intérieure qui
            // borne le texte.
            let marge = Double(largeurVideo) * profil.bandeauMargeInterieureRatioLargeur
            return Double(largeurVideo) - 2 * marge
        }
    }

    /// Pose une réplique déjà découpée en lignes.
    ///
    /// - Parameter lignes: les lignes à afficher, de haut en bas.
    static func poser(
        lignes: [String],
        profil: ProfilHabillage,
        parametres: ParametresMiseEnPage,
        police: PoliceSousTitre,
        largeurVideo: Int,
        hauteurVideo: Int
    ) -> RepliquePosee {

        let largeurUtile = Self.largeurUtile(
            profil: profil, parametres: parametres,
            largeurVideo: largeurVideo, police: police)

        // Aucune ligne, donc rien à poser — et surtout aucun bandeau. Sans ce
        // garde-fou, `max(1, lignes.count)` plus bas réservait la hauteur d'une
        // ligne et le mode `pleine-largeur` peignait une bande vide en travers
        // de l'image : un fond n'a de sens que sous du texte, et il n'y a rien
        // à masquer quand il n'y en a pas.
        guard !lignes.isEmpty else {
            return RepliquePosee(bandeaux: [], lignes: [], largeurUtile: largeurUtile)
        }

        let hauteurLigne = police.hauteurLigne
        let padding = Double(parametres.paddingBandeau)
        let margeBasse = Double(parametres.margeBasse)

        // Nombre de lignes que le bandeau doit couvrir. `hauteur_fixe_lignes`
        // le fige : c'est ce qui empêche la bande de sauter entre une réplique
        // d'une ligne et une réplique de deux.
        let lignesAffichees = max(1, lignes.count)
        let lignesReservees = profil.bandeauHauteurFixeLignes > 0
            ? max(profil.bandeauHauteurFixeLignes, lignesAffichees)
            : lignesAffichees

        let hauteurBandeau = Double(lignesReservees) * hauteurLigne + 2 * padding
        let basBandeau = margeBasse

        // Le bloc de texte est centré verticalement dans la zone intérieure du
        // bandeau : la bande garde sa hauteur, et une réplique d'une ligne
        // reste au milieu plutôt que collée contre un bord.
        let hauteurTexte = Double(lignesAffichees) * hauteurLigne
        let hauteurInterieure = Double(lignesReservees) * hauteurLigne
        let sommetTexte = basBandeau + padding
            + (hauteurInterieure - hauteurTexte) / 2 + hauteurTexte

        var posees: [LignePosee] = []
        var bandeaux: [CGRect] = []

        for (index, texte) in lignes.enumerated() {
            let largeur = police.largeur(de: texte)
            // Sommet de la ligne, puis sa ligne de base : l'interligne se place
            // au-dessus de l'ascendante, convention de Core Text.
            let sommetLigne = sommetTexte - Double(index) * hauteurLigne
            let y = sommetLigne - police.interligne - police.ascendante
            let x = (Double(largeurVideo) - largeur) / 2

            if profil.bandeauMode == .ajuste {
                // Un fond par ligne, épousant sa longueur — comportement
                // historique. Les `espaces_lateraux` du profil élargissent le
                // fond ; le prototype les obtenait en collant des espaces durs
                // au texte, ce qui altérait la chaîne gravée. Ici c'est le
                // rectangle qui s'élargit : le texte, lui, n'est pas touché
                // (invariant nº1).
                let debord = Self.debordDuFond(
                    profil: profil, parametres: parametres, police: police)
                bandeaux.append(CGRect(
                    x: x - debord,
                    y: y - police.descendante - padding,
                    width: largeur + 2 * debord,
                    height: hauteurLigne + 2 * padding))
            }

            posees.append(LignePosee(
                texte: texte, baseline: CGPoint(x: x, y: y), largeur: largeur))
        }

        if profil.bandeauMode == .pleineLargeur {
            // Exactement la largeur de la vidéo, bord à bord : c'est ce qui
            // masque un sous-titre déjà incrusté dans la source.
            bandeaux = [CGRect(x: 0, y: basBandeau,
                               width: Double(largeurVideo), height: hauteurBandeau)]
        }

        return RepliquePosee(
            bandeaux: profil.bandeauActif ? bandeaux : [],
            lignes: posees,
            largeurUtile: largeurUtile)
    }
}
