// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesProfils.swift — le contrat partagé, éprouvé dans les deux sens.
//
// Le critère d'acceptation du lot 6 tient en deux phrases, et elles ne se
// contrôlent pas au même endroit :
//
// 1. « Un profil écrit par le prototype Python est accepté sans retouche. »
//    Se vérifie ICI, sur le fichier même que le prototype livre.
// 2. « Un profil produit par l'app est accepté par le prototype. »
//    Ne peut PAS se vérifier ici : seul le prototype sait ce qu'il accepte.
//    L'application écrit donc ses profils avec `--profils <dossier>`, et
//    `Scripts/verifier.sh` les fait relire par `charger_profil()` du prototype.
//    Un contrôle qui se contenterait de relire ses propres écrits ne prouverait
//    rien de ce critère-là.

import Foundation

enum ControlesProfils {

    static func executer(_ r: Rapport) {
        r.section("Profils — lecture du schéma v1")
        lectureSchema(r)

        r.section("Profils — un profil du prototype, accepté sans retouche")
        profilDuPrototype(r)

        r.section("Profils — conversion d'un profil version 1")
        conversionV1(r)

        r.section("Profils — validation : champs inconnus refusés")
        validation(r)

        r.section("Profils — écriture et aller-retour")
        allerRetour(r)

        r.section("Profils — ce que l'app écrit, et ce que le prototype en fait")
        ecritureEtroite(r)

        r.section("Profils — préréglages livrés")
        prereglages(r)

        r.section("Profils — mémorisation du dernier profil utilisé")
        MainActor.assumeIsolated { memorisation(r) }

        r.section("Profils — le logo, et ses deux pièges")
        MainActor.assumeIsolated { piegesDuLogo(r) }
    }

    // MARK: - Le profil livré par le prototype

    /// Le contenu EXACT de `~/Developer/NONP-Habillage/profil-nonp-defaut.json`,
    /// recopié ici le 28/08/2026.
    ///
    /// Recopié, et non lu depuis le prototype : les contrôles doivent tourner
    /// sans lui, et l'invariant nº5 interdit d'y toucher — pas de le lire. Le
    /// contrôle suivant relit d'ailleurs le vrai fichier quand il est là, et
    /// signale toute divergence entre les deux.
    static let profilPrototype = """
    {
      "schema_version": 1,
      "nom": "NONP (défaut)",
      "logo": {
        "actif": true,
        "fichier": "logo_circle.png",
        "position": {
          "preset": "haut-gauche"
        },
        "taille_pct_hauteur": 11.5,
        "marge_pct_hauteur": 4.0,
        "opacite": 1.0
      },
      "sous_titre": {
        "police": "Arial",
        "taille_pct_hauteur": 7.2,
        "couleur_texte": "#FFFFFF",
        "contour": {
          "couleur": "#000000",
          "epaisseur_pct_hauteur": 0.6
        },
        "bandeau": {
          "actif": true,
          "couleur": "#0067F6",
          "opacite": 1.0,
          "padding_pct_hauteur": 1.9,
          "espaces_lateraux": 4
        },
        "marge_basse_pct_hauteur": 7.2,
        "marge_laterale_pct_largeur": 3.0,
        "lignes_max": 2
      }
    }
    """

