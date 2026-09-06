// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// icone_gabarit.swift — le gabarit d'icône macOS, et les six propositions.
//
// UN SEUL endroit décrit chaque dessin. La planche de comparaison et l'icône
// livrée le lisent tous les deux : sans cela, l'icône fabriquée après le choix
// pourrait dériver de celle sur laquelle le choix a porté, et personne ne s'en
// apercevrait avant de la voir dans le Dock.
//
// Tout est rendu à partir de la GÉOMÉTRIE de la marque (`marque_geometrie.swift`),
// jamais d'un agrandissement d'image : chaque taille du jeu d'icônes est
// rastérisée nativement, y compris le 1024.

import Foundation
import CoreGraphics

func couleur(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
}

let bleuNONP: UInt32 = 0x0067F6
let noirNONP: UInt32 = 0x19191E
let ambre: UInt32 = 0xE8760C
let ambreClair: UInt32 = 0xF2A31B

/// La silhouette d'icône macOS : une superellipse, pas un rectangle arrondi.
/// Le coin d'un rectangle arrondi se voit à côté d'une icône du système.
func squircle(_ r: CGRect, n: Double = 5) -> CGPath {
    let chemin = CGMutablePath()
    let (a, b) = (r.width / 2, r.height / 2)
    let (cx, cy) = (r.midX, r.midY)
    for i in 0...720 {
        let t = Double(i) / 720 * 2 * .pi
        let (c, s) = (cos(t), sin(t))
        let p = CGPoint(x: cx + a * copysign(pow(abs(c), 2 / n), c),
                        y: cy + b * copysign(pow(abs(s), 2 / n), s))
        i == 0 ? chemin.move(to: p) : chemin.addLine(to: p)
    }
    chemin.closeSubpath()
    return chemin
}

/// La plaque, aux proportions du gabarit macOS : l'illustration n'occupe pas
/// toute la toile, elle laisse la marge où vit l'ombre portée.
func plaque(pour cote: Double) -> CGRect {
    let inset = cote * 0.0955
    return CGRect(x: inset, y: inset, width: cote - 2 * inset, height: cote - 2 * inset)
}

/// Une icône complète, à la taille demandée, rendue nativement.
func rendreIcone(cote: Double, _ peindre: (CGContext, CGRect) -> Void) -> CGImage {
    let n = Int(cote.rounded())
    let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let p = plaque(pour: cote)
    ctx.setShadow(offset: CGSize(width: 0, height: -cote * 0.012),
                  blur: cote * 0.030, color: couleur(0x000000, 0.28))
    ctx.addPath(squircle(p)); ctx.setFillColor(couleur(0xFFFFFF)); ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.saveGState()
    ctx.addPath(squircle(p)); ctx.clip()
    peindre(ctx, p)
    ctx.restoreGState()
    return ctx.makeImage()!
}

// ── Les six propositions ────────────────────────────────────────────────────

/// Marque centrée, avec ou sans bandeau de sous-titre.
func marqueCentree(_ ctx: CGContext, _ p: CGRect, fond: UInt32,
                   barres: UInt32, triangles: UInt32, bandeau: UInt32? = nil) {
    ctx.setFillColor(couleur(fond)); ctx.fill(p)
    var centre = CGPoint(x: p.midX, y: p.midY)
    var largeur = p.width * 0.60
    if let bandeau {
        let hauteur = p.height * 0.155, marge = p.height * 0.11
        ctx.setFillColor(couleur(bandeau))
        ctx.fill(CGRect(x: p.minX + p.width * 0.09, y: p.minY + marge,
                        width: p.width * 0.82, height: hauteur))
        // La marque reste centrée dans l'espace qui LUI reste.
        centre.y += (marge + hauteur) / 2
        largeur = p.width * 0.56
    }
    let m = Marque.canonique
    m.tracer(ctx, dans: m.cadre(largeur: largeur, centre: centre),
             barres: couleur(barres), triangles: couleur(triangles))
}

