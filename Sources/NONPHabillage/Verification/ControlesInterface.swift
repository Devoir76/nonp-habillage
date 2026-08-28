// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesInterface.swift — ce qui, du lot 5, se mesure sans cliquer.
//
// Une interface se juge à l'usage, et c'est Éric qui la jugera. Mais tout ne
// relève pas du jugement : qu'un aperçu reflète réellement un réglage, qu'une
// phrase de référence soit calibrée sur la taille choisie, qu'un logo posé sur
// le bandeau déclenche l'avertissement — cela se vérifie par des nombres, et
// c'est fait ici.
//
// Ce qui reste à l'œil : la disposition, la lisibilité, l'agrément. Les
// contrôles ne prétendent pas s'y substituer.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SwiftUI
import AppKit

enum ControlesInterface {

    static func executer(_ r: Rapport) {
        r.section("Interface — l'aperçu reflète chaque réglage")
        apercuReagit(r)

        r.section("Interface — les quatre tailles nommées")
        textePermanent(r)

        r.section("Interface — tailles nommées")
        taillesNommees(r)

        r.section("Interface — liste de polices")
        polices(r)

        r.section("Interface — avertissements de zone")
        avertissements(r)

        r.section("Interface — les trois usages")
        troisUsages(r)

        r.section("Interface — l'accueil tient sans défilement")
        MainActor.assumeIsolated { dispositionAccueil(r) }

        r.section("Interface — deux colonnes, aperçu entier, réglages atteignables")
        MainActor.assumeIsolated { dispositionDeuxColonnes(r) }

        r.section("Interface — aucun libellé de la colonne ne se casse")
        MainActor.assumeIsolated { libellesDeLaColonne(r) }

        r.section("Interface — l'accueil montre une image de la vidéo")
        imageDAccueil(r)
        MainActor.assumeIsolated { dispositionImageAccueil(r) }

        r.section("Interface — retirer la vidéo")
        MainActor.assumeIsolated { retirerLaVideo(r) }

        r.section("Interface — logo recadré en cercle")
        logoRond(r)

        r.section("Interface — marge intérieure : retirée du volet, vivante au profil")
        margeInterieure(r)

        r.section("Interface — « Habiller » dans la barre d'action du bas")
        MainActor.assumeIsolated { barreAction(r) }

        r.section("Interface — hauteur constante : une case, la valeur de « Lignes maximum »")
        MainActor.assumeIsolated { hauteurConstante(r) }

        r.section("Interface — fond de l'aperçu : le contrôle se dit lui-même")
        fondDeLApercu(r)
        MainActor.assumeIsolated { dispositionBarreDeChoix(r) }
    }

    // MARK: - Marge intérieure

    /// Le curseur « Marge intérieure » a quitté le volet Personnaliser au lot 5 :
    /// près de 90 % de sa course ne produisait aucun effet, et l'expliquer à
    /// l'utilisateur revenait à s'excuser d'un réglage inutile. Le chiffre exact
    /// est mesuré plus bas, et reporté dans le rapport plutôt que recopié —
    /// l'estimation de départ, « 24 % de marge, donc 96 % de course inerte »,
    /// était arrondie vers le haut.
    ///
    /// **Ce qui compte désormais, c'est que le CHAMP soit intact.** Il reste au
    /// schéma partagé, dans le profil et dans la géométrie : un fichier de profil
    /// venu du prototype doit rendre exactement comme avant, alors même que plus
    /// aucune commande ne l'expose. C'est le genre de garantie qu'un retrait
    /// d'interface casse en silence — d'où ces contrôles, qui vont jusqu'aux
    /// pixels plutôt que de s'arrêter à la mise en page.
    private static func margeInterieure(_ r: Rapport) {
        var profil = ProfilHabillage.neutre
        let (w, h) = (1920, 1080)

        // Mode « ajuste » : sans effet, par définition du schéma.
        profil.bandeauMode = .ajuste
        let ajuste0 = largeurDecoupe(profil, marge: 0, w, h)
        let ajuste20 = largeurDecoupe(profil, marge: 0.20, w, h)
        r.egal("mode « ajuste » : la marge intérieure est ignorée (schéma v1)",
               ajuste0, ajuste20)

        // Mode « pleine-largeur » : elle borne le texte, mais seulement quand
        // elle passe sous la longueur de ligne cible.
        profil.bandeauMode = .pleineLargeur
        let large = largeurDecoupe(profil, marge: 0.03, w, h)
        let serree = largeurDecoupe(profil, marge: 0.25, w, h)
        r.verifier("sans curseur, le champ agit toujours : une marge serrée "
                   + "réduit la colonne (\(Int(large)) → \(Int(serree)) px)",
                   serree < large)

        // Jusqu'aux PIXELS : la mise en page pourrait changer sans que le rendu
        // bouge. C'est la vraie promesse faite au fichier de profil.
        if let fond = fondDeControle() {
            var p = profil
            p.bandeauMargeInterieureRatioLargeur = 0.03
            let a = try? Apercu.composer(fond: fond, profil: p,
                                         texte: texteDEssai, avecSousTitres: true)
            p.bandeauMargeInterieureRatioLargeur = 0.25
            let b = try? Apercu.composer(fond: fond, profil: p,
                                         texte: texteDEssai, avecSousTitres: true)
            let bouge: Bool
            if let a = a?.image, let b = b?.image {
                bouge = ImagesReference.differe(a, de: b)
            } else {
                bouge = false
            }
            r.verifier("un profil qui pose une marge intérieure rend toujours "
                       + "différemment — le champ va jusqu'aux pixels", bouge)
        }

        // Les deux profils livrés gardent leur valeur : rien n'a bougé côté
        // fichier, seul le volet a changé.
        r.egal("le profil neutre garde sa marge intérieure",
               ProfilHabillage.neutre.bandeauMargeInterieureRatioLargeur, 0.03)
        r.egal("le préréglage NONP garde la sienne",
               ProfilHabillage.nonpHistorique.bandeauMargeInterieureRatioLargeur, 0.03)

        // POURQUOI le curseur est parti, en chiffres. Le seuil est cherché sur
        // toute la course qu'aurait eue le curseur — 0 à 25 %.
        let course = 0.25
        var seuil = course
        for pas in 0...250 {
            let marge = course * Double(pas) / 250
            var p = profil
            p.bandeauMargeInterieureRatioLargeur = marge
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: p, largeurVideo: w, hauteurVideo: h) else { continue }
            if !mep.margeInterieureSansEffet { seuil = marge; break }
        }
        let inerte = Int((seuil / course * 100).rounded())
        r.verifier("16:9 1080p : la marge ne mord qu'à partir de "
                   + "\(String(format: "%.1f", seuil * 100)) %, soit \(inerte) % "
                   + "d'une course de 0 à 25 % sans aucun effet — c'est ce qui a "
                   + "retiré le curseur du volet", inerte >= 85)

