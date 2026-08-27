// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Textes.swift — tous les textes affichés à l'utilisateur, en un seul endroit.
//
// Pourquoi centraliser dès le socle ? L'interface est en français uniquement
// (ADR-0001 §2), mais l'anglais doit pouvoir s'ajouter plus tard « sans
// refonte ». Ce n'est vrai que si aucune chaîne visible n'est écrite en dur
// dans une vue. La règle vaut aussi pour les messages d'erreur : un format
// refusé, une police manquante (invariant nº4) se formulent ici, pas au fil du
// code qui les détecte.
//
// Règle : toute chaîne vue par l'utilisateur passe par ce fichier. Les
// nouvelles entrées se rangent sous la rubrique du lot qui les introduit.

import Foundation

enum Textes {

    // MARK: - Identité de l'application

    /// Nom affiché — titre de la fenêtre. Nom définitif, arrêté le 24/08
    /// (ADR-0001, décision nº1).
    static let nomApplication = "NONP Habillage"

    // MARK: - Sous-titres (lot 2)

    /// Messages d'erreur de lecture des fichiers de sous-titres.
    ///
    /// Ils sont rédigés pour être lus par quelqu'un qui n'a pas écrit le
    /// fichier fautif : ils disent où est le problème et quoi faire, jamais
    /// « parse error ». Le prototype, lui, laissait remonter une trace Python.
    enum SousTitres {

        static func fichierIllisible(_ nom: String) -> String {
            "Impossible de lire le fichier de sous-titres « \(nom) ». "
            + "Vérifiez qu'il existe toujours et qu'il n'est pas ouvert dans un autre logiciel."
        }

        static func encodageNonUTF8(_ nom: String) -> String {
            "Le fichier « \(nom) » n'est pas encodé en UTF-8. "
            + "Réenregistrez-le en UTF-8 depuis votre éditeur de sous-titres, "
            + "puis réessayez."
        }

        static func timecodeIllisible(numeroBloc: Int, ligne: String) -> String {
            "Minutage illisible au bloc \(numeroBloc) : « \(ligne) ». "
            + "Un minutage s'écrit « 00:01:23,400 --> 00:01:26,900 »."
        }

        /// Formule un message pour n'importe quelle erreur du parseur.
        static func message(pour erreur: ErreurSousTitres) -> String {
            switch erreur {
            case .fichierIllisible(let url):
                return fichierIllisible(url.lastPathComponent)
            case .encodageNonUTF8(let url):
                return encodageNonUTF8(url.lastPathComponent)
            case .timecodeIllisible(let numeroBloc, let ligne):
                return timecodeIllisible(numeroBloc: numeroBloc,
                                         ligne: TextePython.rogner(ligne))
            }
        }
    }

    // MARK: - Rendu (lot 3)

    enum Rendu {

        /// Invariant nº4. Le message doit dire clairement que RIEN n'a été
        /// substitué : c'est tout l'objet de l'invariant. libass remplaçait la
        /// police en silence et le rendu partait chez le destinataire sans que
        /// personne ne s'en aperçoive.
        static func policeIntrouvable(_ demandee: String, proches: [String]) -> String {
            var message = "La police « \(demandee) » n'est pas installée sur ce Mac. "
                + "Aucune police de substitution n'a été employée à sa place : le "
                + "rendu aurait été différent de celui que vous avez réglé, sans "
                + "que rien ne vous le signale."
            if !proches.isEmpty {
                message += " Polices proches disponibles : "
                    + proches.map { "« \($0) »" }.joined(separator: ", ") + "."
            }
            return message
        }

        static func message(pour erreur: ErreurPolice) -> String {
            switch erreur {
            case .familleIntrouvable(let demandee, let proches):
                return policeIntrouvable(demandee, proches: proches)
            }
        }
    }

    // MARK: - Avertissements (lot 5)

    /// Ce qui mérite d'être signalé sans empêcher de graver.
    ///
    /// Le prototype imprimait ces avertissements dans un terminal, juste avant
    /// un encodage de plusieurs minutes : personne ne les lisait. L'aperçu les
    /// rend enfin utiles — on voit le défaut AVANT d'encoder, et on peut
    /// déplacer le logo à la souris pour le corriger sur-le-champ.
    enum Avertissements {
        static let logoSurBandeau =
            "Le logo empiète sur la zone des sous-titres. Déplacez-le, "
            + "ou réduisez sa taille."
        static let logoHorsMargesSures =
            "Le logo touche le bord de l'image. Certaines plateformes rognent "
            + "les bords : éloignez-le un peu."
    }