/// Le plan habillé : ce que l'application produit, plutôt que la marque.
func planHabille(_ ctx: CGContext, _ p: CGRect) {
    ctx.setFillColor(couleur(0x22262E)); ctx.fill(p)
    if let degrade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [couleur(0x363C47), couleur(0x1B1F26)] as CFArray,
                                locations: [0, 1]) {
        ctx.drawLinearGradient(degrade, start: CGPoint(x: p.minX, y: p.maxY),
                               end: CGPoint(x: p.maxX, y: p.minY), options: [])
    }
    let d = p.width * 0.44
    let rond = CGRect(x: p.minX + p.width * 0.065, y: p.maxY - p.height * 0.065 - d,
                      width: d, height: d)
    ctx.setFillColor(couleur(bleuNONP)); ctx.fillEllipse(in: rond)
    let m = Marque.canonique
    m.tracer(ctx, dans: m.cadre(largeur: d * 0.62,
                                centre: CGPoint(x: rond.midX, y: rond.midY)),
             barres: couleur(0xFFFFFF), triangles: couleur(noirNONP))
    let bande = CGRect(x: p.minX + p.width * 0.075, y: p.minY + p.height * 0.115,
                       width: p.width * 0.85, height: p.height * 0.185)
    ctx.setFillColor(couleur(bleuNONP)); ctx.fill(bande)
    // UN seul trait clair : deux se confondaient en une barre plus claire dès 32 px.
    ctx.setFillColor(couleur(0xFFFFFF))
    let h = bande.height * 0.30
    ctx.fill(CGRect(x: bande.minX + bande.width * 0.12, y: bande.midY - h / 2,
                    width: bande.width * 0.76, height: h))
}

/// L'inversion nue, dont seul le FOND varie.
///
/// Le fond est le seul paramètre en question depuis le 06/09 : sur un Dock
/// sombre, `#19191E` n'a qu'un contraste de 1,05 à 1,40 et la plaque perd son
/// bord. Trois valeurs sont mises côte à côte plutôt qu'une seule décrétée.
func inversion(fond: UInt32) -> (CGContext, CGRect) -> Void {
    { ctx, p in
        marqueCentree(ctx, p, fond: fond, barres: 0xFFFFFF, triangles: bleuNONP)
    }
}

/// Les trois fonds soumis au jugement.
let variantesDuFond: [(nom: String, fond: UInt32, libelle: String)] = [
    ("fond-19191E", 0x19191E, "#19191E — celui d'aujourd'hui"),
    ("fond-0B0B0E", 0x0B0B0E, "#0B0B0E — nettement plus sombre"),
    ("fond-000000", 0x000000, "#000000 — noir pur"),
]

/// Les propositions, par leur nom de fichier.
///
/// **La nº5 est celle retenue le 06/09** : l'inversion nue. Même bleu, même
/// marque que NONP Transcription, fond sombre — à petite taille l'œil lit les
/// valeurs avant les teintes, et cette différence-là survit là où une
/// différence de teinte s'efface.
let propositions: [(nom: String, dessin: (CGContext, CGRect) -> Void)] = [
    ("1-ambre", { c, p in
        marqueCentree(c, p, fond: ambre, barres: 0xFFFFFF, triangles: noirNONP) }),
    ("2-bandeau-blanc", { c, p in
        marqueCentree(c, p, fond: bleuNONP, barres: 0xFFFFFF, triangles: noirNONP,
                      bandeau: 0xFFFFFF) }),
    ("3-bandeau-ambre", { c, p in
        marqueCentree(c, p, fond: bleuNONP, barres: 0xFFFFFF, triangles: noirNONP,
                      bandeau: ambreClair) }),
    ("4-plan-habille", planHabille),
    ("5-inversion", inversion(fond: noirNONP)),
    ("6-inversion-bandeau", { c, p in
        marqueCentree(c, p, fond: noirNONP, barres: 0xFFFFFF, triangles: bleuNONP,
                      bandeau: bleuNONP) }),
]

/// Le dessin retenu, et rien d'autre ne le nomme.
let propositionRetenue = "5-inversion"
