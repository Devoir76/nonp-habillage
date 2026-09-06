// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// icone_appicon.swift — le jeu d'icônes de l'application, à partir du dessin retenu.
//
//   swiftc -O Scripts/marque_geometrie.swift Scripts/icone_gabarit.swift \
//          Scripts/icone_appicon.swift -o /tmp/gen-appicon
//   /tmp/gen-appicon Resources/AppIcon.iconset
//   iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
//
// **Chaque taille est rastérisée NATIVEMENT**, jamais réduite depuis le 1024.
// C'est tout l'intérêt d'avoir une géométrie : un 16 px réduit depuis un 1024
// est un 16 px flou, alors que les mêmes formes tracées à 16 px tombent sur la
// grille de pixels.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// `@main` plutôt que du code au premier niveau : Swift ne l'accepte que dans un
// fichier nommé `main.swift`, et deux générateurs ne peuvent pas porter ce nom.
@main
struct GenerateurAppIcon {

    /// Les dix entrées qu'`iconutil` attend, sans exception : une seule
    /// manquante et macOS pioche une autre taille et l'interpole.
    static let tailles: [(nom: String, cote: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    static func main() {
        let dossier = CommandLine.arguments[1]
        try? FileManager.default.createDirectory(
            atPath: dossier, withIntermediateDirectories: true)
        guard let dessin = propositions
            .first(where: { $0.nom == propositionRetenue })?.dessin else {
            fatalError("proposition retenue introuvable : \(propositionRetenue)")
        }
        for (nom, cote) in tailles {
            let image = rendreIcone(cote: Double(cote), dessin)
            let url = URL(fileURLWithPath: "\(dossier)/\(nom).png") as CFURL
            let d = CGImageDestinationCreateWithURL(
                url, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(d, image, nil)
            CGImageDestinationFinalize(d)
        }
        print("jeu d'icônes « \(propositionRetenue) » : "
              + "\(tailles.count) tailles dans \(dossier)")
    }
}
