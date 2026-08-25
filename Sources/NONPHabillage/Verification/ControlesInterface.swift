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
import SwiftUI
import AppKit

enum ControlesInterface {

    static func executer(_ r: Rapport) {
        r.section("Interface — l'aperçu reflète chaque réglage")
        apercuReagit(r)

        r.section("Interface — texte affiché en permanence")
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
        let hauteurFenetre: CGFloat = 420
        let largeurFenetre: CGFloat = 620

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

    // MARK: - Texte permanent

    private static func textePermanent(_ r: Rapport) {
        // Sans fichier de sous-titres, l'aperçu montre quand même du texte.
        for taille in TailleNommee.allCases {
            var profil = ProfilHabillage.neutre
            profil.longueurLigneCible = taille.longueurLigneCible
            let phrase = Apercu.texteDeReference(profil: profil)
            r.verifier("\(Textes.Interface.nomTaille(taille)) : une phrase est proposée",
                       !phrase.isEmpty)

            // Calibrée : elle doit remplir les lignes disponibles sans les
            // dépasser — sinon elle ne montre pas la césure, ou elle déborde.
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: profil, largeurVideo: 1920, hauteurVideo: 1080) else { continue }
            let phraseCalibree = Apercu.texteDeReference(profil: profil, miseEnPage: mep)
            let lignes = mep.decouper(phraseCalibree)
            r.verifier("\(Textes.Interface.nomTaille(taille)) : la phrase tient en "
                       + "\(profil.lignesMax) lignes (\(lignes.count) produites)",
                       lignes.count >= 1 && lignes.count <= profil.lignesMax)
        }

        // La phrase doit porter de quoi juger : accents, majuscules, jambages,
        // ponctuation (ADR §2).
        let phrase = Apercu.texteDeReference(profil: .neutre)
        r.verifier("la phrase contient des accents",
                   phrase.rangeOfCharacter(from: CharacterSet(charactersIn: "éèêàçùôî")) != nil)
        r.verifier("la phrase contient une majuscule",
                   phrase.rangeOfCharacter(from: .uppercaseLetters) != nil)
        r.verifier("la phrase contient un jambage descendant",
                   phrase.rangeOfCharacter(from: CharacterSet(charactersIn: "pqgjy")) != nil)
        r.verifier("la phrase contient de la ponctuation",
                   phrase.rangeOfCharacter(from: CharacterSet(charactersIn: ".,;:!?'«»")) != nil)

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
            guard let mep = try? MiseEnPageRendu.calculer(
                profil: profil, largeurVideo: 1080, hauteurVideo: 1920) else { continue }
            if nom == "Petite" { petit = mep.parametres.taille } else { grand = mep.parametres.taille }
        }
        r.verifier("« Petite » donne un texte plus petit que « Très grande » "
                   + "(\(petit) px contre \(grand) px)", petit < grand)

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

        // Logo seul : pas de sous-titres, mais l'aperçu montre quand même la
        // phrase de référence — sinon on réglerait le logo sur une image nue.
        let logoSeul = try? Apercu.composer(
            fond: fond, profil: avecLogo,
            texte: Apercu.texteDeReference(profil: avecLogo), avecSousTitres: false)
        r.verifier("logo seul : un aperçu est produit", logoSeul != nil)

        // Rien à graver : l'interface le dit plutôt que de laisser cliquer.
        r.verifier("« rien à graver » est formulé",
                   !Textes.Interface.rienAGraver.isEmpty)
        r.egal("l'usage vide est nommé",
               CommandeExport.usage(sousTitres: nil, profil: avecLogo),
               "ni sous-titres ni logo — rien à graver")
    }
}
