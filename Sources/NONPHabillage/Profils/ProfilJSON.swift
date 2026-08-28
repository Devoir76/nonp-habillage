// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ProfilJSON.swift — lire, valider et écrire un profil au schéma v1.
//
// INVARIANT nº6 : `docs/profil-habillage.schema.json` est un CONTRAT PARTAGÉ
// avec le prototype Python. Ce fichier l'applique, il ne l'amende pas. Aucun
// champ n'est inventé ici : ce que l'app sait faire et que le schéma ne nomme
// pas — la longueur de ligne cible, le recadrage rond du logo — reste hors du
// fichier partagé et vit dans la mémoire locale (`MemoireProfil`). Leur entrée
// éventuelle au schéma est la décision nº6, instruite au temps 2 du lot 6.
//
// ── Deux lecteurs, un seul fichier ───────────────────────────────────────────
//
// La validation est calquée sur `charger_profil()` du prototype, jusqu'à la
// forme des messages : mêmes champs autorisés, mêmes obligatoires, mêmes
// bornes, et surtout la même façon de répondre — TOUTES les anomalies d'un
// coup, jamais la première seule. Corriger un profil à l'aveugle, une erreur
// après l'autre, est le contraire d'un message clair.
//
// ── Ce que l'app ÉCRIT, et pourquoi c'est plus étroit que ce qu'elle LIT ─────
//
// Le schéma de ce dépôt porte trois champs ajoutés le 23/08 et FACULTATIFS :
// `bandeau.mode`, `bandeau.hauteur_fixe_lignes`,
// `bandeau.marge_interieure_pct_largeur`. Le prototype, lui, ne les connaît
// pas : son `_controler` les refuserait comme champs inconnus.
//
// D'où la règle d'écriture : **un champ facultatif à sa valeur par défaut n'est
// pas écrit**. C'est ce que le schéma dit déjà de lui-même — « les champs
// ajoutés sont facultatifs et leurs valeurs par défaut reproduisent exactement
// le comportement actuel » —, et c'est ce qui rend le critère d'acceptation du
// lot atteignable : un profil qui reste dans ce que le prototype sait rendre
// produit un fichier que le prototype accepte. Un profil qui emploie le bandeau
// pleine largeur, lui, écrit `mode` — et le prototype le refusera, parce qu'il
// ne sait effectivement pas le rendre. Le fichier ne ment pas ; c'est la seule
// réponse honnête tant que le prototype n'a pas reçu l'amendement.

import Foundation

/// Ce qui empêche de lire un profil. Porte TOUTES les anomalies.
struct ErreurProfil: Error {
    /// Une ligne par anomalie, déjà rédigée en français.
    let anomalies: [String]
}

enum ProfilJSON {

    /// Version du schéma partagé. Une seule pour l'instant, et c'est voulu :
    /// les ajouts du 23/08 sont facultatifs, donc sans migration.
    static let versionSchema = 1

    // MARK: - Lecture

    /// Lit un profil depuis un fichier.
    ///
    /// Le chemin du logo est résolu **relativement au fichier de profil**,
    /// comme le schéma le prescrit et comme le prototype le fait. Un logo
    /// introuvable n'est PAS une erreur ici — voir `logoIntrouvable` : le
    /// profil se lit, et c'est l'application qui le signale et propose d'en
    /// choisir un autre, plutôt que de perdre tous les réglages parce qu'une
    /// image a changé de dossier.
    static func lire(_ url: URL) throws -> ProfilHabillage {
        let donnees: Data
        do {
            donnees = try Data(contentsOf: url)
        } catch {
            throw ErreurProfil(anomalies: [Textes.Profil.fichierIllisible(
                url.lastPathComponent)])
        }
        return try decoder(donnees, base: url.deletingLastPathComponent())
    }

