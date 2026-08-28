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

        /// Le message qui remplace les réglages de sous-titre tant qu'aucun
        /// fichier n'est chargé.
        static let ajoutezDesSousTitres =
            "Ajoutez des sous-titres pour régler leur apparence."
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
        /// disait à quoi le choix sert. Le lot 5 renonce à expliquer et rend le
        /// contrôle explicite : son nom dit qu'il ne touche que l'aperçu, et
        /// chaque entrée du menu dit ce qu'elle vaut.
        ///
        /// C'est ce qui a permis d'ALLÉGER la ligne. Le menu a d'abord traîné
        /// deux phrases avec lui : la réserve sur la même ligne, le conseil
        /// d'usage en dessous sur toute la largeur. Trois textes autour d'un
        /// petit menu, dans un volet dont la valeur est l'IMAGE — et l'image y
        /// perdait la place. Les deux phrases sont devenues l'INFOBULLE du
        /// menu : à portée du pointeur pour qui doute, invisibles pour les
        /// autres. Ce que le réglage fait, ses libellés le disent déjà.
        static let fondDeLApercu = "Fond de l'aperçu"
        /// La seule chose qu'on puisse craindre en touchant au menu.
        static let fondApercuSeulement = "N'affecte que l'aperçu, pas la vidéo exportée."
        /// Ce qu'il faut EN FAIRE. C'est le critère de contraste de l'ADR §2 —
        /// regarder les deux extrêmes —, tout ce qui restait d'utile dans
        /// l'ancienne explication.
        static let fondDeLApercuConseil =
            "Regardez le plus sombre et le plus clair : c'est ainsi qu'on vérifie "
            + "que le texte reste lisible sur toute la vidéo."
        /// L'infobulle du menu : la réserve, puis le conseil. Les deux phrases
        /// restent mot pour mot — elles ont seulement quitté la ligne.
        static var fondDeLApercuInfobulle: String {
            fondApercuSeulement + " " + fondDeLApercuConseil
        }

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

    // MARK: - Profils

    /// Les messages de lecture, d'écriture et de mémorisation d'un profil.
    ///
    /// Calqués sur ceux du prototype — mêmes mots, même forme — parce que les
    /// deux outils lisent le MÊME fichier : un profil refusé doit se corriger
    /// avec la même indication, qu'on l'ait ouvert d'un côté ou de l'autre.
    enum Profil {

        // ── Refus de lecture ────────────────────────────────────────────────
        static func fichierIllisible(_ nom: String) -> String {
            "Le fichier « \(nom) » n'a pas pu être ouvert."
        }
        static func jsonIllisible(_ detail: String) -> String {
            "JSON illisible : \(detail)"
        }
        static let pasUnObjet = "Le profil doit être un objet JSON."
        static func doitEtreUnObjet(_ contexte: String) -> String {
            "« \(contexte) » doit être un objet."
        }
        /// Un champ inconnu est REFUSÉ, jamais ignoré : c'est ce qui fait
        /// qu'une faute de frappe se voit, au lieu de rendre un habillage
        /// silencieusement différent de celui qu'on croyait décrire.
        static func champInconnu(_ contexte: String, _ cle: String) -> String {
            "\(contexte) : champ inconnu « \(cle) »"
        }
        static func champObligatoire(_ contexte: String, _ cle: String) -> String {
            "\(contexte) : champ obligatoire « \(cle) » absent"
        }
        static func versionSchema(_ recu: Any?) -> String {
            "profil : schema_version doit valoir \(ProfilJSON.versionSchema) "
            + "(reçu \(description(recu)))"
        }
        static let nomVide = "profil : « nom » doit être un texte non vide"
        static func champTexteNonVide(_ contexte: String, _ cle: String) -> String {
            "\(contexte) : « \(cle) » doit être un texte non vide"
        }
        static func nombreAttendu(_ contexte: String, _ cle: String,
                                  _ mini: Double, _ maxi: Double, _ recu: Any?) -> String {
            "\(contexte) : « \(cle) » doit être un nombre entre "
            + "\(ProfilJSON.lisible(mini)) et \(ProfilJSON.lisible(maxi)) "
            + "(reçu \(description(recu)))"
        }
        static func entierAttendu(_ contexte: String, _ cle: String,
                                  _ mini: Int, _ maxi: Int, _ recu: Any?) -> String {
            "\(contexte) : « \(cle) » doit être un entier entre \(mini) et \(maxi) "
            + "(reçu \(description(recu)))"
        }
        static func couleurAttendue(_ contexte: String, _ cle: String,
                                    _ recu: Any?) -> String {
            "\(contexte) : « \(cle) » doit être une couleur #RRGGBB "
            + "(reçu \(description(recu)))"
        }
        static func presetInvalide(_ recu: Any?) -> String {
            "logo.position.preset invalide : \(description(recu))"
        }
        static func modeInvalide(_ recu: Any?) -> String {
            "sous_titre.bandeau : « mode » doit valoir « ajuste » ou "
            + "« pleine-largeur » (reçu \(description(recu)))"
        }

        /// Les anomalies mises en liste, comme le prototype les présente.
        static func refus(_ nom: String, _ anomalies: [String]) -> String {
            "Le profil « \(nom) » n'a pas pu être lu :\n"
            + anomalies.map { "  • " + $0 }.joined(separator: "\n")
        }

        private static func description(_ v: Any?) -> String {
            guard let v else { return "rien" }
            if let s = v as? String { return "« \(s) »" }
            return "\(v)"
        }

        // ── Le logo, et ses deux pièges ─────────────────────────────────────

        /// PIÈGE Nº1 — un chemin absolu casse dès que le fichier bouge.
        ///
        /// Jamais de gravure silencieuse sans logo : c'est l'esprit de
        /// l'invariant nº4, qui refuse la substitution de police muette. Un
        /// logo qu'on croit poser et qui n'apparaît pas est la même trahison.
        static func logoIntrouvable(_ chemin: String) -> String {
            "Le logo du profil est introuvable : \(chemin)\n"
            + "Choisissez-en un autre — rien ne sera gravé sans lui."
        }
        static let choisirUnAutreLogo = "Choisir un autre logo…"

        // ── Mémoire locale ──────────────────────────────────────────────────
        static let memoireIllisible =
            "Les réglages de la dernière session n'ont pas pu être relus. "
            + "Le profil neutre est appliqué."

        // ── Interface ───────────────────────────────────────────────────────
        static let titre = "Profil"
        static let importer = "Importer…"
        static let exporter = "Exporter…"
        static let preregle = "Préréglage"
        static func importe(_ nom: String) -> String {
            "Profil « \(nom) » importé."
        }
        static func exporte(_ nom: String, logo: String?) -> String {
            guard let logo else { return "Profil enregistré dans « \(nom) »." }
            return "Profil enregistré dans « \(nom) », avec une copie du logo "
                + "(« \(logo) ») pour qu'il reste lisible sur une autre machine."
        }
        /// Ce profil emploie des champs que le prototype Python ne connaît pas.
        ///
        /// Dit À L'ENREGISTREMENT, et sur UNE ligne. Décision nº5 du 28/08 : le
        /// prototype ne sera pas amendé, l'asymétrie est assumée — reste à ne
        /// pas la laisser découvrir au moment de s'en servir. L'enregistrement
        /// n'est pas empêché pour autant : le profil est juste, c'est l'ancien
        /// outil qui ne sait pas le rendre.
        static func inconnuDuPrototype(_ champs: [String]) -> String {
            let liste = champs.map { "« \($0) »" }.joined(separator: ", ")
            return "Ce profil emploie \(liste) : le prototype Python le refusera. "
                + "L'app, elle, le relira sans peine."
        }

        /// PIÈGE Nº2 — un profil partagé ne peut pas porter un chemin local.
        static let logoRecopieExplication =
            "Le logo est recopié à côté du profil et son chemin est écrit "
            + "relatif : un profil envoyé à quelqu'un d'autre ne peut pas "
            + "désigner un dossier qui n'existe que sur cette machine."
    }

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
