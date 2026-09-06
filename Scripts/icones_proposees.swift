import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// ── La marque, reprise du PNG d'origine plutôt que redessinée ───────────────
//
// Deux masques : les barres claires, les triangles sombres. Les redessiner à la
// main aurait introduit une marque « presque » juste ; un masque garde la forme
// au pixel près et laisse libre la couleur.

let sourceMarque = CommandLine.arguments[1]
let dossier = CommandLine.arguments[2]

func charger(_ p: String) -> CGImage {
    let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(s, 0, nil)!
}

struct Masques { let clair: CGImage; let sombre: CGImage; let ratio: Double }

func masquesDeLaMarque(_ chemin: String) -> Masques {
    let img = charger(chemin)
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

    func couverture(_ i: Int, vers r0: Double, _ v0: Double, _ b0: Double) -> Double {
        let dr = Double(px[i]) - r0, dv = Double(px[i+1]) - v0, db = Double(px[i+2]) - b0
        let d = (dr * dr + dv * dv + db * db).squareRoot()
        return max(0, min(1, 1 - d / 110))
    }

    var clair = [UInt8](repeating: 255, count: w * h)
    var sombre = [UInt8](repeating: 255, count: w * h)
    var x0 = w, x1 = -1, y0 = h, y1 = -1
    for y in 0..<h { for x in 0..<w {
        let i = (y * w + x) * 4
        let c = couverture(i, vers: 255, 255, 255)
        let s = couverture(i, vers: 0x19, 0x19, 0x1E)
        // Masque CoreGraphics : 0 = peint, 255 = laisse passer.
        clair[y * w + x] = UInt8(255 - Int(c * 255))
        sombre[y * w + x] = UInt8(255 - Int(s * 255))
        if c > 0.5 || s > 0.5 {
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        }
    }}

    func masque(_ octets: [UInt8]) -> CGImage {
        let data = CFDataCreate(nil, octets, octets.count)!
        let fournisseur = CGDataProvider(data: data)!
        let entier = CGImage(maskWidth: w, height: h, bitsPerComponent: 8,
                             bitsPerPixel: 8, bytesPerRow: w,
                             provider: fournisseur, decode: nil,
                             shouldInterpolate: true)!
        return entier.cropping(to: CGRect(x: x0, y: y0,
                                          width: x1 - x0 + 1, height: y1 - y0 + 1))!
    }
    return Masques(clair: masque(clair), sombre: masque(sombre),
                   ratio: Double(x1 - x0 + 1) / Double(y1 - y0 + 1))
}

let marque = masquesDeLaMarque(sourceMarque)

// ── Outils de dessin ────────────────────────────────────────────────────────

func couleur(_ hex: UInt32, _ alpha: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
}

/// La silhouette d'icône macOS : une superellipse, pas un rectangle arrondi.
/// Le coin d'un rectangle arrondi se voit à côté d'une icône du système.
func squircle(_ r: CGRect, n: Double = 5) -> CGPath {
    let chemin = CGMutablePath()
    let (a, b) = (r.width / 2, r.height / 2)
    let (cx, cy) = (r.midX, r.midY)
    let pas = 720
    for i in 0...pas {
        let t = Double(i) / Double(pas) * 2 * .pi
        let (c, s) = (cos(t), sin(t))
        let x = cx + a * copysign(pow(abs(c), 2 / n), c)
        let y = cy + b * copysign(pow(abs(s), 2 / n), s)
        i == 0 ? chemin.move(to: CGPoint(x: x, y: y))
               : chemin.addLine(to: CGPoint(x: x, y: y))
    }
    chemin.closeSubpath()
    return chemin
}

func dessinerMarque(_ ctx: CGContext, dans cadre: CGRect,
                    clair: CGColor, sombre: CGColor) {
    // Les deux masques couvrent la MÊME étendue : ils viennent de la même
    // image, découpée une fois. Les dessiner dans le même cadre les remet donc
    // exactement l'un sur l'autre.
    ctx.saveGState()
    ctx.clip(to: cadre, mask: marque.clair)
    ctx.setFillColor(clair); ctx.fill(cadre)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.clip(to: cadre, mask: marque.sombre)
    ctx.setFillColor(sombre); ctx.fill(cadre)
    ctx.restoreGState()
}

/// Le cadre où poser la marque, à sa proportion, centré sur `centre`.
func cadreMarque(largeur: Double, centre: CGPoint) -> CGRect {
    let h = largeur / marque.ratio
    return CGRect(x: centre.x - largeur / 2, y: centre.y - h / 2, width: largeur, height: h)
}

func ecrire(_ image: CGImage, _ nom: String) {
    let url = URL(fileURLWithPath: "\(dossier)/\(nom).png") as CFURL
    let d = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, image, nil)
    CGImageDestinationFinalize(d)
}

let cote = 1024.0
let insetSquircle = cote * 0.0955          // proportions du gabarit macOS
let plaque = CGRect(x: insetSquircle, y: insetSquircle,
                    width: cote - 2 * insetSquircle, height: cote - 2 * insetSquircle)

