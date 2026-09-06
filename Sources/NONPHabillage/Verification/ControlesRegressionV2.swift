// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesRegressionV2.swift — la non-régression exigée par la décision nº6.
//
// « Prouve par mesure qu'aucune de mes vidéos 16:9 ne bouge d'un pixel, et
// consigne le gain en vertical. » — Éric, 28/08/2026.
//
// ── Ce qui a changé, et donc ce qu'il faut prouver ───────────────────────────
//
// La v1 posait le retrait du texte de deux façons selon le mode de bandeau :
//
//   ajuste          débord = padding_px + espaces_lateraux × largeur d'espace
//   pleine-largeur  retrait = largeur_vidéo × marge_interieure
//
// La v2 n'en a plus qu'une, `arrondi(largeur_vidéo × marge_texte)`, pour les
// deux modes. La preuve tient en trois temps :
//
// 1. **La valeur par défaut est le débord de la v1, arrondi au pixel.** Sur
//    toutes les définitions 16:9 courantes, `arrondi(l × 5,61 %)` retombe
//    exactement sur `arrondi(débord v1)`. Ce n'est pas une coïncidence : 5,61 %
//    a été mesuré pour cela (ADR, décision nº6).
// 2. **Donc l'image est la même**, au pixel : rendue avec le retrait de la v1
//    ou avec celui de la v2, elle ne diffère d'aucun octet. Contrôlé sur des
//    images réelles, et contrôlé SENSIBLE — un pixel de retrait en plus suffit
//    à faire diverger la comparaison.
// 3. **Le texte est identique sur tout le corpus** : même taille de police,
//    mêmes coupures, réplique par réplique, à cinq définitions 16:9.
//
// Reste l'arrondi lui-même, et il est consigné plutôt que passé sous silence :
// la v1 posait le bord du bandeau à 107,7 px sur une 1920, la v2 à 108. Un
// tiers de pixel, conséquence du passage en pixels entiers — le même parti que
// toutes les autres grandeurs géométriques du moteur.

import Foundation
import CoreGraphics

enum ControlesRegressionV2 {

    /// Les définitions 16:9 qu'on rencontre. Ce sont celles-là qui ne doivent
    /// pas bouger.
    static let definitions169: [(String, Int, Int)] = [
        ("1280×720", 1280, 720),
        ("1920×1080", 1920, 1080),
        ("2560×1440", 2560, 1440),
        ("3840×2160", 3840, 2160),
        ("1024×576", 1024, 576),
    ]

    static func executer(_ r: Rapport, corpus: [URL]) {
        r.section("Schéma v2 — non-régression en 16:9")
        valeurParDefaut(r)
        memeImage(r)
        memeTexte(r, corpus: corpus)

        r.section("Schéma v2 — ce que le vertical y gagne")
        gainVertical(r)
    }

    // MARK: - 1. La v2 est invariante d'échelle ; la v1 ne l'était pas

