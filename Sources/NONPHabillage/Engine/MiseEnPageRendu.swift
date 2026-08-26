// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// MiseEnPageRendu.swift — la mise en page telle que le RENDU l'applique.
//
// `MoteurMiseEnPage.calculer` (lot 2) ignore deux choses que le rendu, lui, ne
// peut pas ignorer :
//
// 1. LE MODE DE BANDEAU CHANGE LA LARGEUR DISPONIBLE. En `pleine-largeur`,
//    c'est la marge intérieure de la bande qui borne le texte, pas les marges
//    latérales du profil. En `ajuste`, le fond déborde de sa ligne, et ce
//    débord doit être déduit sous peine de sortir du cadre (divergence D-5).
//
// 2. LA LONGUEUR DE LIGNE CIBLE EST UNE CIBLE, PAS SEULEMENT UN PLANCHER.
//    L'ADR §5 la donne « conforme à l'usage du sous-titrage (32 à 42
//    caractères) ». Or la mesure exacte de Core Text est bien plus généreuse
//    que l'estimation à 0,72 : sur Arial 78 px, la largeur utile d'une vidéo
//    16:9 accueille 56 caractères. Laisser les lignes se remplir jusque-là
//    donnerait des lignes deux fois plus denses que celles du prototype — et
//    le préréglage NONP est censé ne rien changer à l'existant.
//
// Ces deux corrections se tiennent, et elles bouclent : le débord du fond
// dépend de la largeur d'une espace, donc de la taille, qu'on est justement en
// train de calculer. D'où l'itération ci-dessous, qui converge en deux ou trois
// tours et ne présume rien de la police.
//
// Le calcul du lot 2 reste intact et sert toujours la parité : c'est le seul
// que le Python sache reproduire.

import Foundation

struct MiseEnPageRendu {

    /// Les marges, épaisseurs et tailles, calculées pour la taille retenue.
    let parametres: ParametresMiseEnPage
    /// La police résolue, à la taille retenue.
    let police: PoliceSousTitre
    /// Ce que le mode de bandeau laisse réellement au texte.
    let largeurDisponible: Double
    /// La largeur dans laquelle les lignes sont découpées. Identique à
    /// `largeurDisponible` : c'est la borne DURE, celle qui garantit qu'aucune
    /// ligne ne déborde.
    var largeurDecoupe: Double { largeurDisponible }
    /// Longueur de ligne visée, en caractères.
    let longueurLigneCible: Int
    /// Capacité effective d'une ligne, en caractères moyens.
    let capacite: Int
    /// Largeur moyenne d'un caractère à la taille retenue.
    let largeurMoyenneCaractere: Double

    /// La taille que le PROFIL demandait, avant toute réduction.
    ///
    /// À ne pas confondre avec `parametres.tailleDemandee`, qui ne vaut rien
    /// ici : le calcul ci-dessous appelle `MoteurMiseEnPage` avec `tailleForcee`,
    /// si bien que le moteur voit la taille déjà retenue comme si le profil
    /// l'avait demandée. Ses champs `tailleDemandee` et `reduitePourTenir`
    /// sortent donc toujours égaux et faux. C'est ici que la vérité se trouve.
    let tailleDemandeeParLeProfil: Int
    /// Vrai si la largeur a imposé de réduire la taille demandée par le profil.
    /// C'est le filet de sécurité de l'ADR §5, et le seul endroit qui sache
    /// s'il a servi.
    var reduitePourTenir: Bool { parametres.taille < tailleDemandeeParLeProfil }

    /// Largeur réellement occupée par une ligne pleine.
    ///
    /// C'est la PLUS SERRÉE des deux règles de césure : la largeur disponible,
    /// ou la longueur de ligne cible traduite en pixels. Afficher la seule
    /// largeur disponible tromperait — sur une 16:9, elle vaut 1804 px quand le
    /// texte n'en occupe que 1031.
    var largeurColonneTexte: Double {
        min(largeurDisponible, Double(longueurLigneCible) * largeurMoyenneCaractere)
    }

    /// Vrai quand la largeur disponible ne borne RIEN : la longueur de ligne
    /// cible coupe avant elle.
    ///
    /// Sur une vidéo 16:9, avec une cible de 32 caractères, la colonne de texte
    /// ne fait déjà qu'un peu plus de la moitié de l'image : la marge intérieure
    /// du bandeau doit dépasser 24 % pour changer quoi que ce soit. Mesuré, et
    /// dit à l'utilisateur plutôt que laissé à deviner.
    var margeInterieureSansEffet: Bool { capacite > longueurLigneCible }

