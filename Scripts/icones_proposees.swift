// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// icones_proposees.swift — écrit les six propositions en 1024 px.
//
//   swiftc -O Scripts/marque_geometrie.swift Scripts/icone_gabarit.swift \
//          Scripts/icones_proposees.swift -o /tmp/gen-icones
//   /tmp/gen-icones <dossier de sortie>
//
// Les dessins vivent dans `icone_gabarit.swift`, avec ceux que lit
// `icone_appicon.swift` : l'icône livrée est le dessin choisi, pas sa copie.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// `@main` plutôt que du code au premier niveau : Swift ne l'accepte que dans un
// fichier nommé `main.swift`, et deux générateurs ne peuvent pas porter ce nom.
@main
struct GenerateurPropositions {
    static func main() {
        let dossier = CommandLine.arguments[1]
        for (nom, dessin) in propositions {
            let image = rendreIcone(cote: 1024, dessin)
            let url = URL(fileURLWithPath: "\(dossier)/\(nom).png") as CFURL
            let d = CGImageDestinationCreateWithURL(
                url, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(d, image, nil)
            CGImageDestinationFinalize(d)
        }
        print("\(propositions.count) propositions écrites dans \(dossier)")
    }
}
