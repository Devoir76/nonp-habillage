// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ControlesLogo.swift — les critères d'acceptation du lot 4bis.
//
// La position du logo se mesure : quatre coins, coordonnées libres au centre,
// bornage dans l'image, ratio préservé, taille et marge dérivées de la hauteur.
// Tout est vérifié en nombres, sans encoder la moindre vidéo.
//
// La parité avec `position_logo()` du prototype est mesurée elle aussi, sur un
// logo CARRÉ — le seul cas où les deux implémentations doivent coïncider, le
// prototype écrasant les logos rectangulaires que le schéma veut préservés.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ControlesLogo {

    private static let formats: [(nom: String, largeur: Int, hauteur: Int)] = [
        ("16:9", 1920, 1080),
        ("9:16", 1080, 1920),
        ("1:1", 1080, 1080),
    ]

    static func executer(_ r: Rapport) {
        r.section("Logo — les quatre coins")
        quatreCoins(r)

        r.section("Logo — coordonnées libres")
        coordonneesLibres(r)

        r.section("Logo — taille, marge, ratio")
        tailleEtRatio(r)

        r.section("Logo — parité avec le prototype")
        parite(r)

        r.section("Logo — opacité et fichier manquant")
        opaciteEtErreurs(r)

        r.section("Logo — les trois usages de l'ADR")
        troisUsages(r)
    }

    // MARK: - Coins

    private static func quatreCoins(_ r: Rapport) {
        for (nomFormat, w, h) in formats {
            var profil = ProfilHabillage.bandeauColore
            profil.logoActif = true
            let p = MoteurMiseEnPage.calculer(profil: profil, largeur: w, hauteur: h)
            let marge = Double(p.margeLogo)
            let cote = CGSize(width: 200, height: 200)   // logo carré

            for coin in CoinLogo.allCases {
                profil.logoPosition = .coin(coin)
                let rect = GeometrieLogo.rectangle(
                    profil: profil, parametres: p, tailleSource: cote,
                    largeurVideo: w, hauteurVideo: h)

                // Repère de Core Graphics : y monte. « haut » = grand y.
                let colleAGauche = abs(rect.minX - marge) < 0.5
                let colleADroite = abs(Double(w) - rect.maxX - marge) < 0.5
                let colleEnHaut = abs(Double(h) - rect.maxY - marge) < 0.5
                let colleEnBas = abs(rect.minY - marge) < 0.5

                let attendu: Bool
                switch coin {
                case .hautGauche: attendu = colleAGauche && colleEnHaut
                case .hautDroit:  attendu = colleADroite && colleEnHaut
                case .basGauche:  attendu = colleAGauche && colleEnBas
                case .basDroit:   attendu = colleADroite && colleEnBas
                }
                r.verifier("\(nomFormat) \(coin.rawValue) : posé au bon coin, "
                           + "à \(Int(marge)) px des bords", attendu)
                r.verifier("\(nomFormat) \(coin.rawValue) : entièrement dans l'image",
                           rect.minX >= -0.5 && rect.minY >= -0.5
                           && rect.maxX <= Double(w) + 0.5 && rect.maxY <= Double(h) + 0.5)
            }
        }
    }

    // MARK: - Coordonnées libres

    private static func coordonneesLibres(_ r: Rapport) {
        var profil = ProfilHabillage.bandeauColore
        profil.logoActif = true
        let (w, h) = (1920, 1080)
        let p = MoteurMiseEnPage.calculer(profil: profil, largeur: w, hauteur: h)
        let cote = CGSize(width: 200, height: 200)

        // x_pct et y_pct désignent le CENTRE du logo, pas son coin.
        for (x, y) in [(50.0, 50.0), (25.0, 75.0), (80.0, 20.0)] {
            profil.logoPosition = .libre(xPct: x, yPct: y)
            let rect = GeometrieLogo.rectangle(
                profil: profil, parametres: p, tailleSource: cote,
                largeurVideo: w, hauteurVideo: h)
            let centreX = rect.midX
            // y du schéma descend depuis le haut ; celui de Core Graphics monte.
            let centreYDepuisLeHaut = Double(h) - rect.midY
            r.verifier("centre à \(Int(x)) % × \(Int(y)) % : abscisse juste "
                       + "(\(Int(centreX)) px)",
                       abs(centreX - Double(w) * x / 100) < 1)
            r.verifier("centre à \(Int(x)) % × \(Int(y)) % : ordonnée juste "
                       + "(\(Int(centreYDepuisLeHaut)) px depuis le haut)",
                       abs(centreYDepuisLeHaut - Double(h) * y / 100) < 1)
        }

        // Aux bords, le logo est ramené dans l'image plutôt que débordé.
        for (x, y) in [(0.0, 0.0), (100.0, 100.0), (0.0, 100.0), (100.0, 0.0)] {
            profil.logoPosition = .libre(xPct: x, yPct: y)
            let rect = GeometrieLogo.rectangle(
                profil: profil, parametres: p, tailleSource: cote,
                largeurVideo: w, hauteurVideo: h)
            r.verifier("centre à \(Int(x)) % × \(Int(y)) % : logo ramené dans l'image",
                       rect.minX >= -0.5 && rect.minY >= -0.5
                       && rect.maxX <= Double(w) + 0.5 && rect.maxY <= Double(h) + 0.5)
        }
    }

    // MARK: - Taille et ratio

    private static func tailleEtRatio(_ r: Rapport) {
        var profil = ProfilHabillage.bandeauColore
        profil.logoActif = true
        let (w, h) = (1920, 1080)
        let p = MoteurMiseEnPage.calculer(profil: profil, largeur: w, hauteur: h)

        // 11,5 % de 1080 = 124,2 → 124.
        r.egal("le diamètre suit la hauteur vidéo", p.diametreLogo,
               TextePython.arrondi(Double(h) * 0.115))
        r.egal("la marge suit la hauteur vidéo", p.margeLogo,
               TextePython.arrondi(Double(h) * 0.04))

        // Ratio préservé : la plus grande dimension vaut le diamètre, l'autre
        // suit. Le prototype, lui, écrasait tout en carré.
        let large = GeometrieLogo.dimensions(
            tailleSource: CGSize(width: 400, height: 100),
            plusGrandeDimension: p.diametreLogo)
        r.egal("logo large : la largeur vaut le diamètre",
               Int(large.largeur), p.diametreLogo)
        r.egal("logo large : la hauteur suit le ratio",
               Int(large.hauteur), Int((Double(p.diametreLogo) / 4).rounded()))

        let haut = GeometrieLogo.dimensions(
            tailleSource: CGSize(width: 100, height: 400),
            plusGrandeDimension: p.diametreLogo)
        r.egal("logo haut : la hauteur vaut le diamètre",
               Int(haut.hauteur), p.diametreLogo)
        r.egal("logo haut : la largeur suit le ratio",
               Int(haut.largeur), Int((Double(p.diametreLogo) / 4).rounded()))

        let carre = GeometrieLogo.dimensions(
            tailleSource: CGSize(width: 512, height: 512),
            plusGrandeDimension: p.diametreLogo)
        r.egal("logo carré : les deux côtés valent le diamètre",
               "\(Int(carre.largeur))×\(Int(carre.hauteur))",
               "\(p.diametreLogo)×\(p.diametreLogo)")

        // Les minima du prototype tiennent sur une vidéo minuscule.
        let minus = MoteurMiseEnPage.calculer(profil: profil, largeur: 160, hauteur: 120)
        r.verifier("sur une vidéo minuscule, le diamètre ne descend pas sous 24 px",
                   minus.diametreLogo >= 24)
        r.verifier("sur une vidéo minuscule, la marge ne descend pas sous 6 px",
                   minus.margeLogo >= 6)
    }

    // MARK: - Parité

    private static func parite(_ r: Rapport) {
        // Sur un logo CARRÉ, la position doit être exactement celle du
        // prototype. C'est le cas du logo NONP, un disque dans une image carrée.
        var profil = ProfilHabillage.bandeauColore
        profil.logoActif = true
        let cote = CGSize(width: 512, height: 512)

        for (nomFormat, w, h) in formats {
            let p = MoteurMiseEnPage.calculer(profil: profil, largeur: w, hauteur: h)
            var positions: [PositionLogo] = CoinLogo.allCases.map { .coin($0) }
            positions.append(.libre(xPct: 50, yPct: 50))
            positions.append(.libre(xPct: 12.5, yPct: 87.5))

            for position in positions {
                profil.logoPosition = position
                let rect = GeometrieLogo.rectangle(
                    profil: profil, parametres: p, tailleSource: cote,
                    largeurVideo: w, hauteurVideo: h)
                let proto = GeometrieLogo.positionCommeLePrototype(
                    profil: profil, parametres: p, largeurVideo: w, hauteurVideo: h)

                // Le prototype compte depuis le HAUT : on reconvertit.
                let xNatif = Int(rect.minX.rounded())
                let yNatifDepuisLeHaut = Int((Double(h) - rect.maxY).rounded())
                r.egal("\(nomFormat) \(CommandeExport.descriptionPosition(position)) : "
                       + "même position que le prototype",
                       "\(xNatif),\(yNatifDepuisLeHaut)", "\(proto.x),\(proto.y)")
            }
        }
    }

    // MARK: - Opacité et erreurs

    private static func opaciteEtErreurs(_ r: Rapport) {
        guard let fichier = fabriquerLogoDEssai() else {
            r.verifier("fabrication du logo d'essai", false)
            return
        }
        defer { try? FileManager.default.removeItem(at: fichier) }

        var profil = ProfilHabillage.bandeauColore
        profil.logoActif = true
        profil.logoFichier = fichier
        let p = MoteurMiseEnPage.calculer(profil: profil, largeur: 640, hauteur: 360)

        // Opaque puis translucide : le calque doit changer.
        profil.logoOpacite = 1.0
        let opaque = try? RenduLogo.calque(
            profil: profil, parametres: p, largeur: 640, hauteur: 360)
        profil.logoOpacite = 0.3
        let translucide = try? RenduLogo.calque(
            profil: profil, parametres: p, largeur: 640, hauteur: 360)
        r.verifier("un calque est produit", opaque != nil && translucide != nil)
        if let o = opaque, let t = translucide {
            r.verifier("l'opacité change le calque", ImagesReference.differe(o, de: t))
        }

        // Profil sans logo : aucun calque, et ce n'est pas une erreur.
        profil.logoActif = false
        let aucun = try? RenduLogo.calque(
            profil: profil, parametres: p, largeur: 640, hauteur: 360)
        r.verifier("sans logo actif, aucun calque — et aucune erreur",
                   (aucun ?? nil) == nil)

        // Fichier absent : erreur explicite (jamais un habillage silencieusement
        // amputé de son logo).
        profil.logoActif = true
        profil.logoFichier = URL(fileURLWithPath: "/tmp/logo-qui-n-existe-pas.png")
        var message: String? = nil
        do {
            _ = try RenduLogo.calque(profil: profil, parametres: p,
                                     largeur: 640, hauteur: 360)
        } catch let e as ErreurLogo {
            message = Textes.Logo.message(pour: e)
        } catch {}
        r.verifier("un logo introuvable lève une erreur", message != nil)
        r.verifier("le message dit qu'aucun habillage n'a été gravé",
                   message?.contains("Aucun habillage") == true)
    }

    // MARK: - Trois usages

    private static func troisUsages(_ r: Rapport) {
        // Les trois combinaisons de l'ADR, au niveau du profil : c'est la
        // présence du fichier de sous-titres et celle du logo qui les
        // distinguent, et les deux sont indépendantes.
        var avecLogo = ProfilHabillage.bandeauColore
        avecLogo.logoActif = true
        avecLogo.logoFichier = URL(fileURLWithPath: "/x.png")
        var sansLogo = ProfilHabillage.bandeauColore
        sansLogo.logoActif = false
        let srt = URL(fileURLWithPath: "/x.srt")

        r.egal("sous-titres seuls",
               CommandeExport.usage(sousTitres: srt, profil: sansLogo),
               "sous-titres seuls")
        r.egal("logo seul",
               CommandeExport.usage(sousTitres: nil, profil: avecLogo),
               "logo seul")
        r.egal("les deux",
               CommandeExport.usage(sousTitres: srt, profil: avecLogo),
               "sous-titres + logo")
        r.egal("ni l'un ni l'autre est nommé comme tel",
               CommandeExport.usage(sousTitres: nil, profil: sansLogo),
               "ni sous-titres ni logo — rien à graver")

        // La ligne de commande sait lire les cinq formes de position.
        for texte in CoinLogo.allCases.map(\.rawValue) {
            r.verifier("--logo-position \(texte) est comprise",
                       CommandeExport.lirePosition(texte) != nil)
        }
        r.egal("--logo-position 50,80 est comprise comme un centre",
               CommandeExport.lirePosition("50,80"),
               .libre(xPct: 50, yPct: 80))
        r.verifier("--logo-position 150,10 est refusée",
                   CommandeExport.lirePosition("150,10") == nil)
        r.verifier("--logo-position au-milieu est refusée",
                   CommandeExport.lirePosition("au-milieu") == nil)
    }

    // MARK: - Logo de synthèse

    /// Un disque bleu dans une image carrée : la forme du logo NONP, sans avoir
    /// à versionner d'image (le `.gitignore` exclut les médias).
    private static func fabriquerLogoDEssai() -> URL? {
        let cote = 256
        guard let ctx = CGContext(
            data: nil, width: cote, height: cote, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CouleurProfil.bleuNONP.cgColor)
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: cote, height: cote))
        guard let image = ctx.makeImage() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonp-logo-essai.png")
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return url
    }
}