    /// Calcule la mise en page de rendu pour une vidéo donnée.
    ///
    /// - Throws: `ErreurPolice.familleIntrouvable` si la police du profil est
    ///   absente du système (invariant nº4).
    static func calculer(
        profil: ProfilHabillage,
        largeurVideo: Int,
        hauteurVideo: Int,
        tailleForcee: Int? = nil,
        longueurLigneCible: Int? = nil
    ) throws -> MiseEnPageRendu {

        // Sans consigne explicite, c'est le profil qui commande — c'est lui que
        // règle la taille nommée choisie dans l'interface.
        let demandee = longueurLigneCible ?? profil.longueurLigneCible
        let cible = min(MoteurMiseEnPage.longueurLigneMaximale,
                        max(MoteurMiseEnPage.longueurLigneMinimale, demandee))
        let mesureur = MesureurCoreText(famille: profil.police)

        // Point de départ : la taille demandée par le profil, qui est un
        // MAXIMUM et jamais une consigne (ADR §5).
        let tailleDemandee = tailleForcee
            ?? max(12, TextePython.arrondi(Double(hauteurVideo) * profil.tailleRatio))

        /// Ce que le mode de bandeau laisse au texte, à une taille donnée.
        func disponible(_ taille: Int) throws -> (Double, ParametresMiseEnPage, PoliceSousTitre) {
            let p = MoteurMiseEnPage.calculer(
                profil: profil, largeur: largeurVideo, hauteur: hauteurVideo,
                tailleForcee: taille, longueurLigneCible: cible, mesureur: mesureur)
            let police = try PoliceSousTitre(famille: profil.police, taille: taille)
            let largeur = GeometrieSousTitres.largeurUtile(
                profil: profil, parametres: p, largeurVideo: largeurVideo, police: police)
            return (largeur, p, police)
        }

        func capacite(_ largeur: Double, _ taille: Int) -> Int {
            let moyenne = mesureur.largeurMoyenneCaractere(taillePolice: taille)
            guard moyenne > 0 else { return Int(largeur) }
            return TextePython.tronquer(largeur / moyenne)
        }

        // Réduire tant que la cible n'est pas atteinte. Une taille plus petite
        // ne prend jamais plus de place : la suite est monotone, elle converge.
        var taille = max(1, tailleDemandee)
        for _ in 0..<40 {
            let (largeur, _, _) = try disponible(taille)
            let c = capacite(largeur, taille)
            if c >= cible || taille <= 1 { break }
            // Règle de trois — la largeur d'un caractère est à peu près
            // proportionnelle à la taille — puis descente d'un cran si
            // l'approximation n'a pas suffi à progresser.
            let estimee = TextePython.tronquer(
                Double(taille) * Double(c) / Double(cible))
            taille = max(1, estimee >= taille ? taille - 1 : estimee)
        }
        // Puis remonter tant que la cible reste atteinte : on veut la PLUS
        // GRANDE taille qui tienne, pas la première trouvée.
        while taille < tailleDemandee {
            let (largeur, _, _) = try disponible(taille + 1)
            if capacite(largeur, taille + 1) < cible { break }
            taille += 1
        }

        let (largeurDisponible, parametres, police) = try disponible(taille)

        return MiseEnPageRendu(
            parametres: parametres,
            police: police,
            largeurDisponible: largeurDisponible,
            longueurLigneCible: cible,
            capacite: capacite(largeurDisponible, taille),
            largeurMoyenneCaractere: mesureur.largeurMoyenneCaractere(taillePolice: taille),
            tailleDemandeeParLeProfil: tailleDemandee)
    }

    /// Le critère de tenue de ligne du rendu — DEUX conditions, et il faut les
    /// deux :
    ///
    /// 1. **la longueur de ligne cible, en caractères.** C'est le rythme de
    ///    lecture, et c'est exactement la règle du prototype. La conserver,
    ///    c'est garder la césure aux mêmes endroits sur du texte ordinaire —
    ///    le préréglage NONP ne doit rien changer à l'existant.
    /// 2. **la largeur mesurée.** C'est le filet de sécurité, et c'est là que
    ///    Core Text apporte ce que le prototype n'avait pas : quand 32
    ///    caractères ne TIENNENT pas — une réplique en capitales, une police
    ///    large —, la ligne se coupe plus tôt au lieu de déborder et de se
    ///    faire recouper par libass hors de toute ponctuation.
    ///
    /// La première borne seule reproduirait le défaut du 23/08 ; la seconde
    /// seule laisserait filer les lignes à 56 caractères sur une vidéo large,
    /// soit deux fois la densité du rendu actuel. Ni l'une ni l'autre ne
    /// suffit.
    func tient(_ ligne: String, _ mot: String) -> Bool {
        let candidate = ligne + " " + mot
        return TextePython.longueur(candidate) <= longueurLigneCible
            && police.largeur(de: candidate) <= largeurDisponible
    }

    /// Découpe un texte en lignes qui tiennent.
    func decouper(_ texte: String) -> [String] {
        Segmenteur.envelopper(mots: TextePython.decouperEnMots(texte), tient: tient)
    }

    /// Resegmente des répliques comme le fera le rendu : mêmes règles que le
    /// prototype, avec la mesure exacte en filet.
    func segmenter(_ cues: [Cue], lignesMax: Int) -> [CueGravee] {
        Segmenteur.segmenter(cues, lignesMax: lignesMax, tient: tient)
    }
}