    private static func profilDuPrototype(_ r: Rapport) {
        guard let p = try? ProfilJSON.decoder(
            Data(profilPrototype.utf8),
            base: URL(fileURLWithPath: "/prototype")) else {
            r.verifier("le profil livré par le prototype est accepté", false); return
        }
        r.verifier("le profil livré par le prototype est accepté sans retouche", true)
        r.egal("son nom est repris", p.nom, "NONP (défaut)")
        r.egal("police", p.police, "Arial")
        r.egal("taille : 7,2 % → ratio", p.tailleRatio, 0.072)
        r.egal("contour : 0,6 %", p.contourRatio, 0.006)
        r.egal("marge basse : 7,2 %", p.margeBasseRatio, 0.072)
        r.egal("marge latérale : 3 % de la LARGEUR", p.margeLateraleRatioLargeur, 0.03)
        r.egal("lignes maximum", p.lignesMax, 2)
        r.egal("couleur du bandeau : le bleu NONP",
               ProfilJSON.hex(p.bandeauCouleur), "#0067F6")
        r.verifier("ses 4 espaces latéraux sont convertis en marge de texte "
                   + "(\(String(format: "%.2f", p.bandeauMargeTexteRatioLargeur * 100)) % "
                   + "de la largeur)",
                   abs(p.bandeauMargeTexteRatioLargeur - 0.0561) < 0.0005)
        r.egal("logo : 11,5 % de la hauteur", p.logoTailleRatio, 0.115)
        r.egal("logo : coin haut-gauche", p.logoPosition, .coin(.hautGauche))

        // Les trois champs ajoutés le 23/08 sont ABSENTS de ce fichier. Leurs
        // valeurs par défaut doivent reproduire le comportement historique,
        // sans quoi un profil du prototype ne rendrait plus comme avant — c'est
        // la promesse qui autorise le schéma à rester en version 1.
        r.egal("mode absent → « ajuste », comme avant l'amendement",
               p.bandeauMode, .ajuste)
        r.egal("hauteur_fixe_lignes absent → 0, hauteur automatique",
               p.bandeauHauteurFixeLignes, 0)
        r.egal("longueur de ligne cible absente du v1 → déduite de la taille",
               p.longueurLigneCible, 32)

        // Le chemin du logo est RELATIF au fichier de profil, comme le schéma le
        // dit et comme le prototype le résout.
        r.egal("le chemin du logo est résolu relativement au profil",
               p.logoFichier?.path, "/prototype/logo_circle.png")

        // Le vrai fichier, s'il est là : de quoi voir venir une divergence.
        let vrai = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Developer/NONP-Habillage/profil-nonp-defaut.json")
        if let donnees = try? Data(contentsOf: vrai) {
            let recopie = (try? JSONSerialization.jsonObject(
                with: Data(profilPrototype.utf8))) as? NSDictionary
            let original = (try? JSONSerialization.jsonObject(with: donnees)) as? NSDictionary
            r.verifier("la copie de contrôle est fidèle au fichier du prototype",
                       recopie != nil && recopie == original)
            r.verifier("et le vrai fichier du prototype est accepté tel quel",
                       (try? ProfilJSON.decoder(donnees, base: vrai.deletingLastPathComponent())) != nil)
        } else {
            r.nonExecute("comparaison avec le fichier réel du prototype",
                         motif: "prototype absent de \(vrai.path)")
        }
    }

    // MARK: - Conversion d'un profil version 1

