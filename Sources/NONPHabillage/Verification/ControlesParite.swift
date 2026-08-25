// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesParite.swift — comparaison directe avec la sortie du prototype.
//
// Le prototype Python reste l'outil de production (invariant nº5). Tant qu'il
// fait foi, un portage ne se juge pas à l'œil : il se compare. `test_iso_rendu.py`
// avait posé le précédent côté profils, avec 30 contrôles octet à octet ; c'est
// la même exigence ici, appliquée aux cues.
//
// Le fichier de référence est produit par `Scripts/parite_python.py`, qui
// IMPORTE `nonp_habille.py` depuis le prototype et l'exécute sans le modifier
// (invariant nº5 : ce dépôt ne touche jamais au prototype). Il n'est jamais
// versionné : il contient le texte des sous-titres, et le `.gitignore` du dépôt
// exclut ce contenu par principe. Il vit le temps d'une vérification, dans un
// dossier temporaire.
//
// Ce qui est comparé, fichier par fichier :
//   1. les cues LUES — début, fin, texte brut ;
//   2. les paramètres de mise en page en 16:9 ;
//   3. les cues GRAVÉES — début, fin, lignes.
//
// Ce qui ne l'est PAS : le comportement en 9:16. Il diverge volontairement
// (ADR §5), et cette divergence est mesurée ailleurs, par ControlesMiseEnPage.

import Foundation

/// Miroir du JSON écrit par `Scripts/parite_python.py`.
private struct ReferencePython: Decodable {
    struct Prototype: Decodable {
        let chemin: String
        let sha256: String
    }
    struct Parametres: Decodable {
        let size: Int
        let maxchars: Int
        let margin_lr: Int
        let marginv: Int
        let diam: Int
        let margin: Int
        let outline: Int
        let boxpad: Int
    }
    struct Fichier: Decodable {
        let nom: String
        let chemin: String
        /// [[début_ms, fin_ms, texte], …]
        let cues_source: [[CelluleCue]]
        /// [[début_ms, fin_ms, "ligne1\Nligne2"], …]
        let cues_gravees: [[CelluleCue]]
    }
    let prototype: Prototype
    let largeur: Int
    let hauteur: Int
    let lignes_max: Int
    let parametres: Parametres
    let fichiers: [Fichier]
}

/// Une cue Python est une liste hétérogène `[int, int, str]`. Ce type absorbe
/// les deux formes plutôt que d'imposer au harnais Python un format plus verbeux
/// que ce qu'il représente.
private enum CelluleCue: Decodable {
    case entier(Int)
    case texte(String)

    init(from decodeur: Decoder) throws {
        let v = try decodeur.singleValueContainer()
        if let i = try? v.decode(Int.self) { self = .entier(i); return }
        self = .texte(try v.decode(String.self))
    }

    var entierOuZero: Int { if case .entier(let i) = self { return i }; return 0 }
    var texteOuVide: String { if case .texte(let s) = self { return s }; return "" }
}

enum ControlesParite {

    static func executer(_ r: Rapport, referenceJSON: URL?) {
        r.section("Parité avec le prototype Python")

        guard let url = referenceJSON else {
            r.nonExecute("comparaison avec la sortie Python",
                         motif: "aucune référence fournie — passer --or-python <fichier.json>")
            return
        }
        guard let donnees = try? Data(contentsOf: url) else {
            r.verifier("lecture du fichier de référence \(url.lastPathComponent)", false)
            return
        }
        let reference: ReferencePython
        do {
            reference = try JSONDecoder().decode(ReferencePython.self, from: donnees)
        } catch {
            r.verifier("fichier de référence exploitable — \(error)", false)
            return
        }

        print("    prototype : \(reference.prototype.chemin)")
        print("    empreinte : \(reference.prototype.sha256.prefix(16))…")
        print("    résolution de comparaison : \(reference.largeur)×\(reference.hauteur)")
        print("    fichiers du corpus : \(reference.fichiers.count)")

        comparerParametres(r, reference)
        for fichier in reference.fichiers {
            comparerUnFichier(r, fichier, reference)
        }
    }

