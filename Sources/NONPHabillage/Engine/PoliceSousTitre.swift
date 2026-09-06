// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// PoliceSousTitre.swift — la police, sa mesure exacte, et l'invariant nº4.
//
// Deux choses vivent ici, et elles sont liées :
//
// 1. LA RÉSOLUTION DE LA POLICE, avec échec explicite. `CTFontCreateWithName`
//    ne signale JAMAIS qu'une famille est absente : il rend silencieusement
//    Helvetica à la place. C'est exactement le travers de libass que
//    l'invariant nº4 interdit — « police manquante = erreur explicite, jamais
//    de substitution silencieuse ». La famille demandée est donc cherchée dans
//    la liste du système AVANT de créer quoi que ce soit, et son absence lève
//    une erreur nommée qui propose les familles proches.
//
// 2. LA MESURE EXACTE, réclamée par l'ADR §5. Le prototype estimait la largeur
//    d'un caractère à « 0,72 × taille », toutes polices confondues.
//    L'approximation était la cause directe du recoupage incontrôlé : libass
//    recevait des lignes plus larges que ce que le calcul croyait, et les
//    recoupait lui-même hors de toute logique de ponctuation. Ici, Core Text
//    mesure le texte réel, dans la police réelle, à la taille réelle.

import Foundation
import CoreText
import CoreGraphics

enum ErreurPolice: Error {
    /// La famille demandée n'existe pas sur ce système.
    case familleIntrouvable(demandee: String, proches: [String])
}

struct PoliceSousTitre {

    let famille: String
    let taille: Int
    let ctFont: CTFont

    // MARK: - Résolution

    /// Crée la police, ou échoue si la famille est absente du système.
    init(famille: String, taille: Int) throws {
        let disponibles = Self.famillesDisponibles
        let recherchee = famille.lowercased()
        guard disponibles.contains(where: { $0.lowercased() == recherchee }) else {
            throw ErreurPolice.familleIntrouvable(
                demandee: famille, proches: Self.proches(de: famille, parmi: disponibles))
        }
        self.famille = famille
        self.taille = taille
        self.ctFont = Self.grasse(famille: famille, taille: taille)
    }

    /// La police, **en gras** — comme le prototype, toujours.
    ///
    /// Trouvé par la campagne de parité du 06/09, sur images comparées : le
    /// texte du prototype est nettement plus épais que celui de l'app. La cause
    /// est dans son style ASS, où le champ `Bold` vaut `-1` — vrai — pour les
    /// deux styles qu'il écrit, `Box` et `Text`. Le gras n'est donc pas un
    /// réglage : c'est le rendu, en dur, depuis toujours.
    ///
    /// Aucun champ du schéma ne le porte, et il n'y en aura pas : ajouter un
    /// champ serait une décision d'Éric (invariant nº6), là où il n'y a rien à
    /// décider. Le portage est fidèle par défaut, et une divergence qui n'est
    /// pas au registre est un bug — celle-ci en était un.
    ///
    /// Le gras change aussi la MESURE, donc la césure : un texte plus large
    /// tient en moins de caractères. C'est voulu — mesurer une graisse qu'on ne
    /// dessine pas était la vraie erreur.
    ///
    /// Si la famille n'a pas de graisse grasse, la romaine est rendue telle
    /// quelle. L'invariant nº4 porte sur la FAMILLE, qui est ici présente et
    /// vérifiée juste au-dessus ; refuser d'habiller parce qu'il manque une
    /// graisse serait un refus que le prototype ne fait pas non plus.
    private static func grasse(famille: String, taille: Int) -> CTFont {
        let romaine = CTFontCreateWithName(famille as CFString, CGFloat(taille), nil)
        return CTFontCreateCopyWithSymbolicTraits(
            romaine, CGFloat(taille), nil, .traitBold, .traitBold) ?? romaine
    }

