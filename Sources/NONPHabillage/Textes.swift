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
        // ── Le logo empiète sur la zone des sous-titres ─────────────────────
        //
        // Un seul constat, et un conseil qui dépend du placement. Il disait
        // toujours « Déplacez-le, ou réduisez sa taille » — et réduire ne sert
        // à rien pour un logo ancré dans un coin bas : réduit, son haut se
        // rapproche du bas, et il reste dans la bande (mesuré : l'avertissement
        // persiste de 4 % à 50 % de taille, il ne tombe qu'à 1–3 %, un logo
        // presque invisible). Chaque conseil n'est donné que si
        // `AvertissementsZone` a vérifié, dans la vraie géométrie, qu'il lève
        // l'avertissement — et le harnais le revérifie cas par cas.
        static let logoSurBandeau = "Le logo empiète sur la zone des sous-titres."
        /// Coin bas : un coin du haut, ou la bande qui remonte.
        static let conseilCoinHautOuMargeBasse =
            "Choisissez un coin du haut, ou relevez la marge basse."
        static let conseilCoinHaut = "Choisissez un coin du haut."
        static let conseilRelever = "Relevez la marge basse."
        /// Placement libre, le centre du logo hors de la bande : réduire le
        /// logo l'en écarte.
        static let conseilRemonterOuReduire = "Remontez-le, ou réduisez sa taille."
        /// Placement libre, le centre du logo DANS la bande : aucune taille
        /// n'y échappe. Le conseil ferme explicitement la porte à l'action
        /// inutile — c'était le défaut d'origine.
        static let conseilRemonterSeulement = "Remontez-le : le réduire ne suffira pas."
        /// Coin haut — possible, aux extrêmes : logo à 50 %, marge basse au-delà
        /// de 26 %.
        static let conseilReduireOuAbaisserMarge =
            "Réduisez sa taille, ou abaissez la marge basse."
        static let conseilReduire = "Réduisez sa taille."
        static let conseilAbaisserMarge = "Abaissez la marge basse."

        static func logoSurBandeau(conseil: String?) -> String {
            guard let conseil else { return logoSurBandeau }
            return logoSurBandeau + " " + conseil
        }
        static let logoHorsMargesSures =
            "Le logo touche le bord de l'image. Certaines plateformes rognent "
            + "les bords : éloignez-le un peu."
    }

    // MARK: - Interface (lot 5)

    /// Les infobulles des réglages.
    ///
    /// ── Pourquoi une famille à part ──────────────────────────────────────
    ///
    /// Un libellé nomme un réglage ; il ne dit pas ce qu'on y gagne, ni quand
    /// il compte. « Marge basse » se comprend, mais rien n'annonce qu'une
    /// vidéo destinée à un réseau social a besoin de la relever pour passer
    /// au-dessus des commandes de lecture. C'est ce genre de phrase qui vit
    /// ici, et nulle part ailleurs.
    ///
    /// **Chaque réglage du volet en a une, et ce n'est pas une convention :
    /// c'est le compilateur qui l'exige.** Les constructeurs de contrôles —
    /// `choixSegmente`, `interrupteur`, `curseurPourcent`… — prennent une aide
    /// obligatoire. Un réglage ajouté sans la sienne ne compile pas. Une règle
    /// que le compilateur tient ne se relâche pas au bout de six mois.
    ///
    /// Elles ne répètent jamais le libellé : le survol doit apprendre quelque
    /// chose, sinon il fait perdre du temps à celui qui a pris la peine de
    /// s'arrêter. Un contrôle le vérifie.
    enum Aide {

        // ── Sous-titres ──────────────────────────────────────────────────

        static let taille =
            "Quatre apparences plutôt qu'un pourcentage : le moteur en déduit "
            + "la taille exacte selon le format de la vidéo. Une même valeur ne "
            + "donne pas la même chose en 16:9 et en 9:16."
        static let police =
            "Les premières polices de la liste sont livrées avec macOS : un "
            + "profil qui les emploie rend la même chose sur une autre machine. "
            + "Les suivantes n'existent peut-être que sur la vôtre."
        static let couleurTexte =
            "La couleur des lettres. Regardez le plan le plus clair et le plus "
            + "sombre de la vidéo avant de choisir : c'est là que la lisibilité "
            + "se perd."
        static let couleurContour =
            "Le liseré qui détache les lettres de l'image. C'est lui qui sauve "
            + "un sous-titre posé sur un fond clair, quand il n'y a pas de "
            + "bandeau derrière."
        static let lignesMax =
            "Au-delà, une réplique trop longue est redécoupée en plusieurs, dont "
            + "les minutages se répartissent au prorata. Rien n'est retiré du "
            + "texte : il est seulement montré en plusieurs fois."

        // ── Bandeau ──────────────────────────────────────────────────────

        static let bandeauActif =
            "Le fond posé derrière le texte. Il masque aussi un sous-titre déjà "
            + "incrusté dans la vidéo, ce qu'un simple contour ne fait pas."
        static let modeBandeau =
            "Pleine largeur : une bande constante, qui ne saute pas d'une "
            + "réplique à l'autre. Ajusté : une pastille à la longueur de chaque "
            + "ligne, plus discrète mais mouvante."
        static let couleurBandeau =
            "Le sélecteur porte aussi l'opacité : un fond à demi transparent "
            + "laisse deviner l'image derrière sans que le texte y perde."
        static let hauteurFixe =
            "La bande garde la même hauteur, qu'une réplique tienne sur une "
            + "ligne ou sur deux. Sans cela, elle grandit et rétrécit au fil du "
            + "texte."
        static let margeBasse =
            "La distance entre le bas de l'image et le bas du texte. À relever "
            + "pour une vidéo destinée à un réseau social, où le bas de l'écran "
            + "est occupé par les commandes de lecture."

        // ── Logo ─────────────────────────────────────────────────────────

        static let choisirLogo =
            "Une image PNG, JPEG, HEIC ou TIFF. Un PNG à fond transparent se "
            + "pose sans rectangle autour."
        static let retirerLogo =
            "Retire le logo de l'habillage. Le fichier n'est pas touché, et les "
            + "autres réglages restent en place."
        static let positionLogo =
            "Les quatre coins en un clic. Pour un autre emplacement, faites "
            + "glisser le logo directement dans l'aperçu."
        static let logoRond =
            "Découpe l'image en cercle au moment de la graver. Inutile si le "
            + "fichier est déjà détouré ; réversible à tout moment."
        static let tailleLogo =
            "En pourcentage de la HAUTEUR de la vidéo, jamais de sa largeur : "
            + "le logo garde la même présence en 16:9 et en 9:16."
        static let opaciteLogo =
            "Un logo à demi transparent se fait oublier sur l'image sans "
            + "disparaître. À 100 %, il est posé tel quel."

        // ── Zones de dépôt ───────────────────────────────────────────────

        static let depotVideo =
            "La vidéo à habiller. Elle n'est jamais modifiée : l'habillage part "
            + "dans un nouveau fichier, que vous nommez à l'enregistrement."
        static let depotSousTitres =
            "Le fichier de sous-titres à graver. Aucun mot n'en sera modifié — "
            + "ni orthographe, ni ponctuation, ni tournure."

        /// Toutes les aides, pour que le harnais les éprouve ensemble.
        static let toutes: [(nom: String, texte: String)] = [
            ("taille", taille), ("police", police),
            ("couleur du texte", couleurTexte), ("couleur du contour", couleurContour),
            ("lignes maximum", lignesMax), ("bandeau", bandeauActif),
            ("mode du bandeau", modeBandeau), ("couleur du bandeau", couleurBandeau),
            ("hauteur constante", hauteurFixe), ("marge basse", margeBasse),
            ("choisir un logo", choisirLogo), ("retirer le logo", retirerLogo),
            ("position du logo", positionLogo), ("logo rond", logoRond),
            ("taille du logo", tailleLogo), ("opacité du logo", opaciteLogo),
            ("dépôt de la vidéo", depotVideo),
            ("dépôt des sous-titres", depotSousTitres),
        ]
    }

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
        static let deplacerLogo = "Glissez le logo sur l'aperçu."
        static let logoRond = "Recadrer en cercle"
        static let logoRondExplication =
            "Découpe le disque inscrit, bord lissé. Inutile si votre PNG est "
            + "déjà détouré." 

        /// Le titre des boutons de coin. Abrégé : les noms complets ne tenaient
        /// pas dans la colonne et se tronquaient (DC-1). Le nom complet reste
        /// en infobulle et pour VoiceOver — `nomCoin`.
        static func nomCoinAbrege(_ coin: CoinLogo) -> String {
            switch coin {
            case .hautGauche: return "Haut G."
            case .hautDroit: return "Haut D."
            case .basGauche: return "Bas G."
            case .basDroit: return "Bas D."
            }
        }

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
        /// L'infobulle du menu : le nom, la réserve, puis le conseil. Les
        /// trois textes restent mot pour mot — ils ont seulement quitté la
        /// ligne.
        ///
        /// Le nom les y a rejoints le 06/09, par le même raisonnement : dans
        /// un volet dont la valeur est l'IMAGE, un réglage dont l'état se lit
        /// seul n'a pas besoin d'être annoncé en permanence. « 3/6 — moyen »
        /// dit le rang et le qualificatif ; « Fond de l'aperçu » ne servait
        /// qu'à la première rencontre, et c'est exactement ce que porte une
        /// infobulle. Le nom reste, entier, à portée du pointeur — et il reste
        /// annoncé par VoiceOver, qui ne survole rien.
        static var fondDeLApercuInfobulle: String {
            fondDeLApercu + " — " + fondApercuSeulement + " " + fondDeLApercuConseil
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

        // ── Les deux issues de l'écran de fin ──────────────────────────────
        //
        // Elles sont VOISINES et leurs effets sont OPPOSÉS : l'une garde tout
        // en place, l'autre vide le document. Deux boutons pareils qui font le
        // contraire l'un de l'autre se cliquent au hasard une fois sur deux —
        // d'où, pour chacun, une ligne qui dit ce qu'il advient des fichiers
        // chargés. C'est le même principe que « Il n'y a rien à graver » sous
        // le bouton « Habiller » : l'explication vit contre son bouton.

        /// **En attente du choix d'Éric.** Deux autres libellés tenaient la
        /// corde, et le changement se fait ici, sur cette seule ligne :
        ///
        /// - « Reprendre cette vidéo » — c'est l'opposition la plus nette avec
        ///   « Habiller une AUTRE vidéo » : *cette* contre *une autre*, deux
        ///   mots qui se répondent et qu'on lit d'un coup d'œil.
        /// - « Corriger un réglage » — nomme le motif plutôt que la
        ///   destination, et dit donc pourquoi on cliquerait ; mais il promet
        ///   les réglages, alors que le bouton rend l'écran tel qu'on l'a
        ///   quitté, volet fermé s'il l'était.
        ///
        /// Celui qui est en place nomme la destination, se lit vite, et n'est
        /// démenti par rien : le volet est bien la porte des réglages, ouverte
        /// ou non.
        static let reprendreCetteVideo = "Revenir aux réglages"
        static let reprendreCetteVideoEffet =
            "La vidéo, les sous-titres et les réglages restent chargés."

        static let recommencer = "Habiller une autre vidéo"
        static let recommencerEffet =
            "La vidéo et ses sous-titres sont retirés. Les réglages restent."

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
        /// Une version qu'on ne sait pas lire.
        ///
        /// « Version inconnue » ne dit rien à personne. Le message nomme les
        /// versions acceptées, dit ce que la 2 a changé, et pourquoi — c'est ce
        /// qu'on veut lire quand un fichier est refusé.
        static func versionSchema(_ recu: Any?) -> String {
            "profil : schema_version doit valoir \(ProfilJSON.versionSchema) "
            + "(reçu \(description(recu))). Les profils en version "
            + "\(ProfilJSON.versionPrecedente) sont lus et convertis "
            + "automatiquement ; aucune autre version n'existe."
        }

        // ── Conversion d'un profil version 1 ────────────────────────────────
        //
        // Une conversion silencieuse est une modification silencieuse. Ce qui
        // suit se dit à l'utilisateur, à chaque profil converti.

        static let migrationTitre = "Profil converti de la version 1 à la version 2."

        /// La conversion, telle qu'une sortie de terminal la montre.
        ///
        /// Le message de migration tient sur plusieurs lignes — il explique ce
        /// qu'il a fait, c'est ce qu'on lui demande. Recollé tel quel derrière
        /// une étiquette, il débordait dans la marge et sa suite paraissait
        /// venir d'ailleurs. Chaque ligne est donc alignée sous la première.
        ///
        /// Aucun mot n'est retiré au passage : c'est une mise en page, pas un
        /// résumé. Un résumé de conversion serait une conversion à moitié dite.
        static func migrationEnLignes(_ message: String) -> String {
            message.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .map { $0.offset == 0 ? "  ⚠︎ \($0.element)" : "     \($0.element)" }
                .joined(separator: "\n")
        }
        static func migrationPleineLargeur(_ pourcent: Double) -> String {
            migrationTitre + "\n"
            + "« marge_interieure_pct_largeur » (\(ProfilJSON.lisible(pourcent)) %) "
            + "devient « marge_texte_pct_largeur », à l'identique : les deux "
            + "expriment déjà un pourcentage de la largeur. Le rendu ne change pas."
        }
        static func migrationAjuste(espaces: Int, debord: Double,
                                    pourcent: Double) -> String {
            migrationTitre + "\n"
            + "« espaces_lateraux » (\(espaces)) devient "
            + "« marge_texte_pct_largeur » (\(ProfilJSON.lisible(pourcent)) %). "
            + "Les espaces se comptaient en largeurs d'espace, donc en fraction "
            + "de la taille de police — donc de la HAUTEUR — pour un retrait qui "
            + "consomme de la LARGEUR. La conversion se fait sur le 16:9 1080p, "
            + "où ces \(espaces) espaces valaient \(Int(debord.rounded())) px : "
            + "en 16:9 le rendu est inchangé, et les formats verticaux "
            + "récupèrent la largeur que l'ancienne unité leur prenait."
        }
        static func migrationImpossible(_ police: String) -> String {
            "Ce profil est en version 1 et ne peut pas être converti : la police "
            + "« \(police) » n'est pas installée sur ce Mac.\n"
            + "Convertir « espaces_lateraux » exige de MESURER une espace dans "
            + "cette police — la faire avec une autre donnerait un retrait faux, "
            + "et l'invariant nº4 interdit toute substitution silencieuse. "
            + "Installez la police, ou corrigez le profil."
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
        // ── Le menu Fichier ─────────────────────────────────────────────
        //
        // Ces trois libellés étaient trois boutons d'une section « Profil », en
        // tête du volet Personnaliser. Ce sont des gestes rares et délibérés :
        // ils ont rejoint le menu Fichier le 28/08/2026, et le volet ne
        // contient plus que des réglages.
        //
        // Les libellés sont plus longs qu'en volet, et c'est voulu : dans un
        // menu on ne voit pas le contexte, « Importer… » tout seul n'y dirait
        // pas ce qu'on importe.
        static let importerUnProfil = "Importer un profil…"
        static let exporterLeProfil = "Exporter le profil…"
        static let reglagesParDefaut = "Revenir aux réglages par défaut"
        /// Dit, à l'ouverture du panneau d'import, ce qu'on y trouve.
        ///
        /// Les préréglages livrés décrivent une APPARENCE ; l'habillage d'une
        /// organisation est un fichier qu'on s'échange. Le panneau s'ouvre sur
        /// les exemples pour que la distinction se voie plutôt que se lise.
        static let ouExemples =
            "Profils d'exemple livrés avec l'application. Un profil reçu d'une "
            + "association s'importe de la même façon."
        static func importe(_ nom: String) -> String {
            "Profil « \(nom) » importé."
        }
        static let revenusAuxReglagesParDefaut =
            "Réglages par défaut rétablis."
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
            return "Profil en version \(ProfilJSON.versionSchema) : le prototype "
                + "Python le refusera — il attend la version "
                + "\(ProfilJSON.versionPrecedente), et \(liste) lui sont inconnus. "
                + "L'app, elle, le relira sans peine, et lit toujours les profils "
                + "du prototype."
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

        /// Le suffixe du fichier produit : `<base>_habillee.mp4`.
        ///
        /// **Neutre, et il doit le rester.** C'est la règle écrite pour les
        /// préréglages le 28/08 — rien, dans une application destinée au
        /// téléchargement public, n'applique l'identité d'une association aux
        /// fichiers d'un inconnu. Un suffixe `_NONP` est donc exclu au même
        /// titre qu'un préréglage `NONP` : le fichier sort de la machine de
        /// l'utilisateur, il porte son nom à lui.
        ///
        /// ASCII pur, sans accent ni espace : ce nom traverse des dossiers
        /// partagés, des lecteurs réseau et des lignes de commande.
        ///
        /// Une seule constante, parce qu'il ne s'écrit qu'ici : `sortieProposee`
        /// le pose, et rien d'autre ne le connaît.
        static let suffixeSortie = "_habillee"

        /// La sortie ne peut jamais s'écrire sur un de ses fichiers d'entrée.
        ///
        /// Le nom proposé les évite déjà, mais le champ du panneau
        /// d'enregistrement est libre : on peut y retaper le nom de la vidéo
        /// source. macOS demanderait alors « remplacer ? », et un oui
        /// détruirait l'original. Le garde-fou est donc dans le MOTEUR, pas
        /// dans le panneau — la ligne de commande passe par le même chemin.
        static func ecraseraitUneEntree(_ nom: String) -> String {
            "L'export écrirait par-dessus « \(nom) », qu'il est en train de "
            + "lire. Choisissez un autre nom ou un autre dossier : "
            + "les fichiers d'origine ne sont jamais remplacés."
        }

        /// Formats d'entrée : MP4, MOV, M4V (ADR §3). Un fichier refusé doit
        /// produire un message explicite assorti d'une marche à suivre — jamais
        /// un échec silencieux ni un plantage.
        ///
        /// **Réservé au vrai problème de format.** Ce texte a longtemps servi
        /// de fourre-tout : un fichier introuvable, un dossier, des droits
        /// refusés recevaient tous ce conseil de conversion, qui ne réglait
        /// rien. Chaque cause a désormais son message — voir `RefusVideo`.
        static func formatNonPrisEnCharge(_ nom: String) -> String {
            "Le fichier « \(nom) » n'est pas pris en charge par le moteur vidéo de "
            + "macOS. Les formats acceptés sont MP4, MOV et M4V. Convertissez la "
            + "vidéo dans l'un de ces formats, puis réessayez."
        }

        static func videoIntrouvable(_ nom: String) -> String {
            "Le fichier « \(nom) » est introuvable. Il a sans doute été déplacé, "
            + "renommé ou supprimé depuis. Retrouvez-le, puis déposez-le à nouveau."
        }

        static func pasUnFichier(_ nom: String) -> String {
            "« \(nom) » est un dossier, pas une vidéo. Ouvrez-le et choisissez le "
            + "fichier à habiller."
        }

        static func droitsRefuses(_ nom: String) -> String {
            "macOS refuse l'accès au fichier « \(nom) ». Le format n'est pas en "
            + "cause : ce sont les droits. Vérifiez-les dans le Finder (Lire les "
            + "informations), ou copiez la vidéo dans un dossier qui vous appartient."
        }

        /// Un fichier sans extension du tout. Le conseil n'est pas de
        /// convertir — le fichier est peut-être un MP4 parfaitement valide —
        /// mais de le nommer, puisque c'est à l'extension que l'application
        /// et le sélecteur de fichiers de macOS reconnaissent une vidéo.
        static func sansExtension(_ nom: String) -> String {
            "Le fichier « \(nom) » n'a pas d'extension. L'application reconnaît "
            + "les vidéos à la leur : renommez-le en .mp4, .mov ou .m4v selon ce "
            + "qu'il contient, puis réessayez."
        }

        static func videoVide(_ nom: String) -> String {
            "Le fichier « \(nom) » est vide : il ne contient aucune donnée. La "
            + "copie ou le téléchargement qui l'a produit ne s'est probablement pas "
            + "terminé."
        }

        /// Ce que macOS signale ici, c'est un contenu qu'il n'arrive pas à
        /// analyser : un fichier tronqué, un fichier corrompu, ou un fichier
        /// qui n'est pas du tout ce que son extension annonce. Le message ne
        /// tranche pas entre les trois — il n'en sait rien — mais il écarte
        /// explicitement la conversion, qui ne réglerait aucun des trois.
        static func videoEndommagee(_ nom: String) -> String {
            "Le contenu du fichier « \(nom) » est illisible : il est incomplet, "
            + "endommagé, ou ce n'est pas la vidéo que son nom annonce. Le convertir "
            + "n'y changerait rien. Récupérez une copie intacte du fichier."
        }

        /// Le dernier recours. Il cite la raison rendue par macOS **telle
        /// quelle** : une raison technique vaut mieux qu'une cause inventée.
        static func chargementImpossible(_ nom: String, _ raison: String) -> String {
            "Le fichier « \(nom) » n'a pas pu être ouvert. macOS indique : "
            + "\(raison). Si la vidéo est rangée dans un service de synchronisation "
            + "ou sur un disque distant, vérifiez qu'elle est bien téléchargée sur "
            + "cet ordinateur."
        }

        static func message(pour refus: RefusVideo) -> String {
            switch refus {
            case .introuvable(let url):
                return videoIntrouvable(url.lastPathComponent)
            case .pasUnFichier(let url):
                return pasUnFichier(url.lastPathComponent)
            case .droitsRefuses(let url):
                return droitsRefuses(url.lastPathComponent)
            case .vide(let url):
                return videoVide(url.lastPathComponent)
            case .formatNonPrisEnCharge(let url):
                return formatNonPrisEnCharge(url.lastPathComponent)
            case .sansExtension(let url):
                return sansExtension(url.lastPathComponent)
            case .endommagee(let url):
                return videoEndommagee(url.lastPathComponent)
            case .chargementImpossible(let url, let raison):
                return chargementImpossible(url.lastPathComponent, raison)
            }
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
            case .videoRefusee(let refus):
                return message(pour: refus)
            case .pisteVideoAbsente(let url):
                return pisteVideoAbsente(url.lastPathComponent)
            case .lectureImpossible(let raison):
                return lectureImpossible(raison)
            case .ecritureImpossible(let raison):
                return ecritureImpossible(raison)
            case .ecraseraitUneEntree(let url):
                return ecraseraitUneEntree(url.lastPathComponent)
            case .annule:
                return annule
            }
        }
    }
}
