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

        r.section("Interface — chaque conseil du bandeau lève l'avertissement")
        conseilsBandeau(r)

        r.section("Interface — les trois usages")
        troisUsages(r)

        r.section("Interface — l'accueil tient sans défilement")
        MainActor.assumeIsolated { dispositionAccueil(r) }

        r.section("Interface — deux colonnes, aperçu entier, réglages atteignables")
        MainActor.assumeIsolated { dispositionDeuxColonnes(r) }

        r.section("Interface — aucun libellé de la colonne ne se casse")
        MainActor.assumeIsolated { libellesDeLaColonne(r) }

        r.section("Interface — aucun libellé de la colonne n'est tronqué")
        MainActor.assumeIsolated { troncatures(r) }

        r.section("Interface — aucun contrôle ne déborde de la colonne, même après une mesure")
        MainActor.assumeIsolated { debordements(r) }

        r.section("Interface — la colonne des réglages ne dépend pas de l'ascenseur")
        MainActor.assumeIsolated { colonneEtAscenseur(r) }

        r.section("Interface — l'accueil montre une image de la vidéo")
        imageDAccueil(r)
        MainActor.assumeIsolated { dispositionImageAccueil(r) }

        r.section("Interface — le logo suit la souris")
        MainActor.assumeIsolated { glissementLogo(r) }

        r.section("Interface — retirer la vidéo")
        MainActor.assumeIsolated { retirerLaVideo(r) }

        r.section("Interface — le nom proposé à l'enregistrement")
        MainActor.assumeIsolated { nomProposé(r) }

        r.section("Interface — « Habiller une autre vidéo » repart de zéro")
        MainActor.assumeIsolated { habillerUneAutreVideo(r) }

        r.section("Interface — « Revenir aux réglages » garde tout, et rend un second export")
        MainActor.assumeIsolated { revenirAuxReglages(r) }

        r.section("Interface — logo recadré en cercle")
        logoRond(r)

        r.section("Interface — la marge du texte, unique commande de la colonne")
        margeDuTexte(r)

        r.section("Interface — les contrôles ne lisent ni n'écrivent la machine")
        MainActor.assumeIsolated { miseEnSceneSansMemoire(r) }

        r.section("Interface — « Habiller » dans la barre d'action du bas")
        MainActor.assumeIsolated { barreAction(r) }

        r.section("Interface — hauteur constante : une case, la valeur de « Lignes maximum »")
        MainActor.assumeIsolated { hauteurConstante(r) }

        r.section("Interface — chaque réglage a son aide, et elle apprend quelque chose")
        aideDesReglages(r)

        r.section("Interface — fond de l'aperçu : le contrôle se dit lui-même")
        fondDeLApercu(r)
        MainActor.assumeIsolated { dispositionBarreDeChoix(r) }
    }

    // MARK: - La marge du texte, unique commande de la colonne (schéma v2)

    /// Décision nº6, tranchée le 28/08/2026 — option C.
    ///
    /// Trois réglages se partageaient la largeur de la colonne de texte :
    /// `espaces_lateraux` en mode `ajuste`, `marge_interieure_pct_largeur` en
    /// mode `pleine-largeur`, et la marge latérale du texte par-dessus. Un seul
    /// les remplace, `bandeau.marge_texte_pct_largeur`, et il commande **les
    /// deux modes**.
    ///
    /// Ce qui se contrôle ici, c'est qu'il commande VRAIMENT : dans les deux
    /// modes, sur les deux orientations, et jusqu'aux pixels. La preuve de
    /// non-régression, elle, vit dans `ControlesRegressionV2`.
    private static func margeDuTexte(_ r: Rapport) {
        let w = 1920

        // La colonne se mesure là où elle est CONTRAINTE. En 16:9 la longueur
        // de ligne cible est atteinte de très loin — 49 caractères pour 32
        // visés —, et c'est elle qui borne la colonne, pas la largeur : un
        // contrôle posé là ne verrait rien bouger et ne prouverait rien. La
        // mesure se fait donc en 9:16, le format où la largeur commande.
        for (nomMode, mode) in [("ajuste", ModeBandeau.ajuste),
                                ("pleine-largeur", ModeBandeau.pleineLargeur)] {
            var profil = ProfilHabillage.neutre
            profil.bandeauMode = mode
            let large = largeurDecoupe(profil, marge: 0.02, 1080, 1920)
            let serree = largeurDecoupe(profil, marge: 0.20, 1080, 1920)
            r.verifier("mode « \(nomMode) » : la marge du texte borne la colonne "
                       + "en 9:16 (\(Int(large)) → \(Int(serree)) px)",
                       serree < large)
        }

        // C'est TOUT le changement de la v2 : en v1, ce champ n'agissait que
        // dans un mode, et l'autre dépendait d'un nombre d'espaces durs.
        var ajuste = ProfilHabillage.bandeauColore
        ajuste.logoActif = false
        r.verifier("en mode « ajuste » aussi — ce que la v1 ne savait pas faire "
                   + "autrement qu'en largeurs d'espace",
                   largeurDecoupe(ajuste, marge: 0.20, 1080, 1920)
                   < largeurDecoupe(ajuste, marge: 0.02, 1080, 1920))

        // En PIXELS ENTIERS, comme le reste de la géométrie. C'est la condition
        // pour qu'un pourcentage de largeur retombe sur les débords que la v1
        // calculait en largeurs d'espace.
        for (largeur, attendu) in [(1920, 108), (1280, 72), (3840, 215)] {
            var p = ProfilHabillage.bandeauColore
            p.bandeauMargeTexteRatioLargeur = 0.0561
            let retrait = GeometrieSousTitres.retraitDuTexte(
                profil: p, largeurVideo: largeur)
            r.egal("retrait à 5,61 % sur \(largeur) px de large, en pixels entiers",
                   Int(retrait), attendu)
        }

        // Sans bandeau, aucun retrait : il n'y a pas de bord dont s'écarter.
        var sansFond = ProfilHabillage.bandeauColore
        sansFond.bandeauActif = false
        r.egal("sans bandeau, aucun retrait", GeometrieSousTitres.retraitDuTexte(
            profil: sansFond, largeurVideo: w), 0)

        // Jusqu'aux PIXELS : la mise en page pourrait changer sans que le rendu
        // bouge. C'est la vraie promesse faite au fichier de profil.
        if let fond = fondDeControle(largeur: 1080, hauteur: 1920) {
            for mode in [ModeBandeau.ajuste, .pleineLargeur] {
                var p = ProfilHabillage.neutre
                p.bandeauMode = mode
                p.bandeauMargeTexteRatioLargeur = 0.02
                let a = try? Apercu.composer(fond: fond, profil: p,
                                             texte: texteDEssai, avecSousTitres: true)
                p.bandeauMargeTexteRatioLargeur = 0.20
                let b = try? Apercu.composer(fond: fond, profil: p,
                                             texte: texteDEssai, avecSousTitres: true)
                let bouge: Bool
                if let a = a?.image, let b = b?.image {
                    bouge = ImagesReference.differe(a, de: b)
                } else {
                    bouge = false
                }
                r.verifier("mode « \(mode.rawValue) » : en 9:16, le champ va "
                           + "jusqu'aux pixels", bouge)
            }
        }

        // Les valeurs des deux préréglages, et leur raison.
        r.egal("le préréglage NONP porte 5,61 % — le débord que ses espaces "
               + "latéraux produisaient en 16:9",
               ProfilHabillage.bandeauColore.bandeauMargeTexteRatioLargeur, 0.0561)
        r.egal("le profil neutre garde SES 3 % — ceux de sa marge intérieure de v1",
               ProfilHabillage.neutre.bandeauMargeTexteRatioLargeur, 0.03)
    }

    private static func largeurDecoupe(
        _ profil: ProfilHabillage, marge: Double, _ w: Int, _ h: Int
    ) -> Double {
        var p = profil
        p.bandeauMargeTexteRatioLargeur = marge
        return (try? MiseEnPageRendu.calculer(
            profil: p, largeurVideo: w, hauteurVideo: h))?.largeurColonneTexte ?? 0
    }

    // MARK: - La mise en scène ne vient pas de la machine

    /// **Un contrôle d'interface met en scène l'état qu'il mesure — jamais
    /// celui de la personne aux commandes.**
    ///
    /// La règle a été apprise à ses dépens. `AppState()` ouvre sur le profil
    /// MÉMORISÉ, logo compris : c'est ce qu'il faut à l'application, et
    /// exactement ce qu'il ne faut pas à un contrôle. La colonne mise en scène
    /// « sans logo » en portait donc un dès que la machine en avait un, et le
    /// contrôle de la barre d'action comparait deux fois le même état. Il est
    /// resté rouge trois commits, en accusant l'interface.
    ///
    /// Ce qui se vérifie ici vaut pour tout le harnais, et dans les deux sens :
    /// un état de contrôle ne LIT pas le profil mémorisé, et n'y ÉCRIT rien.
    /// Le second point n'est pas théorique — le profil se mémorise une demi-
    /// seconde après le dernier changement, et un contrôle qui fait tourner la
    /// boucle d'exécution laisse cette écriture partir.
    @MainActor
    private static func miseEnSceneSansMemoire(_ r: Rapport) {
        // 1. Il part des réglages par défaut, quelle que soit la machine.
        let controle = AppState(memoire: false)
        r.egal("un état de contrôle ouvre sur les réglages par défaut",
               controle.profil, ProfilHabillage.neutre)

        // 2. Et il s'écarte bien de ce que l'application aurait relu — sans quoi
        //    le point 1 pourrait n'être vrai que par coïncidence.
        if let memorise = MemoireProfil.relire(), memorise != ProfilHabillage.neutre {
            r.verifier("la machine a un profil mémorisé, et l'état de contrôle "
                       + "ne l'a pas repris", controle.profil != memorise)
        } else {
            r.nonExecute("l'état de contrôle ignore le profil mémorisé",
                         motif: "cette machine n'a pas de profil mémorisé qui "
                         + "s'écarte des réglages par défaut")
        }

        // 3. Et il n'écrit rien. On règle, on laisse passer la temporisation en
        //    faisant tourner la boucle, puis on relit le fichier de la machine.
        //    S'il avait bougé, le contrôle aurait déjà abîmé le profil d'Éric :
        //    il le remet donc en place avant de le signaler.
        let avant = try? Data(contentsOf: MemoireProfil.fichier)
        let regleur = AppState(memoire: false)
        regleur.profil.couleurTexte = CouleurProfil(hex: "#FF3B30")
        regleur.lignesMax = 4
        _ = pomperJusqua({ false }, secondes: 1.2)
        let apres = try? Data(contentsOf: MemoireProfil.fichier)
        if avant != apres, let avant {
            try? avant.write(to: MemoireProfil.fichier)
        }
        r.verifier("et il n'écrit rien dans le profil mémorisé de la machine",
                   avant == apres)
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
    ///
    /// **La mise en scène est vérifiée AVANT d'être mesurée.** Tout le point 1
    /// repose sur deux colonnes de hauteurs différentes : si les deux états
    /// mis en scène se ressemblent, la comparaison ne prouve plus rien, et
    /// c'est arrivé — l'état de contrôle héritait du profil MÉMORISÉ de la
    /// machine, logo compris, donc la colonne « sans logo » en avait un. Les
    /// deux états sont désormais construits sans mémoire (`AppState(memoire:
    /// false)`), et le contrôle commence par dire ce qu'il a réellement mis en
    /// scène. Voir aussi `miseEnSceneSansMemoire`, qui tient la règle pour tout
    /// le harnais.
    @MainActor
    private static func barreAction(_ r: Rapport) {
        _ = NSApplication.shared

        // ── La mise en scène, d'abord ────────────────────────────────────
        //
        // Un vrai fichier de logo, pas un chemin inventé : avec un fichier
        // absent l'application est en état « logo introuvable », que rien
        // n'oblige à afficher les mêmes commandes. La colonne longue doit être
        // une colonne que l'on peut vraiment obtenir.
        guard let logo = fabriquerLogoDEssai() else {
            r.verifier("fabrication du logo d'essai", false); return
        }
        defer { try? FileManager.default.removeItem(at: logo) }

        let court = AppState(memoire: false)
        let long = AppState(memoire: false)
        long.chargerLogo(logo)

        r.verifier("la mise en scène tient : la colonne courte est sans logo, "
                   + "la longue en a un",
                   !court.profil.logoActif && court.profil.logoFichier == nil
                   && long.profil.logoActif && long.profil.logoFichier == logo)
        r.verifier("et le logo mis en scène existe vraiment — la colonne longue "
                   + "est un état atteignable", !long.logoIntrouvable)

        let barreFermee = hauteurBarreAction(court, voletOuvert: false)
        let barreOuverte = hauteurBarreAction(court, voletOuvert: true)
        let barreReglagesLongs = hauteurBarreAction(long, voletOuvert: true)

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
        let panneauCourt = hauteurPanneauReglages(court)
        let panneauLong = hauteurPanneauReglages(long)
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
        let etat = AppState(memoire: false)
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
    ///
    /// L'état lui est DONNÉ, jamais fabriqué ici : c'est l'appelant qui met en
    /// scène, et qui a vérifié sa mise en scène. Un mesureur qui construit
    /// lui-même son état cache ce qu'il mesure — c'est ainsi que la colonne
    /// « sans logo » a pu en porter un pendant trois commits.
    @MainActor
    private static func hauteurBarreAction(_ etat: AppState,
                                           voletOuvert: Bool) -> CGFloat {
        etat.voletOuvert = voletOuvert
        let hote = NSHostingView(
            rootView: BarreAction().environmentObject(etat)
                .frame(width: Fenetre.largeurIdealeOuverte))
        hote.layoutSubtreeIfNeeded()
        return hote.fittingSize.height
    }

    /// Hauteur naturelle du contenu de la colonne défilante. Même règle : l'état
    /// vient de l'appelant.
    @MainActor
    private static func hauteurPanneauReglages(_ etat: AppState) -> CGFloat {
        let hote = NSHostingView(
            rootView: PanneauPersonnaliserView().environmentObject(etat)
                .frame(width: Fenetre.largeurUtileReglages))
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
        let neutre = AppState(memoire: false)
        neutre.profil = .neutre
        r.verifier("profil neutre : la case est cochée", neutre.hauteurConstante)
        r.egal("profil neutre : le champ garde sa valeur",
               ProfilHabillage.neutre.bandeauHauteurFixeLignes, 2)
        r.egal("le préréglage NONP garde la sienne",
               ProfilHabillage.bandeauColore.bandeauHauteurFixeLignes, 0)

        let nonp = AppState(memoire: false)
        nonp.profil = .bandeauColore
        r.verifier("préréglage NONP : la case est décochée", !nonp.hauteurConstante)

        // Cocher reprend « Lignes maximum ». Décocher rend la hauteur au texte.
        let etat = AppState(memoire: false)
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
        let charge = AppState(memoire: false)
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

    // MARK: - L'aide des réglages

    /// Un libellé nomme un réglage ; il ne dit pas ce qu'on y gagne.
    ///
    /// Que chaque réglage AIT une aide, le compilateur s'en charge : les
    /// constructeurs de contrôles en réclament une, et un réglage ajouté sans
    /// la sienne ne compile pas. Ce qu'il ne peut pas exiger, c'est qu'elle
    /// serve à quelque chose — et c'est là-dessus que porte cette rubrique.
    private static func aideDesReglages(_ r: Rapport) {
        let aides = Textes.Aide.toutes
        r.egal("chaque réglage du volet et chaque zone de dépôt a son aide",
               aides.count, 18)

        r.verifier("aucune n'est vide",
                   aides.allSatisfy { !$0.texte.trimmingCharacters(
                       in: .whitespacesAndNewlines).isEmpty })

        // Deux réglages qui reçoivent la même phrase sont deux réglages dont
        // l'un des deux n'a pas été écrit.
        let uniques = Set(aides.map(\.texte))
        r.egal("aucune n'est le copier-coller d'une autre", uniques.count, aides.count)

        // Le survol doit APPRENDRE quelque chose, et cela se joue aux premiers
        // mots : une aide qui S'OUVRE sur son propre libellé commence par ce
        // qu'on savait déjà. Employer le mot plus loin est légitime — « la
        // taille exacte », « les premières polices » —, l'ouvrir dessus ne
        // l'est pas.
        //
        // L'article de tête ne compte pas : « La couleur du fond… » sous un
        // libellé « Couleur du fond » est exactement le cas visé.
        func ouvertureNue(_ texte: String) -> String {
            var t = texte.lowercased()
            for article in ["les ", "le ", "la ", "l'", "un ", "une "]
            where t.hasPrefix(article) {
                t.removeFirst(article.count); break
            }
            return t
        }
        let libelles: [String] = [
            Textes.Interface.taille, Textes.Interface.police,
            Textes.Interface.couleurTexte, Textes.Interface.couleurContour,
            Textes.Interface.lignesMax, Textes.Interface.bandeauActif,
            Textes.Interface.modeBandeau, Textes.Interface.couleurBandeau,
            Textes.Interface.hauteurFixe, Textes.Interface.margeBasse,
        ]
        let repetitions = zip(aides.prefix(libelles.count), libelles)
            .filter { ouvertureNue($0.0.texte).hasPrefix($0.1.lowercased()) }
            .map(\.1)
        r.egal("aucune ne s'ouvre en répétant son libellé", repetitions, [])

        // Assez longue pour dire quelque chose, assez courte pour être lue au
        // survol — une infobulle qu'on ne finit pas ne sert personne.
        let tropCourtes = aides.filter { $0.texte.count < 60 }.map(\.nom)
        let tropLongues = aides.filter { $0.texte.count > 240 }.map(\.nom)
        r.egal("aucune n'est trop courte pour apprendre quoi que ce soit",
               tropCourtes, [])
        r.egal("aucune n'est trop longue pour être lue au survol", tropLongues, [])

        r.verifier("chacune est une phrase, ponctuation comprise",
                   aides.allSatisfy { $0.texte.hasSuffix(".") })

        // Les deux promesses du produit se disent là où l'on dépose un
        // fichier, pas dans un manuel que personne n'ouvrira.
        r.verifier("le dépôt de la vidéo promet que l'original n'est pas touché",
                   Textes.Aide.depotVideo.contains("jamais modifiée"))
        r.verifier("le dépôt des sous-titres porte l'invariant nº1 — aucun mot "
                   + "n'est modifié",
                   Textes.Aide.depotSousTitres.contains("Aucun mot"))

        // Le piège du format vertical, nommé là où il se tend.
        r.verifier("l'aide de la taille du logo dit que le pourcentage porte "
                   + "sur la hauteur",
                   Textes.Aide.tailleLogo.contains("HAUTEUR"))
        r.verifier("l'aide de la taille du texte prévient qu'un format change "
                   + "le résultat",
                   Textes.Aide.taille.contains("16:9")
                   && Textes.Aide.taille.contains("9:16"))
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

        // Les deux phrases ont quitté la ligne pour l'infobulle du menu, et le
        // NOM les y a rejointes le 06/09. Aucun des trois textes n'a été
        // RÉSUMÉ : les perdre en chemin serait la seule façon de rater cet
        // allègement, puisque plus rien à l'écran ne les rappelle.
        let infobulle = Textes.Interface.fondDeLApercuInfobulle
        r.verifier("l'infobulle du menu porte son nom, mot pour mot",
                   infobulle.contains(Textes.Interface.fondDeLApercu))
        r.verifier("elle porte la réserve, mot pour mot",
                   infobulle.contains(Textes.Interface.fondApercuSeulement))
        r.verifier("elle porte aussi le conseil d'usage, mot pour mot",
                   infobulle.contains(Textes.Interface.fondDeLApercuConseil))
        r.verifier("et rien d'autre — l'infobulle est la somme des trois "
                   + "(\(infobulle.count) caractères)",
                   infobulle.count == Textes.Interface.fondDeLApercu.count
                   + Textes.Interface.fondApercuSeulement.count
                   + Textes.Interface.fondDeLApercuConseil.count + 4)

        // Ce que la ligne montre encore doit se lire SEUL : c'est la condition
        // qui autorisait à retirer le nom. Chaque libellé porte son rang sur
        // six et le qualificatif de l'image — on sait ce qu'on choisit sans
        // survoler quoi que ce soit.
        r.verifier("l'état visible du réglage se lit sans son nom",
                   libelles.allSatisfy { $0.contains("/6 — ") })

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
        let etat = AppState(memoire: false)
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
        let avecST = AppState(memoire: false)
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
        let barreAction = hauteurBarreAction(AppState(memoire: false), voletOuvert: true)

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
        //
        // Il y avait ici « les réglages tiennent dans la colonne sans être
        // rognés (313 points pour 313) ». Ce contrôle ne pouvait pas échouer :
        // il mesurait `fittingSize` d'un volet enfermé dans `.frame(width:)`,
        // qui rend la largeur imposée quoi que réclame le contenu. Et il passait
        // pendant que la colonne rognait. La largeur se mesure désormais dans
        // `libellesDeLaColonne`, avec une marge, par une mesure capable de voir
        // un débordement ; et `colonneEtAscenseur` éprouve le conteneur réel.
        let etat = AppState(memoire: false)
        etat.profil.logoActif = true
        etat.profil.logoFichier = URL(fileURLWithPath: "/x.png")
        let hauteur = hauteurPanneauReglages(etat)
        r.verifier("la colonne des réglages a une hauteur exploitable "
                   + "(\(Int(hauteur)) points, défilante)", hauteur > 200)

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
        let etat = AppState(memoire: false)
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

    // MARK: - Glissement du logo

    /// **Déplacer vers la droite déplace vers la droite** — et seulement vers la
    /// droite.
    ///
    /// Rien ne le vérifiait, et le placement à la souris était faux : logo en
    /// haut à gauche, un pas vers la droite le faisait tomber au bas de l'image,
    /// le centre était inatteignable, et en 9:16 le logo sautait en bas à
    /// droite. Le geste confondait l'origine de la fenêtre et celle de l'image —
    /// voir `GlissementLogo`.
    ///
    /// **Ce que le contrôle éprouve.** Un glissement ne se simule pas : AppKit
    /// ignore les événements souris synthétiques. Le contrôle rejoue donc
    /// EXACTEMENT ce que fait le geste — centre à la saisie, translation, puis
    /// `AppState.deplacerLogo` et la vraie géométrie du logo — et mesure où le
    /// logo atterrit, en pixels de la vidéo, en 16:9 et en 9:16. Ce qu'il ne
    /// voit pas : que la vue appelle bien ces fonctions avec la translation.
    ///
    /// Avant tout, il prouve qu'il aurait vu le défaut : l'ancienne formule,
    /// rejouée avec l'origine mesurée de l'image, doit échouer.
    @MainActor
    private static func glissementLogo(_ r: Rapport) {
        guard let urlLogo = fabriquerLogoDEssai() else {
            r.verifier("logo d'essai", false); return
        }

        for (format, l, h) in [("16:9", 1920, 1080), ("9:16", 1080, 1920)] {
            guard let fond = fondDeControle(largeur: l, hauteur: h) else {
                r.verifier("\(format) : fond de contrôle", false); continue
            }
            let etat = AppState(memoire: false)
            etat.chargerLogo(urlLogo)
            etat.poserFondsDeControle([(instant: 0, image: fond, luminosite: 0.5)])
            let image = CGSize(width: l, height: h)
            // La taille à laquelle la fenêtre par défaut affiche cette image.
            let affichee = Apercu.tailleAffichee(image: image,
                                                 dans: CGSize(width: 782, height: 492))
            // Tolérance : un pixel et demi de la vidéo — `GeometrieLogo` arrondit
            // au pixel.
            let tx = 1.5 / CGFloat(l), ty = 1.5 / CGFloat(h)

            func centre() -> CGPoint {
                GlissementLogo.centre(rectangle: etat.rectangleLogo ?? .zero, image: image)
            }
            /// Rejoue le geste : saisie, puis translations successives, en
            /// points d'écran depuis la saisie. Rend le centre après chacune.
            func glisser(depuis depart: PositionLogo, _ translations: [CGSize]) -> (CGPoint, [CGPoint]) {
                etat.profil.logoPosition = depart
                let c0 = centre()
                return (c0, translations.map { t in
                    etat.deplacerLogo(versFraction: GlissementLogo.position(
                        centreDepart: c0, translation: t, affichee: affichee))
                    return centre()
                })
            }
            let pasX = affichee.width * 0.05, pasY = affichee.height * 0.05

            // 0. Le contrôle aurait vu le défaut. L'ancienne formule : la
            //    position du pointeur dans l'espace de la fenêtre, divisée par la
            //    taille de l'image. Origine mesurée de l'image dans cet espace.
            let origine = format == "16:9" ? CGPoint(x: 16, y: 371) : CGPoint(x: 268, y: 345)
            etat.profil.logoPosition = .coin(.hautGauche)
            let ancienDepart = centre()
            let pointeur = CGPoint(x: origine.x + (ancienDepart.x * affichee.width) + pasX,
                                   y: origine.y + ancienDepart.y * affichee.height)
            etat.deplacerLogo(versFraction: CGPoint(x: pointeur.x / affichee.width,
                                                    y: pointeur.y / affichee.height))
            let ancienArrivee = centre()
            r.verifier("\(format) : le contrôle aurait vu le défaut — avec l'ancienne "
                       + "formule, un pas vers la droite déplaçait le logo de "
                       + String(format: "%+.2f", ancienArrivee.y - ancienDepart.y)
                       + " en hauteur",
                       abs(ancienArrivee.y - ancienDepart.y) > ty)

            // 1. Vers la droite, depuis le coin haut-gauche : x suit, y ne bouge pas.
            let (c1, droite) = glisser(depuis: .coin(.hautGauche),
                                       (1...5).map { CGSize(width: CGFloat($0) * pasX, height: 0) })
            let derivesY = droite.map { abs($0.y - c1.y) }.max() ?? 0
            let ecartsX = droite.enumerated().map { i, c in
                abs((c.x - c1.x) - CGFloat(i + 1) * 0.05) }.max() ?? 0
            r.verifier("\(format) : vers la droite depuis le haut à gauche, le logo "
                       + "ne bouge pas en hauteur (dérive max "
                       + String(format: "%.1f", derivesY * CGFloat(h)) + " px)",
                       derivesY <= ty)
            r.verifier("\(format) : … et il suit le pointeur en largeur (écart max "
                       + String(format: "%.1f", ecartsX * CGFloat(l)) + " px)",
                       ecartsX <= tx)

            // 2. Vers le bas, depuis le centre : y suit, x ne bouge pas.
            let (c2, bas) = glisser(depuis: .libre(xPct: 50, yPct: 50),
                                    (1...5).map { CGSize(width: 0, height: CGFloat($0) * pasY) })
            let derivesX = bas.map { abs($0.x - c2.x) }.max() ?? 0
            let ecartsY = bas.enumerated().map { i, c in
                abs((c.y - c2.y) - CGFloat(i + 1) * 0.05) }.max() ?? 0
            r.verifier("\(format) : vers le bas depuis le centre, le logo ne bouge pas "
                       + "en largeur (dérive max "
                       + String(format: "%.1f", derivesX * CGFloat(l)) + " px) et "
                       + "descend avec le pointeur (écart max "
                       + String(format: "%.1f", ecartsY * CGFloat(h)) + " px)",
                       derivesX <= tx && ecartsY <= ty)

            // 3. Saisir sans bouger ne fait pas sauter le logo.
            let (c3, immobile) = glisser(depuis: .coin(.basDroit), [.zero])
            r.verifier("\(format) : saisir le logo sans bouger ne le déplace pas",
                       abs(immobile[0].x - c3.x) <= tx && abs(immobile[0].y - c3.y) <= ty)

            // 4. Le centre est atteignable.
            etat.profil.logoPosition = .coin(.hautGauche)
            let c4 = centre()
            let (_, versCentre) = glisser(depuis: .coin(.hautGauche), [CGSize(
                width: (0.5 - c4.x) * affichee.width, height: (0.5 - c4.y) * affichee.height)])
            r.verifier("\(format) : le centre de l'image est atteignable ("
                       + String(format: "%.3f, %.3f", versCentre[0].x, versCentre[0].y) + ")",
                       abs(versCentre[0].x - 0.5) <= tx && abs(versCentre[0].y - 0.5) <= ty)

            // 5. Tiré au-delà du coin bas-droit, le logo s'y arrête, dans
            //    l'image ; ramené au point de saisie, il revient à sa place —
            //    aucune dérive ne s'accumule.
            let loin = CGSize(width: 2 * affichee.width, height: 2 * affichee.height)
            etat.profil.logoPosition = .libre(xPct: 50, yPct: 50)
            let c5 = centre()
            etat.deplacerLogo(versFraction: GlissementLogo.position(
                centreDepart: c5, translation: loin, affichee: affichee))
            let rectBord = etat.rectangleLogo ?? .zero
            etat.deplacerLogo(versFraction: GlissementLogo.position(
                centreDepart: c5, translation: .zero, affichee: affichee))
            let retour = centre()
            r.verifier("\(format) : tiré au-delà du coin bas-droit, le logo s'y arrête, "
                       + "dans l'image",
                       abs(rectBord.maxX - CGFloat(l)) <= 1 && abs(rectBord.minY) <= 1)
            r.verifier("\(format) : ramené au point de saisie, il revient à sa place",
                       abs(retour.x - c5.x) <= tx && abs(retour.y - c5.y) <= ty)

            // 6. La poignée est là où le logo est dessiné : en HAUT pour un coin
            //    du haut. C'est le retournement de repère Core Graphics → écran.
            let marge = CGFloat(etat.miseEnPage?.parametres.margeLogo ?? 0)
                * affichee.width / CGFloat(l)
            etat.profil.logoPosition = .coin(.hautGauche)
            let haut = GlissementLogo.cadreAffiche(rectangle: etat.rectangleLogo ?? .zero,
                                                   image: image, affichee: affichee)
            etat.profil.logoPosition = .coin(.basDroit)
            let basDroit = GlissementLogo.cadreAffiche(rectangle: etat.rectangleLogo ?? .zero,
                                                       image: image, affichee: affichee)
            r.verifier("\(format) : la poignée d'un logo en haut à gauche est en haut à "
                       + "gauche de l'aperçu",
                       abs(haut.minX - marge) <= 1 && abs(haut.minY - marge) <= 1)
            r.verifier("\(format) : celle d'un logo en bas à droite, en bas à droite",
                       abs(basDroit.maxX - (affichee.width - marge)) <= 1
                       && abs(basDroit.maxY - (affichee.height - marge)) <= 1)
        }
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
        let barreAction = hauteurBarreAction(AppState(memoire: false), voletOuvert: false)

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
        let etat = AppState(memoire: false)
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
        let autre = AppState(memoire: false)
        autre.chargerSousTitres(srt)
        autre.retirerSousTitres()
        r.verifier("retirer les sous-titres n'emporte rien d'autre",
                   autre.sousTitres == nil && autre.cues.isEmpty && autre.video == nil)
    }

    // MARK: - Le nom proposé à l'enregistrement

    /// Le nom du fichier produit vient du **fichier de sous-titres** quand il y
    /// en a un — c'est lui qui porte un nom choisi, quand la vidéo garde
    /// souvent celui que lui a donné son téléchargement.
    @MainActor
    private static func nomProposé(_ r: Rapport) {
        let dossierVideo = URL(fileURLWithPath: "/Users/x/Téléchargements")
        let video = dossierVideo.appendingPathComponent(
            "21 Atelier ORVA reunion publique extrait complet sans montage.mp4")
        let srt = URL(fileURLWithPath: "/Users/x/Documents/Atelier ORVA Exemple.srt")

        let avec = AppState.sortieProposee(video: video, sousTitres: srt)
        r.egal("avec sous-titres : le nom vient du .srt",
               avec.lastPathComponent, "Atelier ORVA Exemple_habillee.mp4")

        // Le NOM vient des sous-titres, le DOSSIER reste celui de la vidéo :
        // le .srt vit souvent ailleurs, et déplacer la sortie sans le dire
        // ferait chercher le fichier produit.
        r.egal("avec sous-titres : le dossier reste celui de la vidéo",
               avec.deletingLastPathComponent().path, dossierVideo.path)

        let sans = AppState.sortieProposee(video: video, sousTitres: nil)
        r.egal("sans sous-titres : le nom vient de la vidéo",
               sans.lastPathComponent,
               "21 Atelier ORVA reunion publique extrait complet sans "
               + "montage_habillee.mp4")

        // Le piège du nom venu du .srt : « ORVA.srt » sur
        // « ORVA_habillee.mp4 » proposerait la vidéo source elle-même.
        let deja = dossierVideo.appendingPathComponent("ORVA_habillee.mp4")
        let repli = AppState.sortieProposee(
            video: deja, sousTitres: URL(fileURLWithPath: "/tmp/ORVA.srt"))
        r.verifier("le nom proposé ne retombe jamais sur la vidéo source",
                   !ExportateurVideo.memeFichier(repli, deja))
        r.egal("il repart alors du nom de la vidéo",
               repli.lastPathComponent, "ORVA_habillee_habillee.mp4")

        // Quelle que soit l'entrée, la sortie reste un .mp4.
        r.verifier("la sortie proposée est un .mp4",
                   avec.pathExtension == "mp4" && sans.pathExtension == "mp4"
                   && repli.pathExtension == "mp4")

        // Le suffixe est NEUTRE. C'est la règle écrite pour les préréglages le
        // 28/08 : rien, dans une application publique, n'applique l'identité
        // d'une association aux fichiers d'un inconnu.
        let suffixe = Textes.Export.suffixeSortie
        r.verifier("le suffixe ne nomme aucune association "
                   + "(« \(suffixe) »)",
                   !suffixe.lowercased().contains("nonp"))
        r.verifier("le suffixe n'est pas vide — sans quoi la sortie pourrait "
                   + "porter le nom d'une entrée", !suffixe.isEmpty)
        r.verifier("le suffixe s'écrit sans accent ni espace",
                   suffixe.allSatisfy { $0.isASCII && !$0.isWhitespace })
    }

    // MARK: - Habiller une autre vidéo

    /// Le bouton de fin de course doit rendre l'application prête pour le
    /// fichier suivant : la vidéo et ses sous-titres partent, l'habillage reste.
    @MainActor
    private static func habillerUneAutreVideo(_ r: Rapport) {
        guard let video = ControlesExport.fabriquerVideoDEssai() else {
            r.verifier("fabrication de la vidéo d'essai", false); return
        }
        defer { try? FileManager.default.removeItem(at: video) }

        let srt = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonp-enchainement-essai.srt")
        try? """
            1
            00:00:00,500 --> 00:00:01,500
            Il m'a dit qu'il n'avait rien vu ce jour-là.

            """.write(to: srt, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: srt) }

        let etat = AppState(memoire: false)
        etat.chargerVideo(video)
        guard pomperJusqua({ etat.video != nil && !etat.apercuEnPreparation }) else {
            r.verifier("la vidéo d'essai se charge dans l'application", false); return
        }
        etat.chargerSousTitres(srt)

        // L'habillage que l'enchaînement doit préserver — des réglages qui ne
        // sont pas ceux par défaut, et un logo.
        guard let logo = fabriquerLogoDEssai() else {
            r.verifier("fabrication du logo d'essai", false); return
        }
        defer { try? FileManager.default.removeItem(at: logo) }
        etat.chargerLogo(logo)
        etat.lignesMax = 3
        etat.profil.couleurTexte = CouleurProfil(hex: "#FF3B30")
        let habillage = etat.profil

        r.verifier("au départ : vidéo, sous-titres, réglages et logo sont là",
                   etat.video != nil && etat.sousTitres != nil
                   && etat.profil.logoActif && etat.profil.logoFichier != nil)

        etat.recommencer()

        // Ce qui doit PARTIR : le document.
        r.verifier("« Habiller une autre vidéo » : plus de vidéo chargée",
                   etat.video == nil)
        r.verifier("« Habiller une autre vidéo » : plus de définition ni de durée",
                   etat.tailleVideo == nil && etat.dureeVideo == 0)
        r.verifier("« Habiller une autre vidéo » : plus d'image de fond",
                   etat.fondsDisponibles.isEmpty)
        // Une autre vidéo appelle d'autres sous-titres : les garder graverait
        // le texte de la précédente sur l'image de la suivante.
        r.verifier("« Habiller une autre vidéo » : plus de sous-titres",
                   etat.sousTitres == nil && etat.cues.isEmpty
                   && etat.repliques.isEmpty)
        r.verifier("« Habiller une autre vidéo » : l'écran d'accueil revient, "
                   + "vide", etat.etape == .accueil && etat.apercu == nil
                   && etat.imageAccueil == nil)
        r.verifier("« Habiller une autre vidéo » : « Habiller » redevient "
                   + "impossible tant qu'on n'a rien déposé", !etat.peutHabiller)
        r.verifier("« Habiller une autre vidéo » : plus aucun geste de retrait "
                   + "n'est nécessaire avant de déposer la suivante",
                   etat.video == nil && etat.sousTitres == nil)

        // Ce qui doit RESTER : l'habillage. Il ne change pas d'une vidéo à
        // l'autre, et le redemander viderait de son sens le profil mémorisé.
        r.egal("« Habiller une autre vidéo » garde tous les réglages",
               etat.profil, habillage)
        r.verifier("« Habiller une autre vidéo » garde le logo",
                   etat.profil.logoActif && etat.profil.logoFichier == logo)
        r.egal("« Habiller une autre vidéo » garde « Lignes maximum »",
               etat.lignesMax, 3)
    }

    // MARK: - Revenir aux réglages

    /// L'autre issue de l'écran de fin — celle qui ne perd rien.
    ///
    /// Contrôle jumeau de `habillerUneAutreVideo`, et volontairement écrit
    /// contre lui : les deux boutons sont voisins, leurs effets sont opposés,
    /// et c'est cette OPPOSITION qui doit être vérifiée. L'un vide le document,
    /// l'autre ne touche à rien. Une régression qui rapprocherait les deux
    /// comportements ferait tomber l'un des deux contrôles.
    ///
    /// Il fait un VRAI export, puis un SECOND depuis l'état revenu. Simuler
    /// l'étape « terminé » n'aurait rien prouvé : ce qui est en cause, c'est
    /// qu'un export laisse l'application capable d'en refaire un, sur le même
    /// fichier, sans redéposer quoi que ce soit.
    @MainActor
    private static func revenirAuxReglages(_ r: Rapport) {
        guard let video = ControlesExport.fabriquerVideoDEssai() else {
            r.verifier("fabrication de la vidéo d'essai", false); return
        }
        defer { try? FileManager.default.removeItem(at: video) }

        let srt = ControlesExport.dossierTemporaire()
            .appendingPathComponent("nonp-retour-essai.srt")
        try? """
            1
            00:00:00,200 --> 00:00:01,500
            Il m'a dit qu'il n'avait rien vu ce jour-là.

            """.write(to: srt, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: srt) }

        let etat = AppState(memoire: false)
        etat.chargerVideo(video)
        guard pomperJusqua({ etat.video != nil && !etat.apercuEnPreparation }) else {
            r.verifier("la vidéo d'essai se charge dans l'application", false); return
        }
        etat.chargerSousTitres(srt)

        guard let logo = fabriquerLogoDEssai() else {
            r.verifier("fabrication du logo d'essai", false); return
        }
        defer { try? FileManager.default.removeItem(at: logo) }
        etat.chargerLogo(logo)
        etat.lignesMax = 3
        etat.profil.couleurTexte = CouleurProfil(hex: "#FF3B30")
        // Le volet OUVERT : c'est l'écran qu'on quitte, et c'est celui qu'on
        // doit retrouver. Le refermer en chemin renverrait sur un accueil nu
        // quelqu'un qui réglait.
        etat.voletOuvert = true
        let habillage = etat.profil
        let fondChoisi = etat.indexFond

        // Le nom d'avant le premier export : celui que l'application calcule.
        let nomCalcule = etat.sortieProposee?.lastPathComponent

        // ── Premier export ────────────────────────────────────────────────
        //
        // Vers un nom CHOISI, différent de celui que l'application propose :
        // c'est le cas qui distingue « reproposer le fichier écrit » de
        // « recalculer le nom », et c'est celui d'un utilisateur qui renomme
        // dans le panneau d'enregistrement.
        let choisi = ControlesExport.dossierTemporaire()
            .appendingPathComponent("retour-choisi.mp4")
        try? FileManager.default.removeItem(at: choisi)
        defer { try? FileManager.default.removeItem(at: choisi) }

        etat.habiller(vers: choisi)
        guard pomperJusqua({ etat.etape == .termine(choisi) }, secondes: 120) else {
            r.verifier("le premier export aboutit — étape « terminé » "
                       + "(obtenu : \(etat.etape))", false); return
        }
        r.verifier("le premier export écrit le fichier",
                   FileManager.default.fileExists(atPath: choisi.path))
        let ecritureDuPremier = ecritureDe(choisi)

        // ── Le retour ─────────────────────────────────────────────────────
        etat.reprendreCetteVideo()

        r.verifier("« Revenir aux réglages » ramène à l'écran précédent",
                   etat.etape == .accueil)
        r.verifier("« Revenir aux réglages » garde la vidéo, avec sa définition "
                   + "et sa durée",
                   etat.video == video && etat.tailleVideo != nil
                   && etat.dureeVideo > 0)
        r.verifier("« Revenir aux réglages » garde les sous-titres et leurs "
                   + "répliques",
                   etat.sousTitres == srt && !etat.cues.isEmpty
                   && !etat.repliques.isEmpty)
        r.egal("« Revenir aux réglages » garde tous les réglages",
               etat.profil, habillage)
        r.verifier("« Revenir aux réglages » garde le logo",
                   etat.profil.logoActif && etat.profil.logoFichier == logo)
        r.verifier("« Revenir aux réglages » garde le volet ouvert et son fond "
                   + "d'aperçu",
                   etat.voletOuvert && etat.indexFond == fondChoisi)
        r.verifier("« Revenir aux réglages » garde les images de fond et l'aperçu",
                   !etat.fondsDisponibles.isEmpty && etat.apercu != nil)
        r.verifier("« Revenir aux réglages » ne laisse aucune progression "
                   + "derrière lui",
                   etat.avancement == 0 && etat.tempsRestant == nil)

        // Le point de tout l'exercice : le bouton « Habiller » est réarmé.
        // `peutHabiller` exige `.accueil` — sans le retour, il reste faux.
        r.verifier("« Habiller » redevient possible sans rien redéposer",
                   etat.peutHabiller)

        // ── Le nom proposé pour le second passage ─────────────────────────
        r.egal("le nom proposé est le fichier qu'on vient d'écrire",
               etat.sortieProposee, choisi)
        r.verifier("il ne repart donc pas du nom calculé "
                   + "(« \(nomCalcule ?? "—") »)",
                   etat.sortieProposee?.lastPathComponent != nomCalcule)
        r.verifier("aucun suffixe ne s'empile sur la sortie précédente",
                   !(etat.sortieProposee?.lastPathComponent
                       .contains(Textes.Export.suffixeSortie
                                 + Textes.Export.suffixeSortie) ?? false))

        // ── Second export, réglage corrigé ────────────────────────────────
        //
        // C'est le geste décrit par le retour d'usage : on revient, on corrige,
        // on refait. Le fichier produit doit REMPLACER le premier, pas s'écrire
        // à côté de lui.
        etat.lignesMax = 2
        etat.habiller(vers: choisi)
        guard pomperJusqua({ etat.etape == .termine(choisi) }, secondes: 120) else {
            r.verifier("le second export aboutit — étape « terminé » "
                       + "(obtenu : \(etat.etape), erreur : "
                       + "\(etat.erreur ?? "aucune"))", false); return
        }
        r.verifier("un second export depuis cet état aboutit", true)
        r.verifier("le second export a bien écrit un fichier non vide",
                   FileManager.default.fileExists(atPath: choisi.path)
                   && octetsDe(choisi) > 0)
        // REMPLACÉ, pas doublé : le fichier est le même, et il est plus récent.
        // C'est la seule mesure qui distingue une réécriture d'un fichier resté
        // en place — deux encodages du même plan peuvent peser pareil.
        r.verifier("il a REMPLACÉ le premier, et non laissé le sien en place",
                   ecritureDe(choisi) ?? .distantPast
                   > ecritureDuPremier ?? .distantFuture)
        r.egal("il n'a rien écrit à côté : un seul .mp4 sous ce nom",
               fichiersMP4(ControlesExport.dossierTemporaire(),
                           prefixe: "retour-choisi"), 1)

        // ── Et l'opposition avec sa voisine ───────────────────────────────
        //
        // Depuis ce MÊME état de fin, l'autre bouton doit tout vider — dont le
        // nom mémorisé, qui appartient au document qui s'en va.
        etat.recommencer()
        r.verifier("« Habiller une autre vidéo », elle, vide bien le document",
                   etat.video == nil && etat.sousTitres == nil)
        r.verifier("et oublie le fichier écrit : plus rien à reproposer",
                   etat.sortieProposee == nil)
    }

    /// Taille d'un fichier, 0 s'il n'existe pas.
    private static func octetsDe(_ url: URL) -> Int {
        let attributs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributs?[.size] as? NSNumber)?.intValue ?? 0
    }

    /// Date de dernière écriture, `nil` si le fichier n'existe pas.
    private static func ecritureDe(_ url: URL) -> Date? {
        let attributs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributs?[.modificationDate] as? Date
    }

    /// Combien de `.mp4` commençant par ce préfixe vivent dans ce dossier.
    ///
    /// C'est ce qui distingue « remplacer » de « écrire à côté » : un second
    /// export qui aurait glissé sur « retour-choisi 2.mp4 » ou
    /// « retour-choisi_habillee.mp4 » se verrait ici, et nulle part ailleurs.
    private static func fichiersMP4(_ dossier: URL, prefixe: String) -> Int {
        let contenu = (try? FileManager.default.contentsOfDirectory(
            atPath: dossier.path)) ?? []
        return contenu.filter {
            $0.hasPrefix(prefixe) && $0.hasSuffix(".mp4")
        }.count
    }

    /// Fait tourner la boucle d'exécution jusqu'à ce que la condition tienne.
    ///
    /// `chargerVideo` travaille en tâche de fond ; le harnais, lui, est
    /// synchrone. Sans cette pompe, aucune vidéo ne serait jamais chargée dans
    /// un `AppState` de contrôle, et l'enchaînement d'une vidéo à la suivante —
    /// le seul retour d'usage qui porte là-dessus — ne serait pas éprouvé.
    @MainActor
    private static func pomperJusqua(_ condition: () -> Bool,
                                     secondes: Double = 20) -> Bool {
        let limite = Date().addingTimeInterval(secondes)
        while !condition(), Date() < limite {
            RunLoop.current.run(mode: .default,
                                before: Date().addingTimeInterval(0.02))
        }
        return condition()
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
    /// de coin qui rogne son titre — ne change pas de hauteur.
    ///
    /// **Ce contrôle est donc aveugle à la troncature.** Il avait été écrit en
    /// la tenant pour une « dégradation acceptable » ; elle ne l'est pas, elle
    /// se voit : les boutons de coin ont affiché « Haut gau… », « Haut dr… »
    /// (DC-1, corrigé par 5a1374a). Qu'il passe ne dit rien des titres
    /// tronqués : c'est `troncatures` qui les cherche.
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
    ///
    /// **Et elle se prend avec une marge.** Le contenu reçoit
    /// `largeurUtileReglages` (316 points) ; les lignes se mesurent à
    /// `largeurDeControleReglages`, plus étroite de `margeDeSecuriteReglages`.
    /// Mesurer à 313 pour 313 reçus, c'était passer au point près — donc ne rien voir
    /// d'une dérive d'un point.
    @MainActor
    private static func libellesDeLaColonne(_ r: Rapport) {
        _ = NSApplication.shared
        let recue = Fenetre.largeurUtileReglages
        let etroit = Fenetre.largeurDeControleReglages

        r.verifier("la largeur que reçoit le contenu retranche l'ascenseur de la "
                   + "colonne défilante (\(Int(recue)) points, et non "
                   + "\(Int(Fenetre.largeurReglages - 2 * Fenetre.margeReglages)))",
                   recue < Fenetre.largeurReglages - 2 * Fenetre.margeReglages)
        r.verifier("la mesure se prend avec une marge : \(Int(etroit)) points "
                   + "pour \(Int(recue)) reçus, et non à l'égalité",
                   recue - etroit >= Fenetre.margeDeSecuriteReglages
                   && Fenetre.margeDeSecuriteReglages > 0)

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
        //
        // La mesure doit d'abord prouver qu'elle SAIT échouer : l'ancienne,
        // `fittingSize` sous `.frame(width:)`, rendait la largeur imposée et
        // ne pouvait donc que passer. Une vue rigide de 40 points trop large
        // doit se voir.
        let rigide = largeurReclamee(Color.clear.frame(width: etroit + 40),
                                     proposee: etroit)
        r.verifier("la mesure de largeur voit un débordement (une vue de "
                   + "\(Int(etroit + 40)) points, proposée à \(Int(etroit)), en "
                   + "réclame \(Int(rigide)))",
                   rigide > etroit + 39)

        // Deux états du volet : sans logo, et celui du défaut constaté — logo
        // chargé, pas de sous-titres. Le format de la vidéo n'y change rien :
        // aucun réglage de la colonne n'en dépend en largeur. Le nom de logo
        // est long exprès : c'est lui qui pousse « Retirer le logo » au bord.
        let nu = AppState(memoire: false)
        let logo = AppState(memoire: false)
        logo.profil.logoActif = true
        logo.profil.logoFichier = URL(
            fileURLWithPath: "/x/logo-de-la-chaine-version-definitive-rond-fond-transparent.png")
        let etats: [(String, AppState)] = [("sans logo", nu), ("logo chargé", logo)]
        for (nom, etat) in etats {
            let reclamee = largeurReclamee(
                PanneauPersonnaliserView().environmentObject(etat), proposee: etroit)
            r.verifier("\(nom) : le volet entier tient à \(Int(etroit)) points "
                       + "(il en réclame \(Int(reclamee.rounded(.up)))), soit "
                       + "\(Int(recue - reclamee)) de marge sur les \(Int(recue)) reçus",
                       reclamee <= etroit + 0.5)
        }
    }

    /// La largeur que réclame une vue quand on lui en propose `largeur`.
    ///
    /// Passe par `NSHostingController.sizeThatFits(in:)` : la vue répond à une
    /// proposition, et si son contenu est plus large, elle le dit. Surtout pas
    /// `fittingSize` d'une vue enfermée dans `.frame(width:)` — ce cadre-là
    /// rend la largeur qu'on lui impose, et le débordement reste dedans.
    @MainActor
    private static func largeurReclamee<V: View>(_ vue: V,
                                                 proposee largeur: CGFloat) -> CGFloat {
        NSHostingController(rootView: vue)
            .sizeThatFits(in: CGSize(width: largeur, height: 100_000)).width
    }

    // MARK: - Troncatures

    /// **Aucun libellé de la colonne n'est tronqué à la largeur de contrôle.**
    ///
    /// C'est DC-1 : « Haut ga… », « Haut d… » sont restés des semaines dans la
    /// colonne, et tous les contrôles passaient. `libellesDeLaColonne` mesure
    /// la HAUTEUR : il attrape un libellé qui se replie, pas un titre qui se
    /// tronque. Et la largeur naturelle d'une ligne ne dit pas où la troncature
    /// commence — un bouton comprime sa marge avant son texte : les abréviations
    /// « Haut G. », que la largeur naturelle déclarait trop larges (329 points),
    /// restent entières jusqu'à 290 points et se tronquent à 280. C'est la
    /// capture qui l'a montré.
    ///
    /// La mesure passe donc par `LibelleSurveille`, qui compare ce que chaque
    /// libellé reçoit à ce que son texte entier demande. Validée contre des
    /// captures de vraies fenêtres : 56 libellés, sept largeurs, aucun désaccord
    /// (`--planche-coins <dossier> --seuils`).
    ///
    /// **Ce qu'il ne voit pas.** Un libellé qui ne passe pas par
    /// `LibelleSurveille`. Les segments d'un sélecteur, dessinés par AppKit —
    /// ils ont débordé (DC-2), et c'est `debordements` qui les surveille. Le
    /// nom du fichier logo, qui a le
    /// droit de se tronquer par le milieu. Les explications en petits
    /// caractères, qui se replient et ne se tronquent pas.
    @MainActor
    private static func troncatures(_ r: Rapport) {
        _ = NSApplication.shared
        let etroit = Fenetre.largeurDeControleReglages

        // Le détecteur doit d'abord prouver qu'il sait échouer, et qu'il ne
        // crie pas au loup.
        let long = "Un libellé bien trop long pour la place qu'on lui laisse"
        let force = libellesTronques(LibelleSurveille(long), largeur: 80)
        r.verifier("le détecteur voit un libellé tronqué (80 points pour un "
                   + "texte qui en demande davantage)", force == [long])
        let entier = libellesTronques(LibelleSurveille("Court"), largeur: 200)
        r.verifier("le détecteur ne signale pas un libellé entier", entier.isEmpty)

        // La colonne, dans les états qui montrent le plus de libellés.
        let nu = AppState(memoire: false)
        let logo = AppState(memoire: false)
        logo.profil.logoActif = true
        logo.profil.logoFichier = URL(fileURLWithPath: "/x/logo-nonp.png")
        let complet = AppState(memoire: false)
        complet.profil.logoActif = true
        complet.profil.logoFichier = URL(fileURLWithPath: "/x/logo-nonp.png")
        complet.profil.bandeauActif = true
        let etats: [(String, AppState)] = [
            ("sans logo", nu), ("logo chargé", logo), ("logo et bandeau", complet)]
        for (nom, etat) in etats {
            let tronques = libellesTronques(
                PanneauPersonnaliserView().environmentObject(etat), largeur: etroit)
            r.verifier("\(nom) : aucun libellé tronqué à \(Int(etroit)) points"
                       + (tronques.isEmpty ? ""
                          : " (tronqués : " + tronques.joined(separator: ", ") + ")"),
                       tronques.isEmpty)
        }
    }

    /// Les libellés tronqués d'une vue posée à une largeur donnée, tels que
    /// `LibelleSurveille` les publie.
    ///
    /// Une vraie fenêtre, jamais montrée : les préférences ne remontent qu'une
    /// fois la vue installée.
    @MainActor
    static func libellesTronques<V: View>(_ vue: V, largeur: CGFloat) -> [String] {
        let releve = ReleveTroncatures()
        let hote = NSHostingView(rootView: vue
            .frame(width: largeur, alignment: .leading)
            .onPreferenceChange(LibellesTronques.self) { releve.libelles = $0 })
        let fenetre = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: largeur + 40, height: 200),
            styleMask: [.borderless], backing: .buffered, defer: false)
        fenetre.isReleasedWhenClosed = false
        fenetre.contentView = hote
        hote.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        hote.layoutSubtreeIfNeeded()
        fenetre.close()
        return releve.libelles
    }

    private final class ReleveTroncatures {
        var libelles: [String] = []
    }

    // MARK: - Débordements

    /// **Aucun contrôle AppKit ne dépasse le bord de la colonne — même après
    /// que la taille de la fenêtre a été calculée.**
    ///
    /// C'est DC-2 : « Très grande » s'affichait « Très gra ». Le sélecteur
    /// segmenté de SwiftUI, aux segments de largeur égale, réclame 386 points ;
    /// dès que la taille est calculée — `fittingSize`, ce que font
    /// `.windowResizability(.contentMinSize)` et `CadreAuContenu` —, AppKit le
    /// remet à cette largeur et SwiftUI ne la corrige plus.
    ///
    /// Aucune mesure SwiftUI ne le voit : `sizeThatFits` rend la largeur que
    /// SwiftUI attribue, pas celle qu'AppKit dessine, et `LibelleSurveille` ne
    /// peut pas instrumenter les segments. Le contrôle lit donc le cadre RÉEL
    /// de chaque contrôle AppKit, dans la hiérarchie de vues, après avoir
    /// provoqué la mesure. Il reproduit exactement ce que les captures
    /// montraient : 16…332 sans mesure, 16…402 après.
    @MainActor
    private static func debordements(_ r: Rapport) {
        _ = NSApplication.shared
        let bord = Fenetre.margeReglages + Fenetre.largeurUtileReglages

        // Il doit d'abord voir DC-2 sur l'ancien sélecteur, construit comme il
        // l'était.
        let ancien = VStack(alignment: .leading, spacing: 4) {
            Text(Textes.Interface.taille)
            Picker("", selection: .constant(TailleNommee.normale)) {
                ForEach(TailleNommee.allCases) { t in
                    Text(Textes.Interface.nomTaille(t)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        let vu = controlesQuiDebordent(ancien, bord: bord)
        r.verifier("le contrôle voit DC-2 : l'ancien sélecteur « Taille », après une "
                   + "mesure, dépasse le bord (" + (vu.map {
                       "\($0.nom) jusqu'à \(Int($0.bordDroit))" }.first ?? "rien")
                   + " pour \(Int(bord)))",
                   !vu.isEmpty)

        let nu = AppState(memoire: false)
        let complet = AppState(memoire: false)
        complet.profil.logoActif = true
        complet.profil.logoFichier = URL(fileURLWithPath: "/x/logo-nonp.png")
        complet.profil.bandeauActif = true
        // Le grisé atteint bien le sélecteur AppKit : sans sous-titres, il ne
        // se clique pas ; avec, il se clique.
        let taille = PanneauPersonnaliserView.choixSegmente(
            Textes.Interface.taille, aide: "", selection: .constant(TailleNommee.normale),
            options: TailleNommee.allCases.map { ($0, Textes.Interface.nomTaille($0)) })
        let actif = selecteursActifs(taille)
        let desactive = selecteursActifs(taille.disabled(true))
        let colonneSansST = selecteursActifs(PanneauPersonnaliserView().environmentObject(nu))
        r.verifier("le sélecteur segmenté est actif par défaut",
                   actif == [true])
        r.verifier("… et `.disabled` le rend inactif, pas seulement pâle",
                   desactive == [false])
        r.verifier("sans sous-titres, les sélecteurs de la colonne sont inactifs "
                   + "(\(colonneSansST.count) trouvé(s))",
                   !colonneSansST.isEmpty && !colonneSansST.contains(true))

        for (nom, etat) in [("sans logo ni bandeau", nu), ("logo et bandeau", complet)] {
            let debord = controlesQuiDebordent(
                PanneauPersonnaliserView().environmentObject(etat), bord: bord)
            r.verifier("\(nom) : après une mesure de taille, aucun contrôle ne dépasse "
                       + "le bord de la colonne (\(Int(bord)))"
                       + (debord.isEmpty ? "" : " — " + debord.map {
                           "\($0.nom) jusqu'à \(Int($0.bordDroit))" }.joined(separator: ", ")),
                       debord.isEmpty)
        }
    }

    /// Le sélecteur AppKit reçoit-il le grisé de SwiftUI ? Il ne l'hérite pas
    /// de lui-même : `SelecteurSegmente` le lui transmet, et c'est ce qui
    /// l'empêche de rester cliquable sans sous-titres.
    @MainActor
    private static func selecteursActifs<V: View>(_ contenu: V) -> [Bool] {
        let hote = NSHostingView(rootView: ColonneReglages { contenu }.frame(height: 900))
        let fenetre = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Fenetre.largeurReglages, height: 900),
            styleMask: [.borderless], backing: .buffered, defer: false)
        fenetre.isReleasedWhenClosed = false
        fenetre.contentView = hote
        hote.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        defer { fenetre.close() }
        func toutes(_ vue: NSView) -> [NSView] { vue.subviews + vue.subviews.flatMap(toutes) }
        return toutes(hote).compactMap { ($0 as? NSSegmentedControl)?.isEnabled }
    }

    /// Les contrôles AppKit qui dépassent `bord`, le contenu posé dans la vraie
    /// colonne, APRÈS une mesure `fittingSize` — la condition de DC-2.
    @MainActor
    private static func controlesQuiDebordent<V: View>(
        _ contenu: V, bord: CGFloat) -> [(nom: String, bordDroit: CGFloat)] {
        let hote = NSHostingView(rootView: ColonneReglages { contenu }.frame(height: 900))
        hote.layoutSubtreeIfNeeded()
        _ = hote.fittingSize
        let fenetre = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Fenetre.largeurReglages, height: 900),
            styleMask: [.borderless], backing: .buffered, defer: false)
        fenetre.isReleasedWhenClosed = false
        fenetre.contentView = hote
        hote.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        defer { fenetre.close() }

        func toutes(_ vue: NSView) -> [NSView] { vue.subviews + vue.subviews.flatMap(toutes) }
        return toutes(hote).compactMap { vue in
            let classe = String(describing: type(of: vue))
            guard classe.hasPrefix("AppKitPlatformViewHost") else { return nil }
            let cadre = vue.convert(vue.bounds, to: hote)
            guard cadre.maxX > bord + 0.5 else { return nil }
            // « …Adaptor<SystemSegmentedControl>> » → « SystemSegmentedControl »
            let nom = classe.components(separatedBy: "<").last?
                .trimmingCharacters(in: CharacterSet(charactersIn: ">")) ?? classe
            return (nom, cadre.maxX)
        }
    }

    // MARK: - Colonne et ascenseur

    /// **Le contenu de la colonne garde sa largeur, quoi que fasse l'ascenseur.**
    ///
    /// Le défaut constaté à l'usage : « Retirer le log », « 15 » au lieu de
    /// « 15 % ». La `ScrollView` proposait à son contenu la largeur disponible
    /// au moment de la disposition, et ne la reproposait pas quand l'ascenseur
    /// changeait d'état — permanent ou superposé, selon Réglages Système, la
    /// souris branchée, la hauteur du contenu. Ascenseur devenu permanent, la
    /// zone visible passait à 345 points, le contenu restait à 328 plus ses
    /// marges, et les 15 derniers points disparaissaient.
    ///
    /// Aucune mesure sur une vue isolée ne peut voir cela : il faut la vraie
    /// zone défilante, dans une vraie fenêtre, et faire basculer l'ascenseur.
    /// Le conteneur éprouvé est `ColonneReglages` lui-même ; une sonde prend la
    /// place du volet et rapporte la largeur et le bord droit qu'elle reçoit.
    ///
    /// Le défaut était intermittent : une seule disposition ne prouve rien. Le
    /// contrôle enchaîne donc les bascules dans les deux sens, et vérifie
    /// chaque état.
    @MainActor
    private static func colonneEtAscenseur(_ r: Rapport) {
        _ = NSApplication.shared

        // La réserve couvre-t-elle ce que le système donne vraiment à un
        // ascenseur permanent ? Elle a valu 15 points pour un ascenseur de 17,
        // étalonnée sur un binaire mal marqué : c'est ce contrôle qui l'a vu,
        // dès que le marquage a été juste.
        let systeme = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        r.verifier("la place réservée à l'ascenseur couvre l'ascenseur permanent "
                   + "du système (\(Int(Fenetre.largeurBarreDefilement)) points "
                   + "réservés pour \(Int(systeme)))",
                   Fenetre.largeurBarreDefilement >= systeme)

        let sonde = SondeLargeur()
        let hote = NSHostingView(rootView: ColonneReglages {
            // Plus haute que la fenêtre : il y a de quoi défiler, donc un
            // ascenseur à afficher.
            Color.clear
                .frame(height: 2000)
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { sonde.cadre = g.frame(in: .global) }
                        .onChange(of: g.frame(in: .global)) { _, n in sonde.cadre = n }
                })
        })
        let fenetre = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Fenetre.largeurReglages, height: 600),
            styleMask: [.titled], backing: .buffered, defer: false)
        fenetre.isReleasedWhenClosed = false
        fenetre.contentView = hote
        defer { fenetre.close() }

        func disposer() {
            hote.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            hote.layoutSubtreeIfNeeded()
        }
        disposer()
        guard let zone = zoneDefilante(dans: hote) else {
            r.verifier("la colonne des réglages est bien une zone défilante AppKit", false)
            return
        }

        // Partir de l'état opposé à celui du système, puis alterner : chaque
        // état est atteint en venant de l'autre, dans les deux sens.
        let depart: NSScroller.Style = zone.scrollerStyle == .legacy ? .overlay : .legacy
        var styles: [NSScroller.Style] = []
        for i in 0..<6 { styles.append(i % 2 == 0 ? depart : (depart == .legacy ? .overlay : .legacy)) }

        for (i, style) in styles.enumerated() {
            zone.scrollerStyle = style
            disposer()
            let nom = style == .legacy ? "ascenseur permanent" : "ascenseur superposé"
            let visible = zone.contentView.convert(zone.contentView.bounds, to: nil)
            let largeur = sonde.cadre.width
            // La marge de droite que garde le contenu dans la zone visible.
            let marge = visible.maxX - sonde.cadre.maxX
            r.verifier("bascule \(i + 1), \(nom) : le contenu reçoit ses "
                       + "\(Int(Fenetre.largeurUtileReglages)) points "
                       + "(\(Int(largeur)))",
                       abs(largeur - Fenetre.largeurUtileReglages) < 0.5)
            r.verifier("bascule \(i + 1), \(nom) : il garde sa marge entière avant "
                       + "le bord visible (\(Int(marge)) points pour "
                       + "\(Int(Fenetre.margeReglages)) exigés, zone visible de "
                       + "\(Int(visible.width)))",
                       marge >= Fenetre.margeReglages - 0.5)
        }
    }

    /// Ce que rapporte la sonde posée à la place du volet.
    private final class SondeLargeur {
        var cadre: CGRect = .zero
    }

    /// La `NSScrollView` que SwiftUI a construite pour la `ScrollView`.
    @MainActor
    private static func zoneDefilante(dans vue: NSView) -> NSScrollView? {
        if let zone = vue as? NSScrollView { return zone }
        for sous in vue.subviews {
            if let zone = zoneDefilante(dans: sous) { return zone }
        }
        return nil
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
        let A = Textes.Aide.self

        var lignes: [(String, AnyView)] = []
        // Plus de titre « Profil » : la section a quitté le volet le 28/08 pour
        // le menu Fichier. La colonne ne porte plus que des réglages.
        for titre in [T.sousTitres, T.bandeau, T.logo] {
            lignes.append((titre, AnyView(Text(titre).font(.headline))))
        }
        lignes += [
            (T.ajoutezDesSousTitres, AnyView(Text(T.ajoutezDesSousTitres)
                .font(.caption).fixedSize(horizontal: false, vertical: true))),
            (T.taille, AnyView(Volet.choixSegmente(
                T.taille, aide: A.taille, selection: .constant(TailleNommee.allCases[0]),
                options: TailleNommee.allCases.map { ($0, T.nomTaille($0)) }))),
            (T.police, AnyView(Volet.choixPolice(
                aide: A.police, selection: .constant(ProfilHabillage.neutre.police)))),
            (T.couleurTexte, AnyView(Volet.selecteurCouleur(
                T.couleurTexte, aide: A.couleurTexte, valeur: .constant(ProfilHabillage.neutre.couleurTexte)))),
            (T.couleurContour, AnyView(Volet.selecteurCouleur(
                T.couleurContour, aide: A.couleurContour, valeur: .constant(ProfilHabillage.neutre.contourCouleur)))),
            (T.lignesMax, AnyView(Volet.pasAPas(
                T.lignesMax, aide: A.lignesMax, valeur: .constant(2), de: 1, a: 4))),
            (T.bandeauActif, AnyView(Volet.interrupteur(
                T.bandeauActif, aide: A.bandeauActif, actif: .constant(true)))),
            (T.modeBandeau, AnyView(Volet.choixSegmente(
                T.modeBandeau, aide: A.modeBandeau, selection: .constant(ModeBandeau.pleineLargeur),
                options: [(ModeBandeau.pleineLargeur, T.modePleineLargeur),
                          (ModeBandeau.ajuste, T.modeAjuste)]))),
            (T.couleurBandeau, AnyView(Volet.selecteurCouleur(
                T.couleurBandeau, aide: A.couleurBandeau, valeur: .constant(ProfilHabillage.neutre.bandeauCouleur)))),
            (T.hauteurFixe, AnyView(Volet.interrupteur(
                T.hauteurFixe, aide: A.hauteurFixe, actif: .constant(true)))),
            (T.margeBasse, AnyView(Volet.curseurPourcent(
                T.margeBasse, aide: A.margeBasse, valeur: .constant(0.10), de: 0, a: 0.30))),
            (T.positionLogo, AnyView(Volet.coinsDuLogo(
                aide: A.positionLogo, position: .constant(.coin(.basDroit))))),
            (T.logoRond, AnyView(Volet.interrupteur(
                T.logoRond, aide: A.logoRond, actif: .constant(true)))),
            (T.tailleLogo, AnyView(Volet.curseurPourcent(
                T.tailleLogo, aide: A.tailleLogo, valeur: .constant(0.10), de: 0.01, a: 0.50))),
            (T.opaciteLogo, AnyView(Volet.curseurPourcent(
                T.opaciteLogo, aide: A.opaciteLogo, valeur: .constant(1), de: 0, a: 1))),
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
            let etat = AppState(memoire: false)
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
        let ferme = AppState(memoire: false)
        let hoteFerme = NSHostingView(
            rootView: ContenuFenetre().environmentObject(ferme).frame(width: largeurFenetre))
        hoteFerme.layoutSubtreeIfNeeded()
        let hauteurFermee = hoteFerme.fittingSize.height

        let ouvert = AppState(memoire: false)
        ouvert.voletOuvert = true
        let hoteOuvert = NSHostingView(
            rootView: ContenuFenetre().environmentObject(ouvert).frame(width: largeurFenetre))
        hoteOuvert.layoutSubtreeIfNeeded()
        let hauteurOuverte = hoteOuvert.fittingSize.height

        r.verifier("le volet fermé n'occupe pas la place du volet ouvert "
                   + "(\(Int(hauteurFermee)) contre \(Int(hauteurOuverte)) points)",
                   hauteurOuverte > hauteurFermee)
        r.verifier("le volet est fermé au premier lancement", !AppState(memoire: false).voletOuvert)

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
                   && PolicesSures.estSure(ProfilHabillage.bandeauColore.police))
        r.verifier("le choix « autre police » propose tout le système",
                   PolicesSures.toutes.count > PolicesSures.recommandees.count)
        r.verifier("une police hors liste est signalée comme risquée",
                   !PolicesSures.estSure("Zapfino"))
    }

    // MARK: - Avertissements

    private static func avertissements(_ r: Rapport) {
        var profil = ProfilHabillage.bandeauColore
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

    // MARK: - Conseils du bandeau

    /// **Le conseil donné par l'avertissement « le logo empiète sur la zone des
    /// sous-titres » lève réellement l'avertissement — dans chaque cas.**
    ///
    /// Il disait toujours « Déplacez-le, ou réduisez sa taille ». Constaté à
    /// l'usage : logo en « Bas G. », taille réduite de 15 % à 8 %, l'avertissement
    /// reste — un logo ancré en bas se rapproche du bas en rapetissant. Le
    /// contrôle reproduit d'abord ce constat, puis, pour chaque placement, lit
    /// le conseil affiché, APPLIQUE chacune des actions qu'il propose, et exige
    /// qu'elle lève l'avertissement. « Le réduire ne suffira pas » est prouvé
    /// sur toute la course du curseur.
    private static func conseilsBandeau(_ r: Rapport) {
        let T = Textes.Avertissements.self

        /// L'avertissement d'empiètement, s'il y en a un, pour ce profil.
        func empietement(_ p: ProfilHabillage, _ l: Int, _ h: Int) -> AvertissementZone? {
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: p, largeurVideo: l, hauteurVideo: h) else { return nil }
            let rect = GeometrieLogo.rectangle(
                profil: p, parametres: mep.parametres,
                tailleSource: CGSize(width: 128, height: 128),
                largeurVideo: l, hauteurVideo: h)
            return AvertissementsZone.examiner(
                profil: p, parametres: mep.parametres, police: mep.police,
                rectangleLogo: rect, avecSousTitres: true,
                largeurVideo: l, hauteurVideo: h)
                .first { $0.sorte == .logoSurBandeau }
        }

        /// Les actions qu'un conseil propose, chacune appliquée à un profil.
        let actions: [(nom: String, conseils: [String], appliquer: (ProfilHabillage) -> ProfilHabillage)] = [
            ("choisir un coin du haut",
             [T.conseilCoinHautOuMargeBasse, T.conseilCoinHaut], { p in
                var q = p
                if case .coin(let c) = p.logoPosition {
                    q.logoPosition = .coin(c == .basDroit ? .hautDroit : .hautGauche)
                }
                return q }),
            ("relever la marge basse au maximum",
             [T.conseilCoinHautOuMargeBasse, T.conseilRelever], { p in
                var q = p; q.margeBasseRatio = BornesReglages.margeBasse.upperBound; return q }),
            ("remonter le logo tout en haut",
             [T.conseilRemonterOuReduire, T.conseilRemonterSeulement], { p in
                var q = p
                if case .libre(let x, _) = p.logoPosition { q.logoPosition = .libre(xPct: x, yPct: 0) }
                return q }),
            ("réduire à la plus petite taille",
             [T.conseilRemonterOuReduire, T.conseilReduireOuAbaisserMarge, T.conseilReduire], { p in
                var q = p; q.logoTailleRatio = BornesReglages.tailleLogo.lowerBound; return q }),
            ("abaisser la marge basse au minimum",
             [T.conseilReduireOuAbaisserMarge, T.conseilAbaisserMarge], { p in
                var q = p; q.margeBasseRatio = BornesReglages.margeBasse.lowerBound; return q }),
        ]

        func verifierCas(_ nom: String, _ p: ProfilHabillage, _ l: Int, _ h: Int,
                         attendu: String) {
            guard let a = empietement(p, l, h) else {
                r.verifier("\(nom) : l'avertissement est bien là (condition du cas)", false)
                return
            }
            r.verifier("\(nom) : « \(a.message) »",
                       a.message == T.logoSurBandeau(conseil: attendu))
            for action in actions where action.conseils.contains(attendu) {
                r.verifier("\(nom) : \(action.nom) lève l'avertissement",
                           empietement(action.appliquer(p), l, h) == nil)
            }
            if attendu == T.conseilRemonterSeulement {
                let pas = stride(from: BornesReglages.tailleLogo.lowerBound,
                                 through: BornesReglages.tailleLogo.upperBound, by: 0.01)
                let reductibles = pas.filter { t in
                    var q = p; q.logoTailleRatio = t; return empietement(q, l, h) == nil }
                r.verifier("\(nom) : « le réduire ne suffira pas » est vrai — aucune "
                           + "taille de 1 à 50 % ne lève l'avertissement",
                           reductibles.isEmpty)
            }
        }

        var base = ProfilHabillage.neutre
        base.logoActif = true

        for (format, l, h) in [("16:9", 1920, 1080), ("9:16", 1080, 1920)] {
            // Le constat d'Éric : « Bas G. », 15 % puis 8 %, l'avertissement reste.
            var basG = base
            basG.logoPosition = .coin(.basGauche)
            basG.logoTailleRatio = 0.15
            var reduit = basG
            reduit.logoTailleRatio = 0.08
            r.verifier("\(format) : constat reproduit — « Bas G. » réduit de 15 % à 8 %, "
                       + "l'avertissement reste",
                       empietement(basG, l, h) != nil && empietement(reduit, l, h) != nil)

            verifierCas("\(format), coin bas, logo à 15 %", basG, l, h,
                        attendu: T.conseilCoinHautOuMargeBasse)

            // Un logo trop grand pour que la marge basse, même au maximum, le
            // laisse sous la bande : on ne la conseille plus.
            var grand = basG
            grand.logoTailleRatio = 0.40
            verifierCas("\(format), coin bas, logo à 40 %", grand, l, h,
                        attendu: T.conseilCoinHaut)
            var margeMax = grand
            margeMax.margeBasseRatio = BornesReglages.margeBasse.upperBound
            r.verifier("\(format), coin bas, logo à 40 % : la marge basse au maximum ne "
                       + "suffirait pas — c'est pourquoi elle n'est pas conseillée",
                       empietement(margeMax, l, h) != nil)

            var auDessus = base
            auDessus.logoPosition = .libre(xPct: 50, yPct: 70)
            auDessus.logoTailleRatio = 0.30
            verifierCas("\(format), libre, centre au-dessus de la bande", auDessus, l, h,
                        attendu: T.conseilRemonterOuReduire)

            var dedans = base
            dedans.logoPosition = .libre(xPct: 50, yPct: 85)
            verifierCas("\(format), libre, centre dans la bande", dedans, l, h,
                        attendu: T.conseilRemonterSeulement)
        }

        // Coin haut : atteignable aux extrêmes — logo à 50 %, marge basse à 30 %.
        var haut = ProfilHabillage.neutre
        haut.logoActif = true
        haut.logoPosition = .coin(.hautGauche)
        haut.logoTailleRatio = 0.50
        haut.margeBasseRatio = 0.30
        haut.lignesMax = 2
        haut.longueurLigneCible = TailleNommee.normale.longueurLigneCible
        haut.tailleRatio = TailleNommee.normale.tailleRatio
        verifierCas("16:9, coin haut, logo à 50 % et marge basse à 30 %", haut, 1920, 1080,
                    attendu: T.conseilReduireOuAbaisserMarge)
    }

    // MARK: - Trois usages

    private static func troisUsages(_ r: Rapport) {
        guard let fond = fondDeControle() else { return }
        var avecLogo = ProfilHabillage.bandeauColore
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