    /// Lit un profil depuis des octets.
    ///
    /// - Parameter base: dossier auquel rapporter un chemin de logo relatif.
    static func decoder(_ donnees: Data, base: URL?) throws -> ProfilHabillage {
        let brut: Any
        do {
            brut = try JSONSerialization.jsonObject(with: donnees)
        } catch {
            throw ErreurProfil(anomalies: [Textes.Profil.jsonIllisible(
                error.localizedDescription)])
        }
        guard let d = brut as? [String: Any] else {
            throw ErreurProfil(anomalies: [Textes.Profil.pasUnObjet])
        }

        var err: [String] = []
        var p = ProfilHabillage.neutre

        controler(d, autorises: ["schema_version", "nom", "logo", "sous_titre"],
                  obligatoires: ["schema_version", "nom", "sous_titre"],
                  contexte: "profil", &err)

        if let v = d["schema_version"] as? Int, v == versionSchema {
            // Rien à faire : c'est la seule version.
        } else {
            err.append(Textes.Profil.versionSchema(d["schema_version"]))
        }

        if let nom = d["nom"] as? String, !nom.trimmingCharacters(
            in: .whitespacesAndNewlines).isEmpty {
            p.nom = nom
        } else if d["nom"] != nil {
            err.append(Textes.Profil.nomVide)
        }

        lireLogo(d["logo"], base: base, dans: &p, &err)
        lireSousTitre(d["sous_titre"], dans: &p, &err)

        if !err.isEmpty { throw ErreurProfil(anomalies: err) }
        return p
    }

    // MARK: - Lecture — logo

    private static func lireLogo(_ brut: Any?, base: URL?,
                                 dans p: inout ProfilHabillage, _ err: inout [String]) {
        // Section absente : pas de logo. C'est ce que dit le schéma, et le
        // profil neutre livré est dans ce cas.
        guard let brut else {
            p.logoActif = false
            p.logoFichier = nil
            return
        }
        guard let lg = brut as? [String: Any] else {
            err.append(Textes.Profil.doitEtreUnObjet("logo")); return
        }
        controler(lg, autorises: ["actif", "fichier", "position",
                                  "taille_pct_hauteur", "marge_pct_hauteur", "opacite"],
                  obligatoires: ["actif"], contexte: "logo", &err)

        p.logoActif = (lg["actif"] as? Bool) ?? false
        if let v = nombre(lg, "taille_pct_hauteur", 1, 50, "logo", &err) {
            p.logoTailleRatio = ratio(depuisPourcent: v)
        }
        if let v = nombre(lg, "marge_pct_hauteur", 0, 20, "logo", &err) {
            p.logoMargeRatio = ratio(depuisPourcent: v)
        }
        if let v = nombre(lg, "opacite", 0, 1, "logo", &err) {
            p.logoOpacite = v
        }

        if let pos = lg["position"] {
            lirePosition(pos, dans: &p, &err)
        }

        // Le fichier. Résolu relativement au profil, jamais deviné.
        p.logoFichier = nil
        if let f = lg["fichier"] as? String,
           !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let chemin = (f as NSString).isAbsolutePath
                ? URL(fileURLWithPath: f)
                : (base ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
                    .appendingPathComponent(f)
            p.logoFichier = chemin.standardizedFileURL
        } else if lg["fichier"] != nil {
            err.append(Textes.Profil.champTexteNonVide("logo", "fichier"))
        } else if p.logoActif {
            // Le prototype en fait une erreur. Ici c'est un profil sans image
            // choisie — état parfaitement normal du préréglage NONP livré —,
            // et l'interface propose d'en déposer une.
            p.logoActif = false
        }
    }

    private static func lirePosition(_ brut: Any, dans p: inout ProfilHabillage,
                                     _ err: inout [String]) {
        guard let pos = brut as? [String: Any] else {
            err.append(Textes.Profil.doitEtreUnObjet("logo.position")); return
        }
        if pos["preset"] != nil {
            controler(pos, autorises: ["preset"], obligatoires: ["preset"],
                      contexte: "logo.position", &err)
            if let nom = pos["preset"] as? String, let coin = CoinLogo(rawValue: nom) {
                p.logoPosition = .coin(coin)
            } else {
                err.append(Textes.Profil.presetInvalide(pos["preset"]))
            }
        } else {
            controler(pos, autorises: ["x_pct", "y_pct"],
                      obligatoires: ["x_pct", "y_pct"], contexte: "logo.position", &err)
            let x = nombre(pos, "x_pct", 0, 100, "logo.position", &err) ?? 50
            let y = nombre(pos, "y_pct", 0, 100, "logo.position", &err) ?? 50
            p.logoPosition = .libre(xPct: x, yPct: y)
        }
    }

