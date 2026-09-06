import Foundation
import CoreGraphics
import ImageIO

// Vérifie la géométrie canonique contre un PNG officiel : on la rastérise à la
// taille et à la place de la marque de ce fichier, puis on compare pixel à
// pixel. Aucun paramètre n'est ajusté ici — seuls le cadrage et l'échelle,
// c'est-à-dire OÙ la marque est posée dans l'image, sont retrouvés.

// `@main` plutôt que du code au premier niveau : Swift ne l'accepte que dans un
// fichier nommé `main.swift`, et ce dépôt a plusieurs petits exécutables.
@main
struct VerificationMarque {
    static func main() {
        let chemin = CommandLine.arguments[1]
        let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: chemin) as CFURL, nil)!
        let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
        let N = img.width
        precondition(img.height == N, "image carrée attendue")

        func pixels(_ image: CGImage) -> [UInt8] {
            var px = [UInt8](repeating: 0, count: N * N * 4)
            let ctx = CGContext(data: &px, width: N, height: N, bitsPerComponent: 8,
                                bytesPerRow: N * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: N, height: N))
            return px
        }
        let origine = pixels(img)

        var comptes: [Int: Int] = [:]
        for i in stride(from: 0, to: origine.count, by: 4) {
            comptes[(Int(origine[i]) << 16) | (Int(origine[i+1]) << 8) | Int(origine[i+2]),
                    default: 0] += 1
        }
        let dom = comptes.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        func lum(_ c: Int) -> Int {
            (((c >> 16) & 0xFF) * 299 + ((c >> 8) & 0xFF) * 587 + (c & 0xFF) * 114) / 1000
        }
        let fond = dom[0]
        let autres = dom.dropFirst().sorted { lum($0) > lum($1) }
        let cBarres = autres[0], cTri = autres[1]

        /// Les deux couvertures, démêlées : un pixel est un mélange de TROIS couleurs.
        /// Projeter sur le seul axe fond → barres donnerait une valeur non nulle aux
        /// pixels de triangle — le bleu n'est pas orthogonal au blanc.
        func couvertures(_ px: [UInt8]) -> (barres: [Double], triangles: [Double]) {
            func vecteur(_ c: Int) -> (Double, Double, Double) {
                (Double((c >> 16) & 0xFF), Double((c >> 8) & 0xFF), Double(c & 0xFF))
            }
            let f = vecteur(fond), cb = vecteur(cBarres), ct = vecteur(cTri)
            let u = (cb.0 - f.0, cb.1 - f.1, cb.2 - f.2)
            let v = (ct.0 - f.0, ct.1 - f.1, ct.2 - f.2)
            let uu = u.0*u.0 + u.1*u.1 + u.2*u.2, vv = v.0*v.0 + v.1*v.1 + v.2*v.2
            let uv = u.0*v.0 + u.1*v.1 + u.2*v.2, det = uu * vv - uv * uv
            var a = [Double](repeating: 0, count: N * N), b = a
            // Core Graphics remplit son tampon de bas en haut : on range dans le repère
            // de l'image, y vers le bas — celui où la géométrie est décrite.
            for y in 0..<N { for x in 0..<N {
                let i = (y * N + x) * 4
                let p = (Double(px[i]) - f.0, Double(px[i+1]) - f.1, Double(px[i+2]) - f.2)
                let pu = p.0*u.0 + p.1*u.1 + p.2*u.2, pv = p.0*v.0 + p.1*v.1 + p.2*v.2
                let j = (N - 1 - y) * N + x
                a[j] = max(0, min(1, (pu * vv - pv * uv) / det))
                b[j] = max(0, min(1, (pv * uu - pu * uv) / det))
            }}
            return (a, b)
        }
        let ref = couvertures(origine)

        /// Rastérise la marque canonique dans un cadre donné, en repère image.
        func rendre(_ cadre: CGRect) -> (barres: [Double], triangles: [Double]) {
            func canal(_ barres: Bool) -> [Double] {
                var px = [UInt8](repeating: 0, count: N * N * 4)
                let ctx = CGContext(data: &px, width: N, height: N, bitsPerComponent: 8,
                                    bytesPerRow: N * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setShouldAntialias(true)
                let opaque = CGColor(gray: 1, alpha: 1), rien = CGColor(gray: 0, alpha: 0)
                // Repère image (y vers le bas) → repère Core Graphics.
                let cible = CGRect(x: cadre.minX, y: Double(N) - cadre.maxY,
                                   width: cadre.width, height: cadre.height)
                Marque.canonique.tracer(ctx, dans: cible,
                                        barres: barres ? opaque : rien,
                                        triangles: barres ? rien : opaque)
                var out = [Double](repeating: 0, count: N * N)
                for y in 0..<N { for x in 0..<N {
                    out[(N - 1 - y) * N + x] = Double(px[(y * N + x) * 4 + 3]) / 255
                }}
                return out
            }
            let b = canal(true), t = canal(false)
            // Les barres d'abord, les triangles par-dessus : c'est l'ordre de la marque.
            var bVisible = b
            for j in 0..<(N * N) { bVisible[j] = b[j] * (1 - t[j]) }
            return (bVisible, t)
        }

        func erreur(_ cadre: CGRect) -> Double {
            let r = rendre(cadre)
            var s = 0.0
            for j in 0..<(N * N) {
                let a = r.barres[j] - ref.barres[j], b = r.triangles[j] - ref.triangles[j]
                s += a * a + b * b
            }
            return s
        }

        // Où la marque est posée : quatre nombres seulement (x, y, largeur), la hauteur
        // découlant de la proportion. On les cherche, la FORME ne bouge pas.
        let h = Marque.canonique.hauteurRelative
        var x = Double(N) * 0.28, y = Double(N) * 0.36, L = Double(N) * 0.44
        func cadre() -> CGRect { CGRect(x: x, y: y, width: L, height: L * h) }
        var meilleure = erreur(cadre())
        for pas in [8.0, 4.0, 2.0, 1.0, 0.5, 0.25, 0.1, 0.05, 0.02, 0.01].map({ $0 * Double(N) / 400 }) {
            var progresse = true
            while progresse {
                progresse = false
                for i in 0..<3 {
                    for signe in [1.0, -1.0] {
                        let (sx, sy, sL) = (x, y, L)
                        if i == 0 { x += signe * pas } else if i == 1 { y += signe * pas }
                        else { L += signe * pas }
                        let e = erreur(cadre())
                        if e < meilleure - 1e-9 { meilleure = e; progresse = true }
                        else { x = sx; y = sy; L = sL }
                    }
                }
            }
        }

        print("── \((chemin as NSString).lastPathComponent) — \(N)×\(N) ──")
        print(String(format: "  marque posée en (%.2f, %.2f), largeur %.2f px", x, y, L))

        let r = rendre(cadre())
        var pixelsMarque = 0, changentDeCamp = 0, notables = 0, surBord = 0
        var somme = 0.0, maxi = 0.0
        var ecarts = [Double](repeating: 0, count: N * N)
        for j in 0..<(N * N) {
            let d = max(abs(r.barres[j] - ref.barres[j]),
                        abs(r.triangles[j] - ref.triangles[j]))
            ecarts[j] = d
            somme += d; maxi = max(maxi, d)
            if ref.barres[j] > 0.001 || ref.triangles[j] > 0.001
                || r.barres[j] > 0.001 || r.triangles[j] > 0.001 { pixelsMarque += 1 }
            if d > 0.5 { changentDeCamp += 1 }
            if d > 0.02 { notables += 1 }
        }
        for py in 0..<N { for px in 0..<N {
            let j = py * N + px
            guard ecarts[j] > 0.02 else { continue }
            var bord = false
            for dy in -1...1 { for dx in -1...1 {
                let (nx, ny) = (px + dx, py + dy)
                guard nx >= 0, ny >= 0, nx < N, ny < N else { continue }
                let k = ny * N + nx
                if abs(ref.barres[k] - ref.barres[j]) > 0.3
                    || abs(ref.triangles[k] - ref.triangles[j]) > 0.3 { bord = true }
            }}
            if bord { surBord += 1 }
        }}
        print("  pixels couverts par la marque    : \(pixelsMarque)")
        print(String(format: "  écart moyen (image entière)      : %.6f", somme / Double(N * N)))
        print(String(format: "  écart maximal sur un pixel       : %.3f", maxi))
        print("  pixels qui CHANGENT DE CAMP      : \(changentDeCamp)")
        print("  pixels d'écart notable (> 0,02)  : \(notables), dont \(surBord) sur un bord")

    }
}
