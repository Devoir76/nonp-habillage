// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ProductionImages.swift — fabrique la planche de validation visuelle.
//
// Le lot 3 se termine par le jugement d'Éric, et le jugement conditionne le lot
// 4. Ce fichier lui donne de quoi juger : des rendus sur de vraies images, aux
// quatre formats exigés, pour les deux profils livrés, et un côte à côte avec
// le prototype sur la MÊME réplique au MÊME instant.
//
// La réplique n'est pas choisie au hasard : on retient celle que la
// resegmentation découpe le plus. C'est le pire cas — si elle passe, le reste
// passe.

import Foundation
import CoreGraphics

enum ProductionImages {

    /// Une source : une vidéo, ses sous-titres, et éventuellement le rendu que
    /// le prototype en a fait.
    struct Source {
        let etiquette: String
        let video: URL
        let sousTitres: URL
        /// Vidéo produite par `nonp_habille.py` sur les mêmes fichiers.
        let rendueParLePrototype: URL?
    }

    static func executer(sorties dossier: URL, sources: [Source]) -> Int32 {
        print("Production des images de référence — lot 3")
        print(String(repeating: "─", count: 66))

        var erreurs: [String] = []
        var produites: [String] = []

        try? FileManager.default.createDirectory(
            at: dossier, withIntermediateDirectories: true)

        for source in sources {
            do {
                let faites = try traiter(source, dans: dossier)
                produites.append(contentsOf: faites)
            } catch {
                erreurs.append("\(source.etiquette) : \(description(de: error))")
                print("  ✗ \(source.etiquette) : \(description(de: error))")
            }
        }

        // Les formats carrés et portrait ne se trouvent pas tels quels dans les
        // vidéos fournies : on recadre une image réelle plutôt que d'inventer
        // un fond. Ce que juge Éric reste une vraie image.
        if let premiere = sources.first {
            do {
                let faites = try formatsRecadres(premiere, dans: dossier)
                produites.append(contentsOf: faites)
            } catch {
                erreurs.append("formats recadrés : \(description(de: error))")
                print("  ✗ formats recadrés : \(description(de: error))")
            }
        }

        ecrireIndex(dans: dossier, images: produites, sources: sources)

        print("\n" + String(repeating: "─", count: 66))
        if erreurs.isEmpty {
            print("✓ \(produites.count) images écrites dans \(dossier.path)")
            print("  Commencer par LISEZ-MOI.md.")
            return 0
        }
        print("✗ \(erreurs.count) erreur(s) :")
        for e in erreurs { print("   • \(e)") }
        return 1
    }

    // MARK: - Une source

    private static func traiter(_ source: Source, dans dossier: URL) throws -> [String] {
        let (largeur, hauteur) = try ImagesReference.dimensions(de: source.video)
        let cues = try ParseurSousTitres.analyser(fichier: source.sousTitres)
        print("\n▸ \(source.etiquette) — \(largeur)×\(hauteur), \(cues.count) répliques")

        // Découpage tel que le prototype le ferait : c'est lui qui fixe les
        // minutages gravés, donc l'instant où extraire l'image des deux côtés.
        let paramsHistoriques = MoteurMiseEnPage.calculerCommeLePrototype(
            profil: .bandeauColore, largeur: largeur, hauteur: hauteur)
        // Une vidéo peut être un extrait : la réplique retenue doit tomber
        // dedans, sinon l'image extraite ne montre pas ce qu'on croit.
        let duree = try ImagesReference.duree(de: source.video)
        let choisie = try repliqueLaPlusDecoupee(
            cues, maxCaracteres: paramsHistoriques.maxCaracteres,
            avantMs: Int(duree * 1000))

        let instant = Double(choisie.gravee.debutMs + choisie.gravee.finMs) / 2000.0
        print("  réplique retenue : \(choisie.morceaux) morceaux, "
              + "\(TextePython.longueur(choisie.source.texte)) caractères")
        print("  « \(choisie.source.texte) »")
        print("  image extraite à \(String(format: "%.2f", instant)) s")

        let fond = try ImagesReference.image(de: source.video, a: instant)
        var ecrites: [String] = []
        let instantMs = Int(instant * 1000)

        for (nomProfil, profil) in ControlesRendu.profils {
            let mep = try MiseEnPageRendu.calculer(
                profil: profil, largeurVideo: largeur, hauteurVideo: hauteur)
            // La réplique AFFICHÉE à cet instant, pas le bloc source entier :
            // la resegmentation le découpe en plusieurs répliques successives
            // d'au plus `lignesMax` lignes, et l'écran n'en montre qu'une.
            let affichee = repliqueAffichee(cues, a: instantMs, profil: profil, miseEnPage: mep)
            let image = try RenduSousTitres.rendre(
                fond: fond, lignes: affichee, profil: profil, miseEnPage: mep)
            let nom = "\(source.etiquette)--\(nomProfil).png"
            try ImagesReference.ecrire(image, vers: dossier.appendingPathComponent(nom))
            ecrites.append(nom)
            print("  ✓ \(nom)  (police \(mep.parametres.taille) px"
                  + (mep.parametres.reduitePourTenir
                     ? ", réduite depuis \(mep.parametres.tailleDemandee)" : "")
                  + ", \(mep.capacite) caractères par ligne)")

            // Côte à côte avec le prototype, sur la même réplique, au même
            // instant. C'est la comparaison qui décide du lot.
            if nomProfil == "NONP", let protoVideo = source.rendueParLePrototype {
                let imageProto = try ImagesReference.image(de: protoVideo, a: instant)
                if let planche = ImagesReference.cote(imageProto, image) {
                    let nomPlanche = "\(source.etiquette)--COTE-A-COTE.png"
                    try ImagesReference.ecrire(
                        planche, vers: dossier.appendingPathComponent(nomPlanche))
                    ecrites.append(nomPlanche)
                    print("  ✓ \(nomPlanche)  (à gauche le prototype, à droite le natif)")
                }
            }
        }
        return ecrites
    }

