// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// MoteurMiseEnPage.swift — des ratios du profil aux valeurs en pixels.
//
// Portage de `calculer_parametres()` de nonp_habille.py, AVEC la correction
// décidée à l'ADR §5. C'est le seul endroit du lot 2 où le comportement diverge
// volontairement du prototype, et la divergence est bornée : elle ne se
// manifeste que lorsque la largeur de la vidéo ne suffit pas.
//
// ── Le défaut corrigé ────────────────────────────────────────────────────────
//
// Le prototype dérive la taille de police de la seule HAUTEUR, puis impose un
// plancher de 16 caractères par ligne :
//
//     size     = max(12, round(h * ratio))
//     maxchars = max(16, int((w - 2*marge) / (size * 0.72)))
//
// En 16:9 cela tombe juste. En 9:16 la hauteur est la GRANDE dimension : la
// police explose (138 px sur du 1080×1920), la largeur utile n'accueille plus
// que 10 caractères, et le plancher en réclame 16. Les lignes débordent, libass
// les recoupe lui-même hors de toute logique de ponctuation, et l'on obtient
// les escaliers et les bandeaux inégaux constatés le 23/08.
//
// ── La règle qui remplace le plancher ────────────────────────────────────────
//
// La taille demandée par le profil devient un MAXIMUM. Une longueur de ligne
// cible, exprimée en caractères, la contraint : si la largeur ne permet pas de
// l'atteindre, c'est la TAILLE qui est réduite — jamais le texte qui déborde.
// Aucun plancher ne contredit plus la géométrie.
//
// Conséquence mesurée, et c'est bien le résultat attendu :
//
//   16:9 1080p  taille 78   largeur utile 1804  capacité 32  → inchangé
//   9:16 1080p  taille 138 → 44                 1016     32  → tient
//
// En 16:9, la capacité géométrique atteint déjà la cible : rien n'est réduit,
// et la parité avec le prototype est intacte. En 9:16, elle ne l'atteint pas :
// la taille descend à 44 px et la ligne tient. La divergence est là, et là
// seulement.
//
// ── Ce que ce fichier ne fait pas encore ─────────────────────────────────────
//
// La largeur du texte est estimée par le facteur « 0,72 × taille » du
// prototype. C'est une approximation grossière, et l'ADR §5 la condamne : la
// mesure exacte par Core Text arrive au lot 3. Elle entre par
// `MesureurLargeur`, sans toucher au reste du calcul — la mesure est un
// paramètre, pas une constante enfouie. La parité avec le prototype se mesure
// évidemment avec l'estimation historique, la seule que le Python connaisse.

import Foundation

/// Estime la largeur moyenne d'un caractère pour une taille de police donnée.
///
/// Le lot 3 en fournira une implémentation adossée à Core Text, qui mesurera le
/// texte réel dans la police réelle. D'ici là, l'estimation du prototype fait
/// foi — c'est aussi elle qui rend la parité mesurable.
protocol MesureurLargeur {
    func largeurMoyenneCaractere(taillePolice: Int) -> Double
}

/// L'estimation du prototype : 0,72 × la taille de police, toutes polices
/// confondues. Conservée pour la parité, condamnée par l'ADR §5.
struct MesureurHistorique: MesureurLargeur {
    static let facteur = 0.72
    func largeurMoyenneCaractere(taillePolice: Int) -> Double {
        Double(taillePolice) * Self.facteur
    }
}

/// Les valeurs en pixels dont le rendu a besoin, pour une vidéo donnée.
struct ParametresMiseEnPage: Equatable {
    /// Taille de police effectivement appliquée.
    var taille: Int
    /// Taille que le profil demandait, avant réduction éventuelle.
    var tailleDemandee: Int
    /// Vrai si la largeur a imposé de réduire la taille.
    var reduitePourTenir: Bool

    /// Diamètre du logo.
    var diametreLogo: Int
    /// Marge de coin du logo.
    var margeLogo: Int
    /// Marge basse des sous-titres.
    var margeBasse: Int
    /// Marge latérale des sous-titres, de chaque côté.
    var margeLaterale: Int
    /// Épaisseur du contour.
    var contour: Int
    /// Marge intérieure du bandeau.
    var paddingBandeau: Int

    /// Largeur disponible pour le texte, marges latérales déduites.
    var largeurUtile: Int
    /// Nombre de caractères qui tiennent sur une ligne à la taille appliquée.
    var maxCaracteres: Int
}

enum MoteurMiseEnPage {

    /// Longueur de ligne visée par défaut, en caractères.
    ///
    /// 32 est la valeur basse de l'usage courant du sous-titrage (32 à 42) et
    /// c'est aussi, exactement, ce que le prototype atteint en 16:9 1080p —
    /// d'où une parité gratuite sur le format de référence.
    static let longueurLigneCibleParDefaut = 32

    /// Bornes admissibles pour une longueur de ligne cible (ADR §5 : « 32 à 42
    /// caractères, jamais moins de 28 »). Les quatre tailles nommées de
    /// l'interface — Petite, Normale, Grande, Très grande — viseront ≈ 42, 37,
    /// 32 et 28 ; elles arrivent au lot 5 et se poseront dans cet intervalle.
    static let longueurLigneMinimale = 28
    static let longueurLigneMaximale = 42