    // MARK: - Lecture — sous-titres

    private static func lireSousTitre(_ brut: Any?, dans p: inout ProfilHabillage,
                                      _ err: inout [String]) {
        guard let brut else { return }   // l'absence est déjà signalée plus haut
        guard let st = brut as? [String: Any] else {
            err.append(Textes.Profil.doitEtreUnObjet("sous_titre")); return
        }
        controler(st, autorises: ["police", "taille_pct_hauteur", "couleur_texte",
                                  "contour", "bandeau", "marge_basse_pct_hauteur",
                                  "marge_laterale_pct_largeur", "lignes_max"],
                  obligatoires: ["police", "taille_pct_hauteur", "couleur_texte"],
                  contexte: "sous_titre", &err)

        if let police = st["police"] as? String,
           !police.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            p.police = police
        } else if st["police"] != nil {
            err.append(Textes.Profil.champTexteNonVide("sous_titre", "police"))
        }
        if let v = nombre(st, "taille_pct_hauteur", 1.5, 12, "sous_titre", &err) {
            p.tailleRatio = ratio(depuisPourcent: v)
        }
        if let v = nombre(st, "marge_basse_pct_hauteur", 0, 30, "sous_titre", &err) {
            p.margeBasseRatio = ratio(depuisPourcent: v)
        }
        if let v = nombre(st, "marge_laterale_pct_largeur", 0, 20, "sous_titre", &err) {
            p.margeLateraleRatioLargeur = ratio(depuisPourcent: v)
        }
        if let v = entier(st, "lignes_max", 1, 4, "sous_titre", &err) {
            p.lignesMax = v
        }
        if let c = couleur(st, "couleur_texte", "sous_titre", &err) {
            p.couleurTexte = c
        }

        if let ct = st["contour"] {
            guard let contour = ct as? [String: Any] else {
                err.append(Textes.Profil.doitEtreUnObjet("sous_titre.contour")); return
            }
            controler(contour, autorises: ["couleur", "epaisseur_pct_hauteur"],
                      obligatoires: ["couleur", "epaisseur_pct_hauteur"],
                      contexte: "sous_titre.contour", &err)
            if let c = couleur(contour, "couleur", "sous_titre.contour", &err) {
                p.contourCouleur = c
            }
            if let v = nombre(contour, "epaisseur_pct_hauteur", 0, 3,
                              "sous_titre.contour", &err) {
                p.contourRatio = ratio(depuisPourcent: v)
            }
        }

        lireBandeau(st["bandeau"], dans: &p, &err)

