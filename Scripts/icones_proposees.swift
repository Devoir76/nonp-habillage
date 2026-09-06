import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Fabrique les propositions d'icône à partir de la GÉOMÉTRIE de la marque
// (`Marque.canonique`), jamais d'un agrandissement d'image : à 1024 px la
// marque fait environ 600 px de large, soit 3,4× le PNG officiel de 400 — un
// bord droit agrandi de 3,4× est un bord flou, et rien ne le rattrape.

let dossier = CommandLine.arguments[1]

func couleur(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
}

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

let cote = 1024.0
let inset = cote * 0.0955                       // proportions du gabarit macOS
let plaque = CGRect(x: inset, y: inset, width: cote - 2 * inset, height: cote - 2 * inset)
let marque = Marque.canonique

func icone(_ nom: String, _ peindre: (CGContext, CGRect) -> Void) {
    let ctx = CGContext(data: nil, width: Int(cote), height: Int(cote),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShadow(offset: CGSize(width: 0, height: -cote * 0.012),
                  blur: cote * 0.030, color: couleur(0x000000, 0.28))
    ctx.addPath(squircle(plaque)); ctx.setFillColor(couleur(0xFFFFFF)); ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.saveGState()
    ctx.addPath(squircle(plaque)); ctx.clip()
    peindre(ctx, plaque)
    ctx.restoreGState()
    let url = URL(fileURLWithPath: "\(dossier)/\(nom).png") as CFURL
    let d = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(d)
}

let bleu: UInt32 = 0x0067F6
let noir: UInt32 = 0x19191E
let ambre: UInt32 = 0xE8760C
let ambreClair: UInt32 = 0xF2A31B

/// Une icône « marque centrée », avec ou sans bandeau de sous-titre.
func marqueCentree(_ nom: String, fond: UInt32, barres: UInt32, triangles: UInt32,
                   bandeau: UInt32? = nil) {
    icone(nom) { ctx, p in
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
        marque.tracer(ctx, dans: marque.cadre(largeur: largeur, centre: centre),
                      barres: couleur(barres), triangles: couleur(triangles))
    }
}

// 1 — la marque seule, dans une teinte qui ne peut pas se confondre.
marqueCentree("1-ambre", fond: ambre, barres: 0xFFFFFF, triangles: noir)
// 2 et 3 — fond bleu, bandeau de sous-titre : la silhouette change.
marqueCentree("2-bandeau-blanc", fond: bleu, barres: 0xFFFFFF, triangles: noir,
              bandeau: 0xFFFFFF)
marqueCentree("3-bandeau-ambre", fond: bleu, barres: 0xFFFFFF, triangles: noir,
              bandeau: ambreClair)
// 5 — l'inversion nue : l'icône de Transcription aux valeurs échangées.
marqueCentree("5-inversion", fond: noir, barres: 0xFFFFFF, triangles: bleu)
// 6 — l'inversion, plus le bandeau : les valeurs ET la silhouette.
marqueCentree("6-inversion-bandeau", fond: noir, barres: 0xFFFFFF, triangles: bleu,
              bandeau: bleu)

// 4 — de mon cru : l'icône EST ce que l'app produit.
icone("4-plan-habille") { ctx, p in
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
    ctx.setFillColor(couleur(bleu)); ctx.fillEllipse(in: rond)
    marque.tracer(ctx, dans: marque.cadre(largeur: d * 0.62,
                                          centre: CGPoint(x: rond.midX, y: rond.midY)),
                  barres: couleur(0xFFFFFF), triangles: couleur(noir))
    let bande = CGRect(x: p.minX + p.width * 0.075, y: p.minY + p.height * 0.115,
                       width: p.width * 0.85, height: p.height * 0.185)
    ctx.setFillColor(couleur(bleu)); ctx.fill(bande)
    // UN seul trait clair : le texte, sans prétendre être lisible. Deux se
    // confondaient en une barre plus claire dès 32 px.
    ctx.setFillColor(couleur(0xFFFFFF))
    let h = bande.height * 0.30
    ctx.fill(CGRect(x: bande.minX + bande.width * 0.12, y: bande.midY - h / 2,
                    width: bande.width * 0.76, height: h))
}
print("six icônes écrites dans \(dossier)")