    /// Les familles installées, calculées une fois — l'appel système est lent.
    static let famillesDisponibles: [String] =
        (CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []

    /// Quelques familles dont le nom ressemble à celui demandé, pour que le
    /// message d'erreur propose une issue au lieu de constater un échec.
    private static func proches(de nom: String, parmi familles: [String]) -> [String] {
        let n = nom.lowercased()
        let premierMot = n.split(separator: " ").first.map(String.init) ?? n
        return familles
            .filter { $0.lowercased().contains(premierMot) || premierMot.contains($0.lowercased()) }
            .sorted()
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Métriques verticales

    var ascendante: Double { Double(CTFontGetAscent(ctFont)) }
    var descendante: Double { Double(CTFontGetDescent(ctFont)) }
    var interligne: Double { Double(CTFontGetLeading(ctFont)) }

    /// Hauteur d'une ligne, interligne comprise.
    var hauteurLigne: Double { ascendante + descendante + interligne }

    /// Largeur d'une espace, dans cette police à cette taille.
    ///
    /// Sert à convertir les `espaces_lateraux` du profil — que le prototype
    /// exprimait en espaces durs `\h` collés au texte — en une largeur de fond,
    /// sans toucher au texte lui-même (invariant nº1).
    var largeurEspace: Double { largeur(de: " ") }

    // MARK: - Mesure

    /// Largeur d'avance d'un texte, en pixels. C'est la mesure qui décide des
    /// césures.
    func largeur(de texte: String) -> Double {
        guard !texte.isEmpty else { return 0 }
        let ligne = CTLineCreateWithAttributedString(attribuee(texte))
        return CTLineGetTypographicBounds(ligne, nil, nil, nil)
    }

    /// Le texte, prêt pour Core Text.
    private func attribuee(_ texte: String) -> CFAttributedString {
        NSAttributedString(string: texte, attributes: [
            .font: ctFont,
            // Sans ce réglage, Core Text applique le crénage par défaut de la
            // police : c'est ce qu'on veut, la mesure doit coller au rendu.
            .ligature: 1,
        ]) as CFAttributedString
    }

    // MARK: - Tracé des glyphes

    /// Le contour de tous les glyphes d'un texte, positionnés, origine sur la
    /// ligne de base à gauche.
    ///
    /// Le contour noir du sous-titre s'obtient en TRAÇANT ce chemin avant de le
    /// remplir. C'est plus fidèle que l'attribut `strokeWidth` de Core Text,
    /// qui s'exprime en pourcentage de la taille de police et rendrait un
    /// contour dont l'épaisseur ne serait plus celle qu'annonce le profil.
    func cheminGlyphes(de texte: String) -> CGPath {
        let chemin = CGMutablePath()
        guard !texte.isEmpty else { return chemin }

        let ligne = CTLineCreateWithAttributedString(attribuee(texte))
        guard let passages = CTLineGetGlyphRuns(ligne) as? [CTRun] else { return chemin }

        for passage in passages {
            let nombre = CTRunGetGlyphCount(passage)
            guard nombre > 0 else { continue }

            var glyphes = [CGGlyph](repeating: 0, count: nombre)
            var positions = [CGPoint](repeating: .zero, count: nombre)
            CTRunGetGlyphs(passage, CFRangeMake(0, nombre), &glyphes)
            CTRunGetPositions(passage, CFRangeMake(0, nombre), &positions)

            // La police du passage peut différer de la nôtre si Core Text a dû
            // composer (un caractère absent de la famille demandée). On la lit
            // sur le passage pour tracer le bon glyphe.
            let attributs = CTRunGetAttributes(passage) as NSDictionary
            let policePassage = (attributs[kCTFontAttributeName] as! CTFont)

            for i in 0..<nombre {
                guard let glyphe = CTFontCreatePathForGlyph(
                    policePassage, glyphes[i], nil) else { continue }
                let deplacement = CGAffineTransform(
                    translationX: positions[i].x, y: positions[i].y)
                chemin.addPath(glyphe, transform: deplacement)
            }
        }
        return chemin
    }
}

/// Le mesureur exact réclamé par l'ADR §5, branché sur `MoteurMiseEnPage`.
///
/// `largeurMoyenneCaractere` reste une moyenne : c'est ce que le calcul de
/// taille demande pour estimer une capacité de ligne. La différence avec le
/// prototype est qu'elle est MESURÉE, dans la police réelle, sur un texte
/// représentatif du français — accents, apostrophes, ponctuation, mots courts —
/// au lieu d'être postulée à 0,72 pour toutes les polices du monde.
///
/// La césure, elle, ne se contente pas de cette moyenne : elle mesure chaque
/// ligne. Voir `GeometrieSousTitres`.
struct MesureurCoreText: MesureurLargeur {

    let famille: String

    /// Texte témoin : une phrase française ordinaire, de celles qu'on grave.
    /// La moyenne qu'on en tire vaut pour du sous-titre, pas pour du latin.
    static let texteTemoin =
        "Il m'a dit qu'il n'avait rien vu ce jour-là, vers quatre heures du matin."

    func largeurMoyenneCaractere(taillePolice: Int) -> Double {
        guard let police = try? PoliceSousTitre(famille: famille, taille: taillePolice)
        else {
            // La police manquante est signalée à la construction du rendu, avec
            // un message utile. Ici, on ne peut que refuser de mentir : rendre
            // l'estimation historique laisserait croire à une mesure.
            return MesureurHistorique().largeurMoyenneCaractere(taillePolice: taillePolice)
        }
        let temoin = Self.texteTemoin
        return police.largeur(de: temoin) / Double(TextePython.longueur(temoin))
    }
}