    // MARK: - Interface (lot 5)

    enum Interface {

        // Écran d'accueil
        static let deposezVotreVideo = "Déposez votre vidéo ici"
        static let formatsAcceptes = "MP4, MOV ou M4V"
        static let ouChoisir = "Choisir un fichier…"
        static let sousTitresFacultatifs =
            "Sous-titres (facultatif) — déposez un .srt ou un .vtt"
        static let boutonHabiller = "Habiller"
        static let boutonAnnuler = "Annuler"
        static let retirer = "Retirer"

        // L'image de l'accueil, sous les zones de dépôt. Elle confirme le
        // fichier chargé, et elle occupe la place que la fenêtre agrandie
        // laissait vide. Les deux phrases disent ce qu'on regarde — sans quoi
        // on prendrait l'une pour l'autre.
        static let imageAccueilSansSousTitres =
            "Une image de votre vidéo. Ouvrez « Personnaliser » pour voir "
            + "l'habillage et le régler."
        static let imageAccueilAvecSousTitres =
            "Aperçu sur la réplique la plus longue de votre fichier. Ouvrez "
            + "« Personnaliser » pour la parcourir et régler l'habillage."

        static func videoChargee(_ nom: String, largeur: Int, hauteur: Int,
                                 duree: String) -> String {
            "\(nom) — \(largeur)×\(hauteur), \(duree)"
        }
        static func sousTitresCharges(_ nom: String, repliques: Int) -> String {
            "\(nom) — \(repliques) répliques"
        }

        // Volet Personnaliser
        static let personnaliser = "Personnaliser"
        static let sousTitres = "Sous-titres"
        static let logo = "Logo"
        static let bandeau = "Bandeau"

        static let taille = "Taille"
        static let police = "Police"
        static let autrePolice = "Autre police du système…"
        static let policeRisquee =
            "Cette police n'est pas garantie sur les autres Mac : un profil "
            + "partagé pourrait ne pas s'afficher à l'identique."
        static let couleurTexte = "Couleur du texte"
        static let couleurContour = "Contour"
        static let epaisseurContour = "Épaisseur du contour"
        static let lignesMax = "Lignes maximum"

        static let bandeauActif = "Fond derrière le texte"
        static let modeBandeau = "Largeur du fond"
        static let modePleineLargeur = "Pleine largeur"
        static let modeAjuste = "Ajusté au texte"
        static let couleurBandeau = "Couleur du fond"
        /// Une CASE À COCHER depuis le lot 5, plus un menu « N lignes ».
        ///
        /// « Lignes maximum : 2 » et « Hauteur constante : 2 lignes » se
        /// lisaient comme deux façons de dire la même chose. Elles ne le sont
        /// pas — l'une borne le TEXTE, l'autre fige la HAUTEUR DE LA BANDE —,
        /// mais l'interface ne le disait nulle part. Cochée, la case reprend
        /// la valeur de « Lignes maximum » et la suit ; les deux phrases
        /// ci-dessous disent ce que le fond fait dans chaque cas, sous la case
        /// plutôt qu'en bas de fenêtre.
        static let hauteurFixe = "Hauteur constante"
        static func hauteurFixeActive(_ n: Int) -> String {
            "Le fond garde la hauteur de \(n == 1 ? "1 ligne" : "\(n) lignes") — "
            + "la valeur de « Lignes maximum ». Il ne saute plus entre une "
            + "réplique d'une ligne et une réplique de deux."
        }
        static let hauteurFixeInactive =
            "Le fond s'ajuste à chaque réplique : il change de hauteur entre "
            + "une réplique d'une ligne et une réplique de deux."
        static let margeBasse = "Marge basse"
        // « Marge intérieure » n'a plus de libellé : le curseur a été retiré du
        // volet au lot 5 — voir `PanneauPersonnaliserView`. Le champ du profil,
        // lui, reste.