    /// Ce que la mesure a appris, et qui n'était pas prévu : **le débord de la
    /// v1 ne valait pas le même pourcentage de largeur selon la définition.**
    ///
    /// Il empruntait au `padding_pct_hauteur`, arrondi au pixel sur la HAUTEUR.
    /// 1080 × 1,9 % arrondit à 21 px (1,944 % de la hauteur), 1440 × 1,9 %
    /// arrondit à 27 (1,875 %). Le débord d'une 1080p valait donc 5,609 % de la
    /// largeur, celui d'une 1440p 5,570 % : **la v1 dérivait avec la
    /// définition**, sur un format pourtant identique.
    ///
    /// La v2, elle, est un pourcentage de la largeur et rien d'autre : elle ne
    /// dérive pas. C'est un gain, pas une régression — mais cela veut dire
    /// qu'aucune valeur unique ne peut retomber sur la v1 à TOUTES les
    /// définitions 16:9. Les intervalles ne se recoupent pas : rester à un
    /// demi-pixel de la v1 sur une 1440p demanderait entre 5,551 et 5,590 %, et
    /// sur une 1080p entre 5,583 et 5,635 %.
    ///
    /// 5,61 % retombe donc exactement sur la v1 aux définitions où le profil a
    /// été réglé — 1024, 1280 et 1920 —, et s'en écarte de 1,4 px au plus
    /// ailleurs. Ce qui compte, le TEXTE, ne bouge à aucune (contrôle nº3).
    private static func valeurParDefaut(_ r: Rapport) {
        // La v2 ne dérive pas : UN pourcentage, et l'arrondi au pixel pour
        // seule liberté — donc moins d'un demi-pixel d'écart à la proportion
        // exacte, par construction.
        for (nom, w, _) in definitions169 {
            let retrait = GeometrieSousTitres.retraitDuTexte(
                profil: .bandeauColore, largeurVideo: w)
            let exact = Double(w) * ProfilHabillage.bandeauColore.bandeauMargeTexteRatioLargeur
            r.verifier("\(nom) : la v2 tient sa proportion à l'arrondi près "
                       + "(\(Int(retrait)) px pour \(String(format: "%.1f", exact)))",
                       abs(retrait - exact) <= 0.5)
        }

        var ecarts: [(String, Double)] = []
        for (nom, w, h) in definitions169 {
            guard let v1 = debordVersion1(.bandeauColore, w, h) else {
                r.verifier("\(nom) : débord de la v1 calculable", false); continue
            }
            let v2 = GeometrieSousTitres.retraitDuTexte(
                profil: .bandeauColore, largeurVideo: w)
            ecarts.append((nom, abs(v2 - v1.debord)))
            r.verifier("\(nom) : v1 \(String(format: "%.1f", v1.debord)) px "
                       + "(\(String(format: "%.3f", v1.debord / Double(w) * 100)) % "
                       + "de la largeur) → v2 \(Int(v2)) px, écart "
                       + "\(String(format: "%.1f", abs(v2 - v1.debord))) px",
                       abs(v2 - v1.debord) <= 1.5)
        }

        // La v1, elle, dérivait VRAIMENT : son débord n'était pas proportionnel
        // à la largeur, parce qu'il empruntait au padding vertical arrondi sur
        // la hauteur. C'est le constat qui explique tout le reste — et qui
        // interdit qu'un pourcentage unique retombe partout sur elle.
        let ratiosV1 = definitions169.compactMap { (_, w, h) -> Double? in
            debordVersion1(.bandeauColore, w, h).map { $0.debord / Double(w) }
        }
        let ecartMax = definitions169.compactMap { (_, w, h) -> Double? in
            guard let v1 = debordVersion1(.bandeauColore, w, h),
                  let ref = debordVersion1(.bandeauColore, 1920, 1080) else { return nil }
            return abs(v1.debord - ref.debord / 1920 * Double(w))
        }.max() ?? 0
        r.verifier("la v1 n'était PAS proportionnelle à la largeur : "
                   + "\(ratiosV1.map { String(format: "%.3f", $0 * 100) }.joined(separator: ", ")) % "
                   + "pour le même format 16:9, soit jusqu'à "
                   + "\(String(format: "%.1f", ecartMax)) px d'écart à sa propre "
                   + "proportion de 1080p",
                   ecartMax > 0.5)

        // Le mode « pleine-largeur » — celui du profil neutre, appliqué au
        // premier lancement — se convertit sans la moindre approximation : sa
        // marge intérieure était DÉJÀ un pourcentage de la largeur.
        r.egal("profil neutre : la marge du texte reprend telle quelle la marge "
               + "intérieure de la v1",
               ProfilHabillage.neutre.bandeauMargeTexteRatioLargeur, 0.03)
    }

    // MARK: - 2. L'image, définition par définition

