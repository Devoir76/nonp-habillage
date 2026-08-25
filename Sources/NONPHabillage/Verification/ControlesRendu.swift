// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesRendu.swift — les critères d'acceptation du lot 3, en nombres.
//
// Les trois exigences du lot portent sur des grandeurs, pas sur une impression :
//
//   « aucune ligne ne déborde de la largeur utile, quel que soit le format »
//   « en mode pleine-largeur, la bande couvre exactement la largeur »
//   « sa hauteur ne varie pas d'une réplique à l'autre quand
//     hauteur_fixe_lignes est renseigné »
//
// Elles se mesurent donc, et elles sont mesurées ici — sur les quatre formats
// exigés, pour les deux profils livrés, et sur le corpus réel quand il est
// fourni. Reste la parité VISUELLE avec le prototype, qui ne se mesure pas :
// c'est Éric qui tranche, sur les images produites par `--images`.

import Foundation
import CoreGraphics

enum ControlesRendu {

    /// Les quatre formats exigés par le lot, plus la 4K pour la mise à
    /// l'échelle.
    static let formats: [(nom: String, largeur: Int, hauteur: Int)] = [
        ("16:9", 1920, 1080),
        ("9:16", 1080, 1920),
        ("1:1", 1080, 1080),
        ("4:5", 1080, 1350),
        ("16:9 4K", 3840, 2160),
    ]

    static let profils: [(nom: String, profil: ProfilHabillage)] = [
        ("neutre", .neutre),
        ("NONP", .nonpHistorique),
    ]

    static func executer(_ r: Rapport, corpus: [URL]) {
        r.section("Rendu — la police manquante est une erreur (invariant nº4)")
        policeManquante(r)

        r.section("Rendu — mesure exacte plutôt qu'estimation")
        mesureExacte(r)

        r.section("Rendu — aucune ligne ne déborde, quel que soit le format")
        aucunDebordement(r, corpus: corpus)

        r.section("Rendu — bandeau pleine largeur")
        bandeauPleineLargeur(r)

        r.section("Rendu — hauteur de bande fixée")
        hauteurFixe(r)

        r.section("Rendu — le tracé aboutit")
        traceAboutit(r)
    }

    // MARK: - Invariant nº4

    private static func policeManquante(_ r: Rapport) {
        // Core Text substitue Helvetica en silence. Le refus doit venir de nous.
        var erreur: ErreurPolice? = nil
        do {
            _ = try PoliceSousTitre(famille: "Police Qui N'Existe Pas", taille: 40)
        } catch let e as ErreurPolice {
            erreur = e
        } catch {}
        r.verifier("une famille absente lève une erreur", erreur != nil)
        if case .familleIntrouvable(let demandee, _) = erreur {
            r.egal("l'erreur nomme la famille demandée", demandee, "Police Qui N'Existe Pas")
        }
        let message = erreur.map { Textes.Rendu.message(pour: $0) } ?? ""
        r.verifier("le message dit que rien n'a été substitué",
                   message.contains("substitu"))

        // Et les polices des deux profils livrés doivent, elles, exister.
        for (nom, profil) in profils {
            let ok = (try? PoliceSousTitre(famille: profil.police, taille: 40)) != nil
            r.verifier("profil \(nom) : la police « \(profil.police) » est présente", ok)
        }
    }

    // MARK: - Mesure

    private static func mesureExacte(_ r: Rapport) {
        guard let police = try? PoliceSousTitre(famille: "Arial", taille: 78) else {
            r.verifier("Arial disponible pour la mesure", false)
            return
        }
        // Une mesure exacte doit dépendre du texte, pas seulement de sa
        // longueur : c'est précisément ce que l'estimation « 0,72 × taille »
        // ne savait pas faire.
        let etroit = police.largeur(de: "lililililil")
        let large = police.largeur(de: "WMWMWMWMWMW")
        r.verifier("la mesure distingue « lil… » de « WMW… » (même nombre de "
                   + "caractères)", large > etroit * 1.5)

        let estimation = MesureurHistorique().largeurMoyenneCaractere(taillePolice: 78)
        let mesure = MesureurCoreText(famille: "Arial")
            .largeurMoyenneCaractere(taillePolice: 78)
        r.verifier("la moyenne mesurée (\(String(format: "%.1f", mesure)) px) diffère de "
                   + "l'estimation du prototype (\(String(format: "%.1f", estimation)) px)",
                   abs(mesure - estimation) > 1)
    }

    // MARK: - Débordement