        // La longueur de ligne cible n'a pas de champ au schéma : elle se
        // DÉDUIT de la taille de police, par la table des tailles nommées.
        // C'est provisoire et documenté comme tel — la question est posée à la
        // décision nº6. Ne rien déduire laisserait un profil importé incohérent
        // avec la taille qu'il porte : la police du fichier, la longueur de
        // ligne de la session précédente.
        p.longueurLigneCible = TailleNommee
            .laPlusProche(deTaille: p.tailleRatio).longueurLigneCible
    }

    private static func lireBandeau(_ brut: Any?, dans p: inout ProfilHabillage,
                                    _ err: inout [String]) {
        guard let brut else { p.bandeauActif = false; return }
        guard let bd = brut as? [String: Any] else {
            err.append(Textes.Profil.doitEtreUnObjet("sous_titre.bandeau")); return
        }
        controler(bd, autorises: ["actif", "mode", "couleur", "opacite",
                                  "padding_pct_hauteur", "espaces_lateraux",
                                  "marge_interieure_pct_largeur", "hauteur_fixe_lignes"],
                  obligatoires: ["actif"], contexte: "sous_titre.bandeau", &err)

        p.bandeauActif = (bd["actif"] as? Bool) ?? false
        let opacite = nombre(bd, "opacite", 0, 1, "sous_titre.bandeau", &err) ?? 1.0
        if var c = couleur(bd, "couleur", "sous_titre.bandeau", &err) {
            c.opacite = opacite
            p.bandeauCouleur = c
        } else if bd["couleur"] == nil {
            p.bandeauCouleur = CouleurProfil(hex: "#000000", opacite: opacite)
        }
        if let v = nombre(bd, "padding_pct_hauteur", 0, 10, "sous_titre.bandeau", &err) {
            p.bandeauPaddingRatio = ratio(depuisPourcent: v)
        }
        if let v = entier(bd, "espaces_lateraux", 0, 12, "sous_titre.bandeau", &err) {
            p.bandeauEspacesLateraux = v
        }

        // Les trois ajouts du 23/08. Facultatifs, valeurs par défaut égales au
        // comportement historique : un profil du prototype qui les ignore rend
        // exactement comme avant.
        if let nom = bd["mode"] as? String {
            if let mode = ModeBandeau(rawValue: nom) {
                p.bandeauMode = mode
            } else {
                err.append(Textes.Profil.modeInvalide(nom))
            }
        } else if bd["mode"] != nil {
            err.append(Textes.Profil.modeInvalide(bd["mode"]))
        } else {
            p.bandeauMode = .ajuste
        }
        p.bandeauMargeInterieureRatioLargeur = ratio(depuisPourcent:
            nombre(bd, "marge_interieure_pct_largeur", 0, 25,
                   "sous_titre.bandeau", &err) ?? 3.0)
        p.bandeauHauteurFixeLignes =
            entier(bd, "hauteur_fixe_lignes", 0, 4, "sous_titre.bandeau", &err) ?? 0
    }

    // MARK: - Écriture

    /// Écrit un profil PARTAGEABLE à côté de son logo.
    ///
    /// Le logo est recopié dans le dossier du profil s'il n'y est pas déjà, et
    /// le chemin est écrit **relatif**. C'est la seule forme qui survive à
    /// l'envoi : un profil partagé ne peut pas porter `/Users/x/…`, chemin
    /// qui n'existe que sur une machine. Le prototype lit exactement cela — son
    /// propre `profil.json` livré dit `"fichier": "logo_circle.png"`.
    ///
    /// - Returns: le fichier de logo recopié, s'il y en a eu un.
    @discardableResult
    static func ecrire(_ profil: ProfilHabillage, vers url: URL) throws -> URL? {
        var copie: URL? = nil
        var nomRelatif: String? = nil

        if profil.logoActif, let source = profil.logoFichier {
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw ErreurProfil(anomalies: [Textes.Profil.logoIntrouvable(source.path)])
            }
            let destination = url.deletingLastPathComponent()
                .appendingPathComponent(source.lastPathComponent)
            if destination.standardizedFileURL != source.standardizedFileURL {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: source, to: destination)
                copie = destination
            }
            nomRelatif = source.lastPathComponent
        }

        let donnees = try encoder(profil, cheminLogo: nomRelatif)
        try donnees.write(to: url, options: .atomic)
        return copie
    }

    /// Le profil en JSON, au schéma v1.
    ///
    /// - Parameter cheminLogo: ce qu'on écrit dans `logo.fichier`. `nil` : pas
    ///   de logo. C'est l'appelant qui décide de la forme du chemin — relative
    ///   pour un profil partagé, absolue pour la mémoire locale —, parce que
    ///   les deux usages n'ont pas les mêmes besoins.
    static func encoder(_ profil: ProfilHabillage, cheminLogo: String?) throws -> Data {
        var d: [String: Any] = [
            "schema_version": versionSchema,
            "nom": profil.nom,
        ]

        // `actif` dit ce qui sera GRAVÉ. Un profil qui poserait un logo sans
        // fichier ne pose aucun logo : l'écrire « actif » ferait un fichier que
        // le prototype refuse, pour une intention vide.
        var logo: [String: Any] = ["actif": cheminLogo != nil]
        if let cheminLogo { logo["fichier"] = cheminLogo }
        switch profil.logoPosition {
        case .coin(let c):
            logo["position"] = ["preset": c.rawValue]
        case .libre(let x, let y):
            logo["position"] = ["x_pct": nombreJSON(x), "y_pct": nombreJSON(y)]
        }
        logo["taille_pct_hauteur"] = nombreJSON(pourcent(profil.logoTailleRatio))
        logo["marge_pct_hauteur"] = nombreJSON(pourcent(profil.logoMargeRatio))
        logo["opacite"] = nombreJSON(profil.logoOpacite)
        d["logo"] = logo

        var bandeau: [String: Any] = [
            "actif": profil.bandeauActif,
            "couleur": hex(profil.bandeauCouleur),
            "opacite": nombreJSON(profil.bandeauCouleur.opacite),
            "padding_pct_hauteur": nombreJSON(pourcent(profil.bandeauPaddingRatio)),
            "espaces_lateraux": profil.bandeauEspacesLateraux,
        ]
        // Les trois ajouts du 23/08 : écrits SEULEMENT s'ils s'écartent du
        // comportement historique. Voir l'en-tête de ce fichier.
        if profil.bandeauMode != .ajuste {
            bandeau["mode"] = profil.bandeauMode.rawValue
        }
        if profil.bandeauHauteurFixeLignes != 0 {
            bandeau["hauteur_fixe_lignes"] = profil.bandeauHauteurFixeLignes
        }
        if profil.bandeauMode == .pleineLargeur,
           pourcent(profil.bandeauMargeInterieureRatioLargeur) != 3.0 {
            bandeau["marge_interieure_pct_largeur"] =
                nombreJSON(pourcent(profil.bandeauMargeInterieureRatioLargeur))
        }

        d["sous_titre"] = [
            "police": profil.police,
            "taille_pct_hauteur": nombreJSON(pourcent(profil.tailleRatio)),
            "couleur_texte": hex(profil.couleurTexte),
            "contour": [
                "couleur": hex(profil.contourCouleur),
                "epaisseur_pct_hauteur": nombreJSON(pourcent(profil.contourRatio)),
            ],
            "bandeau": bandeau,
            "marge_basse_pct_hauteur": nombreJSON(pourcent(profil.margeBasseRatio)),
            "marge_laterale_pct_largeur": nombreJSON(pourcent(profil.margeLateraleRatioLargeur)),
            "lignes_max": profil.lignesMax,
        ]

        return try JSONSerialization.data(
            withJSONObject: d, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Conversions

    /// Ratio → pourcentage lisible : 0.072 → 7.2, pas 7.199999999999999.
    ///
    /// Même procédé que le `_pct()` du prototype (`%g`), pour que les deux
    /// écrivent le même nombre et qu'un aller-retour soit stable.
    static func pourcent(_ ratio: Double) -> Double { lisible(ratio * 100) }

    /// Le même arrondi d'écriture, pour un nombre qui n'est pas un pourcentage
    /// — l'opacité, que le schéma exprime de 0 à 1.
    static func lisible(_ v: Double) -> Double {
        Double(String(format: "%g", v)) ?? v
    }

    /// Pourcentage → ratio, SANS l'erreur d'arrondi binaire.
    ///
    /// `7.2 / 100` ne vaut pas `0.072` en virgule flottante : il vaut
    /// 0,07200000000000001. Un profil écrit puis relu revenait donc
    /// imperceptiblement différent de lui-même, et l'aller-retour n'était plus
    /// une identité — ce qui, pour un format de fichier partagé, est
    /// exactement ce qu'il ne faut pas.
    ///
    /// Le quotient est donc RÉÉCRIT en décimal avant d'être relu : dix chiffres
    /// significatifs, largement plus que les six que le schéma sait porter, et
    /// bien moins que les dix-sept où le bruit binaire apparaît. `0.072`
    /// retombe alors sur le même Double que la constante écrite dans le code,
    /// et un profil relu est rigoureusement celui qu'on a écrit.
    static func ratio(depuisPourcent pct: Double) -> Double {
        let brut = pct / 100
        return Double(String(format: "%.10g", brut)) ?? brut
    }

    /// Le nombre tel qu'il doit être ÉCRIT.
    ///
    /// `JSONSerialization` imprime un `Double` avec dix-sept chiffres
    /// significatifs : 0,6 devient « 0.59999999999999998 ». Un profil reste
    /// lisible et modifiable à la main — il n'a pas à ressembler à une sortie
    /// de machine. Un nombre décimal l'écrit tel qu'on le lit.
    static func nombreJSON(_ v: Double) -> NSNumber {
        NSDecimalNumber(string: String(format: "%g", v))
    }

    static func hex(_ c: CouleurProfil) -> String {
        func o(_ v: Double) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", o(c.rouge), o(c.vert), o(c.bleu))
    }

    // MARK: - Contrôles élémentaires

    /// Champs inconnus refusés, champs obligatoires exigés.
    ///
    /// Même règle que `_controler()` du prototype : `additionalProperties:
    /// false` du schéma, appliqué à la main. Un champ inconnu n'est pas ignoré
    /// — il est REFUSÉ. C'est ce qui fait qu'une faute de frappe dans un profil
    /// se voit au lieu de rendre un habillage silencieusement différent.
    private static func controler(_ d: [String: Any], autorises: Set<String>,
                                  obligatoires: Set<String>, contexte: String,
                                  _ err: inout [String]) {
        for cle in d.keys.sorted() where !autorises.contains(cle) {
            err.append(Textes.Profil.champInconnu(contexte, cle))
        }
        for cle in obligatoires.sorted() where d[cle] == nil {
            err.append(Textes.Profil.champObligatoire(contexte, cle))
        }
    }

    private static func nombre(_ d: [String: Any], _ cle: String,
                               _ mini: Double, _ maxi: Double, _ contexte: String,
                               _ err: inout [String]) -> Double? {
        guard let brut = d[cle] else { return nil }
        // `as? Double` accepterait `true` : JSONSerialization rend les booléens
        // comme des NSNumber. On les écarte par leur TYPE — un test sur la
        // taille du nombre écartait aussi les entiers 0 et 1, qui sont des
        // valeurs parfaitement légitimes.
        guard let n = brut as? NSNumber, !estBooleen(n) else {
            err.append(Textes.Profil.nombreAttendu(contexte, cle, mini, maxi, brut))
            return nil
        }
        let v = n.doubleValue
        guard v >= mini, v <= maxi else {
            err.append(Textes.Profil.nombreAttendu(contexte, cle, mini, maxi, brut))
            return nil
        }
        return v
    }

    private static func entier(_ d: [String: Any], _ cle: String,
                               _ mini: Int, _ maxi: Int, _ contexte: String,
                               _ err: inout [String]) -> Int? {
        guard let brut = d[cle] else { return nil }
        guard let n = brut as? NSNumber, !estBooleen(n),
              n.doubleValue == n.doubleValue.rounded() else {
            err.append(Textes.Profil.entierAttendu(contexte, cle, mini, maxi, brut))
            return nil
        }
        let v = n.intValue
        guard v >= mini, v <= maxi else {
            err.append(Textes.Profil.entierAttendu(contexte, cle, mini, maxi, brut))
            return nil
        }
        return v
    }

    private static func couleur(_ d: [String: Any], _ cle: String, _ contexte: String,
                                _ err: inout [String]) -> CouleurProfil? {
        guard let brut = d[cle] else { return nil }
        guard let s = brut as? String, estHexValide(s) else {
            err.append(Textes.Profil.couleurAttendue(contexte, cle, brut))
            return nil
        }
        return CouleurProfil(hex: s)
    }

    /// `true` et `false` arrivent en `NSNumber` : seul leur identifiant de type
    /// les distingue d'un 0 ou d'un 1.
    private static func estBooleen(_ n: NSNumber) -> Bool {
        CFGetTypeID(n) == CFBooleanGetTypeID()
    }

    /// `#RRGGBB`, et rien d'autre — pas d'alpha hexadécimal : le schéma sépare
    /// toujours la couleur de l'opacité.
    static func estHexValide(_ s: String) -> Bool {
        guard s.count == 7, s.hasPrefix("#") else { return false }
        return s.dropFirst().allSatisfy { $0.isHexDigit }
    }
}