    // MARK: - Formats recadrés

    private static func formatsRecadres(_ source: Source, dans dossier: URL) throws -> [String] {
        let cues = try ParseurSousTitres.analyser(fichier: source.sousTitres)
        let (l, h) = try ImagesReference.dimensions(de: source.video)
        let params = MoteurMiseEnPage.calculerCommeLePrototype(
            profil: .bandeauColore, largeur: l, hauteur: h)
        let duree = try ImagesReference.duree(de: source.video)
        let choisie = try repliqueLaPlusDecoupee(
            cues, maxCaracteres: params.maxCaracteres, avantMs: Int(duree * 1000))
        let instant = Double(choisie.gravee.debutMs + choisie.gravee.finMs) / 2000.0
        let source16x9 = try ImagesReference.image(de: source.video, a: instant)

        print("\n▸ formats carrés et portrait — recadrés depuis \(source.etiquette)")
        var ecrites: [String] = []
        let instantMs = Int(instant * 1000)
        for (nomFormat, rapport) in [("1-1", 1.0), ("4-5", 4.0 / 5.0)] {
            let fond = ImagesReference.recadrer(source16x9, versRapport: rapport)
            for (nomProfil, profil) in ControlesRendu.profils {
                let mep = try MiseEnPageRendu.calculer(
                    profil: profil, largeurVideo: fond.width, hauteurVideo: fond.height)
                let affichee = repliqueAffichee(
                    cues, a: instantMs, profil: profil, miseEnPage: mep)
                let image = try RenduSousTitres.rendre(
                    fond: fond, lignes: affichee, profil: profil, miseEnPage: mep)
                let nom = "\(nomFormat)--\(nomProfil).png"
                try ImagesReference.ecrire(image, vers: dossier.appendingPathComponent(nom))
                ecrites.append(nom)
                print("  ✓ \(nom)  (\(fond.width)×\(fond.height), police "
                      + "\(mep.parametres.taille) px, \(mep.capacite) caractères par ligne)")
            }
        }
        return ecrites
    }

    // MARK: - Choix de la réplique

    private struct Choix {
        let source: Cue
        let gravee: CueGravee
        let morceaux: Int
    }

    /// Les lignes réellement à l'écran à un instant donné, pour un profil.
    ///
    /// La resegmentation découpe un bloc long en répliques successives d'au
    /// plus `lignesMax` lignes : à un instant donné, une seule est affichée.
    /// Rendre le bloc source entier donnerait une image que le moteur ne
    /// produit jamais — et rendrait la comparaison avec le prototype fausse.
    ///
    /// Le découpage est ici piloté par la LARGEUR MESURÉE, comme au rendu réel.
    private static func repliqueAffichee(
        _ cues: [Cue], a instantMs: Int, profil: ProfilHabillage,
        miseEnPage: MiseEnPageRendu
    ) -> [String] {
        let gravees = miseEnPage.segmenter(cues, lignesMax: profil.lignesMax)
        let courante = gravees.first { $0.debutMs <= instantMs && instantMs < $0.finMs }
            ?? gravees.min { abs($0.debutMs - instantMs) < abs($1.debutMs - instantMs) }
        return courante?.lignes ?? []
    }