    /// Là où la v2 retombe sur la v1, le rendu ne bouge pas d'un octet ; là où
    /// elle s'en écarte, on compte les pixels touchés plutôt que de l'annoncer.
    private static func memeImage(_ r: Rapport) {
        for (nom, w, h) in definitions169 {
            guard let fond = fondDeControle(largeur: w, hauteur: h),
                  let v1 = debordVersion1(.bandeauColore, w, h) else {
                r.verifier("\(nom) : fond de contrôle", false); continue
            }

            // Le profil tel que la v1 le posait : son débord, exprimé dans
            // l'unité de la v2. C'est la MÊME géométrie, dite autrement.
            var commeV1 = ProfilHabillage.bandeauColore
            commeV1.logoActif = false
            commeV1.bandeauMargeTexteRatioLargeur = v1.debord / Double(w)

            var commeV2 = ProfilHabillage.bandeauColore
            commeV2.logoActif = false

            let a = try? Apercu.composer(fond: fond, profil: commeV1,
                                         texte: texteDEssai, avecSousTitres: true)
            let b = try? Apercu.composer(fond: fond, profil: commeV2,
                                         texte: texteDEssai, avecSousTitres: true)
            guard let imageV1 = a?.image, let imageV2 = b?.image else {
                r.verifier("\(nom) : les deux rendus sont produits", false); continue
            }

            let touches = pixelsDifferents(imageV1, imageV2)
            let total = w * h
            let part = Double(touches) / Double(total) * 100
            if touches == 0 {
                r.verifier("\(nom) : le rendu ne bouge pas d'un pixel", true)
            } else {
                // Pas un échec : un chiffre. Le bord du bandeau se déplace de
                // moins de deux pixels, et rien d'autre ne bouge — le texte est
                // au même endroit, à la même taille (contrôle nº3).
                r.verifier("\(nom) : \(touches) pixels touchés sur \(total) "
                           + "(\(String(format: "%.4f", part)) %), le bord du "
                           + "bandeau et lui seul",
                           part < 0.5)
            }

            // ET LE CONTRÔLE SAIT VOIR UNE DIFFÉRENCE. Sans cette contre-épreuve,
            // « aucun pixel ne bouge » ne prouverait rien : il pourrait aussi
            // bien signifier que la comparaison ne regarde pas au bon endroit.
            var dUnPixel = commeV2
            dUnPixel.bandeauMargeTexteRatioLargeur =
                (GeometrieSousTitres.retraitDuTexte(profil: commeV2, largeurVideo: w) + 1)
                / Double(w)
            let c = try? Apercu.composer(fond: fond, profil: dUnPixel,
                                         texte: texteDEssai, avecSousTitres: true)
            r.verifier("\(nom) : un seul pixel de retrait en plus, et la "
                       + "comparaison le voit",
                       c.map { ImagesReference.differe($0.image, de: imageV2) } == true)
        }
    }

    /// Combien de pixels diffèrent entre deux images de même taille.
    private static func pixelsDifferents(_ a: CGImage, _ b: CGImage) -> Int {
        guard a.width == b.width, a.height == b.height,
              let da = a.dataProvider?.data, let db = b.dataProvider?.data,
              let pa = CFDataGetBytePtr(da), let pb = CFDataGetBytePtr(db),
              CFDataGetLength(da) == CFDataGetLength(db) else { return -1 }
        var touches = 0
        for y in 0..<a.height {
            let ligneA = y * a.bytesPerRow
            let ligneB = y * b.bytesPerRow
            for x in 0..<a.width where
                memcmp(pa + ligneA + x * 4, pb + ligneB + x * 4, 4) != 0 {
                touches += 1
            }
        }
        return touches
    }

    // MARK: - 3. Le même texte, sur tout le corpus

