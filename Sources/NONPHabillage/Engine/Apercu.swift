// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Apercu.swift — l'habillage peint sur une image fixe, sans encoder.
//
// C'est la pièce qui rend l'interface utilisable : « Régler une taille, une
// couleur ou une police à l'aveugle n'a pas de sens — il faut voir le résultat
// sur SA vidéo, immédiatement » (ADR §2). Chaque réglage repasse ici, et rien
// d'autre ne bouge : aucune vidéo n'est écrite, aucun encodeur n'est réveillé.
//
// L'aperçu emploie EXACTEMENT le même code que l'export — `MiseEnPageRendu`,
// `RenduSousTitres`, `RenduLogo`, `GeometrieLogo`. C'est la seule façon d'être
// sûr que ce qu'on voit est ce qu'on obtiendra.

import Foundation
import CoreGraphics

/// Ce que l'aperçu a produit, et ce qu'il a remarqué en chemin.
struct ResultatApercu {
    let image: CGImage
    let avertissements: [AvertissementZone]
    /// La mise en page retenue — taille de police, capacité de ligne. Affichée
    /// à titre indicatif : elle explique pourquoi le texte a la taille qu'il a.
    let miseEnPage: MiseEnPageRendu
    /// Le rectangle du logo, dans le repère de l'image. Sert au déplacement à
    /// la souris : c'est la zone que le curseur doit pouvoir saisir.
    let rectangleLogo: CGRect?
}

enum Apercu {

    /// Compose un aperçu.
    ///
    /// - Parameters:
    ///   - lignes: les lignes à afficher. Si `nil`, `texte` est découpé par la
    ///     mesure exacte, comme au rendu.
    static func composer(
        fond: CGImage,
        profil: ProfilHabillage,
        texte: String? = nil,
        lignes: [String]? = nil,
        avecSousTitres: Bool
    ) throws -> ResultatApercu {

        let largeur = fond.width
        let hauteur = fond.height

        let miseEnPage = try MiseEnPageRendu.calculer(
            profil: profil, largeurVideo: largeur, hauteurVideo: hauteur)

        // Le logo, si le profil en pose un.
        var calqueLogo: CGImage? = nil
        var rectangleLogo: CGRect? = nil
        if profil.logoActif, let fichier = profil.logoFichier {
            let source = try RenduLogo.charger(fichier)
            rectangleLogo = GeometrieLogo.rectangle(
                profil: profil, parametres: miseEnPage.parametres,
                tailleSource: CGSize(width: source.width, height: source.height),
                largeurVideo: largeur, hauteurVideo: hauteur)
            calqueLogo = try RenduLogo.calque(
                profil: profil, parametres: miseEnPage.parametres,
                largeur: largeur, hauteur: hauteur)
        }

        // Ce que l'écran montrera VRAIMENT à cet instant : la première
        // réplique issue de la resegmentation, d'au plus `lignesMax` lignes —
        // pas le bloc source entier étalé sur cinq lignes, qui n'apparaît
        // jamais au rendu. Sans cela, l'aperçu mentirait dès qu'un réglage
        // touche au nombre de lignes.
        let lignesAffichees = lignes ?? premiereReplique(
            texte: texte ?? "", profil: profil, miseEnPage: miseEnPage)

        let image = try RenduSousTitres.rendre(
            fond: fond, lignes: lignesAffichees,
            profil: profil, miseEnPage: miseEnPage, calqueLogo: calqueLogo)

        let avertissements = AvertissementsZone.examiner(
            profil: profil, parametres: miseEnPage.parametres,
            police: miseEnPage.police, rectangleLogo: rectangleLogo,
            avecSousTitres: avecSousTitres,
            largeurVideo: largeur, hauteurVideo: hauteur)

        return ResultatApercu(
            image: image, avertissements: avertissements,
            miseEnPage: miseEnPage, rectangleLogo: rectangleLogo)
    }

    /// Les lignes réellement affichées pour un texte donné.
    static func premiereReplique(
        texte: String, profil: ProfilHabillage, miseEnPage: MiseEnPageRendu
    ) -> [String] {
        let cue = Cue(debutMs: 0, finMs: 1000, texte: texte)
        return miseEnPage.segmenter([cue], lignesMax: profil.lignesMax)
            .first?.lignes ?? []
    }

    /// Le texte à montrer quand aucun fichier de sous-titres n'est chargé.
    ///
    /// L'aperçu affiche du texte EN PERMANENCE (ADR §2) : sans cela, on
    /// règlerait la police et les couleurs sur une image vide.
    ///
    /// « Calibrée sur la longueur de ligne cible » se mesure, plutôt que de
    /// s'estimer au nombre de caractères : on retient la phrase la plus longue
    /// qui remplit encore les lignes disponibles sans les déborder. Une phrase
    /// trop courte ne montrerait pas la césure ; une trop longue serait coupée
    /// à l'affichage et donnerait une fausse idée du réglage.
    static func texteDeReference(
        profil: ProfilHabillage, miseEnPage: MiseEnPageRendu? = nil
    ) -> String {
        guard let miseEnPage else {
            return PhrasesDeReference.phrase(
                pourLongueurLigne: profil.longueurLigneCible, lignes: profil.lignesMax)
        }
        return PhrasesDeReference.laPlusLongueTenantEn(
            profil.lignesMax, mesure: { miseEnPage.decouper($0).count })
    }

    /// Les répliques d'un fichier, la **plus longue en premier**.
    ///
    /// C'est le pire cas, et l'ADR le veut ainsi : « Si elle passe, tout passe. »
    /// Les autres restent parcourables aux flèches.
    static func repliquesParPireCas(_ cues: [Cue]) -> [Cue] {
        cues.sorted {
            TextePython.longueur($0.texte) > TextePython.longueur($1.texte)
        }
    }
}