        // Sur une vidéo étroite, elle mord bien plus tôt : c'est là qu'elle
        // servirait, et c'est ce que la décision nº6 devra trancher au lot 6.
        profil.bandeauMargeInterieureRatioLargeur = 0.10
        let verticale = try? MiseEnPageRendu.calculer(
            profil: profil, largeurVideo: 1080, hauteurVideo: 1920)
        r.verifier("en 9:16, la marge agirait dès 10 % — matière à la décision nº6",
                   verticale?.margeInterieureSansEffet == false)
    }

    private static func largeurDecoupe(
        _ profil: ProfilHabillage, marge: Double, _ w: Int, _ h: Int
    ) -> Double {
        var p = profil
        p.bandeauMargeInterieureRatioLargeur = marge
        return (try? MiseEnPageRendu.calculer(
            profil: p, largeurVideo: w, hauteurVideo: h))?.largeurColonneTexte ?? 0
    }


    // MARK: - Barre d'action

    /// « Habiller » est descendu de la barre des dépôts au pied de la fenêtre.
    ///
    /// Ce qui se juge à l'œil — une barre d'action au bas de la fenêtre, action
    /// alignée à droite — reste le jugement d'Éric, capture 4 à l'appui. Ce qui
    /// se mesure, c'est la promesse qui a motivé le déplacement : **toujours
    /// visible**. Elle se démontre en trois temps.
    ///
    /// 1. La barre ne DÉFILE pas. C'est ce qu'il fallait éviter avant tout : la
    ///    colonne des réglages défile, et un bouton posé dedans disparaît dès
    ///    qu'on descend chercher la taille du logo. La barre étant sœur de cette
    ///    colonne et non fille, sa hauteur ne bouge pas d'un point quand le
    ///    volet s'ouvre ni quand les réglages s'allongent — alors que la hauteur
    ///    du panneau, elle, change beaucoup. Les deux mesures ensemble le disent.
    /// 2. La barre TIENT dans la fenêtre, volet fermé comme ouvert, sans rien
    ///    pousser dehors.
    /// 3. Elle ne prend pas sa place sur l'aperçu : les minima de l'aperçu
    ///    valent toujours une fois sa hauteur retranchée (voir
    ///    `dispositionDeuxColonnes`, qui la retranche vraiment).
    @MainActor
    private static func barreAction(_ r: Rapport) {
        _ = NSApplication.shared

        let barreFermee = hauteurBarreAction(voletOuvert: false, avecLogo: false)
        let barreOuverte = hauteurBarreAction(voletOuvert: true, avecLogo: false)
        let barreReglagesLongs = hauteurBarreAction(voletOuvert: true, avecLogo: true)

        r.verifier("la barre d'action a une hauteur de barre, pas de panneau "
                   + "(\(Int(barreFermee)) points)",
                   barreFermee > 0 && barreFermee <= 80)
        r.verifier("la place que la fenêtre lui réserve couvre celle qu'elle "
                   + "prend (\(Int(barreFermee)) points pour "
                   + "\(Int(Fenetre.hauteurBarreAction)) réservés)",
                   barreFermee <= Fenetre.hauteurBarreAction)

        // 1. Hors de la zone défilante.
        r.egal("sa hauteur ne change pas quand le volet s'ouvre",
               Int(barreOuverte), Int(barreFermee))
        let panneauCourt = hauteurPanneauReglages(avecLogo: false)
        let panneauLong = hauteurPanneauReglages(avecLogo: true)
        r.verifier("la colonne des réglages, elle, s'allonge vraiment "
                   + "(\(Int(panneauCourt)) → \(Int(panneauLong)) points)",
                   panneauLong > panneauCourt + 50)
        r.egal("des réglages plus longs ne déplacent pas la barre d'un point — "
               + "elle n'est pas dans la colonne qui défile",
               Int(barreReglagesLongs), Int(barreFermee))

        // 2. Elle tient dans la fenêtre, avec ce qu'il y a au-dessus.
        let entrees = hauteurBarreEntrees()
        r.verifier("volet fermé : dépôts + barre d'action tiennent dans la "
                   + "fenêtre (\(Int(entrees + barreFermee)) points pour "
                   + "\(Int(Fenetre.hauteurFermee)))",
                   entrees + barreFermee <= Fenetre.hauteurFermee)
        r.verifier("volet ouvert : dépôts + aperçu minimal + barre d'action "
                   + "tiennent dans la fenêtre minimale "
                   + "(\(Int(entrees + Fenetre.hauteurMinimaleApercu + barreOuverte)) "
                   + "points pour \(Int(Fenetre.hauteurMinimaleOuverte)))",
                   entrees + Fenetre.hauteurMinimaleApercu + barreOuverte
                   <= Fenetre.hauteurMinimaleOuverte)

        // 3. Le bouton reste commandé par le même état qu'avant : le déplacer
        //    ne devait rien changer à QUAND il est actionnable.
        let etat = AppState()
        r.verifier("sans vidéo, « Habiller » est impossible", !etat.peutHabiller)
        etat.profil.logoActif = true
        etat.profil.logoFichier = URL(fileURLWithPath: "/x.png")
        r.verifier("un logo seul ne suffit pas sans vidéo", !etat.peutHabiller)

        // Et « il n'y a rien à graver » a suivi le bouton : la phrase n'explique
        // qu'un bouton grisé, elle doit être à côté de lui.
        r.verifier("la phrase qui explique le bouton grisé existe toujours",
                   !Textes.Interface.rienAGraver.isEmpty)
    }

    /// Hauteur naturelle de la barre d'action, mesurée sur la VRAIE vue.
    @MainActor
    private static func hauteurBarreAction(voletOuvert: Bool,
                                           avecLogo: Bool) -> CGFloat {
        let etat = AppState()
        etat.voletOuvert = voletOuvert
        if avecLogo {
            etat.profil.logoActif = true
            etat.profil.logoFichier = URL(fileURLWithPath: "/x.png")
        }
        let hote = NSHostingView(
            rootView: BarreAction().environmentObject(etat)
                .frame(width: Fenetre.largeurIdealeOuverte))
        hote.layoutSubtreeIfNeeded()
        return hote.fittingSize.height
    }

    /// Hauteur naturelle du contenu de la colonne défilante.
    @MainActor
    private static func hauteurPanneauReglages(avecLogo: Bool) -> CGFloat {
        let etat = AppState()
        if avecLogo {
            etat.profil.logoActif = true
            etat.profil.logoFichier = URL(fileURLWithPath: "/x.png")
        }
        let hote = NSHostingView(
            rootView: PanneauPersonnaliserView().environmentObject(etat)
                .frame(width: Fenetre.largeurReglages - 32))
        hote.layoutSubtreeIfNeeded()
        return hote.fittingSize.height
    }

    // MARK: - Hauteur constante

    /// Le menu « Hauteur constante : N lignes » est devenu une CASE À COCHER qui
    /// reprend la valeur de « Lignes maximum ».
    ///
    /// Même situation que la marge intérieure, et donc mêmes exigences : une
    /// commande quitte l'interface, le champ du schéma partagé reste. Ce qui
    /// doit être prouvé n'est pas que la case fonctionne — c'est que
    /// `bandeau.hauteur_fixe_lignes` n'a rien perdu au passage. Les contrôles
    /// vont donc jusqu'aux PIXELS, et parcourent TOUTE la course que le schéma
    /// autorise (0 à 4), y compris les valeurs que plus aucune commande ne sait
    /// choisir : c'est exactement là qu'un retrait d'interface casse un champ en
    /// silence.
    @MainActor
    private static func hauteurConstante(_ r: Rapport) {
        // La case dit la vérité sur les deux profils livrés, sans les toucher.
        let neutre = AppState()
        neutre.profil = .neutre
        r.verifier("profil neutre : la case est cochée", neutre.hauteurConstante)
        r.egal("profil neutre : le champ garde sa valeur",
               ProfilHabillage.neutre.bandeauHauteurFixeLignes, 2)
        r.egal("le préréglage NONP garde la sienne",
               ProfilHabillage.nonpHistorique.bandeauHauteurFixeLignes, 0)

        let nonp = AppState()
        nonp.profil = .nonpHistorique
        r.verifier("préréglage NONP : la case est décochée", !nonp.hauteurConstante)

        // Cocher reprend « Lignes maximum ». Décocher rend la hauteur au texte.
        let etat = AppState()
        etat.profil = .neutre
        etat.lignesMax = 3
        r.egal("cochée, la case suit « Lignes maximum » quand il change",
               etat.profil.bandeauHauteurFixeLignes, 3)
        etat.hauteurConstante = false
        r.egal("décochée, le champ retombe à 0 — hauteur automatique",
               etat.profil.bandeauHauteurFixeLignes, 0)
        etat.lignesMax = 4
        r.egal("décochée, elle ne suit plus rien",
               etat.profil.bandeauHauteurFixeLignes, 0)
        etat.hauteurConstante = true
        r.egal("recochée, elle reprend la valeur courante de « Lignes maximum »",
               etat.profil.bandeauHauteurFixeLignes, 4)

        // La valeur LIBRE du schéma survit : un profil venu du prototype peut
        // figer 3 lignes là où le texte en autorise 2, et rien ne le réécrit.
        var libre = ProfilHabillage.neutre
        libre.lignesMax = 2
        libre.bandeauHauteurFixeLignes = 3
        let charge = AppState()
        charge.profil = libre
        r.egal("un profil qui dissocie les deux valeurs est chargé tel quel",
               charge.profil.bandeauHauteurFixeLignes, 3)
        r.verifier("la case l'affiche comme figé, sans y toucher",
                   charge.hauteurConstante
                   && charge.profil.bandeauHauteurFixeLignes == 3)

        // TOUTE la course du schéma reste vivante, commande ou pas : chaque
        // valeur de 1 à 4 donne une bande strictement plus haute.
        var hauteurs: [Int] = []
        for lignes in 0...4 {
            var p = ProfilHabillage.neutre
            p.bandeauHauteurFixeLignes = lignes
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: p, largeurVideo: 1920, hauteurVideo: 1080) else { continue }
            let pose = GeometrieSousTitres.poser(
                lignes: ["Oui."], profil: p, parametres: mep.parametres,
                police: mep.police, largeurVideo: 1920, hauteurVideo: 1080)
            hauteurs.append(Int(pose.bandeaux.first?.height ?? 0))
        }
        let figees = Array(hauteurs.dropFirst())
        r.verifier("de 1 à 4, chaque valeur du schéma donne une bande "
                   + "strictement plus haute \(figees) — le champ n'a rien perdu "
                   + "à voir sa commande remplacée",
                   figees.count == 4
                   && zip(figees, figees.dropFirst()).allSatisfy { $0 < $1 })
        // Et 0 vaut bien « automatique », pas « rien » : sur une réplique d'une
        // ligne, la bande automatique fait exactement une ligne. C'est ce que
        // dit le schéma, et ce qui coûterait cher à casser en silence — plus
        // aucune commande ne permet d'atteindre cette valeur au clic.
        r.egal("0 = hauteur automatique : sur une réplique d'une ligne, la bande "
               + "vaut celle d'une ligne (\(hauteurs.first ?? -1) points)",
               hauteurs.first, figees.first)

        // Jusqu'aux PIXELS : la géométrie pourrait bouger sans que le rendu suive.
        if let fond = fondDeControle() {
            var sans = ProfilHabillage.neutre
            sans.bandeauHauteurFixeLignes = 0
            var avec = ProfilHabillage.neutre
            avec.bandeauHauteurFixeLignes = 4
            let a = try? Apercu.composer(fond: fond, profil: sans,
                                         texte: "Oui.", avecSousTitres: true)
            let b = try? Apercu.composer(fond: fond, profil: avec,
                                         texte: "Oui.", avecSousTitres: true)
            let bouge: Bool
            if let a = a?.image, let b = b?.image {
                bouge = ImagesReference.differe(a, de: b)
            } else {
                bouge = false
            }
            r.verifier("un profil qui fige la hauteur rend différemment — "
                       + "le champ va jusqu'aux pixels", bouge)
        }

        // Ce que la case devait rendre lisible : les deux réglages ne font pas
        // la même chose, et l'interface le dit maintenant, sous la case.
        r.verifier("cochée, la phrase nomme la valeur reprise à « Lignes maximum »",
                   Textes.Interface.hauteurFixeActive(2).contains("2 lignes")
                   && Textes.Interface.hauteurFixeActive(2)
                       .contains(Textes.Interface.lignesMax))
        r.verifier("au singulier, elle s'accorde",
                   Textes.Interface.hauteurFixeActive(1).contains("1 ligne")
                   && !Textes.Interface.hauteurFixeActive(1).contains("1 lignes"))
        r.verifier("décochée, elle dit ce que le fond fait alors",
                   !Textes.Interface.hauteurFixeInactive.isEmpty
                   && Textes.Interface.hauteurFixeInactive
                       != Textes.Interface.hauteurFixeActive(2))
    }

    // MARK: - Fond de l'aperçu

    /// « Image de la vidéo » n'était pas compris, et l'explication vivait trop
    /// loin pour rattraper le nom.
    ///
    /// Le contrôle doit donc se dire lui-même : chaque entrée porte un libellé,
    /// et la réserve « aperçu seulement » tient sur la même ligne que le menu.
    private static func fondDeLApercu(_ r: Rapport) {
        // Six fonds, du plus sombre au plus clair — ce que produit
        // `ImagesVideo.instantsRepresentatifs`.
        let luminosites = [0.05, 0.22, 0.41, 0.58, 0.74, 0.93]
        let libelles = luminosites.enumerated().map {
            Textes.Interface.nomFond(index: $0.offset, total: luminosites.count,
                                     luminosite: $0.element)
        }

        // AUCUN numéro nu : c'est le défaut qu'on corrige. « 3/6 » tout seul
        // n'annonçait pas l'image qu'on allait obtenir.
        let nus = libelles.filter { !$0.contains("—") }
        r.egal("les six entrées sont libellées, aucune n'est un numéro nu",
               nus, [])
        r.verifier("chaque entrée annonce son rang", libelles.enumerated()
                   .allSatisfy { $0.element.hasPrefix("\($0.offset + 1)/6 ") })
        r.verifier("la première dit qu'elle est la plus sombre "
                   + "(« \(libelles[0]) »)",
                   libelles[0].hasSuffix(Textes.Interface.fondLePlusSombre))
        r.verifier("la dernière dit qu'elle est la plus claire "
                   + "(« \(libelles[5]) »)",
                   libelles[5].hasSuffix(Textes.Interface.fondLePlusClair))

        // L'échelle ne recule jamais : une image plus claire n'est jamais
        // qualifiée plus sombre que celle qui la précède.
        let echelle = [Textes.Interface.fondLePlusSombre, Textes.Interface.fondSombre,
                       Textes.Interface.fondMoyen, Textes.Interface.fondClair,
                       Textes.Interface.fondLePlusClair]
        // Le qualificatif EXACT, pas un suffixe : « le plus sombre » se termine
        // par « sombre », et une comparaison par suffixe confondrait les deux.
        let rangs = libelles.map { libelle -> Int in
            guard let separateur = libelle.range(of: " — ") else { return -1 }
            let qualificatif = String(libelle[separateur.upperBound...])
            return echelle.firstIndex(of: qualificatif) ?? -1
        }
        r.verifier("l'échelle des libellés est croissante \(rangs)",
                   !rangs.contains(-1)
                   && zip(rangs, rangs.dropFirst()).allSatisfy { $0 <= $1 })

        // Deux fonds seulement : les deux extrêmes, et rien entre eux.
        r.egal("à deux fonds, les deux libellés restent justes",
               [Textes.Interface.nomFond(index: 0, total: 2, luminosite: 0.1),
                Textes.Interface.nomFond(index: 1, total: 2, luminosite: 0.9)],
               ["1/2 — \(Textes.Interface.fondLePlusSombre)",
                "2/2 — \(Textes.Interface.fondLePlusClair)"])

        // Le nom du menu, et la réserve qui l'accompagne.
        r.verifier("le menu s'appelle « \(Textes.Interface.fondDeLApercu) » et "
                   + "ne promet plus rien sur la vidéo",
                   Textes.Interface.fondDeLApercu.localizedCaseInsensitiveContains("aperçu")
                   && !Textes.Interface.fondDeLApercu.localizedCaseInsensitiveContains("vidéo"))
        r.verifier("la réserve dit que la vidéo exportée n'est pas concernée",
                   Textes.Interface.fondApercuSeulement
                       .localizedCaseInsensitiveContains("aperçu")
                   && Textes.Interface.fondApercuSeulement
                       .localizedCaseInsensitiveContains("export"))
        r.verifier("le conseil d'usage garde le critère de contraste de l'ADR §2",
                   Textes.Interface.fondDeLApercuConseil
                       .contains(Textes.Interface.fondLePlusSombre)
                   && Textes.Interface.fondDeLApercuConseil
                       .contains(Textes.Interface.fondLePlusClair))

        // Les deux phrases ont quitté la ligne pour l'infobulle du menu. Elles
        // n'ont pas été RÉSUMÉES : les perdre en chemin serait la seule façon
        // de rater cet allègement, puisque plus rien à l'écran ne les rappelle.
        let infobulle = Textes.Interface.fondDeLApercuInfobulle
        r.verifier("l'infobulle du menu porte la réserve, mot pour mot",
                   infobulle.contains(Textes.Interface.fondApercuSeulement))
        r.verifier("elle porte aussi le conseil d'usage, mot pour mot",
                   infobulle.contains(Textes.Interface.fondDeLApercuConseil))
        r.verifier("et rien d'autre — l'infobulle est la somme des deux "
                   + "(\(infobulle.count) caractères)",
                   infobulle.count == Textes.Interface.fondApercuSeulement.count
                   + Textes.Interface.fondDeLApercuConseil.count + 1)

        // Ce qui autorisait à les retirer de la ligne : les libellés du menu
        // disent déjà le sens du réglage. On ne survole pas pour savoir ce
        // qu'on choisit — seulement pour lever un doute.
        r.verifier("les libellés du menu suffisent sans l'infobulle : ils "
                   + "nomment les deux extrêmes",
                   Textes.Interface.nomFond(index: 0, total: 6, luminosite: 0)
                       .hasSuffix(Textes.Interface.fondLePlusSombre)
                   && Textes.Interface.nomFond(index: 5, total: 6, luminosite: 1)
                       .hasSuffix(Textes.Interface.fondLePlusClair))
    }

    /// **La ligne sous l'aperçu tient sur UNE ligne**, et dans la largeur
    /// minimale du volet.
    ///
    /// C'est la seule façon de savoir : une ligne trop chargée ne produit pas
    /// d'erreur, elle se replie en paragraphe — et le paragraphe prend sa place
    /// sur l'image, qui est la valeur du volet.
    ///
    /// L'ancien contrôle mesurait le volet entier et concluait que sa hauteur
    /// était « supérieure à zéro » : il ne pouvait rien dire. `BarreChoixApercu`
    /// étant devenue une vue à part entière, sa hauteur RÉELLE se mesure, et se
    /// compare à celle d'un menu seul — la hauteur d'une ligne de commandes.
    @MainActor
    private static func dispositionBarreDeChoix(_ r: Rapport) {
        _ = NSApplication.shared
        guard let sombre = fondDeControle(largeur: 320, hauteur: 180),
              let clair = fondDeControle(largeur: 320, hauteur: 180) else {
            r.verifier("fonds de contrôle", false); return
        }
        let etat = AppState()
        etat.voletOuvert = true
        etat.poserFondsDeControle((0..<6).map { i in
            (instant: Double(i), image: i < 3 ? sombre : clair,
             luminosite: Double(i) / 5)
        })
        r.egal("six fonds posés, le menu s'affiche", etat.fondsDisponibles.count, 6)

        let largeurUtile = Fenetre.largeurMinimaleApercu - 32
        let hote = NSHostingView(
            rootView: ApercuView().environmentObject(etat)
                .frame(width: largeurUtile))
        hote.layoutSubtreeIfNeeded()
        let taille = hote.fittingSize
        r.verifier("le volet d'aperçu tient dans sa largeur minimale sans être "
                   + "rogné (\(Int(taille.width)) points pour \(Int(largeurUtile)))",
                   taille.width <= largeurUtile + 1)

        // La hauteur d'un menu seul : l'étalon d'une ligne de commandes.
        let menuSeul = NSHostingView(
            rootView: Picker("", selection: .constant(0)) { Text("1/6").tag(0) }
                .pickerStyle(.menu).labelsHidden())
        menuSeul.layoutSubtreeIfNeeded()
        let uneLigne = menuSeul.fittingSize.height

        // Sans sous-titres chargés : le menu et la mention « phrase de
        // référence ». C'est l'état où la ligne portait le plus de texte.
        let ligne = NSHostingView(
            rootView: BarreChoixApercu().environmentObject(etat)
                .frame(width: largeurUtile))
        ligne.layoutSubtreeIfNeeded()
        r.verifier("sans sous-titres : la ligne du menu reste une ligne de "
                   + "commandes (\(Int(ligne.fittingSize.height)) points pour "
                   + "\(Int(uneLigne)) qu'en prend un menu seul)",
                   ligne.fittingSize.height <= uneLigne + 1)

        // Avec un fichier chargé — l'état COURANT : le menu, les chevrons et le
        // compteur. C'est là que la barre faisait une ligne et demie, « la plus
        // longue du fichier » s'écrivant sous le compteur.
        let avecST = AppState()
        avecST.voletOuvert = true
        avecST.poserFondsDeControle((0..<6).map { i in
            (instant: Double(i), image: i < 3 ? sombre : clair,
             luminosite: Double(i) / 5)
        })
        avecST.poserRepliquesDeControle((0..<57).map { i in
            Cue(debutMs: i * 2000, finMs: i * 2000 + 1800, texte: texteDEssai)
        })
        let ligneST = NSHostingView(
            rootView: BarreChoixApercu().environmentObject(avecST)
                .frame(width: largeurUtile))
        ligneST.layoutSubtreeIfNeeded()
        r.verifier("sous-titres chargés, première réplique : toujours une seule "
                   + "ligne (\(Int(ligneST.fittingSize.height)) points pour "
                   + "\(Int(uneLigne)))",
                   ligneST.fittingSize.height <= uneLigne + 1)

        // Et elle ne se replie pas quand on la serre : à la largeur minimale du
        // volet, elle garde la hauteur qu'elle a sans aucune contrainte.
        let libre = NSHostingView(
            rootView: BarreChoixApercu().environmentObject(etat))
        libre.layoutSubtreeIfNeeded()
        r.verifier("elle ne se replie pas à la largeur minimale du volet "
                   + "(\(Int(ligne.fittingSize.height)) points contre "
                   + "\(Int(libre.fittingSize.height)) sans contrainte)",
                   ligne.fittingSize.height <= libre.fittingSize.height + 0.5)

        // Plus rien n'escorte le menu : les deux phrases sont dans l'infobulle.
        // On le vérifie par la LARGEUR NATURELLE de la ligne — une phrase de
        // plus la ferait bondir de plusieurs centaines de points.
        r.verifier("la ligne ne traîne plus de phrase avec elle : elle réclame "
                   + "\(Int(libre.fittingSize.width)) points, moins que la "
                   + "largeur minimale du volet (\(Int(largeurUtile)))",
                   libre.fittingSize.width <= largeurUtile)
    }

    // MARK: - Deux colonnes

    /// À taille par défaut ET fenêtre agrandie : l'aperçu montre l'image
    /// ENTIÈRE, et tous les réglages restent atteignables.
    @MainActor
    private static func dispositionDeuxColonnes(_ r: Rapport) {
        _ = NSApplication.shared

        let tailles: [(String, CGSize)] = [
            ("taille par défaut", CGSize(width: Fenetre.largeurIdealeOuverte,
                                         height: Fenetre.hauteurIdealeOuverte)),
            ("taille minimale", CGSize(width: Fenetre.largeurMinimaleOuverte,
                                       height: Fenetre.hauteurMinimaleOuverte)),
            ("fenêtre agrandie", CGSize(width: 1800, height: 1150)),
        ]
        // Quatre formats de vidéo : ce qui tient en 16:9 peut déborder en 9:16.
        let formats: [(String, CGSize)] = [
            ("16:9", CGSize(width: 1920, height: 1080)),
            ("9:16", CGSize(width: 1080, height: 1920)),
            ("1:1", CGSize(width: 1080, height: 1080)),
            ("4:5", CGSize(width: 1080, height: 1350)),
        ]

        // La barre d'action du bas mange de la hauteur : la retrancher, plutôt
        // que de laisser les minima de l'aperçu se vérifier sur une place qui
        // n'existe plus.
        let barreAction = hauteurBarreAction(voletOuvert: true, avecLogo: false)

        for (nomTaille, fenetre) in tailles {
            // La place réellement laissée à l'aperçu : la fenêtre, moins la
            // colonne des réglages, moins la barre du haut, moins la barre
            // d'action du bas, moins les marges.
            let zone = CGSize(
                width: fenetre.width - Fenetre.largeurReglages - 32,
                height: fenetre.height - hauteurBarreEntrees() - barreAction - 90)

            r.verifier("\(nomTaille) : l'aperçu garde au moins "
                       + "\(Int(Fenetre.largeurMinimaleApercu)) points de large "
                       + "(\(Int(zone.width)))",
                       zone.width >= Fenetre.largeurMinimaleApercu - 32)
            r.verifier("\(nomTaille) : l'aperçu garde au moins "
                       + "\(Int(Fenetre.hauteurMinimaleApercu)) points de haut "
                       + "(\(Int(zone.height)))",
                       zone.height >= Fenetre.hauteurMinimaleApercu - 10)

            for (nomFormat, video) in formats {
                let affichee = Apercu.tailleAffichee(image: video, dans: zone)
                // Image ENTIÈRE : elle tient dans la zone…
                let tient = affichee.width <= zone.width + 0.5
                    && affichee.height <= zone.height + 0.5
                // …et le rapport est conservé, donc rien n'est rogné.
                let rapportVideo = video.width / video.height
                let rapportAffiche = affichee.height > 0
                    ? affichee.width / affichee.height : 0
                let memeRapport = abs(rapportVideo - rapportAffiche) < 0.02
                r.verifier("\(nomTaille) \(nomFormat) : image entière, non rognée "
                           + "(\(Int(affichee.width))×\(Int(affichee.height)))",
                           tient && memeRapport)
            }
        }

        // La fenêtre grandit : l'aperçu doit grandir avec elle.
        let petite = Apercu.tailleAffichee(
            image: CGSize(width: 1920, height: 1080),
            dans: CGSize(width: 600, height: 400))
        let grande = Apercu.tailleAffichee(
            image: CGSize(width: 1920, height: 1080),
            dans: CGSize(width: 1200, height: 800))
        r.verifier("l'aperçu grandit avec la fenêtre "
                   + "(\(Int(petite.width)) → \(Int(grande.width)) points)",
                   grande.width > petite.width)

        // Les réglages : la colonne est défilante, donc tous atteignables quelle
        // que soit la hauteur. Ce qui doit être vérifié, c'est qu'ils tiennent
        // en LARGEUR — une colonne trop étroite rognerait un curseur.
        let etat = AppState()
        etat.profil.logoActif = true
        etat.profil.logoFichier = URL(fileURLWithPath: "/x.png")
        let hote = NSHostingView(
            rootView: PanneauPersonnaliserView().environmentObject(etat)
                .frame(width: Fenetre.largeurUtileReglages))
        hote.layoutSubtreeIfNeeded()
        let taille = hote.fittingSize
        // Cette mesure ne dit RIEN des libellés — `fittingSize` d'une vue
        // contrainte rend la largeur qu'on lui a imposée. C'est
        // `libellesDeLaColonne` qui s'en charge, ligne par ligne.
        r.verifier("les réglages tiennent dans la colonne sans être rognés "
                   + "(\(Int(taille.width)) points pour "
                   + "\(Int(Fenetre.largeurUtileReglages)))",
                   taille.width <= Fenetre.largeurUtileReglages + 1)
        r.verifier("la colonne des réglages a une hauteur exploitable "
                   + "(\(Int(taille.height)) points, défilante)", taille.height > 200)

        // Et la fenêtre minimale doit vraiment loger les deux colonnes.
        r.verifier("la largeur minimale loge l'aperçu et les réglages",
                   Fenetre.largeurMinimaleOuverte
                   >= Fenetre.largeurMinimaleApercu + Fenetre.largeurReglages)
    }

    /// Hauteur de la barre du haut, mesurée sur la VRAIE vue.
    ///
    /// C'est la disposition AppKit qui répond, pas une estimation : l'estimer à
    /// la hausse faisait croire que l'aperçu n'avait que 150 points de haut à la
    /// taille minimale.
    ///
    /// Ce qu'elle mesure est la forme HAUTE — zones de dépôt vides, 120 points
    /// chacune. `chargerVideo` est asynchrone et le fichier n'existe pas : la
    /// vidéo n'arrive jamais, et les zones ne passent pas à leur forme compacte
    /// de 44 points. C'est sans gravité, et même utile : toute place calculée à
    /// partir de cette hauteur est la PIRE : à l'usage, volet ouvert, une vidéo
    /// est forcément chargée et la barre est plus courte. Un contrôle qui passe
    /// ici passe donc a fortiori. Mais il ne faut pas lire cette valeur comme
    /// « la hauteur de la barre en usage » — elle ne l'est pas.
    @MainActor
    private static func hauteurBarreEntrees() -> CGFloat {
        let etat = AppState()
        etat.voletOuvert = true
        let hote = NSHostingView(
            rootView: BarreEntrees().environmentObject(etat)
                .frame(width: Fenetre.largeurIdealeOuverte))
        hote.layoutSubtreeIfNeeded()
        return hote.fittingSize.height
    }

    // MARK: - Image de l'accueil

    /// Ce que l'accueil montre, volet fermé — et surtout ce qu'il ne montre PAS.
    ///
    /// Le piège est nommé : l'aperçu du volet affiche une phrase de référence
    /// quand aucun sous-titre n'est chargé, pour qu'on ne règle pas à l'aveugle.
    /// La même image sur l'accueil ferait croire que cette phrase sera gravée.
    /// C'est un mensonge que les pixels savent démentir, alors on le leur
    /// demande : sans sous-titres ni logo, l'accueil doit rendre le plan NU,
    /// octet pour octet.
    private static func imageDAccueil(_ r: Rapport) {
        guard let fond = fondDeControle() else {
            r.verifier("fond de contrôle", false); return
        }
        let profil = ProfilHabillage.neutre

        guard let nu = try? Apercu.composerAccueil(
            fond: fond, profil: profil, replique: nil) else {
            r.verifier("image d'accueil sans sous-titres", false); return
        }
        r.verifier("sans sous-titres ni logo : l'accueil montre le plan nu, "
                   + "sans phrase de référence ni bandeau vide",
                   !ImagesReference.differe(nu.image, de: fond))

        // ET LE VOLET AUSSI, depuis le lot 6. C'est le contrôle qui a changé de
        // sens : il exigeait auparavant que le volet, lui, affiche une phrase à
        // nous. Un texte qui n'est pas le sien, posé sur sa propre vidéo, se lit
        // comme un sous-titre qui va être gravé. Les réglages étant désormais
        // mémorisés, on règle une fois avec son vrai texte, et l'aperçu sans
        // fichier ne montre plus que le plan.
        let auVolet = try? Apercu.composer(
            fond: fond, profil: profil, lignes: [], avecSousTitres: false)
        r.verifier("le volet non plus n'invente aucun texte : le plan nu, "
                   + "octet pour octet",
                   auVolet.map { !ImagesReference.differe($0.image, de: fond) } == true)

        // Avec un fichier de sous-titres, l'accueil montre EXACTEMENT l'aperçu :
        // ce texte-là est réel, il sera gravé.
        let avecST = try? Apercu.composerAccueil(
            fond: fond, profil: profil, replique: texteDEssai)
        let apercu = try? Apercu.composer(
            fond: fond, profil: profil, texte: texteDEssai, avecSousTitres: true)
        let identiques: Bool
        if let a = avecST?.image, let b = apercu?.image {
            identiques = !ImagesReference.differe(a, de: b)
        } else {
            identiques = false
        }
        r.verifier("avec des sous-titres : l'accueil est exactement l'aperçu",
                   identiques)

        // Le logo, lui, figure sur l'accueil sans sous-titres : il sera gravé.
        if let fichier = fabriquerLogoDEssai() {
            defer { try? FileManager.default.removeItem(at: fichier) }
            var avecLogo = profil
            avecLogo.logoActif = true
            avecLogo.logoFichier = fichier
            let image = try? Apercu.composerAccueil(
                fond: fond, profil: avecLogo, replique: nil)
            r.verifier("un logo est gravé, donc il figure sur l'accueil",
                       image.map { ImagesReference.differe($0.image, de: fond) } == true)
            r.verifier("le logo reste saisissable : son rectangle est connu",
                       image?.rectangleLogo != nil)
        } else {
            r.verifier("fabrication du logo d'essai", false)
        }

        // Le bandeau vide était le second mensonge possible : en mode
        // `pleine-largeur`, une réplique sans ligne peignait quand même sa bande
        // en travers de l'image.
        var pleineLargeur = profil
        pleineLargeur.bandeauMode = .pleineLargeur
        pleineLargeur.bandeauActif = true
        let sansLigne = try? Apercu.composerAccueil(
            fond: fond, profil: pleineLargeur, replique: nil)
        r.verifier("mode « pleine-largeur » : aucune bande vide sur l'accueil",
                   sansLigne.map { !ImagesReference.differe($0.image, de: fond) } == true)
    }

    /// Un logo d'essai sur disque : `RenduLogo` lit un fichier, pas une image en
    /// mémoire. Fabriqué ici plutôt que versionné — le `.gitignore` exclut les
    /// médias.
    private static func fabriquerLogoDEssai() -> URL? {
        let cote = 128
        guard let ctx = CGContext(
            data: nil, width: cote, height: cote, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CouleurProfil.bleuNONP.cgColor)
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: cote, height: cote))
        guard let image = ctx.makeImage() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonp-logo-accueil.png")
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return url
    }

    /// La place laissée à l'image de l'accueil, volet fermé.
    ///
    /// Même méthode que pour les deux colonnes : la fenêtre, moins la barre du
    /// haut. La barre est mesurée dans sa forme HAUTE — voir
    /// `hauteurBarreEntrees` —, donc la place calculée ici est la pire ; la
    /// vraie, zones de dépôt compactes, est plus généreuse.
    @MainActor
    private static func dispositionImageAccueil(_ r: Rapport) {
        _ = NSApplication.shared

        let tailles: [(String, CGSize)] = [
            ("à l'ouverture", CGSize(width: Fenetre.largeurFermee,
                                     height: Fenetre.hauteurFermeeAvecVideo)),
            ("fenêtre agrandie", CGSize(width: 1400, height: 900)),
        ]

        // Comme pour les deux colonnes : la barre d'action du bas n'est pas de
        // la place disponible pour l'image.
        let barreAction = hauteurBarreAction(voletOuvert: false, avecLogo: false)

        for (nom, fenetre) in tailles {
            let zone = CGSize(
                width: fenetre.width - 32,
                height: fenetre.height - hauteurBarreEntrees() - barreAction - 60)
            r.verifier("\(nom) : l'image garde au moins "
                       + "\(Int(Fenetre.hauteurMinimaleImageAccueil)) points de haut "
                       + "(\(Int(zone.height)))",
                       zone.height >= Fenetre.hauteurMinimaleImageAccueil)

            for (format, video) in [("16:9", CGSize(width: 1920, height: 1080)),
                                    ("9:16", CGSize(width: 1080, height: 1920))] {
                let affichee = Apercu.tailleAffichee(image: video, dans: zone)
                r.verifier("\(nom) \(format) : image entière, non rognée "
                           + "(\(Int(affichee.width))×\(Int(affichee.height)))",
                           affichee.width <= zone.width + 0.5
                           && affichee.height <= zone.height + 0.5
                           && affichee.width > 0)
            }
        }

        // Une vidéo chargée fait grandir la fenêtre : sinon l'image ne serait
        // qu'une vignette, et ne confirmerait rien.
        r.verifier("l'accueil grandit quand une vidéo arrive "
                   + "(\(Int(Fenetre.hauteurFermee)) → "
                   + "\(Int(Fenetre.hauteurFermeeAvecVideo)) points)",
                   Fenetre.hauteurFermeeAvecVideo > Fenetre.hauteurFermee)
    }

    // MARK: - Retirer la vidéo

    /// Le fichier de sous-titres avait son bouton « Retirer », la vidéo non : on
    /// ne pouvait changer de vidéo qu'en relançant l'application.
    @MainActor
    private static func retirerLaVideo(_ r: Rapport) {
        let etat = AppState()
        etat.voletOuvert = true

        // Des sous-titres réellement chargés : c'est ce qui doit SURVIVRE.
        let srt = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonp-accueil-essai.srt")
        let contenu = """
            1
            00:00:01,000 --> 00:00:03,000
            Il m'a dit qu'il n'avait rien vu ce jour-là.

            """
        try? contenu.write(to: srt, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: srt) }
        etat.chargerSousTitres(srt)
        r.verifier("des sous-titres sont chargés pour l'essai", etat.sousTitres != nil)

        etat.retirerVideo()

        r.verifier("retirer la vidéo : plus de vidéo", etat.video == nil)
        r.verifier("retirer la vidéo : plus de définition ni de durée",
                   etat.tailleVideo == nil && etat.dureeVideo == 0)
        r.verifier("retirer la vidéo : plus d'image de fond",
                   etat.fondsDisponibles.isEmpty)
        r.verifier("retirer la vidéo : plus d'aperçu ni d'image d'accueil",
                   etat.apercu == nil && etat.imageAccueil == nil)
        r.verifier("retirer la vidéo : rien de la vidéo précédente ne subsiste "
                   + "(avertissements, mise en page, rectangle du logo)",
                   etat.avertissements.isEmpty && etat.miseEnPage == nil
                   && etat.rectangleLogo == nil)
        r.verifier("retirer la vidéo : le volet se referme", !etat.voletOuvert)
        r.verifier("retirer la vidéo : « Habiller » redevient impossible",
                   !etat.peutHabiller)

        // Et surtout : les sous-titres ne sont pas jetés au passage. Ce sont
        // deux dépôts distincts, et on change souvent de vidéo en gardant le
        // même habillage.
        r.verifier("retirer la vidéo garde les sous-titres chargés",
                   etat.sousTitres != nil && !etat.cues.isEmpty)

        // La réciproque tenait déjà, mais rien ne la vérifiait : retirer les
        // sous-titres ne doit pas retirer la vidéo.
        let autre = AppState()
        autre.chargerSousTitres(srt)
        autre.retirerSousTitres()
        r.verifier("retirer les sous-titres n'emporte rien d'autre",
                   autre.sousTitres == nil && autre.cues.isEmpty && autre.video == nil)
    }

    // MARK: - Logo rond

    private static func logoRond(_ r: Rapport) {
        // Un carré plein : après recadrage, les coins doivent être transparents
        // et le centre intact.
        let cote = 200
        guard let ctx = CGContext(
            data: nil, width: cote, height: cote, bitsPerComponent: 8,
            bytesPerRow: cote * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            r.verifier("image d'essai", false); return
        }
        ctx.setFillColor(CouleurProfil.bleuNONP.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: cote, height: cote))
        guard let carre = ctx.makeImage(),
              let rond = LogoRond.recadrerEnCercle(carre) else {
            r.verifier("recadrage en cercle", false); return
        }

        r.egal("le recadrage garde les dimensions",
               "\(rond.width)×\(rond.height)", "\(cote)×\(cote)")
        r.egal("le coin est transparent", alpha(de: rond, x: 3, y: 3), 0)
        r.egal("le centre est opaque", alpha(de: rond, x: cote / 2, y: cote / 2), 255)

        // Anticrénelage : sur le bord du disque, on doit trouver des valeurs
        // INTERMÉDIAIRES. Un bord franc ne contiendrait que 0 et 255, et le
        // cercle serait dentelé.
        var intermediaires = 0
        let rayon = Double(cote) / 2
        for angle in stride(from: 0.0, to: 2 * Double.pi, by: 0.05) {
            let x = Int(rayon + rayon * cos(angle) * 0.999)
            let y = Int(rayon + rayon * sin(angle) * 0.999)
            let a = alpha(de: rond, x: min(max(x, 0), cote - 1),
                          y: min(max(y, 0), cote - 1))
            if a > 10 && a < 245 { intermediaires += 1 }
        }
        r.verifier("le bord est lissé (\(intermediaires) pixels intermédiaires)",
                   intermediaires > 10)

        // Une image rectangulaire donne un vrai rond, pas une ellipse coupée :
        // elle est d'abord ramenée à son carré central.
        guard let large = CGContext(
            data: nil, width: 400, height: 100, bitsPerComponent: 8,
            bytesPerRow: 400 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        large.setFillColor(CouleurProfil.bleuNONP.cgColor)
        large.fill(CGRect(x: 0, y: 0, width: 400, height: 100))
        if let rect = large.makeImage(), let rondRect = LogoRond.recadrerEnCercle(rect) {
            r.egal("une image rectangulaire donne un carré",
                   "\(rondRect.width)×\(rondRect.height)", "100×100")
        }

        // Le réglage est réversible : sans lui, l'image sort telle quelle.
        r.verifier("sans le réglage, l'image n'est pas touchée",
                   LogoRond.carreCentral(de: carre).width == cote)
    }

    /// Alpha d'un pixel, coordonnées depuis le HAUT à gauche.
    private static func alpha(de image: CGImage, x: Int, y: Int) -> Int {
        guard let donnees = image.dataProvider?.data,
              let base = CFDataGetBytePtr(donnees) else { return -1 }
        let index = y * image.bytesPerRow + x * 4
        guard index + 3 < CFDataGetLength(donnees) else { return -1 }
        // Format premultipliedLast : l'alpha est le quatrième octet.
        return Int(base[index + 3])
    }

    // MARK: - Libellés de la colonne des réglages

    /// **Aucun libellé de la colonne ne se casse à la largeur minimale.**
    ///
    /// C'est le défaut qu'aucun contrôle n'attrapait, et il était visible à
    /// l'œil nu : « Taille » s'écrivait « Ta / ill / e », trois lignes
    /// verticales à côté d'un sélecteur segmenté qui, lui, tenait très bien.
    /// `Picker(titre, …)` range son libellé à gauche et lui laisse ce qui reste
    /// une fois le contrôle servi ; quand il ne reste rien, le texte se replie
    /// caractère par caractère plutôt que d'avertir.
    ///
    /// Pourquoi rien ne le voyait : les contrôles mesuraient le panneau ENTIER,
    /// contraint à une largeur donnée. `fittingSize` d'une vue contrainte rend
    /// la largeur qu'on lui a imposée — la vérification « les réglages tiennent
    /// dans la colonne » était donc vraie par construction, quoi qu'il arrive
    /// aux libellés. Et elle mesurait 328 points, la colonne moins ses marges,
    /// en oubliant l'ascenseur : or « Taille » tenait à 328 et se cassait à 313.
    ///
    /// La mesure juste est LIGNE PAR LIGNE, et en HAUTEUR :
    ///
    /// > à la largeur la plus étroite que la colonne puisse offrir, chaque ligne
    /// > doit garder la hauteur qu'elle a quand rien ne la contraint.
    ///
    /// Un libellé qui se replie ajoute une ligne de texte, donc de la hauteur :
    /// il ne peut pas passer inaperçu. Un contrôle qui se comprime sans se
    /// replier — un sélecteur segmenté qui raccourcit ses segments, un bouton
    /// de coin qui rogne son titre — ne change pas de hauteur, et reste donc
    /// permis : c'est la dégradation acceptable, celle qui n'écrit pas de
    /// travers.
    ///
    /// Les lignes sont construites par les MÊMES fonctions que le volet
    /// (`PanneauPersonnaliserView.choixSegmente`, `selecteurCouleur`,
    /// `curseurPourcent`…), avec les MÊMES libellés, pris à `Textes`. Ce n'est
    /// pas une copie de la disposition : c'est la disposition.
    ///
    /// **Ce que le contrôle suppose**, et qui est devenu la règle du volet :
    /// un réglage par ligne, chacun ayant la colonne entière. Les deux couleurs
    /// des sous-titres étaient côte à côte — 313 points partagés en deux, et
    /// « Couleur du texte » se repliait, 32 points au lieu de 24. Mesurées
    /// appariées, elles échouent ici ; l'une sous l'autre, elles passent. Mais
    /// c'est la seule disposition que ce contrôle sache voir : remettre deux
    /// réglages sur une même ligne le rendrait aveugle à leur étroitesse.
    @MainActor
    private static func libellesDeLaColonne(_ r: Rapport) {
        _ = NSApplication.shared
        let etroit = Fenetre.largeurUtileReglages

        r.verifier("la largeur de mesure retranche l'ascenseur de la colonne "
                   + "défilante (\(Int(etroit)) points, et non "
                   + "\(Int(Fenetre.largeurReglages - 2 * Fenetre.margeReglages)))",
                   etroit < Fenetre.largeurReglages - 2 * Fenetre.margeReglages)

        for (nom, vue) in lignesDeLaColonne() {
            let contrainte = hauteurLigne(vue, largeur: etroit)
            let naturelle = hauteurLigne(vue, largeur: nil)
            r.verifier("« \(nom) » garde sa hauteur d'une ligne à "
                       + "\(Int(etroit)) points (\(Int(contrainte)) points "
                       + "contre \(Int(naturelle)) sans contrainte)",
                       contrainte <= naturelle + 0.5)
        }

        // Le libellé d'un curseur a une colonne à lui, de largeur fixe : elle
        // doit rester plus large que le plus long d'entre eux, sans quoi c'est
        // là, et non dans la colonne, que le repli se produirait.
        for titre in [Textes.Interface.margeBasse, Textes.Interface.tailleLogo,
                      Textes.Interface.opaciteLogo] {
            let hote = NSHostingView(rootView: Text(titre))
            hote.layoutSubtreeIfNeeded()
            r.verifier("le libellé de curseur « \(titre) » tient dans sa colonne "
                       + "(\(Int(hote.fittingSize.width)) points pour "
                       + "\(Int(Fenetre.largeurLibelleCurseur)))",
                       hote.fittingSize.width <= Fenetre.largeurLibelleCurseur)
        }

        // Et le volet entier, à cette même largeur : rien ne dépasse.
        let etat = AppState()
        etat.profil.logoActif = true
        etat.profil.logoFichier = URL(fileURLWithPath: "/x.png")
        let hote = NSHostingView(
            rootView: PanneauPersonnaliserView().environmentObject(etat)
                .frame(width: etroit))
        hote.layoutSubtreeIfNeeded()
        r.verifier("le volet entier tient à \(Int(etroit)) points sans être rogné "
                   + "(\(Int(hote.fittingSize.width)))",
                   hote.fittingSize.width <= etroit + 1)
    }

    /// Toutes les lignes de la colonne qui portent un libellé, y compris les
    /// titres de section.
    ///
    /// Les explications en petits caractères n'y sont PAS : ce sont des
    /// paragraphes, ils ont le droit — et le devoir — de se replier sur
    /// plusieurs lignes. Le contrôle porte sur les libellés de commande.
    @MainActor
    private static func lignesDeLaColonne() -> [(String, AnyView)] {
        typealias Volet = PanneauPersonnaliserView
        let T = Textes.Interface.self

        var lignes: [(String, AnyView)] = []
        for titre in [Textes.Profil.titre, T.sousTitres, T.bandeau, T.logo] {
            lignes.append((titre, AnyView(Text(titre).font(.headline))))
        }
        lignes += [
            (Textes.Profil.preregle, AnyView(Volet.prereglages(appliquer: { _ in }))),
            (Textes.Profil.exporter, AnyView(Volet.importExport(importer: {},
                                                                exporter: {}))),
            (T.ajoutezDesSousTitres, AnyView(Text(T.ajoutezDesSousTitres)
                .font(.caption).fixedSize(horizontal: false, vertical: true))),
            (T.taille, AnyView(Volet.choixSegmente(
                T.taille, selection: .constant(TailleNommee.allCases[0])) {
                    ForEach(TailleNommee.allCases) { t in
                        Text(T.nomTaille(t)).tag(t)
                    }
                })),
            (T.police, AnyView(Volet.choixPolice(
                selection: .constant(ProfilHabillage.neutre.police)))),
            (T.couleurTexte, AnyView(Volet.selecteurCouleur(
                T.couleurTexte, valeur: .constant(ProfilHabillage.neutre.couleurTexte)))),
            (T.couleurContour, AnyView(Volet.selecteurCouleur(
                T.couleurContour, valeur: .constant(ProfilHabillage.neutre.contourCouleur)))),
            (T.lignesMax, AnyView(Volet.pasAPas(
                T.lignesMax, valeur: .constant(2), de: 1, a: 4))),
            (T.bandeauActif, AnyView(Volet.interrupteur(
                T.bandeauActif, actif: .constant(true)))),
            (T.modeBandeau, AnyView(Volet.choixSegmente(
                T.modeBandeau, selection: .constant(ModeBandeau.pleineLargeur)) {
                    Text(T.modePleineLargeur).tag(ModeBandeau.pleineLargeur)
                    Text(T.modeAjuste).tag(ModeBandeau.ajuste)
                })),
            (T.couleurBandeau, AnyView(Volet.selecteurCouleur(
                T.couleurBandeau, valeur: .constant(ProfilHabillage.neutre.bandeauCouleur)))),
            (T.hauteurFixe, AnyView(Volet.interrupteur(
                T.hauteurFixe, actif: .constant(true)))),
            (T.margeBasse, AnyView(Volet.curseurPourcent(
                T.margeBasse, valeur: .constant(0.10), de: 0, a: 0.30))),
            (T.positionLogo, AnyView(Volet.coinsDuLogo(
                position: .constant(.coin(.basDroit))))),
            (T.logoRond, AnyView(Volet.interrupteur(
                T.logoRond, actif: .constant(true)))),
            (T.tailleLogo, AnyView(Volet.curseurPourcent(
                T.tailleLogo, valeur: .constant(0.10), de: 0.01, a: 0.50))),
            (T.opaciteLogo, AnyView(Volet.curseurPourcent(
                T.opaciteLogo, valeur: .constant(1), de: 0, a: 1))),
        ]
        return lignes
    }

    /// Hauteur d'une ligne, contrainte à une largeur ou laissée libre.
    @MainActor
    private static func hauteurLigne(_ vue: AnyView, largeur: CGFloat?) -> CGFloat {
        let hote: NSHostingView<AnyView>
        if let largeur {
            hote = NSHostingView(rootView: AnyView(vue.frame(width: largeur)))
        } else {
            hote = NSHostingView(rootView: vue)
        }
        hote.layoutSubtreeIfNeeded()
        return hote.fittingSize.height
    }

    // MARK: - Disposition

    /// Le critère « l'écran d'accueil tient sans défilement et ne montre aucun
    /// réglage tant que le volet est fermé » se mesure.
    ///
    /// La mesure passe par `NSHostingView.fittingSize`, c'est-à-dire par la
    /// VRAIE disposition AppKit — la même qui s'appliquera à l'écran. Le rendu
    /// hors écran, lui, ne saurait pas : il dessine les contrôles natifs comme
    /// des rectangles vides et se tromperait de hauteur.
    @MainActor
    private static func dispositionAccueil(_ r: Rapport) {
        _ = NSApplication.shared
        // Les VRAIES dimensions de la fenêtre, pas deux nombres recopiés à côté :
        // c'est la raison d'être de `Fenetre`, et la barre d'action du lot 5 les
        // a fait changer.
        let hauteurFenetre = Fenetre.hauteurFermee
        let largeurFenetre = Fenetre.largeurFermee

        for (nom, prepare) in [
            ("accueil vide", { (_: AppState) in }),
            ("accueil avec erreur", { (e: AppState) in
                e.profil.police = "Police Absente"; e.rafraichirApercu() }),
        ] {
            let etat = AppState()
            prepare(etat)
            let vue = ContenuFenetre().environmentObject(etat)
                .frame(width: largeurFenetre)
            let hote = NSHostingView(rootView: vue)
            hote.layoutSubtreeIfNeeded()
            let taille = hote.fittingSize
            r.verifier("\(nom) : \(Int(taille.height)) points de haut, "
                       + "la fenêtre en fait \(Int(hauteurFenetre))",
                       taille.height <= hauteurFenetre)
        }

        // Volet fermé : aucun réglage visible. On le vérifie par la hauteur —
        // le volet fait plusieurs centaines de points, il ne peut pas se cacher.
        let ferme = AppState()
        let hoteFerme = NSHostingView(
            rootView: ContenuFenetre().environmentObject(ferme).frame(width: largeurFenetre))
        hoteFerme.layoutSubtreeIfNeeded()
        let hauteurFermee = hoteFerme.fittingSize.height

        let ouvert = AppState()
        ouvert.voletOuvert = true
        let hoteOuvert = NSHostingView(
            rootView: ContenuFenetre().environmentObject(ouvert).frame(width: largeurFenetre))
        hoteOuvert.layoutSubtreeIfNeeded()
        let hauteurOuverte = hoteOuvert.fittingSize.height

        r.verifier("le volet fermé n'occupe pas la place du volet ouvert "
                   + "(\(Int(hauteurFermee)) contre \(Int(hauteurOuverte)) points)",
                   hauteurOuverte > hauteurFermee)
        r.verifier("le volet est fermé au premier lancement", !AppState().voletOuvert)

        // ── La fenêtre s'ouvre à la taille NATURELLE de son contenu ──────────
        //
        // « Tient sans défilement » ne suffisait pas : une fenêtre deux fois
        // trop haute passait ce critère les yeux fermés. Elle s'ouvrait à 470
        // points pour 377 de contenu, et l'accueil flottait au-dessus d'un vide
        // que rien ne remplissait. Ce qui manquait, c'est la borne d'EN HAUT.
        //
        // `hauteurFermee` n'est plus une hauteur imposée — l'accueil nu ne pose
        // aucun minimum, `ContenuFenetre.hauteurMinimale` rend `nil` — mais la
        // taille d'ouverture demandée. Elle doit donc coller à ce que le contenu
        // mesure vraiment. Trop basse, `.contentMinSize` la relève sans dommage ;
        // trop haute, le vide revient. La marge tolérée est celle d'un arrondi,
        // pas celle d'un choix.
        //
        // Le contrôle vaut aussi dans l'autre sens, et c'est ce qui le rend
        // suffisant : `hauteurFermee` est ici la hauteur MESURÉE du contenu.
        // Réimposer un minimum de 470 points la ferait remonter à 470 pour 380
        // demandés, l'écart passerait sous zéro, et le contrôle échouerait.
        let jeu = hauteurFenetre - hauteurFermee
        r.verifier("la taille d'ouverture ne dépasse pas le contenu de plus de "
                   + "10 points (\(Int(hauteurFenetre)) demandés pour "
                   + "\(Int(hauteurFermee)) mesurés, soit \(Int(jeu)))",
                   jeu >= 0 && jeu <= 10)

        // La fenêtre grandit quand une vidéo arrive, et seulement alors : les
        // trois hauteurs sont strictement croissantes, dans l'ordre où l'usage
        // les rencontre.
        r.verifier("une vidéo fait grandir la fenêtre "
                   + "(\(Int(Fenetre.hauteurFermee)) → "
                   + "\(Int(Fenetre.hauteurFermeeAvecVideo)) points)",
                   Fenetre.hauteurFermeeAvecVideo > Fenetre.hauteurFermee)
        r.verifier("l'ouverture du volet la fait grandir encore "
                   + "(\(Int(Fenetre.hauteurFermeeAvecVideo)) → "
                   + "\(Int(Fenetre.hauteurMinimaleOuverte)) points)",
                   Fenetre.hauteurMinimaleOuverte > Fenetre.hauteurFermeeAvecVideo)
    }

    // MARK: - Aperçu

    /// Un fond de contrôle : moitié sombre, moitié claire, pour que le moindre
    /// changement d'habillage se voie dans les pixels.
    private static func fondDeControle(largeur: Int = 960, hauteur: Int = 540) -> CGImage? {
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

    private static func apercuReagit(_ r: Rapport) {
        guard let fond = fondDeControle() else {
            r.verifier("fond de contrôle", false); return
        }
        let base = ProfilHabillage.neutre
        guard let reference = try? Apercu.composer(
            fond: fond, profil: base, texte: texteDEssai, avecSousTitres: true) else {
            r.verifier("aperçu de référence", false); return
        }
        r.egal("l'aperçu garde les dimensions du fond",
               "\(reference.image.width)×\(reference.image.height)", "960×540")
        r.verifier("l'aperçu a bien peint quelque chose",
                   ImagesReference.differe(reference.image, de: fond))

        // Chaque réglage doit changer l'image. Un aperçu qui ne bouge pas est
        // pire qu'une absence d'aperçu : il ment.
        var variantes: [(String, ProfilHabillage)] = []
        var p = base; p.couleurTexte = .bleuNONP;         variantes.append(("couleur du texte", p))
        p = base; p.contourCouleur = .bleuNONP;           variantes.append(("couleur du contour", p))
        p = base; p.bandeauCouleur = .bleuNONP;           variantes.append(("couleur du bandeau", p))
        p = base; p.bandeauActif = false;                 variantes.append(("bandeau désactivé", p))
        p = base; p.bandeauMode = .ajuste;                variantes.append(("mode du bandeau", p))
        p = base; p.longueurLigneCible = 28;              variantes.append(("taille nommée", p))
        p = base; p.police = "Georgia";                   variantes.append(("police", p))
        p = base; p.margeBasseRatio = 0.20;               variantes.append(("marge basse", p))
        p = base; p.bandeauHauteurFixeLignes = 4;         variantes.append(("hauteur du bandeau", p))
        p = base; p.lignesMax = 1;                        variantes.append(("lignes maximum", p))

        for (nom, profil) in variantes {
            guard let variante = try? Apercu.composer(
                fond: fond, profil: profil, texte: texteDEssai, avecSousTitres: true) else {
                r.verifier("\(nom) : aperçu produit", false); continue
            }
            r.verifier("\(nom) : l'aperçu change",
                       ImagesReference.differe(variante.image, de: reference.image))
        }
    }

    private static let texteDEssai =
        "Il m'a dit qu'il n'avait rien vu ce jour-là, vers quatre heures du matin."

    // MARK: - Les quatre tailles nommées

    /// Une taille nommée doit CHANGER LA TAILLE DU TEXTE.
    ///
    /// La rubrique s'appelait « texte affiché en permanence » : elle vérifiait
    /// qu'une phrase de référence s'affichait sans fichier de sous-titres, et
    /// qu'elle restait la même aux quatre tailles. La phrase a disparu au lot 6
    /// — voir `ReglagesInterface` — mais l'essentiel de ce que la rubrique
    /// prouvait n'en dépendait pas : que les quatre tailles nommées donnent
    /// quatre polices distinctes, et croissantes. C'est le défaut qui l'avait
    /// motivée, et il reste à surveiller.
    ///
    /// Le texte d'épreuve est désormais celui des autres contrôles, un vrai
    /// sous-titre : plus rien, dans l'application, n'en fabrique.
    private static func textePermanent(_ r: Rapport) {
        var taillesDePolice: [Int] = []
        for taille in TailleNommee.allCases {
            var profil = ProfilHabillage.neutre
            profil.longueurLigneCible = taille.longueurLigneCible
            profil.tailleRatio = taille.tailleRatio

            guard let mep = try? MiseEnPageRendu.calculer(
                profil: profil, largeurVideo: 1920, hauteurVideo: 1080) else { continue }
            taillesDePolice.append(mep.parametres.taille)

            let lignes = Apercu.premiereReplique(
                texte: texteDEssai, profil: profil, miseEnPage: mep)
            r.verifier("\(Textes.Interface.nomTaille(taille)) : le texte "
                       + "d'épreuve tient en \(profil.lignesMax) lignes au plus "
                       + "(police \(mep.parametres.taille) px)",
                       !lignes.isEmpty && lignes.count <= profil.lignesMax)
        }

        // ET LA TAILLE DU TEXTE DOIT CHANGER. C'est le défaut qui a motivé la
        // correction : les quatre réglages rendaient tous 78 px sur une 16:9.
        r.egal("les quatre tailles donnent quatre polices distinctes",
               Set(taillesDePolice).count, taillesDePolice.count)
        r.verifier("les tailles vont croissant (\(taillesDePolice.map(String.init).joined(separator: ", ")) px)",
                   zip(taillesDePolice, taillesDePolice.dropFirst()).allSatisfy { $0 < $1 })
        if let plusPetite = taillesDePolice.first, let plusGrande = taillesDePolice.last {
            r.verifier("l'écart est visible à l'œil (\(plusGrande - plusPetite) px, "
                       + "soit \(Int(Double(plusGrande - plusPetite) / Double(plusPetite) * 100)) %)",
                       Double(plusGrande) >= Double(plusPetite) * 1.4)
        }

        // Avec un fichier, c'est la réplique LA PLUS LONGUE qui vient d'abord.
        let cues = [
            Cue(debutMs: 0, finMs: 1000, texte: "Court."),
            Cue(debutMs: 1000, finMs: 2000,
                texte: "Une réplique nettement plus longue que les autres, pour le pire cas."),
            Cue(debutMs: 2000, finMs: 3000, texte: "Moyen, celle-ci."),
        ]
        let classees = Apercu.repliquesParPireCas(cues)
        r.egal("la plus longue réplique vient en premier",
               classees.first?.texte, cues[1].texte)
        r.egal("toutes les répliques restent parcourables", classees.count, cues.count)
    }

    // MARK: - Tailles nommées

    private static func taillesNommees(_ r: Rapport) {
        // Les quatre valeurs de l'ADR §2, ni plus ni moins.
        r.egal("quatre tailles proposées", TailleNommee.allCases.count, 4)
        r.egal("Petite vise 42 caractères", TailleNommee.petite.longueurLigneCible, 42)
        r.egal("Normale vise 37 caractères", TailleNommee.normale.longueurLigneCible, 37)
        r.egal("Grande vise 32 caractères", TailleNommee.grande.longueurLigneCible, 32)
        r.egal("Très grande vise 28 caractères", TailleNommee.tresGrande.longueurLigneCible, 28)

        // Toutes tiennent dans les bornes de l'ADR §5.
        for t in TailleNommee.allCases {
            r.verifier("\(Textes.Interface.nomTaille(t)) est dans [28, 42]",
                       t.longueurLigneCible >= MoteurMiseEnPage.longueurLigneMinimale
                       && t.longueurLigneCible <= MoteurMiseEnPage.longueurLigneMaximale)
        }

        // Plus la ligne est longue, plus le texte est petit.
        var petit: Int = 0, grand: Int = 0
        for (nom, taille) in [("Petite", TailleNommee.petite),
                              ("Très grande", TailleNommee.tresGrande)] {
            var profil = ProfilHabillage.neutre
            profil.longueurLigneCible = taille.longueurLigneCible
            profil.tailleRatio = taille.tailleRatio
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: profil, largeurVideo: 1080, hauteurVideo: 1920) else { continue }
            if nom == "Petite" { petit = mep.parametres.taille } else { grand = mep.parametres.taille }
        }
        r.verifier("« Petite » donne un texte plus petit que « Très grande » "
                   + "(\(petit) px contre \(grand) px)", petit < grand)
        r.egal("« Grande » vaut exactement le 7,2 % du prototype",
               TailleNommee.grande.tailleRatio, 0.072)

        // POURQUOI les deux réglages sont distincts, en chiffres. L'ADR §5
        // couplait taille et longueur de ligne : la taille demandée devait être
        // réduite quand la largeur ne permettait pas d'atteindre la cible. Cette
        // arithmétique reposait sur l'estimation « 0,72 × taille » ; avec la
        // mesure exacte, la place est bien plus grande, et la réduction ne mord
        // plus jamais en 16:9. Si ce contrôle venait à échouer, ce serait le
        // signe que le couplage est redevenu vrai — et que §5 est à relire.
        for t in TailleNommee.allCases {
            var profil = ProfilHabillage.neutre
            profil.longueurLigneCible = t.longueurLigneCible
            profil.tailleRatio = t.tailleRatio
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: profil, largeurVideo: 1920, hauteurVideo: 1080) else { continue }
            r.verifier("16:9 1080p, \(Textes.Interface.nomTaille(t)) : "
                       + "\(mep.parametres.taille) px, place pour "
                       + "\(mep.capacite) caractères, cible "
                       + "\(t.longueurLigneCible) — la taille n'est pas réduite",
                       !mep.reduitePourTenir && mep.capacite >= t.longueurLigneCible)
        }

        // En 9:16, la réduction sert encore : c'est le défaut du 23/08, et le
        // filet de sécurité reste tendu.
        var verticale = ProfilHabillage.neutre
        verticale.longueurLigneCible = TailleNommee.grande.longueurLigneCible
        verticale.tailleRatio = TailleNommee.grande.tailleRatio
        if let mep = try? MiseEnPageRendu.calculer(
            profil: verticale, largeurVideo: 1080, hauteurVideo: 1920) {
            r.verifier("9:16, Grande : la taille est bien réduite pour tenir "
                       + "(\(mep.tailleDemandeeParLeProfil) → "
                       + "\(mep.parametres.taille) px)",
                       mep.reduitePourTenir)
        }

        r.egal("une longueur précise retrouve sa taille nommée",
               TailleNommee.laPlusProche(de: 32), .grande)
        r.egal("une longueur intermédiaire tombe sur la plus proche",
               TailleNommee.laPlusProche(de: 29), .tresGrande)
        r.egal("une longueur hors bornes se rabat sur l'extrême",
               TailleNommee.laPlusProche(de: 60), .petite)
    }

    // MARK: - Polices

    private static func polices(_ r: Rapport) {
        r.verifier("la liste courte compte 8 à 10 familles",
                   (8...10).contains(PolicesSures.recommandees.count))
        r.egal("toutes les familles recommandées sont installées",
               PolicesSures.disponibles.count, PolicesSures.recommandees.count)
        r.verifier("les polices des deux profils livrés sont dans la liste sûre",
                   PolicesSures.estSure(ProfilHabillage.neutre.police)
                   && PolicesSures.estSure(ProfilHabillage.nonpHistorique.police))
        r.verifier("le choix « autre police » propose tout le système",
                   PolicesSures.toutes.count > PolicesSures.recommandees.count)
        r.verifier("une police hors liste est signalée comme risquée",
                   !PolicesSures.estSure("Zapfino"))
    }

    // MARK: - Avertissements

    private static func avertissements(_ r: Rapport) {
        var profil = ProfilHabillage.nonpHistorique
        profil.logoActif = true
        profil.logoFichier = URL(fileURLWithPath: "/x.png")
        let (w, h) = (1920, 1080)
        guard let mep = try? MiseEnPageRendu.calculer(
            profil: profil, largeurVideo: w, hauteurVideo: h) else {
            r.verifier("mise en page", false); return
        }
        let taille = CGSize(width: 200, height: 200)

        // Bas-gauche : le logo tombe dans la zone des sous-titres.
        profil.logoPosition = .coin(.basGauche)
        let bas = GeometrieLogo.rectangle(
            profil: profil, parametres: mep.parametres, tailleSource: taille,
            largeurVideo: w, hauteurVideo: h)
        let surBandeau = AvertissementsZone.examiner(
            profil: profil, parametres: mep.parametres, police: mep.police,
            rectangleLogo: bas, avecSousTitres: true, largeurVideo: w, hauteurVideo: h)
        r.verifier("logo en bas + sous-titres : l'empiètement est signalé",
                   surBandeau.contains { $0.sorte == .logoSurBandeau })

        // Haut-gauche : rien à signaler.
        profil.logoPosition = .coin(.hautGauche)
        let haut = GeometrieLogo.rectangle(
            profil: profil, parametres: mep.parametres, tailleSource: taille,
            largeurVideo: w, hauteurVideo: h)
        let enHaut = AvertissementsZone.examiner(
            profil: profil, parametres: mep.parametres, police: mep.police,
            rectangleLogo: haut, avecSousTitres: true, largeurVideo: w, hauteurVideo: h)
        r.egal("logo en haut : aucun avertissement", enHaut.count, 0)

        // Sans sous-titres, il n'y a pas de zone à protéger.
        profil.logoPosition = .coin(.basGauche)
        let sansST = AvertissementsZone.examiner(
            profil: profil, parametres: mep.parametres, police: mep.police,
            rectangleLogo: bas, avecSousTitres: false, largeurVideo: w, hauteurVideo: h)
        r.verifier("logo en bas sans sous-titres : rien à signaler",
                   !sansST.contains { $0.sorte == .logoSurBandeau })

        // Placement libre collé au bord : marges sûres.
        profil.logoPosition = .libre(xPct: 2, yPct: 50)
        let auBord = GeometrieLogo.rectangle(
            profil: profil, parametres: mep.parametres, tailleSource: taille,
            largeurVideo: w, hauteurVideo: h)
        let horsMarges = AvertissementsZone.examiner(
            profil: profil, parametres: mep.parametres, police: mep.police,
            rectangleLogo: auBord, avecSousTitres: false, largeurVideo: w, hauteurVideo: h)
        r.verifier("logo collé au bord : les marges sûres sont signalées",
                   horsMarges.contains { $0.sorte == .logoHorsMargesSures })

        // Au centre : rien.
        profil.logoPosition = .libre(xPct: 50, yPct: 40)
        let centre = GeometrieLogo.rectangle(
            profil: profil, parametres: mep.parametres, tailleSource: taille,
            largeurVideo: w, hauteurVideo: h)
        let auCentre = AvertissementsZone.examiner(
            profil: profil, parametres: mep.parametres, police: mep.police,
            rectangleLogo: centre, avecSousTitres: true, largeurVideo: w, hauteurVideo: h)
        r.egal("logo au centre : aucun avertissement", auCentre.count, 0)

        // Sans logo du tout : rien à examiner.
        let sansLogo = AvertissementsZone.examiner(
            profil: profil, parametres: mep.parametres, police: mep.police,
            rectangleLogo: nil, avecSousTitres: true, largeurVideo: w, hauteurVideo: h)
        r.egal("sans logo : aucun avertissement", sansLogo.count, 0)
    }

    // MARK: - Trois usages

    private static func troisUsages(_ r: Rapport) {
        guard let fond = fondDeControle() else { return }
        var avecLogo = ProfilHabillage.nonpHistorique
        avecLogo.logoActif = false   // pas de fichier : on éprouve la composition seule

        // Sous-titres seuls.
        let st = try? Apercu.composer(fond: fond, profil: avecLogo,
                                      texte: texteDEssai, avecSousTitres: true)
        r.verifier("sous-titres seuls : un aperçu est produit", st != nil)
        r.verifier("sous-titres seuls : aucun rectangle de logo",
                   (st?.rectangleLogo) == nil)

        // Logo seul : pas de sous-titres, et l'aperçu ne montre QUE le plan et
        // le logo. C'est le chemin qui gagne le plus au retrait de la phrase de
        // référence — on ne règle plus un logo par-dessus un bandeau et un
        // texte dont on n'a que faire.
        let logoSeul = try? Apercu.composer(
            fond: fond, profil: avecLogo, lignes: [], avecSousTitres: false)
        r.verifier("logo seul : un aperçu est produit", logoSeul != nil)
        r.verifier("logo seul : aucun sous-titre n'est peint",
                   logoSeul.map { !ImagesReference.differe($0.image, de: fond) } == true)

        // Rien à graver : l'interface le dit plutôt que de laisser cliquer.
        r.verifier("« rien à graver » est formulé",
                   !Textes.Interface.rienAGraver.isEmpty)
        r.egal("l'usage vide est nommé",
               CommandeExport.usage(sousTitres: nil, profil: avecLogo),
               "ni sous-titres ni logo — rien à graver")
    }
}