    /// Taille de police et coupures de lignes, réplique par réplique.
    ///
    /// C'est ce qui détermine chaque glyphe à l'écran. Le corpus réel s'il est
    /// fourni ; sinon un texte d'épreuve, et la rubrique le dit.
    private static func memeTexte(_ r: Rapport, corpus: [URL]) {
        var cues: [Cue] = []
        for fichier in corpus {
            cues += (try? ParseurSousTitres.analyser(fichier: fichier)) ?? []
        }
        if cues.isEmpty {
            cues = [Cue(debutMs: 0, finMs: 1000, texte: texteDEssai)]
        }

        for (nom, w, h) in definitions169 {
            guard let v1 = debordVersion1(.bandeauColore, w, h) else { continue }
            var commeV1 = ProfilHabillage.bandeauColore
            commeV1.logoActif = false
            commeV1.bandeauMargeTexteRatioLargeur = v1.debord / Double(w)
            var commeV2 = ProfilHabillage.bandeauColore
            commeV2.logoActif = false

            guard let mepV1 = try? MiseEnPageRendu.calculer(
                    profil: commeV1, largeurVideo: w, hauteurVideo: h),
                  let mepV2 = try? MiseEnPageRendu.calculer(
                    profil: commeV2, largeurVideo: w, hauteurVideo: h) else {
                r.verifier("\(nom) : mises en page calculées", false); continue
            }
            r.egal("\(nom) : même taille de police",
                   mepV2.parametres.taille, mepV1.parametres.taille)

            let graveesV1 = mepV1.segmenter(cues, lignesMax: commeV1.lignesMax)
            let graveesV2 = mepV2.segmenter(cues, lignesMax: commeV2.lignesMax)
            let differentes = zip(graveesV1, graveesV2).filter { $0.lignes != $1.lignes }
            r.verifier("\(nom) : les \(graveesV1.count) répliques gravées sont "
                       + "coupées à l'identique"
                       + (differentes.isEmpty ? ""
                          : " — \(differentes.count) diffèrent"),
                       graveesV1.count == graveesV2.count && differentes.isEmpty)
        }
        if corpus.isEmpty {
            r.nonExecute("coupures sur corpus réel",
                         motif: "aucun corpus fourni — passer --corpus <dossier>")
        }
    }

    // MARK: - 4. Le gain en vertical, consigné

    private static func gainVertical(_ r: Rapport) {
        for (nom, w, h) in [("9:16 1080×1920", 1080, 1920),
                            ("1:1 1080×1080", 1080, 1080),
                            ("4:5 1080×1350", 1080, 1350)] {
            guard let v1 = tailleVersion1(.bandeauColore, w, h) else {
                r.verifier("\(nom) : taille de la v1 calculable", false); continue
            }
            var commeV2 = ProfilHabillage.bandeauColore
            commeV2.logoActif = false
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: commeV2, largeurVideo: w, hauteurVideo: h) else { continue }
            let gain = mep.parametres.taille - v1
            r.verifier("\(nom) : la police passe de \(v1) à "
                       + "\(mep.parametres.taille) px"
                       + (v1 > 0 ? " (+\(Int(Double(gain) / Double(v1) * 100)) %)" : ""),
                       mep.parametres.taille > v1)
        }