    /// La réplique que la resegmentation découpe le plus, à égalité la plus
    /// longue. C'est le pire cas, celui qui met la césure à l'épreuve.
    private static func repliqueLaPlusDecoupee(
        _ cues: [Cue], maxCaracteres: Int, avantMs: Int
    ) throws -> Choix {
        var meilleur: Choix? = nil
        for cue in cues where cue.finMs <= avantMs {
            let morceaux = Segmenteur.segmenter(
                [cue], maxCaracteres: maxCaracteres,
                lignesMax: ProfilHabillage.bandeauColore.lignesMax)
            guard let premier = morceaux.first else { continue }
            let candidat = Choix(source: cue, gravee: premier, morceaux: morceaux.count)
            if let actuel = meilleur {
                let mieux = candidat.morceaux > actuel.morceaux
                    || (candidat.morceaux == actuel.morceaux
                        && TextePython.longueur(candidat.source.texte)
                           > TextePython.longueur(actuel.source.texte))
                if mieux { meilleur = candidat }
            } else {
                meilleur = candidat
            }
        }
        guard let choix = meilleur else {
            throw ErreurImages.aucuneRepliqueDansLaVideo(secondes: Double(avantMs) / 1000)
        }
        return choix
    }

    // MARK: - Index

    private static func ecrireIndex(dans dossier: URL, images: [String], sources: [Source]) {
        var texte = """
        # Images de référence — lot 3

        Produites par `./Scripts/images_reference.sh`. Rendu Core Text, sans
        aucune vidéo réencodée : les fonds sont des images extraites des vidéos
        réelles, les habillages sont peints par le moteur natif.

        ## Ce qu'il faut regarder, dans l'ordre

        1. **Les planches `--COTE-A-COTE.png`** — à gauche le prototype Python
           (libass), à droite le moteur natif (Core Text), sur la **même
           réplique** au **même instant**. C'est la comparaison qui décide.
           Le rendu ne sera pas identique au pixel près ; le critère est
           *indiscernable à l'usage*.
        2. **Les rendus par format** — que rien ne déborde, que le bandeau tombe
           juste, que le texte reste lisible.

        ## Ce qu'on cherche

        - Une ligne qui **déborde** de la largeur utile — le défaut du 23/08.
        - Un contour trop **épais** ou trop **fin** par rapport au prototype.
        - Un bandeau qui ne **couvre** pas ce qu'il devrait, ou dont la hauteur
          **saute** d'une réplique à l'autre.
        - Un interlettrage ou une graisse visiblement différents.

        ## Répliques retenues

        Les plus **découpées** par la resegmentation, donc les plus longues :
        le pire cas. Si elles passent, le reste passe.

        ## Sources


        """
        for s in sources {
            texte += "- **\(s.etiquette)** — `\(s.video.lastPathComponent)`"
                + " + `\(s.sousTitres.lastPathComponent)`"
                + (s.rendueParLePrototype != nil ? " + rendu du prototype" : "")
                + "\n"
        }
        texte += "\n## Images\n\n"
        for nom in images.sorted() {
            texte += "- `\(nom)`\n"
        }
        try? texte.write(to: dossier.appendingPathComponent("LISEZ-MOI.md"),
                         atomically: true, encoding: .utf8)
    }

    // MARK: - Messages

    static func description(de erreur: Error) -> String {
        switch erreur {
        case let e as ErreurPolice: return Textes.Rendu.message(pour: e)
        case let e as ErreurSousTitres: return Textes.SousTitres.message(pour: e)
        case ErreurImages.videoIllisible(let url):
            return "Vidéo illisible ou sans piste vidéo : \(url.path)"
        case ErreurImages.extractionImpossible(let url, let raison):
            return "Extraction impossible dans \(url.lastPathComponent) — \(raison)"
        case ErreurImages.ecritureImpossible(let url):
            return "Écriture impossible : \(url.path)"
        case ErreurImages.aucuneRepliqueDansLaVideo(let secondes):
            return "Aucune réplique du fichier de sous-titres ne tombe dans les "
                + String(format: "%.0f", secondes) + " s de la vidéo — "
                + "sous-titres et vidéo ne vont pas ensemble"
        default: return "\(erreur)"
        }
    }
}
