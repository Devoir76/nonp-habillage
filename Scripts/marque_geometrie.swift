import Foundation
import CoreGraphics

// ── La marque NONP, en géométrie ────────────────────────────────────────────
//
// Deux barres, deux triangles. Onze nombres, exprimés en fraction de la LARGEUR
// de la marque, origine au coin haut-gauche de son cadre, y vers le bas.
//
// Ils ne sont pas relevés à la main : ils ont été AJUSTÉS numériquement sur les
// PNG officiels, par descente de coordonnées sur l'erreur de couverture — les
// bords antialiasés de l'original portent l'information sous-pixel qui rend
// l'ajustement possible. Puis vérifiés en rastérisant et en comparant pixel à
// pixel. Voir `Scripts/marque_verification.swift`.
//
// ── Deux choses que la mesure a apprises, et qu'un relevé à l'œil aurait
//    manquées ────────────────────────────────────────────────────────────────
//
// 1. **Les triangles se chevauchent.** La pointe du second est à l'INTÉRIEUR du
//    premier, de 3 px sur 175. Les poser bout à bout laissait une erreur en
//    croix : l'un débordait, l'autre manquait.
// 2. **Les triangles ne sont pas alignés sur les barres.** Ils sont 2 px plus
//    haut, sur 106 de hauteur. La marque n'est pas symétrique verticalement, et
//    l'ignorer se voit.
//
// ── Pourquoi une géométrie, et pas l'image ──────────────────────────────────
//
// Les sources officielles font 400 px, deux d'entre elles 834. Un `.icns`
// réclame 1024 : la marque y occupe environ 600 px de large, soit un
// agrandissement de 3,4× depuis le 400. Un bord droit agrandi de 3,4× est un
// bord flou, et il n'y a rien à faire pour le rattraper — l'information n'est
// pas dans le fichier. Une géométrie, elle, se rastérise nette à n'importe
// quelle taille. C'est la seule façon d'obtenir un 1024 propre.

struct Marque {

    // Fractions de la largeur du cadre de la marque.
    var barreX: Double
    var barreLargeur: Double
    var barreEcart: Double
    var barreY: Double
    var barreHauteur: Double
    var triX: Double
    var triLargeur: Double
    var triX2: Double
    var triLargeur2: Double
    var triY: Double
    var triHauteur: Double

    /// La géométrie retenue : la moyenne des deux ajustements indépendants,
    /// celui du PNG de 400 px et celui du PNG de 834 px. Ils s'accordent à
    /// 0,2 % de la largeur près sur chacun des onze nombres.
    static let canonique = Marque(
        barreX:       0.000000,
        barreLargeur: 0.203480,
        barreEcart:   0.085535,
        barreY:       0.009760,
        barreHauteur: 0.609685,
        triX:         0.329010,
        triLargeur:   0.344565,
        triX2:        0.656305,
        triLargeur2:  0.343695,
        triY:         0.000000,
        triHauteur:   0.606470)

    /// Hauteur de la marque, en fraction de sa largeur.
    var hauteurRelative: Double { max(barreY + barreHauteur, triY + triHauteur) }

    var parametres: [Double] {
        get { [barreX, barreLargeur, barreEcart, barreY, barreHauteur,
               triX, triLargeur, triX2, triLargeur2, triY, triHauteur] }
        set { barreX = newValue[0]; barreLargeur = newValue[1]
              barreEcart = newValue[2]; barreY = newValue[3]
              barreHauteur = newValue[4]; triX = newValue[5]
              triLargeur = newValue[6]; triX2 = newValue[7]
              triLargeur2 = newValue[8]; triY = newValue[9]; triHauteur = newValue[10] }
    }
    static let noms = ["barreX", "barreLargeur", "barreEcart", "barreY",
                       "barreHauteur", "triX", "triLargeur", "triX2",
                       "triLargeur2", "triY", "triHauteur"]

    /// Trace la marque dans `cible`, un cadre du repère de `ctx` (y vers le
    /// haut, comme partout en Core Graphics).
    ///
    /// **L'ordre compte** : les barres, puis les triangles PAR-DESSUS. La
    /// pointe du premier triangle entaille la deuxième barre, et cette entaille
    /// est un trait de la marque — la mesure l'a confirmée sur les deux
    /// sources.
    func tracer(_ ctx: CGContext, dans cible: CGRect,
                barres couleurBarres: CGColor, triangles couleurTri: CGColor) {
        let k = cible.width
        // (u, v) en fraction de largeur, v vers le BAS → repère de Core Graphics.
        func point(_ u: Double, _ v: Double) -> CGPoint {
            CGPoint(x: cible.minX + u * k, y: cible.maxY - v * k)
        }
        ctx.setFillColor(couleurBarres)
        for i in 0..<2 {
            let x = barreX + Double(i) * (barreLargeur + barreEcart)
            let a = point(x, barreY)
            let b = point(x + barreLargeur, barreY + barreHauteur)
            ctx.fill(CGRect(x: a.x, y: b.y, width: b.x - a.x, height: a.y - b.y))
        }
        ctx.setFillColor(couleurTri)
        for (x0, l) in [(triX, triLargeur), (triX2, triLargeur2)] {
            ctx.beginPath()
            ctx.move(to: point(x0, triY + triHauteur / 2))
            ctx.addLine(to: point(x0 + l, triY))
            ctx.addLine(to: point(x0 + l, triY + triHauteur))
            ctx.closePath()
            ctx.fillPath()
        }
    }

    /// Le cadre où poser la marque, à sa proportion, centré sur `centre`.
    func cadre(largeur: Double, centre: CGPoint) -> CGRect {
        let h = largeur * hauteurRelative
        return CGRect(x: centre.x - largeur / 2, y: centre.y - h / 2,
                      width: largeur, height: h)
    }
}