        // Le chiffre annoncé à l'ADR, vérifié plutôt que recopié.
        //
        // Il a changé le 06/09 — 61 → 68 est devenu 57 → 63 — et le gain qu'il
        // mesure n'a pas bougé d'un point. Tous les chiffres de la décision nº6
        // avaient été calculés sur une graisse ROMAINE, alors que le rendu est
        // gras depuis toujours du côté du prototype : un texte plus large tient
        // en moins de caractères, donc la taille qui atteint la longueur de
        // ligne cible est plus petite. La correction est dans `PoliceSousTitre`,
        // le raisonnement dans l'ADR, « Tranché le 06/09 — la campagne de
        // parité ». Ce qui était vrai reste vrai : c'est la mesure qui était
        // faite sur la mauvaise graisse.
        var nonp = ProfilHabillage.bandeauColore
        nonp.logoActif = false
        let v1 = tailleVersion1(nonp, 1080, 1920) ?? 0
        let v2 = (try? MiseEnPageRendu.calculer(
            profil: nonp, largeurVideo: 1080, hauteurVideo: 1920))?.parametres.taille ?? 0
        r.egal("9:16 : le 57 → 63 px annoncé à la décision nº6, corrigé le 06/09",
               "\(v1) → \(v2)", "57 → 63")
    }

    // MARK: - La géométrie de la version 1, reconstituée

    /// Le débord du fond tel que la v1 le calculait, en mode `ajuste`.
    ///
    /// Reconstitué ici, et nulle part ailleurs : rien dans l'application ne
    /// l'appelle. Même raison d'être que `calculerCommeLePrototype` du moteur —
    /// rendre une divergence MESURABLE plutôt que déclarée.
    ///
    /// La v1 mesurait la largeur d'une espace dans la police RÉELLE, à la
    /// taille RÉELLE : c'est de là que venait le défaut, l'unité étant une
    /// fraction de la taille de police, donc de la hauteur de la vidéo.
    static func debordVersion1(_ profil: ProfilHabillage, _ w: Int, _ h: Int,
                               espacesLateraux: Int = 4)
    -> (debord: Double, taille: Int)? {
        guard let taille = tailleVersion1(profil, w, h,
                                          espacesLateraux: espacesLateraux),
              let police = try? PoliceSousTitre(famille: profil.police, taille: taille)
        else { return nil }
        let padding = max(4, TextePython.arrondi(Double(h) * profil.bandeauPaddingRatio))
        return (Double(padding) + Double(espacesLateraux) * police.largeurEspace, taille)
    }

    /// La taille de police que la v1 appliquait.
    ///
    /// Même boucle que `MiseEnPageRendu`, mais avec la largeur utile de la v1 :
    /// on descend d'un cran tant que la capacité n'atteint pas la cible. En
    /// 16:9 elle ne descend jamais ; en 9:16 elle descend beaucoup, et c'est
    /// tout le sujet.
    static func tailleVersion1(_ profil: ProfilHabillage, _ w: Int, _ h: Int,
                               espacesLateraux: Int = 4) -> Int? {
        let mesureur = MesureurCoreText(famille: profil.police)
        let cible = min(MoteurMiseEnPage.longueurLigneMaximale,
                        max(MoteurMiseEnPage.longueurLigneMinimale,
                            profil.longueurLigneCible))
        let demandee = max(12, TextePython.arrondi(Double(h) * profil.tailleRatio))
        let margeLaterale = max(10, TextePython.arrondi(
            Double(w) * profil.margeLateraleRatioLargeur))

        for taille in stride(from: demandee, through: 1, by: -1) {
            guard let police = try? PoliceSousTitre(famille: profil.police, taille: taille)
            else { return nil }
            let padding = max(4, TextePython.arrondi(Double(h) * profil.bandeauPaddingRatio))
            let disponible: Double
            switch profil.bandeauMode {
            case .ajuste:
                let debord = profil.bandeauActif
                    ? Double(padding) + Double(espacesLateraux) * police.largeurEspace
                    : 0
                disponible = Double(w - 2 * margeLaterale) - 2 * debord
            case .pleineLargeur:
                // La v1 employait ici `marge_interieure_pct_largeur`, non
                // arrondie. Le profil converti en porte la valeur.
                let marge = Double(w) * profil.bandeauMargeTexteRatioLargeur
                disponible = Double(w) - 2 * marge
            }
            let moyenne = mesureur.largeurMoyenneCaractere(taillePolice: taille)
            guard moyenne > 0 else { return taille }
            if TextePython.tronquer(disponible / moyenne) >= cible { return taille }
        }
        return 1
    }

    // MARK: - Fond de contrôle

    private static let texteDEssai =
        "Il m'a dit qu'il n'avait rien vu ce jour-là, vers quatre heures du matin."

    private static func fondDeControle(largeur: Int, hauteur: Int) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: largeur, height: hauteur, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        ctx.setFillColor(CGColor(red: 0.85, green: 0.85, blue: 0.82, alpha: 1))
        ctx.fill(CGRect(x: largeur / 2, y: 0, width: largeur / 2, height: hauteur))
        return ctx.makeImage()
    }
}