func icone(_ nom: String, _ peindre: (CGContext, CGRect) -> Void) {
    let ctx = CGContext(data: nil, width: Int(cote), height: Int(cote),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShadow(offset: CGSize(width: 0, height: -cote * 0.012),
                  blur: cote * 0.030, color: couleur(0x000000, 0.28))
    ctx.addPath(squircle(plaque))
    ctx.setFillColor(couleur(0xFFFFFF))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    ctx.saveGState()
    ctx.addPath(squircle(plaque))
    ctx.clip()
    peindre(ctx, plaque)
    ctx.restoreGState()
    ecrire(ctx.makeImage()!, nom)
}

// ── Les quatre propositions ─────────────────────────────────────────────────

let bleuNONP: UInt32 = 0x0067F6
let sombreNONP: UInt32 = 0x19191E

// 1 — la marque seule, dans une teinte qui ne peut pas être confondue.
icone("1-ambre") { ctx, p in
    ctx.setFillColor(couleur(0xE8760C)); ctx.fill(p)
    dessinerMarque(ctx, dans: cadreMarque(largeur: p.width * 0.60,
                                          centre: CGPoint(x: p.midX, y: p.midY)),
                   clair: couleur(0xFFFFFF), sombre: couleur(sombreNONP))
}

// 2 — fond bleu, bandeau de sous-titre en bas : la silhouette change.
func avecBandeau(_ nom: String, fond: UInt32, bandeau: UInt32, marqueClaire: UInt32) {
    icone(nom) { ctx, p in
        ctx.setFillColor(couleur(fond)); ctx.fill(p)
        let hauteurBandeau = p.height * 0.155
        let margeBasse = p.height * 0.11
        let bande = CGRect(x: p.minX + p.width * 0.09,
                           y: p.minY + margeBasse,
                           width: p.width * 0.82, height: hauteurBandeau)
        ctx.setFillColor(couleur(bandeau))
        ctx.fill(bande)
        // La marque remonte de la moitié de ce que le bandeau occupe : elle
        // reste centrée dans l'espace qui LUI reste.
        let centre = CGPoint(x: p.midX,
                             y: p.midY + (margeBasse + hauteurBandeau) / 2)
        dessinerMarque(ctx, dans: cadreMarque(largeur: p.width * 0.60, centre: centre),
                       clair: couleur(marqueClaire), sombre: couleur(sombreNONP))
    }
}
avecBandeau("2-bandeau-blanc", fond: bleuNONP, bandeau: 0xFFFFFF, marqueClaire: 0xFFFFFF)
avecBandeau("3-bandeau-ambre", fond: bleuNONP, bandeau: 0xF2A31B, marqueClaire: 0xFFFFFF)

// 4 — de mon cru : l'icône EST ce que l'app produit.
//
// Un plan de vidéo, le logo rond en haut à gauche là où l'app le pose par
// défaut, le bandeau en bas. À 32 px la silhouette ne ressemble à rien d'autre :
// une pastille en haut à gauche, une barre en bas. Et elle dit ce que fait
// l'application, au lieu de répéter la marque de la maison.
icone("4-plan-habille") { ctx, p in
    // Le fond n'est pas le bleu de la marque : c'est un plan, pas une identité.
    ctx.setFillColor(couleur(0x22262E)); ctx.fill(p)
    // Un dégradé très léger, pour que le plan ne soit pas une surface morte.
    if let degrade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [couleur(0x363C47), couleur(0x1B1F26)] as CFArray,
                                locations: [0, 1]) {
        ctx.drawLinearGradient(degrade, start: CGPoint(x: p.minX, y: p.maxY),
                               end: CGPoint(x: p.maxX, y: p.minY), options: [])
    }
    // Le logo rond, en haut à gauche — la position par défaut du profil.
    let d = p.width * 0.44
    let rond = CGRect(x: p.minX + p.width * 0.065,
                      y: p.maxY - p.height * 0.065 - d, width: d, height: d)
    ctx.setFillColor(couleur(bleuNONP))
    ctx.fillEllipse(in: rond)
    dessinerMarque(ctx, dans: cadreMarque(largeur: d * 0.62,
                                          centre: CGPoint(x: rond.midX, y: rond.midY)),
                   clair: couleur(0xFFFFFF), sombre: couleur(sombreNONP))
    // Le bandeau, à la place qu'il occupe dans le rendu.
    let bande = CGRect(x: p.minX + p.width * 0.075, y: p.minY + p.height * 0.115,
                       width: p.width * 0.85, height: p.height * 0.185)
    ctx.setFillColor(couleur(bleuNONP)); ctx.fill(bande)
    // UN seul trait clair : le texte, sans prétendre être lisible. Deux se
    // confondaient en une barre plus claire dès 32 px, ce qui ne disait plus
    // rien — un trait épais et centré tient à toutes les tailles.
    ctx.setFillColor(couleur(0xFFFFFF))
    let h = bande.height * 0.30
    ctx.fill(CGRect(x: bande.minX + bande.width * 0.12, y: bande.midY - h / 2,
                    width: bande.width * 0.76, height: h))
}
print("quatre icônes écrites dans \(dossier)")