        static let choisirLogo = "Choisir une image…"
        static let aucunLogo = "Aucun logo"
        static let retirerLogo = "Retirer le logo"
        static let positionLogo = "Position"
        static let tailleLogo = "Taille"
        static let opaciteLogo = "Opacité"
        static let deplacerLogo = "Faites glisser le logo sur l'aperçu pour le placer."
        static let logoRond = "Recadrer en cercle"
        static let logoRondExplication =
            "Découpe le disque inscrit, bord lissé. Inutile si votre PNG est "
            + "déjà détouré." 

        static func nomCoin(_ coin: CoinLogo) -> String {
            switch coin {
            case .hautGauche: return "Haut gauche"
            case .hautDroit: return "Haut droit"
            case .basGauche: return "Bas gauche"
            case .basDroit: return "Bas droit"
            }
        }

        static func nomTaille(_ t: TailleNommee) -> String {
            switch t {
            case .petite: return "Petite"
            case .normale: return "Normale"
            case .grande: return "Grande"
            case .tresGrande: return "Très grande"
            }
        }

        // Aperçu
        static let apercu = "Aperçu"

        /// Le menu des images de fond, nommé TROIS fois avant de se faire
        /// comprendre.
        ///
        /// « Image de fond », puis « Image de la vidéo » : ni l'un ni l'autre ne
        /// disait à quoi le choix sert, et l'explication vivait en bas du volet
        /// d'aperçu — trop loin du menu pour être lue. Le lot 5 renonce à
        /// expliquer et rend le contrôle explicite : son nom dit qu'il ne touche
        /// que l'aperçu, chaque entrée dit ce qu'elle vaut, et la réserve
        /// « jamais la vidéo exportée » tient sur la MÊME LIGNE que le menu.
        static let fondDeLApercu = "Fond de l'aperçu"
        /// Sur la même ligne que le menu : la seule chose qu'on puisse craindre
        /// en y touchant, démentie là où on la craint.
        static let fondApercuSeulement = "N'affecte que l'aperçu, pas la vidéo exportée."
        /// Sous le menu : ce qu'il faut EN FAIRE. C'est le critère de contraste
        /// de l'ADR §2 — regarder les deux extrêmes —, tout ce qui restait
        /// d'utile dans l'ancienne explication.
        static let fondDeLApercuConseil =
            "Regardez le plus sombre et le plus clair : c'est ainsi qu'on vérifie "
            + "que le texte reste lisible sur toute la vidéo."

        /// Libellé d'une entrée du menu : son rang, puis ce qu'elle vaut.
        ///
        /// TOUTES les entrées sont libellées, plus seulement les deux extrêmes.
        /// « 3/6 » tout seul ne disait rien de l'image qu'on allait obtenir, et
        /// obligeait à essayer pour savoir. Les extrêmes gardent un nom absolu —
        /// ce sont eux qui tranchent une couleur de texte (ADR §2) ; les autres
        /// sont qualifiées par leur luminosité MESURÉE, pas par leur rang, de
        /// sorte que le libellé décrive l'image et non sa place dans la liste.
        static func nomFond(index: Int, total: Int, luminosite: Double) -> String {
            let numero = "\(index + 1)/\(total)"
            let qualificatif: String
            if index == 0 {
                qualificatif = fondLePlusSombre
            } else if index == total - 1 {
                qualificatif = fondLePlusClair
            } else if luminosite < 0.35 {
                qualificatif = fondSombre
            } else if luminosite < 0.65 {
                qualificatif = fondMoyen
            } else {
                qualificatif = fondClair
            }
            return "\(numero) — \(qualificatif)"
        }

        static let fondLePlusSombre = "le plus sombre"
        static let fondSombre = "sombre"
        static let fondMoyen = "moyen"
        static let fondClair = "clair"
        static let fondLePlusClair = "le plus clair"
        /// Ce que l'utilisateur obtient : la taille du texte et la longueur de
        /// ligne visée. Surtout pas la « capacité » brute — la place que la
        /// largeur laisserait —, qui annonçait 55 caractères là où les lignes
        /// en font 32.
        static func tailleEtLongueurLigne(_ px: Int, caracteres: Int) -> String {
            "\(px) px — lignes d'environ \(caracteres) caractères"
        }
        // Partis avec le curseur « Marge intérieure » : la largeur de la colonne
        // de texte et l'avertissement « sans effet pour l'instant ». Les deux
        // n'existaient que pour expliquer un réglage qui ne faisait rien.

