// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// CommandeMesures.swift — `--mesures-decision6` : les chiffres qui instruisent
// la décision nº6.
//
// L'ADR ne cite pas de nombres qu'on ne puisse pas refaire. Cette commande
// produit les tableaux de la section « Décision nº6 » : qui commande vraiment
// la largeur de la colonne de texte, et ce que chaque réglage coûte.
//
// Elle n'applique RIEN. Elle mesure le code tel qu'il est aujourd'hui, avec
// Core Text — donc les vraies largeurs, pas l'estimation « 0,72 × taille » du
// prototype. À supprimer le jour où la décision sera prise et appliquée.

import Foundation

enum CommandeMesures {

    /// Les formats sur lesquels tout se joue. Le 16:9 est le format de
    /// référence, le 9:16 celui qui révèle les défauts — la hauteur y est la
    /// GRANDE dimension, donc la police y est grande et la largeur étroite.
    static let formats: [(String, Int, Int)] = [
        ("16:9 1920×1080", 1920, 1080),
        ("9:16 1080×1920", 1080, 1920),
        ("1:1  1080×1080", 1080, 1080),
        ("4:5  1080×1350", 1080, 1350),
    ]

    static let texte =
        "Il m'a dit qu'il n'avait rien vu ce jour-là, vers quatre heures du matin."

    static func executer(arguments args: [String]) -> Int32 {
        print("Décision nº6 — qui commande la largeur de la colonne de texte ?")
        print(String(repeating: "═", count: 74))

        budgetDeLargeur()
        coursesInertes()
        tailleNommee()
        recadrageRond()
        remplacementParUnPourcentage()
        return 0
    }

    // MARK: - 1. Le budget de largeur, réglage par réglage

    private static func budgetDeLargeur() {
        titre("1. Où passe la largeur — profil NONP (bandeau « ajuste »)")
        print("   marge lat. = sous_titre.marge_laterale_pct_largeur (3 %)")
        print("   débord     = 2 × (padding + espaces_lateraux × largeur d'espace)")
        print("")
        ligne(["format", "largeur", "marge lat.", "débord", "reste",
               "taille app./dem.", "cap."])
        for (nom, w, h) in formats {
            var p = ProfilHabillage.nonpHistorique
            p.logoActif = false
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: p, largeurVideo: w, hauteurVideo: h) else { continue }
            let debord = 2 * GeometrieSousTitres.debordDuFond(
                profil: p, parametres: mep.parametres, police: mep.police)
            let marges = Double(2 * mep.parametres.margeLaterale)
            let reste = Double(w) - marges - debord
            ligne([nom, "\(w)", pct(marges, w), pct(debord, w),
                   "\(Int(reste)) px",
                   taille(mep, p, h), "\(mep.capacite)"])
        }