    // MARK: - Paramètres

    private static func comparerParametres(_ r: Rapport, _ ref: ReferencePython) {
        let p = MoteurMiseEnPage.calculer(
            profil: .nonpHistorique, largeur: ref.largeur, hauteur: ref.hauteur)
        r.egal("paramètres : taille de police", p.taille, ref.parametres.size)
        r.egal("paramètres : capacité de ligne", p.maxCaracteres, ref.parametres.maxchars)
        r.egal("paramètres : marge latérale", p.margeLaterale, ref.parametres.margin_lr)
        r.egal("paramètres : marge basse", p.margeBasse, ref.parametres.marginv)
        r.egal("paramètres : diamètre du logo", p.diametreLogo, ref.parametres.diam)
        r.egal("paramètres : marge du logo", p.margeLogo, ref.parametres.margin)
        r.egal("paramètres : contour", p.contour, ref.parametres.outline)
        r.egal("paramètres : marge intérieure du bandeau",
               p.paddingBandeau, ref.parametres.boxpad)
    }

    // MARK: - Un fichier du corpus

    private static func comparerUnFichier(
        _ r: Rapport, _ fichier: ReferencePython.Fichier, _ ref: ReferencePython
    ) {
        let url = URL(fileURLWithPath: fichier.chemin)
        let cues: [Cue]
        do {
            cues = try ParseurSousTitres.analyser(fichier: url)
        } catch let e as ErreurSousTitres {
            r.verifier("\(fichier.nom) : lecture — \(Textes.SousTitres.message(pour: e))", false)
            return
        } catch {
            r.verifier("\(fichier.nom) : lecture", false)
            return
        }

        // 1. Cues lues.
        let luesPython = fichier.cues_source.map {
            Cue(debutMs: $0[0].entierOuZero, finMs: $0[1].entierOuZero,
                texte: $0[2].texteOuVide)
        }
        if let ecart = premierEcart(cues, luesPython) {
            r.verifier("\(fichier.nom) : cues lues identiques — \(ecart)", false)
            return
        }
        r.verifier("\(fichier.nom) : \(cues.count) cues lues identiques", true)

        // 2. Cues gravées, à la résolution de comparaison.
        let graves = Segmenteur.segmenter(
            cues, maxCaracteres: ref.parametres.maxchars, lignesMax: ref.lignes_max)
        let gravesPython = fichier.cues_gravees.map {
            ($0[0].entierOuZero, $0[1].entierOuZero, $0[2].texteOuVide)
        }
        if graves.count != gravesPython.count {
            r.verifier("\(fichier.nom) : cues gravées identiques — "
                       + "\(graves.count) contre \(gravesPython.count) côté Python", false)
            return
        }
        for (i, (obtenu, attendu)) in zip(graves, gravesPython).enumerated() {
            if obtenu.debutMs != attendu.0 || obtenu.finMs != attendu.1
                || obtenu.texteStyleASS != attendu.2 {
                r.verifier("""
                    \(fichier.nom) : cues gravées identiques — écart à la réplique \(i + 1)
                          Python : \(attendu.0)–\(attendu.1) « \(attendu.2) »
                          Swift  : \(obtenu.debutMs)–\(obtenu.finMs) « \(obtenu.texteStyleASS) »
                    """, false)
                return
            }
        }
        r.verifier("\(fichier.nom) : \(graves.count) cues gravées identiques "
                   + "(texte et minutages)", true)
    }

    /// Renvoie une description du premier écart, ou `nil` si les deux suites
    /// coïncident. Décrire l'écart évite d'avoir à relancer avec un débogueur.
    private static func premierEcart(_ a: [Cue], _ b: [Cue]) -> String? {
        if a.count != b.count {
            return "\(a.count) cues contre \(b.count) côté Python"
        }
        for (i, (x, y)) in zip(a, b).enumerated() where x != y {
            return """
                écart à la cue \(i + 1)
                      Python : \(y.debutMs)–\(y.finMs) « \(y.texte) »
                      Swift  : \(x.debutMs)–\(x.finMs) « \(x.texte) »
                """
        }
        return nil
    }
}