        // « plan clair » et « plan sombre » ont laissé la place à l'échelle
        // complète ci-dessus : ils ne nommaient que les deux extrêmes, et les
        // quatre entrées du milieu restaient des numéros nus.
        static let repliquePrecedente = "Réplique précédente"
        static let repliqueSuivante = "Réplique suivante"
        static let phraseDeReference = "Phrase de référence — aucun sous-titre chargé"
        static func repliqueSur(_ index: Int, _ total: Int) -> String {
            "Réplique \(index) sur \(total)"
        }
        static let repliqueLaPlusLongue = "la plus longue du fichier"
        static let apercuSansEncodage = "Aucun encodage : l'aperçu est instantané."

        // Progression
        static func progression(_ pourcent: Int) -> String { "\(pourcent) %" }
        static let estimationEnCours = "Estimation du temps restant…"
        static func tempsRestant(_ texte: String) -> String { "Encore \(texte) environ" }
        static let exportTermine = "Vidéo habillée"
        static let exportAnnule = "Export annulé."
        static let revelerDansFinder = "Afficher dans le Finder"
        static let recommencer = "Habiller une autre vidéo"

        // Divers
        static let rienAGraver =
            "Ajoutez des sous-titres ou un logo : sans l'un ni l'autre, "
            + "il n'y a rien à graver."
        static let chargementApercu = "Préparation de l'aperçu…"
    }

    // MARK: - Logo (lot 4bis)

    enum Logo {

        /// Même exigence que pour la police (invariant nº4) : rien ne se fait
        /// en silence. Un logo demandé et absent doit arrêter l'export, pas
        /// produire une vidéo sans logo qu'on découvrirait après diffusion.
        static func fichierIntrouvable(_ chemin: String) -> String {
            "Le fichier du logo est introuvable : « \(chemin) ». "
            + "Aucun habillage n'a été gravé — vérifiez le chemin, puis réessayez."
        }

        static func imageIllisible(_ nom: String) -> String {
            "Le fichier « \(nom) » n'a pas pu être lu comme une image. "
            + "Utilisez un PNG (fond transparent conseillé), un JPEG ou un HEIC."
        }

        static func message(pour erreur: ErreurLogo) -> String {
            switch erreur {
            case .fichierIntrouvable(let url): return fichierIntrouvable(url.path)
            case .imageIllisible(let url): return imageIllisible(url.lastPathComponent)
            }
        }
    }

    // MARK: - Export vidéo (lot 4)

    enum Export {

        /// Formats d'entrée : MP4, MOV, M4V (ADR §3). Un fichier refusé doit
        /// produire un message explicite assorti d'une marche à suivre — jamais
        /// un échec silencieux ni un plantage.
        static func formatNonPrisEnCharge(_ nom: String) -> String {
            "Le fichier « \(nom) » n'est pas pris en charge par le moteur vidéo de "
            + "macOS. Les formats acceptés sont MP4, MOV et M4V. Convertissez la "
            + "vidéo dans l'un de ces formats, puis réessayez."
        }

        static func pisteVideoAbsente(_ nom: String) -> String {
            "Le fichier « \(nom) » ne contient aucune piste vidéo. "
            + "S'il s'agit d'un fichier audio, il n'y a rien à habiller."
        }

        static func lectureImpossible(_ raison: String) -> String {
            "La vidéo n'a pas pu être lue jusqu'au bout (\(raison)). "
            + "Le fichier est peut-être incomplet ou endommagé."
        }

        static func ecritureImpossible(_ raison: String) -> String {
            "L'export n'a pas pu être écrit (\(raison)). "
            + "Vérifiez l'espace disque disponible et les droits du dossier de sortie."
        }

        static let annule =
            "Export annulé. Aucun fichier n'a été laissé sur le disque."

        static func message(pour erreur: ErreurExport) -> String {
            switch erreur {
            case .videoIllisible(let url):
                return formatNonPrisEnCharge(url.lastPathComponent)
            case .pisteVideoAbsente(let url):
                return pisteVideoAbsente(url.lastPathComponent)
            case .lectureImpossible(let raison):
                return lectureImpossible(raison)
            case .ecritureImpossible(let raison):
                return ecritureImpossible(raison)
            case .annule:
                return annule
            }
        }
    }
}