        print("")
        titre("   profil Neutre (bandeau « pleine-largeur »)")
        print("   marge int. = bandeau.marge_interieure_pct_largeur (3 %)")
        print("   la marge LATÉRALE du texte ne borne plus rien : la bande occupe")
        print("   toute la largeur, et c'est la marge INTÉRIEURE qui compte.")
        print("")
        ligne(["format", "largeur", "marge lat.", "marge int.", "reste",
               "taille app./dem.", "cap."])
        for (nom, w, h) in formats {
            var p = ProfilHabillage.neutre
            p.logoActif = false
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: p, largeurVideo: w, hauteurVideo: h) else { continue }
            let margeInt = 2 * Double(w) * p.bandeauMargeInterieureRatioLargeur
            ligne([nom, "\(w)",
                   pct(Double(2 * mep.parametres.margeLaterale), w),
                   pct(margeInt, w),
                   "\(Int(Double(w) - margeInt)) px",
                   taille(mep, p, h), "\(mep.capacite)"])
        }
    }

    // MARK: - 2. Ce qui, dans la course de chaque réglage, ne fait rien

    /// Le cœur du dossier : trois réglages prétendent gouverner la largeur de
    /// la colonne, et la longueur de ligne cible les bat tous les trois tant
    /// qu'elle est atteinte.
    private static func coursesInertes() {
        titre("2. La course inerte de chaque réglage")
        print("   Premier point de la course où le RENDU change — lignes coupées")
        print("   autrement, ou taille de police réduite. En deçà, le réglage")
        print("   bouge sans rien produire.")
        print("")

        for (nomFormat, w, h) in formats {
            print("  ▸ \(nomFormat)")

            // espaces_lateraux : entier de 0 à 12, mode « ajuste ».
            var ajuste = ProfilHabillage.nonpHistorique
            ajuste.logoActif = false
            seuilEntier(nom: "bandeau.espaces_lateraux", course: 0...12,
                        profil: ajuste, w: w, h: h) { p, v in
                p.bandeauEspacesLateraux = v
            }

            // marge_interieure_pct_largeur : 0 à 25 %, mode « pleine-largeur ».
            var pleine = ProfilHabillage.neutre
            pleine.logoActif = false
            seuilReel(nom: "bandeau.marge_interieure_pct_largeur (0–25 %)",
                      course: 0...0.25, pas: 250, profil: pleine, w: w, h: h) { p, v in
                p.bandeauMargeInterieureRatioLargeur = v
            }

            // marge_laterale_pct_largeur : 0 à 20 %, les deux modes.
            seuilReel(nom: "sous_titre.marge_laterale_pct_largeur (0–20 %), ajuste",
                      course: 0...0.20, pas: 200, profil: ajuste, w: w, h: h) { p, v in
                p.margeLateraleRatioLargeur = v
            }
            seuilReel(nom: "sous_titre.marge_laterale_pct_largeur (0–20 %), pleine",
                      course: 0...0.20, pas: 200, profil: pleine, w: w, h: h) { p, v in
                p.margeLateraleRatioLargeur = v
            }

            // longueurLigneCible : 28 à 42, hors schéma.
            seuilEntier(nom: "longueurLigneCible (28–42, HORS SCHÉMA)",
                        course: 28...42, profil: ajuste, w: w, h: h) { p, v in
                p.longueurLigneCible = v
            }
            print("")
        }
    }

    /// Combien de valeurs de la course produisent un rendu DIFFÉRENT de celui
    /// de la valeur de départ.
    private static func seuilEntier(nom: String, course: ClosedRange<Int>,
                                    profil: ProfilHabillage, w: Int, h: Int,
                                    poser: (inout ProfilHabillage, Int) -> Void) {
        var distincts: Set<String> = []
        var premierChangement: Int? = nil
        var reference: String? = nil
        for v in course {
            var p = profil
            poser(&p, v)
            let e = empreinte(p, w, h)
            distincts.insert(e)
            if reference == nil { reference = e }
            else if premierChangement == nil && e != reference { premierChangement = v }
        }
        rapport(nom: nom, distincts: distincts.count, total: course.count,
                premier: premierChangement.map { "\($0)" })
    }

    private static func seuilReel(nom: String, course: ClosedRange<Double>, pas: Int,
                                  profil: ProfilHabillage, w: Int, h: Int,
                                  poser: (inout ProfilHabillage, Double) -> Void) {
        var distincts: Set<String> = []
        var premierChangement: Double? = nil
        var reference: String? = nil
        for i in 0...pas {
            let v = course.lowerBound
                + (course.upperBound - course.lowerBound) * Double(i) / Double(pas)
            var p = profil
            poser(&p, v)
            let e = empreinte(p, w, h)
            distincts.insert(e)
            if reference == nil { reference = e }
            else if premierChangement == nil && e != reference { premierChangement = v }
        }
        rapport(nom: nom, distincts: distincts.count, total: pas + 1,
                premier: premierChangement.map { String(format: "%.1f %%", $0 * 100) })
    }

    private static func rapport(nom: String, distincts: Int, total: Int, premier: String?) {
        let inerte = premier == nil
            ? "AUCUN EFFET sur toute la course"
            : "premier effet à \(premier!)"
        print("      " + cale(nom, 56) + cale(inerte, 34)
              + "\(distincts) images distinctes sur \(total)")
    }

    /// Complète à droite. `String(format: "%-58s")` massacrait les tirets
    /// cadratins : il compte des octets là où l'on veut des caractères.
    private static func cale(_ t: String, _ largeur: Int) -> String {
        t.count >= largeur ? t + " "
            : t + String(repeating: " ", count: largeur - t.count)
    }

    /// Ce qui SE VOIT du rendu : la taille de police appliquée, et l'endroit
    /// où les lignes se coupent. Deux profils de même empreinte donnent la même
    /// image.
    ///
    /// La capacité de ligne en est volontairement absente. C'est un nombre
    /// intermédiaire : elle bouge d'un caractère sans que rien ne change à
    /// l'écran, et la compter faisait passer pour « un effet » ce qui n'en est
    /// pas un. C'est le piège dans lequel la mesure du lot 5 était tombée en
    /// sens inverse — elle ne regardait que la largeur de découpe, et concluait
    /// à 89 % de course inerte là où la taille de police, elle, bougeait.
    private static func empreinte(_ p: ProfilHabillage, _ w: Int, _ h: Int) -> String {
        guard let mep = try? MiseEnPageRendu.calculer(
            profil: p, largeurVideo: w, hauteurVideo: h) else { return "—" }
        let lignes = mep.segmenter([Cue(debutMs: 0, finMs: 1000, texte: texte)],
                                   lignesMax: p.lignesMax)
            .map { $0.lignes.joined(separator: "|") }.joined(separator: "//")
        return "\(mep.parametres.taille)/\(lignes)"
    }

    // MARK: - 3. La taille nommée, et l'aller-retour par le schéma

    private static func tailleNommee() {
        titre("3. La taille nommée — déduite de taille_pct_hauteur, faute de champ")
        print("   L'app déduit aujourd'hui la longueur de ligne cible de la taille")
        print("   de police, par la table des quatre tailles nommées. Ce que cela")
        print("   coûte se mesure : un profil dont la taille ne tombe pas sur")
        print("   l'une des quatre reçoit une cible qui n'est pas la sienne.")
        print("")
        ligne(["taille_pct", "taille nommée déduite", "cible posée", "cible atteignable*",
               "écart"])
        var p = ProfilHabillage.nonpHistorique
        p.logoActif = false
        for pct in stride(from: 3.0, through: 11.0, by: 0.6) {
            var profil = p
            profil.tailleRatio = pct / 100
            let nommee = TailleNommee.laPlusProche(deTaille: profil.tailleRatio)
            profil.longueurLigneCible = nommee.longueurLigneCible
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: profil, largeurVideo: 1920, hauteurVideo: 1080) else { continue }
            let ecart = mep.capacite - nommee.longueurLigneCible
            ligne([String(format: "%.1f %%", pct),
                   Textes.Interface.nomTaille(nommee),
                   "\(nommee.longueurLigneCible)",
                   "\(mep.capacite)",
                   ecart == 0 ? "—" : String(format: "%+d", ecart)])
        }
        print("   * capacité réellement obtenue en 16:9 1080p, à la taille demandée.")
        print("")
        print("   Les quatre tailles nommées, et leur couple :")
        for t in TailleNommee.allCases {
            print("      " + cale(Textes.Interface.nomTaille(t), 14)
                  + String(format: "taille %.1f %%  →  cible %d caractères",
                           t.tailleRatio * 100, t.longueurLigneCible))
        }
    }

    // MARK: - 5. Ce que coûterait la piste de l'ADR

    /// La piste inscrite à l'ADR : remplacer `espaces_lateraux` — dont l'unité
    /// est une largeur d'espace, donc une fraction de la TAILLE DE POLICE, donc
    /// de la HAUTEUR — par un pourcentage de la LARGEUR, comme tout le reste du
    /// schéma.
    ///
    /// L'ADR pose la bonne question : « quelle valeur par défaut donne, en 16:9,
    /// un fond visuellement identique à celui d'aujourd'hui ? » La voici.
    private static func remplacementParUnPourcentage() {
        titre("5. Remplacer espaces_lateraux par un % de largeur — ce que ça donne")
        print("   Le débord actuel, décomposé. « côté » = padding + 4 × espace,")
        print("   c'est-à-dire ce qu'un pourcentage de largeur devrait reproduire.")
        print("")
        ligne(["format", "taille", "padding", "4 × espace", "côté", "% de largeur"])
        for (nom, w, h) in formats {
            var p = ProfilHabillage.nonpHistorique
            p.logoActif = false
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: p, largeurVideo: w, hauteurVideo: h) else { continue }
            let espaces = Double(p.bandeauEspacesLateraux) * mep.police.largeurEspace
            let cote = Double(mep.parametres.paddingBandeau) + espaces
            ligne([nom, "\(mep.parametres.taille) px",
                   "\(mep.parametres.paddingBandeau) px",
                   String(format: "%.0f px", espaces),
                   String(format: "%.0f px", cote),
                   String(format: "%.2f %%", cote / Double(w) * 100)])
        }
        print("")
        print("   Le même réglage coûte 5,6 % de la largeur en 16:9 et 9,6 % en")
        print("   9:16 : c'est tout le défaut, et c'est pourquoi la marge y est")
        print("   trois fois plus chère qu'elle ne devrait.")
        print("")
        print("   La question de l'ADR — « quelle valeur par défaut laisse le")
        print("   16:9 inchangé ? » — a donc une réponse : 5,61 % de la largeur.")
        print("   Ce que les autres formats y gagneraient, à ce défaut-là :")
        print("")
        ligne(["format", "côté auj.", "côté à 5,61 %", "taille auj.", "taille alors"])
        let defaut = 0.0561
        for (nom, w, h) in formats {
            var actuel = ProfilHabillage.nonpHistorique
            actuel.logoActif = false
            guard let avant = try? MiseEnPageRendu.calculer(
                profil: actuel, largeurVideo: w, hauteurVideo: h) else { continue }
            let coteAvant = Double(avant.parametres.paddingBandeau)
                + Double(actuel.bandeauEspacesLateraux) * avant.police.largeurEspace

            // Simulation : plus d'espaces latéraux, et un débord posé en
            // pourcentage de la LARGEUR. Le padding sert de véhicule — il est
            // le seul terme du débord qui ne dépende pas de la police. Sa part
            // verticale change aussi, sans effet sur la taille ni sur la césure,
            // qui sont ce que l'on mesure ici.
            var simule = actuel
            simule.bandeauEspacesLateraux = 0
            simule.bandeauPaddingRatio = Double(w) * defaut / Double(h)
            guard let apres = try? MiseEnPageRendu.calculer(
                profil: simule, largeurVideo: w, hauteurVideo: h) else { continue }
            ligne([nom, String(format: "%.0f px", coteAvant),
                   String(format: "%.0f px", Double(w) * defaut),
                   "\(avant.parametres.taille) px",
                   "\(apres.parametres.taille) px"
                   + (apres.parametres.taille > avant.parametres.taille ? " ↑" : "")])
        }
        print("")
        print("   Le 16:9 ne bouge pas — c'est la condition posée. Les formats")
        print("   étroits récupèrent la largeur que l'unité « largeur d'espace »")
        print("   leur prenait, et la police y remonte.")
    }

    // MARK: - 4. Le recadrage rond

    private static func recadrageRond() {
        titre("4. Le recadrage rond — propriété du profil, ou du fichier ?")
        print("   `logo.recadre_en_cercle` n'existe pas au schéma. Il vit dans")
        print("   `reglages_app` de la mémoire locale, donc il ne PART PAS avec")
        print("   un profil partagé : le destinataire obtient un logo carré là où")
        print("   l'expéditeur voyait un rond.")
        print("")
        print("   Ce que le prototype en faisait : `--make-logo`, qui FABRIQUAIT")
        print("   un fichier rond à côté du logo. Le rond était donc une propriété")
        print("   du FICHIER, jamais du profil — et le profil ne portait que le")
        print("   chemin du fichier déjà rond.")
        print("")
        print("   Conséquence mesurable : le rendu diffère, et rien ne le dit.")
        var rond = ProfilHabillage.nonpHistorique
        rond.logoRecadreEnCercle = true
        let annonce = ProfilJSON.champsInconnusDuPrototype(rond)
        print("      champs annoncés à l'enregistrement : "
              + (annonce.isEmpty ? "aucun" : annonce.joined(separator: ", ")))
        print("      → un profil qui recadre en cercle s'exporte SANS le dire.")
    }

    // MARK: - Mise en forme

    private static func titre(_ t: String) {
        print("")
        print(t)
        print(String(repeating: "─", count: 74))
    }

    private static func ligne(_ colonnes: [String]) {
        let largeurs = [18, 12, 17, 17, 12, 18, 6]
        var sortie = "   "
        for (i, c) in colonnes.enumerated() {
            sortie += cale(c, i < largeurs.count ? largeurs[i] : 12)
        }
        print(sortie)
    }

    /// « appliquée / demandée par le profil ». La taille demandée est celle que
    /// `taille_pct_hauteur` réclame AVANT toute réduction : c'est l'écart entre
    /// les deux qui dit si la largeur a eu le dernier mot.
    private static func taille(_ mep: MiseEnPageRendu,
                               _ p: ProfilHabillage, _ h: Int) -> String {
        let demandee = max(12, TextePython.arrondi(Double(h) * p.tailleRatio))
        return "\(mep.parametres.taille)/\(demandee)"
            + (mep.parametres.taille < demandee ? " ↓" : "")
    }

    private static func pct(_ v: Double, _ w: Int) -> String {
        String(format: "%d px (%.1f %%)", Int(v), v / Double(w) * 100)
    }
}