    /// Calcule les paramètres de mise en page pour une vidéo de `largeur` ×
    /// `hauteur` pixels.
    ///
    /// - Parameters:
    ///   - tailleForcee: court-circuite le calcul de taille (équivalent de
    ///     `--size` côté prototype). Reste soumis à la contrainte de largeur.
    ///   - longueurLigneCible: bornée à [28, 42].
    static func calculer(
        profil: ProfilHabillage,
        largeur: Int,
        hauteur: Int,
        tailleForcee: Int? = nil,
        longueurLigneCible: Int = longueurLigneCibleParDefaut,
        mesureur: MesureurLargeur = MesureurHistorique()
    ) -> ParametresMiseEnPage {

        let h = Double(hauteur)
        let w = Double(largeur)

        // Marges et épaisseurs : formules et minima du prototype, inchangés.
        // Ces planchers-là ne contredisent aucune géométrie — ils empêchent
        // seulement une marge de 2 px sur une vidéo minuscule.
        let margeLaterale = max(10, TextePython.arrondi(w * profil.margeLateraleRatioLargeur))
        let largeurUtile = largeur - 2 * margeLaterale

        let cible = min(longueurLigneMaximale, max(longueurLigneMinimale, longueurLigneCible))

        let tailleDemandee = tailleForcee ?? max(12, TextePython.arrondi(h * profil.tailleRatio))

        // Capacité réelle d'une ligne à une taille donnée.
        func capacite(_ taille: Int) -> Int {
            let largeurCaractere = mesureur.largeurMoyenneCaractere(taillePolice: taille)
            guard largeurCaractere > 0 else { return largeurUtile }
            return TextePython.tronquer(Double(largeurUtile) / largeurCaractere)
        }

        var taille = tailleDemandee
        var reduite = false
        if capacite(tailleDemandee) < cible {
            // Cherche la plus grande taille dont la capacité atteint encore la
            // cible. La largeur d'un caractère étant à peu près proportionnelle
            // à la taille, une règle de trois donne un point de départ juste ;
            // les deux boucles qui suivent corrigent ce que l'approximation
            // laisse passer. Elles ne présument donc RIEN du mesureur, sinon
            // qu'une police plus petite ne prend pas plus de place — ce qui
            // vaudra encore quand Core Text remplacera l'estimation au lot 3.
            var t = max(1, TextePython.tronquer(
                Double(tailleDemandee) * Double(capacite(tailleDemandee)) / Double(cible)))
            while t > 1 && capacite(t) < cible { t -= 1 }
            while t < tailleDemandee && capacite(t + 1) >= cible { t += 1 }
            taille = max(1, min(tailleDemandee, t))
            reduite = taille < tailleDemandee
        }

        // Plancher à 1 caractère : une vidéo si étroite qu'aucun caractère n'y
        // tient est un cas dégénéré, pas une mise en page. Mettre 1 n'y fait
        // rien tenir — cela évite seulement un découpage en lignes vides.
        let maxCaracteres = max(1, capacite(taille))

        return ParametresMiseEnPage(
            taille: taille,
            tailleDemandee: tailleDemandee,
            reduitePourTenir: reduite,
            diametreLogo: max(24, TextePython.arrondi(h * profil.logoTailleRatio)),
            margeLogo: max(6, TextePython.arrondi(h * profil.logoMargeRatio)),
            margeBasse: max(10, TextePython.arrondi(h * profil.margeBasseRatio)),
            margeLaterale: margeLaterale,
            contour: max(1, TextePython.arrondi(h * profil.contourRatio)),
            paddingBandeau: max(4, TextePython.arrondi(h * profil.bandeauPaddingRatio)),
            largeurUtile: largeurUtile,
            maxCaracteres: maxCaracteres
        )
    }

    /// Le calcul du prototype, plancher de 16 caractères compris.
    ///
    /// Présent pour une seule raison : rendre la divergence de l'ADR §5
    /// MESURABLE plutôt que déclarée. Le harnais de vérification compare les
    /// deux sur les mêmes résolutions et montre où elles se séparent. Ce n'est
    /// pas un mode de repli — rien dans l'application ne l'appelle.
    static func calculerCommeLePrototype(
        profil: ProfilHabillage, largeur: Int, hauteur: Int, tailleForcee: Int? = nil
    ) -> (taille: Int, maxCaracteres: Int, largeurUtile: Int) {
        let h = Double(hauteur)
        let w = Double(largeur)
        let taille = tailleForcee ?? max(12, TextePython.arrondi(h * profil.tailleRatio))
        let margeLaterale = max(10, TextePython.arrondi(w * profil.margeLateraleRatioLargeur))
        let largeurUtile = largeur - 2 * margeLaterale
        let capacite = TextePython.tronquer(
            Double(largeurUtile) / (Double(taille) * MesureurHistorique.facteur))
        return (taille, max(16, capacite), largeurUtile)
    }
}
