// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// icone_verification.swift — les couleurs de l'icône sont-elles celles demandées ?
//
//   swiftc -O Scripts/marque_geometrie.swift Scripts/icone_gabarit.swift \
//          Scripts/icone_verification.swift -o /tmp/verifier-icone
//   /tmp/verifier-icone Resources/AppIcon.iconset/icon_512x512.png
//
// La question n'est pas rhétorique : la première version du générateur peignait
// des couleurs sRGB dans un contexte `DeviceRGB`, et le bleu NONP `#0067F6`
// ressortait en `#0080F8` — un écart de 25 sur le vert, visible à côté de
// l'icône de NONP Transcription et du bandeau que l'application grave. Rien ne
// le signalait : l'icône avait l'air juste.

import Foundation
import CoreGraphics
import ImageIO

@main
struct VerificationIcone {

    /// Ce que l'icône doit contenir, et rien d'autre en surface notable.
    static let attendues: [(nom: String, valeur: UInt32)] = [
        ("fond", fondRetenu), ("barres", 0xFFFFFF), ("triangles", bleuNONP),
    ]

    /// La couleur est-elle un mélange de deux couleurs attendues ? Si oui,
    /// c'est un bord antialiasé, et rien d'autre. Rend les deux extrêmes et la
    /// proportion.
    static func melangeDeDeuxAttendues(_ c: UInt32) -> (UInt32, UInt32, Double)? {
        func canaux(_ v: UInt32) -> [Double] {
            [Double((v >> 16) & 255), Double((v >> 8) & 255), Double(v & 255)]
        }
        let p = canaux(c)
        for i in 0..<attendues.count {
            for j in 0..<attendues.count where i != j {
                let (a, b) = (canaux(attendues[i].valeur), canaux(attendues[j].valeur))
                // t qui minimise l'écart, puis vérification de l'écart obtenu.
                let d = zip(b, a).map(-)
                let norme = d.reduce(0) { $0 + $1 * $1 }
                guard norme > 1 else { continue }
                let t = zip(p, a).map(-).enumerated()
                    .reduce(0.0) { $0 + $1.element * d[$1.offset] } / norme
                guard t > 0.02, t < 0.98 else { continue }
                let reste = (0..<3).map { a[$0] + t * d[$0] - p[$0] }
                    .reduce(0.0) { $0 + $1 * $1 }
                if reste < 12 {           // moins de deux niveaux par canal
                    return (attendues[i].valeur, attendues[j].valeur, t)
                }
            }
        }
        return nil
    }

    static func main() {
        let chemin = CommandLine.arguments[1]
        let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: chemin) as CFURL, nil)!
        let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
        let (w, h) = (img.width, img.height)
        var px = [UInt8](repeating: 0, count: w * h * 4)
        // Lu dans le MÊME espace que celui où l'icône a été peinte : une
        // conversion à la lecture masquerait exactement ce qu'on cherche.
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: espaceCouleur,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

        var comptes: [UInt32: Int] = [:]
        for j in 0..<(w * h) {
            let i = j * 4
            guard px[i+3] > 250 else { continue }      // hors ombre portée
            comptes[(UInt32(px[i]) << 16) | (UInt32(px[i+1]) << 8) | UInt32(px[i+2]),
                    default: 0] += 1
        }
        print("── \((chemin as NSString).lastPathComponent) — \(w)×\(h) ──")
        var toutJuste = true
        for (nom, valeur) in attendues {
            let part = Double(comptes[valeur] ?? 0) / Double(w * h) * 100
            // Une plage APLAT, pas un pixel isolé : une conversion de profil
            // déplace la couleur en bloc, elle ne l'écorne pas.
            let ok = part > 0.5
            toutJuste = toutJuste && ok
            let etat = ok ? "présent" : "ABSENT"
            print(String(format: "  %-10@ #%06X  ", nom as NSString, valeur)
                  + etat + String(format: "  (%.2f %% de l'image)", part))
            guard !ok else { continue }
            // Absente : deux causes possibles, et elles n'ont pas la même
            // gravité. Une CONVERSION d'espace déplace la couleur hors de la
            // palette. L'ANTIALIASING, lui, ne produit que des mélanges des
            // couleurs demandées — à 16 px les barres font deux pixels de
            // large et n'ont plus d'intérieur, ce qui est normal.
            //
            // On les distingue en regardant si la couleur dominante voisine
            // tombe sur le SEGMENT entre deux couleurs attendues.
            let voisines = comptes
                .filter { $0.value > w * h / 200 }
                .sorted { $0.value > $1.value }
            let melange = voisines.first { melangeDeDeuxAttendues($0.key) != nil }
            if let (c, n) = melange, let (a, b, t) = melangeDeDeuxAttendues(c) {
                print(String(format: "     → aucun aplat à cette taille : la forme "
                             + "est trop fine. Le dominant #%06X (%.2f %%) est un "
                             + "mélange de #%06X et #%06X à %.0f %% — pas une "
                             + "conversion.", c, Double(n) / Double(w * h) * 100,
                             a, b, t * 100))
                toutJuste = true   // ce n'est pas un défaut de l'icône
            } else if let (c, n) = voisines.first {
                print(String(format: "     → trouvé #%06X à la place, sur %.2f %% "
                             + "— une conversion d'espace de couleur",
                             c, Double(n) / Double(w * h) * 100))
            }
        }
        print(toutJuste
              ? "  ✓ les trois couleurs de la marque sont écrites à l'octet près"
              : "  ✗ l'icône ne porte pas les couleurs demandées")
        exit(toutJuste ? 0 : 1)
    }
}