    /// Textes de contrôle : des répliques réelles, longues, avec des mots que
    /// l'estimation à 0,72 sous-évaluait.
    private static let repliquesDeControle = [
        "Il m'a dit qu'il n'avait rien vu ce jour-là, vers quatre heures du matin.",
        "MONSIEUR LE PRÉSIDENT, JE VOUS DEMANDE DE RÉPONDRE À LA QUESTION POSÉE.",
        "anticonstitutionnellement, disait-il, en martelant chaque syllabe",
        "WWW MMM WWW MMM WWW MMM WWW MMM WWW MMM",
        "Oui.",
    ]

    private static func aucunDebordement(_ r: Rapport, corpus: [URL]) {
        var textes = repliquesDeControle
        // Le corpus réel, quand il est là : c'est lui qui compte.
        for url in corpus.prefix(12) {
            if let cues = try? ParseurSousTitres.analyser(fichier: url) {
                textes.append(contentsOf: cues.map(\.texte))
            }
        }

        for (nomProfil, profil) in profils {
            for (nomFormat, w, h) in formats {
                let params = MoteurMiseEnPage.calculer(
                    profil: profil, largeur: w, hauteur: h,
                    mesureur: MesureurCoreText(famille: profil.police))
                guard let police = try? PoliceSousTitre(
                    famille: profil.police, taille: params.taille) else {
                    r.verifier("\(nomProfil) \(nomFormat) : police", false)
                    continue
                }
                let largeurUtile = GeometrieSousTitres.largeurUtile(
                    profil: profil, parametres: params, largeurVideo: w, police: police)

                var pireDebordement = 0.0
                var texteFautif = ""
                for texte in textes {
                    let lignes = GeometrieSousTitres.decouper(
                        texte: texte, police: police, largeurUtile: largeurUtile)
                    for ligne in lignes {
                        // Un mot seul plus large que la ligne est le seul cas
                        // toléré : le couper violerait l'invariant nº1.
                        let motUnique = TextePython.decouperEnMots(ligne).count <= 1
                        let debord = police.largeur(de: ligne) - largeurUtile
                        if debord > 0.5 && !motUnique && debord > pireDebordement {
                            pireDebordement = debord
                            texteFautif = ligne
                        }
                    }
                }
                r.verifier("\(nomProfil) \(nomFormat) : aucune ligne ne déborde"
                           + (pireDebordement > 0
                              ? " — « \(texteFautif) » dépasse de \(Int(pireDebordement)) px"
                              : ""),
                           pireDebordement == 0)
            }
        }
    }

    // MARK: - Bandeau

    private static func bandeauPleineLargeur(_ r: Rapport) {
        let profil = ProfilHabillage.neutre
        for (nomFormat, w, h) in formats {
            let params = MoteurMiseEnPage.calculer(
                profil: profil, largeur: w, hauteur: h,
                mesureur: MesureurCoreText(famille: profil.police))
            guard let police = try? PoliceSousTitre(
                famille: profil.police, taille: params.taille) else { continue }
            let pose = GeometrieSousTitres.poser(
                lignes: ["Une ligne courte."], profil: profil, parametres: params,
                police: police, largeurVideo: w, hauteurVideo: h)
            r.egal("\(nomFormat) : une seule bande", pose.bandeaux.count, 1)
            guard let bande = pose.bandeaux.first else { continue }
            r.egal("\(nomFormat) : la bande part du bord gauche", bande.minX, 0)
            r.egal("\(nomFormat) : la bande couvre exactement la largeur",
                   bande.width, CGFloat(w))
        }

        // En mode « ajuste », au contraire, le fond épouse chaque ligne : c'est
        // le comportement historique que le préréglage NONP conserve.
        let nonp = ProfilHabillage.nonpHistorique
        let params = MoteurMiseEnPage.calculer(
            profil: nonp, largeur: 1920, hauteur: 1080,
            mesureur: MesureurCoreText(famille: nonp.police))
        if let police = try? PoliceSousTitre(famille: nonp.police, taille: params.taille) {
            let pose = GeometrieSousTitres.poser(
                lignes: ["Courte.", "Une ligne nettement plus longue que la précédente."],
                profil: nonp, parametres: params, police: police,
                largeurVideo: 1920, hauteurVideo: 1080)
            r.egal("NONP « ajuste » : un fond par ligne", pose.bandeaux.count, 2)
            r.verifier("NONP « ajuste » : le fond épouse chaque ligne",
                       pose.bandeaux[0].width < pose.bandeaux[1].width)
            r.verifier("NONP « ajuste » : chaque fond est centré",
                       pose.bandeaux.allSatisfy { abs($0.midX - 960) < 1 })

            // Le fond déborde de sa ligne : sur une ligne remplissant la
            // largeur utile, il doit malgré tout rester dans le cadre.
            let largeurUtile = GeometrieSousTitres.largeurUtile(
                profil: nonp, parametres: params, largeurVideo: 1920, police: police)
            let longue = GeometrieSousTitres.decouper(
                texte: String(repeating: "interminablement long ", count: 12),
                police: police, largeurUtile: largeurUtile)
            let poseLongue = GeometrieSousTitres.poser(
                lignes: [longue.first ?? ""], profil: nonp, parametres: params,
                police: police, largeurVideo: 1920, hauteurVideo: 1080)
            let deborde = poseLongue.bandeaux.filter { $0.minX < 0 || $0.maxX > 1920 }
            r.egal("NONP « ajuste » : le fond d'une ligne pleine reste dans le cadre",
                   deborde.map { Int($0.width) }, [])
        }
    }