    /// Un profil v1 est LU, converti, et la conversion est DITE.
    private static func conversionV1(_ r: Rapport) {
        guard let lecture = try? ProfilJSON.decoderDetaille(
            Data(profilPrototype.utf8),
            base: URL(fileURLWithPath: "/prototype")) else {
            r.verifier("un profil v1 est lu", false); return
        }
        r.verifier("un profil version 1 est lu et converti, pas refusé",
                   lecture.migration != nil)
        let m = lecture.migration ?? ""
        r.verifier("la conversion DIT ce qu'elle a fait — une conversion "
                   + "silencieuse est une modification silencieuse",
                   m.contains("espaces_lateraux") && m.contains("marge_texte_pct_largeur"))
        r.verifier("elle dit POURQUOI : l'unité était adossée à la hauteur",
                   m.localizedCaseInsensitiveContains("hauteur")
                   && m.localizedCaseInsensitiveContains("largeur"))
        r.verifier("elle nomme le format de référence de la conversion",
                   m.contains("16:9 1080p"))

        // Mode « pleine-largeur » : conversion exacte, sans convention.
        let pleine = """
        {"schema_version": 1, "nom": "P",
         "sous_titre": {"police": "Arial", "taille_pct_hauteur": 7.2,
                        "couleur_texte": "#FFFFFF",
                        "bandeau": {"actif": true, "mode": "pleine-largeur",
                                    "marge_interieure_pct_largeur": 8}}}
        """
        let lu = try? ProfilJSON.decoderDetaille(Data(pleine.utf8), base: nil)
        r.egal("mode « pleine-largeur » : la marge intérieure devient la marge "
               + "du texte, à l'identique",
               lu?.profil.bandeauMargeTexteRatioLargeur, 0.08)
        r.verifier("et la conversion le dit sans invoquer de convention",
                   lu?.migration?.localizedCaseInsensitiveContains(
                    "le rendu ne change pas") == true)

        // Refus MOTIVÉ : convertir des espaces exige de mesurer une espace
        // dans la police du profil. Absente, on ne convertit pas.
        let policeAbsente = """
        {"schema_version": 1, "nom": "P",
         "sous_titre": {"police": "Police Absolument Absente", "taille_pct_hauteur": 7.2,
                        "couleur_texte": "#FFFFFF",
                        "bandeau": {"actif": true, "espaces_lateraux": 4}}}
        """
        var refus: [String] = []
        do { _ = try ProfilJSON.decoder(Data(policeAbsente.utf8), base: nil) }
        catch let e as ErreurProfil { refus = e.anomalies }
        catch { refus = ["\(error)"] }
        r.verifier("police absente : la conversion est refusée, pas bricolée",
                   !refus.isEmpty)
        r.verifier("et le refus est MOTIVÉ — il nomme la police et l'invariant "
                   + "qui l'interdit (\(refus.first ?? "aucun message"))",
                   refus.first?.contains("Police Absolument Absente") == true
                   && refus.first?.contains("nº4") == true)

        // Une version qu'on ne sait pas lire : ce qui a changé, pas « inconnue ».
        var v3: [String] = []
        do {
            _ = try ProfilJSON.decoder(Data(##"{"schema_version": 3, "nom": "P", "sous_titre": {"police": "Arial", "taille_pct_hauteur": 7.2, "couleur_texte": "#FFFFFF"}}"##.utf8), base: nil)
        } catch let e as ErreurProfil { v3 = e.anomalies } catch {}
        r.verifier("une version inconnue est refusée en disant lesquelles sont "
                   + "lues (\(v3.first ?? "aucun message"))",
                   v3.first?.contains("convertis automatiquement") == true)

        // Les champs disparus sont REFUSÉS dans un fichier v2 : sans quoi deux
        // champs décriraient encore la même chose.
        for disparu in ["espaces_lateraux", "marge_interieure_pct_largeur"] {
            let json = """
            {"schema_version": 2, "nom": "P",
             "sous_titre": {"police": "Arial", "taille_pct_hauteur": 7.2,
                            "couleur_texte": "#FFFFFF",
                            "bandeau": {"actif": true, "\(disparu)": 4}}}
            """
            var e: [String] = []
            do { _ = try ProfilJSON.decoder(Data(json.utf8), base: nil) }
            catch let err as ErreurProfil { e = err.anomalies } catch {}
            r.verifier("« \(disparu) » dans un fichier v2 est refusé",
                       e.contains { $0.contains(disparu) })
        }
        // Et réciproquement, les champs de la v2 sont refusés dans un v1.
        let v2DansV1 = """
        {"schema_version": 1, "nom": "P",
         "sous_titre": {"police": "Arial", "taille_pct_hauteur": 7.2,
                        "couleur_texte": "#FFFFFF", "longueur_ligne_cible": 32}}
        """
        var e: [String] = []
        do { _ = try ProfilJSON.decoder(Data(v2DansV1.utf8), base: nil) }
        catch let err as ErreurProfil { e = err.anomalies } catch {}
        r.verifier("« longueur_ligne_cible » dans un fichier v1 est refusé",
                   e.contains { $0.contains("longueur_ligne_cible") })
    }

    // MARK: - Lecture

    private static func lectureSchema(_ r: Rapport) {
        // Le minimum que le schéma exige, et rien d'autre.
        let minimal = """
        {"schema_version": 1, "nom": "Minimal",
         "sous_titre": {"police": "Arial", "taille_pct_hauteur": 5,
                        "couleur_texte": "#FFFFFF"}}
        """
        guard let p = try? ProfilJSON.decoder(Data(minimal.utf8), base: nil) else {
            r.verifier("un profil minimal est accepté", false); return
        }
        r.verifier("un profil minimal — les trois champs obligatoires — est accepté", true)
        r.egal("sans section logo : aucun logo", p.logoActif, false)
        r.egal("sans section bandeau : aucun fond", p.bandeauActif, false)

        // Les deux formes de position du logo.
        for (nom, json, attendu) in [
            ("preset", ##"{"preset": "bas-droit"}"##, PositionLogo.coin(.basDroit)),
            ("libre", ##"{"x_pct": 25, "y_pct": 80}"##, .libre(xPct: 25, yPct: 80)),
        ] {
            let texte = """
            {"schema_version": 1, "nom": "P",
             "logo": {"actif": false, "position": \(json)},
             "sous_titre": {"police": "Arial", "taille_pct_hauteur": 5,
                            "couleur_texte": "#FFFFFF"}}
            """
            let lu = try? ProfilJSON.decoder(Data(texte.utf8), base: nil)
            r.egal("position du logo, forme « \(nom) »", lu?.logoPosition, attendu)
        }

        // L'opacité du bandeau est un champ SÉPARÉ de la couleur — le schéma
        // l'exige (« pas d'alpha hexadécimal »).
        let semiTransparent = """
        {"schema_version": 1, "nom": "P",
         "sous_titre": {"police": "Arial", "taille_pct_hauteur": 5,
                        "couleur_texte": "#FFFFFF",
                        "bandeau": {"actif": true, "couleur": "#000000", "opacite": 0.6}}}
        """
        let lu = try? ProfilJSON.decoder(Data(semiTransparent.utf8), base: nil)
        r.egal("la couleur et l'opacité du bandeau restent deux champs",
               lu?.bandeauCouleur, CouleurProfil(hex: "#000000", opacite: 0.6))

        // La longueur de ligne cible n'a pas de champ : elle se DÉDUIT de la
        // taille. Provisoire, et posé à la décision nº6.
        for (pct, attendu) in [(5.4, 42), (6.3, 37), (7.2, 32), (8.4, 28)] {
            let texte = """
            {"schema_version": 1, "nom": "P",
             "sous_titre": {"police": "Arial", "taille_pct_hauteur": \(pct),
                            "couleur_texte": "#FFFFFF"}}
            """
            let lu = try? ProfilJSON.decoder(Data(texte.utf8), base: nil)
            r.egal("taille \(pct) % → longueur de ligne cible déduite",
                   lu?.longueurLigneCible, attendu)
        }
    }

    // MARK: - Validation

    private static func validation(_ r: Rapport) {
        func anomalies(_ json: String) -> [String] {
            do {
                _ = try ProfilJSON.decoder(Data(json.utf8), base: nil)
                return []
            } catch let e as ErreurProfil {
                return e.anomalies
            } catch {
                return ["\(error)"]
            }
        }

        // LE point du lot : un champ inconnu est REFUSÉ, pas ignoré.
        let inconnu = """
        {"schema_version": 1, "nom": "P", "couleur_du_ciel": "#0000FF",
         "sous_titre": {"police": "Arial", "taille_pct_hauteur": 5,
                        "couleur_texte": "#FFFFFF", "gras": true}}
        """
        let a = anomalies(inconnu)
        r.verifier("un champ inconnu à la racine est refusé "
                   + "(\(a.first ?? "aucune anomalie"))",
                   a.contains { $0.contains("couleur_du_ciel") })
        r.verifier("un champ inconnu dans « sous_titre » est refusé",
                   a.contains { $0.contains("gras") })
        r.egal("les DEUX sont signalées, pas seulement la première", a.count, 2)

        // Un champ obligatoire absent.
        r.verifier("« nom » absent est signalé",
                   anomalies(##"{"schema_version": 1, "sous_titre": {"police": "A", "taille_pct_hauteur": 5, "couleur_texte": "#FFFFFF"}}"##)
                       .contains { $0.contains("nom") })
        r.verifier("« sous_titre » absent est signalé",
                   anomalies(##"{"schema_version": 1, "nom": "P"}"##)
                       .contains { $0.contains("sous_titre") })

        // Les bornes du schéma.
        for (cas, json, motCle) in [
            ("taille hors bornes",
             ##"{"schema_version": 1, "nom": "P", "sous_titre": {"police": "A", "taille_pct_hauteur": 99, "couleur_texte": "#FFFFFF"}}"##,
             "taille_pct_hauteur"),
            ("lignes_max hors bornes",
             ##"{"schema_version": 1, "nom": "P", "sous_titre": {"police": "A", "taille_pct_hauteur": 5, "couleur_texte": "#FFFFFF", "lignes_max": 9}}"##,
             "lignes_max"),
            ("couleur mal formée",
             ##"{"schema_version": 1, "nom": "P", "sous_titre": {"police": "A", "taille_pct_hauteur": 5, "couleur_texte": "bleu"}}"##,
             "couleur_texte"),
            ("mode inconnu",
             ##"{"schema_version": 1, "nom": "P", "sous_titre": {"police": "A", "taille_pct_hauteur": 5, "couleur_texte": "#FFFFFF", "bandeau": {"actif": true, "mode": "centre"}}}"##,
             "mode"),
            ("preset de logo inconnu",
             ##"{"schema_version": 1, "nom": "P", "logo": {"actif": false, "position": {"preset": "milieu"}}, "sous_titre": {"police": "A", "taille_pct_hauteur": 5, "couleur_texte": "#FFFFFF"}}"##,
             "preset"),
            ("version de schéma inattendue",
             ##"{"schema_version": 3, "nom": "P", "sous_titre": {"police": "A", "taille_pct_hauteur": 5, "couleur_texte": "#FFFFFF"}}"##,
             "schema_version"),
        ] {
            let e = anomalies(json)
            r.verifier("\(cas) : refusé, et le message nomme le champ "
                       + "(\(e.first ?? "aucune anomalie"))",
                       e.contains { $0.contains(motCle) })
        }

        // `true` n'est pas un nombre, même si NSNumber le pontifie.
        r.verifier("un booléen là où un nombre est attendu est refusé",
                   !anomalies(##"{"schema_version": 1, "nom": "P", "sous_titre": {"police": "A", "taille_pct_hauteur": true, "couleur_texte": "#FFFFFF"}}"##).isEmpty)

        // Un fichier corrompu : message clair, aucun rendu (critère du cahier).
        r.verifier("un JSON illisible produit un message, pas une exception nue",
                   !anomalies("{ ceci n'est pas du JSON").isEmpty)
        r.verifier("un JSON qui n'est pas un objet est refusé",
                   !anomalies("[1, 2, 3]").isEmpty)

        // Les messages sont EN FRANÇAIS.
        let tous = anomalies(inconnu) + anomalies("{ pas du JSON")
        r.verifier("tous les messages sont en français",
                   tous.allSatisfy { $0.contains("champ") || $0.contains("JSON")
                       || $0.contains("doit") || $0.contains("profil") })
        r.verifier("aucun message ne laisse filtrer un terme technique anglais",
                   !tous.contains { $0.lowercased().contains("unexpected")
                       || $0.lowercased().contains("invalid value") })
    }

    // MARK: - Écriture

    private static func allerRetour(_ r: Rapport) {
        for profil in [ProfilHabillage.neutre, .nonpHistorique] {
            guard let donnees = try? ProfilJSON.encoder(profil, cheminLogo: nil),
                  let relu = try? ProfilJSON.decoder(donnees, base: nil) else {
                r.verifier("\(profil.nom) : aller-retour", false); continue
            }
            // Le logo mis à part — il n'a pas de fichier dans les préréglages —,
            // tout doit revenir à l'identique.
            var attendu = profil
            attendu.logoActif = false
            attendu.logoFichier = nil
            r.egal("\(profil.nom) : le profil relu est identique à l'écrit",
                   relu, attendu)
        }

        // Les nombres sont écrits LISIBLES : 7.2, pas 7.199999999999999. Même
        // procédé que le prototype (`%g`), pour que les deux écrivent pareil.
        guard let donnees = try? ProfilJSON.encoder(.nonpHistorique, cheminLogo: nil),
              let texte = String(data: donnees, encoding: .utf8) else {
            r.verifier("écriture du profil NONP", false); return
        }
        r.verifier("les pourcentages sont écrits lisibles (7.2, pas 7.1999…)",
                   texte.contains("7.2") && !texte.contains("7.19999"))
        r.verifier("les couleurs sont écrites en #RRGGBB majuscules",
                   texte.contains("#0067F6"))
        r.verifier("aucun alpha hexadécimal ne se glisse dans une couleur",
                   !texte.contains("#0067F6FF"))

        // Un profil réglé finement, avec toutes les valeurs déplacées : c'est
        // l'aller-retour qui compte, pas les préréglages seuls.
        var fin = ProfilHabillage.neutre
        fin.nom = "Réglé à la main"
        fin.police = "Georgia"
        fin.tailleRatio = 0.0567
        fin.margeBasseRatio = 0.123
        fin.margeLateraleRatioLargeur = 0.075
        fin.lignesMax = 3
        fin.couleurTexte = CouleurProfil(hex: "#FFD400")
        fin.contourCouleur = CouleurProfil(hex: "#123456")
        fin.contourRatio = 0.011
        fin.bandeauCouleur = CouleurProfil(hex: "#0067F6", opacite: 0.42)
        fin.bandeauMode = .pleineLargeur
        fin.bandeauPaddingRatio = 0.031
        fin.bandeauMargeTexteRatioLargeur = 0.08
        fin.longueurLigneCible = 38
        fin.logoRecadreEnCercle = true
        fin.bandeauHauteurFixeLignes = 3
        fin.logoPosition = .libre(xPct: 12.5, yPct: 87.5)
        fin.logoTailleRatio = 0.2
        fin.logoMargeRatio = 0.06
        fin.logoOpacite = 0.75
        guard let d2 = try? ProfilJSON.encoder(fin, cheminLogo: nil),
              let relu = try? ProfilJSON.decoder(d2, base: nil) else {
            r.verifier("profil réglé finement : aller-retour", false); return
        }
        var attendu = fin
        attendu.logoActif = false
        attendu.logoFichier = nil
        r.egal("un profil réglé finement revient à l'identique", relu, attendu)
    }

    /// Ce que l'app écrit, et ce que le prototype en fait.
    ///
    /// **La réponse a changé le 28/08 avec la version 2 du schéma.** Au temps 1,
    /// l'app s'astreignait à n'écrire un champ facultatif que s'il s'écartait de
    /// sa valeur par défaut, pour qu'un profil resté dans ce que le prototype
    /// sait rendre lui demeure lisible. La décision nº6 a rendu cette
    /// gymnastique sans objet : le prototype vérifie `schema_version == 1` avant
    /// tout le reste, donc il refuse désormais TOUT profil écrit par l'app.
    ///
    /// C'est le coût accepté de l'option C, et la décision nº5 l'avait déjà
    /// pesé : le prototype prend sa retraite avec l'app native, et le sens qui
    /// compte — ses profils lus par l'app — reste sans restriction.
    ///
    /// Ce qui se contrôle ici, c'est donc l'INVERSE de ce qu'on contrôlait :
    /// que l'app écrive bien du v2, et que l'avertissement d'enregistrement le
    /// dise. La preuve que le prototype refuse, elle, se fait chez lui —
    /// `Scripts/profils_python.py`.
    private static func ecritureEtroite(_ r: Rapport) {
        func champsEcrits(_ profil: ProfilHabillage) -> [String: Set<String>] {
            guard let d = try? ProfilJSON.encoder(profil, cheminLogo: "logo.png"),
                  let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
            else { return [:] }
            let st = o["sous_titre"] as? [String: Any] ?? [:]
            return [
                "": Set(o.keys),
                "logo": Set((o["logo"] as? [String: Any] ?? [:]).keys),
                "sous_titre": Set(st.keys),
                "bandeau": Set((st["bandeau"] as? [String: Any] ?? [:]).keys),
            ]
        }

        // La version, et les champs qui n'existent qu'en v2.
        for profil in [ProfilHabillage.nonpHistorique, .neutre] {
            guard let d = try? ProfilJSON.encoder(profil, cheminLogo: nil),
                  let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
            else { r.verifier("écriture de \(profil.nom)", false); continue }
            r.egal("\(profil.nom) : écrit en version \(ProfilJSON.versionSchema)",
                   (o["schema_version"] as? NSNumber)?.intValue, 2)
        }
        let nonp = champsEcrits(.nonpHistorique)
        r.verifier("la marge du texte est écrite — c'est la commande unique",
                   nonp["bandeau"]?.contains("marge_texte_pct_largeur") == true)
        r.verifier("la longueur de ligne cible est écrite — elle a un champ",
                   nonp["sous_titre"]?.contains("longueur_ligne_cible") == true)
        r.verifier("« espaces_lateraux » a disparu de ce que l'app écrit",
                   nonp["bandeau"]?.contains("espaces_lateraux") == false)
        r.verifier("« marge_interieure_pct_largeur » aussi",
                   nonp["bandeau"]?.contains("marge_interieure_pct_largeur") == false)

        // Le recadrage rond : écrit seulement quand il est demandé.
        var rond = ProfilHabillage.nonpHistorique
        rond.logoRecadreEnCercle = true
        r.verifier("le recadrage rond n'est écrit que s'il est demandé",
                   champsEcrits(.nonpHistorique)["logo"]?
                       .contains("recadre_en_cercle") == false
                   && champsEcrits(rond)["logo"]?
                       .contains("recadre_en_cercle") == true)

        // `mode` et `hauteur_fixe_lignes` gardent la règle du temps 1 : un
        // fichier de profil ne porte que ce qu'on a réellement choisi.
        r.verifier("« mode » reste tu quand il vaut « ajuste »",
                   nonp["bandeau"]?.contains("mode") == false)
        r.verifier("profil neutre : « mode » est écrit, parce qu'il ne vaut plus "
                   + "« ajuste »",
                   champsEcrits(.neutre)["bandeau"]?.contains("mode") == true)

        // ── L'AVERTISSEMENT D'ENREGISTREMENT ───────────────────────────────
        //
        // Il ne dépend plus du profil : c'est la VERSION qui fait refuser.
        for profil in [ProfilHabillage.nonpHistorique, .neutre, rond] {
            let annonce = ProfilJSON.champsInconnusDuPrototype(profil)
            r.verifier("\(profil.nom) : l'annonce commence par la version, "
                       + "qui suffit à faire refuser (\(annonce.first ?? "rien"))",
                       annonce.first == "schema_version 2")
        }
        r.verifier("l'annonce du neutre nomme aussi ses champs propres",
                   Set(ProfilJSON.champsInconnusDuPrototype(.neutre))
                       .isSuperset(of: ["mode", "hauteur_fixe_lignes",
                                        "marge_texte_pct_largeur",
                                        "longueur_ligne_cible"]))
        r.verifier("le message nomme la version et ne bloque pas l'enregistrement",
                   Textes.Profil.inconnuDuPrototype(["x"]).contains("version 2")
                   && Textes.Profil.inconnuDuPrototype(["x"])
                       .localizedCaseInsensitiveContains("refusera"))

        // Le logo « actif » dit ce qui sera GRAVÉ : sans fichier, rien.
        guard let sansFichier = try? ProfilJSON.encoder(.nonpHistorique, cheminLogo: nil),
              let o = (try? JSONSerialization.jsonObject(with: sansFichier)) as? [String: Any],
              let logo = o["logo"] as? [String: Any] else {
            r.verifier("écriture d'un profil sans fichier de logo", false); return
        }
        r.egal("sans fichier de logo, « actif » vaut faux", logo["actif"] as? Bool, false)
        r.verifier("et aucun « fichier » n'est inventé", logo["fichier"] == nil)
    }

    // MARK: - Préréglages

    private static func prereglages(_ r: Rapport) {
        r.egal("le profil appliqué au premier lancement est le neutre",
               ProfilHabillage.neutre.nom, "Neutre")
        r.egal("l'autre préréglage livré est NONP",
               ProfilHabillage.nonpHistorique.nom, "NONP")
        r.verifier("le neutre ne pose aucun logo — imposer celui d'une "
                   + "association à l'ouverture serait déroutant",
                   !ProfilHabillage.neutre.logoActif)
        r.verifier("le neutre emploie le bandeau pleine largeur",
                   ProfilHabillage.neutre.bandeauMode == .pleineLargeur)
        r.verifier("NONP conserve le bandeau ajusté, comme le prototype",
                   ProfilHabillage.nonpHistorique.bandeauMode == .ajuste)
    }

    // MARK: - Mémorisation

    @MainActor
    private static func memorisation(_ r: Rapport) {
        let bac = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nonp-profils-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: bac, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bac) }
        let memoire = bac.appendingPathComponent("dernier-profil.json")

        // Un logo qui existe vraiment : c'est son chemin qu'on veut retrouver.
        let logo = bac.appendingPathComponent("mon-logo.png")
        FileManager.default.createFile(atPath: logo.path, contents: Data([0x89, 0x50]))

        var profil = ProfilHabillage.neutre
        profil.nom = "Le mien"
        profil.logoActif = true
        profil.logoFichier = logo
        profil.logoRecadreEnCercle = true
        profil.longueurLigneCible = 28
        profil.tailleRatio = 0.084
        profil.couleurTexte = CouleurProfil(hex: "#FFD400")

        MemoireProfil.enregistrer(profil, vers: memoire)
        r.verifier("le fichier de mémoire est écrit",
                   FileManager.default.fileExists(atPath: memoire.path))

        guard let relu = MemoireProfil.relire(depuis: memoire) else {
            r.verifier("le profil mémorisé est relu", false); return
        }
        r.egal("le nom est retrouvé", relu.nom, "Le mien")
        r.egal("la couleur du texte est retrouvée",
               ProfilJSON.hex(relu.couleurTexte), "#FFD400")
        r.egal("LE CHEMIN DU LOGO est retrouvé — on ne redépose pas son logo "
               + "à chaque lancement",
               relu.logoFichier?.path, logo.path)
        r.verifier("le logo est toujours actif", relu.logoActif)

        // Les deux réglages que le schéma partagé ne nomme pas. Ils vivent dans
        // l'enveloppe locale, PAS dans le profil : les y mêler amenderait le
        // contrat en douce (invariant nº6).
        r.egal("le recadrage rond, hors schéma, est mémorisé",
               relu.logoRecadreEnCercle, true)
        r.egal("la longueur de ligne cible, hors schéma, est mémorisée",
               relu.longueurLigneCible, 28)

        guard let donnees = try? Data(contentsOf: memoire),
              let enveloppe = (try? JSONSerialization.jsonObject(with: donnees))
                as? [String: Any] else {
            r.verifier("l'enveloppe est lisible", false); return
        }
        r.verifier("l'enveloppe ne porte plus que le profil : la section "
                   + "« reglages_app » a disparu, ses deux réglages ayant un "
                   + "champ au schéma v2",
                   enveloppe["profil"] != nil && enveloppe["reglages_app"] == nil)
        let corps = enveloppe["profil"] as? [String: Any] ?? [:]
        let st = corps["sous_titre"] as? [String: Any] ?? [:]
        r.verifier("les deux réglages sont dans le PROFIL, à leur place",
                   st["longueur_ligne_cible"] != nil
                   && (corps["logo"] as? [String: Any])?["recadre_en_cercle"] != nil)
        r.verifier("et il repasse par le validateur strict, sans passe-droit",
                   (try? ProfilJSON.decoder(
                       try JSONSerialization.data(withJSONObject: corps),
                       base: nil)) != nil)

        // Le chemin du logo est ABSOLU dans la mémoire locale : elle ne quitte
        // pas la machine, et c'est ce qui permet de retrouver le fichier.
        let logoEcrit = (corps["logo"] as? [String: Any])?["fichier"] as? String
        r.verifier("le chemin mémorisé est absolu (\(logoEcrit ?? "aucun"))",
                   logoEcrit.map { ($0 as NSString).isAbsolutePath } == true)

        // Un fichier abîmé ne doit pas empêcher l'application de s'ouvrir.
        try? Data("{ pas du JSON".utf8).write(to: memoire)
        r.verifier("une mémoire abîmée ne fait rien planter — le profil neutre "
                   + "prend le relais",
                   MemoireProfil.relire(depuis: memoire) == nil)
        MemoireProfil.effacer(memoire)
        r.verifier("sans mémoire, rien n'est relu — premier lancement",
                   MemoireProfil.relire(depuis: memoire) == nil)
    }

    // MARK: - Le logo et ses deux pièges

    @MainActor
    private static func piegesDuLogo(_ r: Rapport) {
        let bac = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nonp-logo-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: bac, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bac) }

        let ailleurs = bac.appendingPathComponent("ailleurs", isDirectory: true)
        try? FileManager.default.createDirectory(at: ailleurs, withIntermediateDirectories: true)
        let logo = ailleurs.appendingPathComponent("logo-rond.png")
        FileManager.default.createFile(atPath: logo.path, contents: Data([0x89, 0x50]))

        // ── PIÈGE Nº1 : le chemin absolu qui casse ──────────────────────────
        let etat = AppState()
        var profil = ProfilHabillage.neutre
        profil.logoActif = true
        profil.logoFichier = logo
        etat.profil = profil
        r.verifier("logo présent : rien à signaler", !etat.logoIntrouvable)

        try? FileManager.default.removeItem(at: logo)
        r.verifier("logo déplacé : l'application le REMARQUE", etat.logoIntrouvable)
        r.verifier("elle le dit, et nomme le fichier",
                   etat.messageLogoIntrouvable?.contains("logo-rond.png") == true)
        r.verifier("le message propose d'en choisir un autre",
                   etat.messageLogoIntrouvable?
                       .localizedCaseInsensitiveContains("choisissez") == true)

        // LE POINT QUI COMPTE : jamais de gravure silencieuse sans logo.
        etat.poserVideoDeControle(URL(fileURLWithPath: "/x.mp4"))
        r.verifier("« Habiller » est BLOQUÉ tant que le logo manque — jamais "
                   + "d'habillage silencieusement sans lui",
                   !etat.peutHabiller)

        // Et l'avertissement ne s'efface pas d'un clic : il est dérivé de
        // l'état, pas posé une fois dans le canal d'erreur.
        etat.effacerErreur()
        r.verifier("l'avertissement survit à un effacement d'erreur",
                   etat.messageLogoIntrouvable != nil)

        // En choisir un autre lève le blocage.
        let remplacant = ailleurs.appendingPathComponent("autre.png")
        FileManager.default.createFile(atPath: remplacant.path, contents: Data([0x89, 0x50]))
        etat.profil.logoFichier = remplacant
        r.verifier("un autre logo choisi, l'avertissement tombe",
                   !etat.logoIntrouvable && etat.messageLogoIntrouvable == nil)

        // ── PIÈGE Nº2 : un profil partagé ne porte pas un chemin local ──────
        var aPartager = ProfilHabillage.nonpHistorique
        aPartager.logoActif = true
        aPartager.logoFichier = remplacant
        let sortie = bac.appendingPathComponent("mon-profil.json")
        let copie = try? ProfilJSON.ecrire(aPartager, vers: sortie)

        guard let donnees = try? Data(contentsOf: sortie),
              let o = (try? JSONSerialization.jsonObject(with: donnees)) as? [String: Any],
              let lg = o["logo"] as? [String: Any] else {
            r.verifier("le profil partageable est écrit", false); return
        }
        let chemin = lg["fichier"] as? String
        r.egal("le chemin écrit est RELATIF, réduit au nom du fichier",
               chemin, "autre.png")
        r.verifier("aucun chemin de cette machine ne s'échappe dans le fichier",
                   !(String(data: donnees, encoding: .utf8) ?? "")
                       .contains(NSHomeDirectory()))
        r.verifier("le logo est recopié à côté du profil, pour qu'il parte avec lui",
                   copie != nil
                   && FileManager.default.fileExists(
                       atPath: bac.appendingPathComponent("autre.png").path))

        // Et le profil ainsi écrit se relit, logo compris — c'est la preuve que
        // le couple fichier + copie se suffit à lui-même.
        let relu = try? ProfilJSON.lire(sortie)
        r.egal("relu depuis son dossier, il retrouve son logo",
               relu?.logoFichier?.lastPathComponent, "autre.png")
        r.verifier("et ce logo existe vraiment",
                   relu.flatMap { $0.logoFichier }
                       .map { FileManager.default.fileExists(atPath: $0.path) } == true)

        // Exporter un profil dont le logo a disparu : refus explicite, pas un
        // fichier qui désignerait le vide.
        var casse = aPartager
        casse.logoFichier = bac.appendingPathComponent("jamais-existe.png")
        var refuse = false
        do { _ = try ProfilJSON.ecrire(casse, vers: bac.appendingPathComponent("x.json")) }
        catch { refuse = true }
        r.verifier("exporter un profil au logo disparu est refusé, avec un message",
                   refuse)
    }
}