    private static func hauteurFixe(_ r: Rapport) {
        // Le profil neutre fixe la hauteur à deux lignes. Une réplique d'une
        // ligne et une réplique de deux doivent produire la MÊME bande.
        let profil = ProfilHabillage.neutre
        r.verifier("le profil neutre renseigne hauteur_fixe_lignes",
                   profil.bandeauHauteurFixeLignes > 0)

        for (nomFormat, w, h) in formats {
            let params = MoteurMiseEnPage.calculer(
                profil: profil, largeur: w, hauteur: h,
                mesureur: MesureurCoreText(famille: profil.police))
            guard let police = try? PoliceSousTitre(
                famille: profil.police, taille: params.taille) else { continue }

            let uneLigne = GeometrieSousTitres.poser(
                lignes: ["Oui."], profil: profil, parametres: params,
                police: police, largeurVideo: w, hauteurVideo: h)
            let deuxLignes = GeometrieSousTitres.poser(
                lignes: ["Première ligne de la réplique,", "et la seconde ligne."],
                profil: profil, parametres: params, police: police,
                largeurVideo: w, hauteurVideo: h)

            r.egal("\(nomFormat) : la bande garde la même hauteur",
                   uneLigne.bandeaux.first?.height, deuxLignes.bandeaux.first?.height)
            r.egal("\(nomFormat) : la bande garde la même position",
                   uneLigne.bandeaux.first?.minY, deuxLignes.bandeaux.first?.minY)
        }

        // Sans l'option, la bande suit le nombre de lignes — comportement
        // historique, conservé.
        var sansOption = ProfilHabillage.neutre
        sansOption.bandeauHauteurFixeLignes = 0
        let params = MoteurMiseEnPage.calculer(
            profil: sansOption, largeur: 1920, hauteur: 1080,
            mesureur: MesureurCoreText(famille: sansOption.police))
        if let police = try? PoliceSousTitre(famille: sansOption.police, taille: params.taille) {
            let une = GeometrieSousTitres.poser(
                lignes: ["Oui."], profil: sansOption, parametres: params,
                police: police, largeurVideo: 1920, hauteurVideo: 1080)
            let deux = GeometrieSousTitres.poser(
                lignes: ["Première ligne,", "seconde ligne."], profil: sansOption,
                parametres: params, police: police, largeurVideo: 1920, hauteurVideo: 1080)
            r.verifier("sans l'option, la bande suit le nombre de lignes",
                       (une.bandeaux.first?.height ?? 0) < (deux.bandeaux.first?.height ?? 0))
        }
    }

    // MARK: - Tracé

    private static func traceAboutit(_ r: Rapport) {
        // Un rendu complet sur un fond synthétique : on ne juge pas l'aspect
        // ici — Éric le fera sur les images —, seulement que la chaîne va
        // jusqu'au bout et produit bien des pixels.
        for (nomProfil, profil) in profils {
            let (w, h) = (960, 540)
            guard let fond = ImagesReference.fondUni(
                largeur: w, hauteur: h, gris: 0.35) else {
                r.verifier("\(nomProfil) : fond de contrôle", false)
                continue
            }
            let params = MoteurMiseEnPage.calculer(
                profil: profil, largeur: w, hauteur: h,
                mesureur: MesureurCoreText(famille: profil.police))
            do {
                let image = try RenduSousTitres.rendre(
                    fond: fond,
                    texte: "Il m'a dit qu'il n'avait rien vu ce jour-là, "
                         + "vers quatre heures du matin.",
                    profil: profil, parametres: params)
                r.egal("\(nomProfil) : l'image rendue garde ses dimensions",
                       "\(image.width)×\(image.height)", "\(w)×\(h)")
                r.verifier("\(nomProfil) : le rendu a modifié l'image",
                           ImagesReference.differe(image, de: fond))
            } catch {
                r.verifier("\(nomProfil) : rendu — \(error)", false)
            }
        }
    }
}
