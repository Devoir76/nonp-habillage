# Cahier des lots — app native d'habillage

Un lot par branche, dans l'ordre. **À donner à Claude Code un lot à la fois** :
copier la section du lot en cours, pas le fichier entier. Un lot n'est terminé
que lorsque **tous** ses critères d'acceptation sont vérifiables.

Référence : `docs/adr/0001-app-compagnon-avfoundation.md`.

---

## Lot 1 — Socle (0,5 j)

Projet SwiftPM produisant un exécutable macOS 14+, structure de dossiers de
l'ADR, `Scripts/build_app.sh` calqué sur NONP Transcription (bundle `.app`,
identifiant `.test` par défaut, signature ad-hoc), `.gitignore`, `LICENSE`
MPL-2.0, en-têtes MPL sur chaque source.

**Acceptation** — `./Scripts/build_app.sh` produit un `.app` qui se lance et
affiche une fenêtre vide ; l'identifiant de test est distinct de la production ;
aucune dépendance externe déclarée dans `Package.swift`.

## Lot 2 — Parseur et segmenteur (1 j)

Portage fidèle depuis `nonp_habille.py` : lecture SRT et VTT, resegmentation à
la ponctuation avec réaffectation des minutages au prorata, calcul des
paramètres de mise en page.

**Nouveauté par rapport au prototype** (ADR §5) : la longueur de ligne cible
pilote la taille, aucun plancher ne contredit la géométrie.

**Acceptation** — tests de parité automatisés contre la sortie Python sur un
corpus de SRT réels : cues identiques (texte **et** minutages) à profil et
résolution 16:9 donnés. Test dédié « fidélité » : chaque mot du SRT d'entrée se
retrouve, inchangé et dans l'ordre, dans les cues produites. Le comportement en
9:16 diverge volontairement du prototype — divergence **documentée et testée**,
pas subie.

## Lot 3 — Rendu du texte (1,5 j)

Core Text : lignes, contour, bandeau (modes `ajuste` et `pleine-largeur`,
hauteur fixe optionnelle), mesure **exacte** du texte, césure prévisible.
Rendu dans un `CALayer`, sans vidéo, sur image fixe.

**Acceptation** — images de référence produites en 16:9, 9:16, 1:1 et 4:5 pour
le profil neutre et le préréglage « Bandeau coloré » ; aucune ligne ne déborde de la largeur
utile, quel que soit le format ; en mode `pleine-largeur`, la bande couvre
exactement la largeur et sa hauteur ne varie pas d'une réplique à l'autre quand
`hauteur_fixe_lignes` est renseigné. Validation visuelle par Éric **avant** le
lot suivant.

## Lot 4 — Composition et export vidéo (1,5 j)

`AVMutableVideoComposition` + `AVAssetExportSession`, encodage VideoToolbox
H.264, audio **recopié sans réencodage**, progression réelle et durée restante
estimée, annulation possible.

**Acceptation** — une vidéo de 10 minutes en 1080p s'exporte sans perte audio,
avec une progression qui avance ; l'annulation laisse le disque propre ; le
fichier produit se lit dans QuickTime et VLC ; temps mesuré et consigné.

## Lot 4bis — Incrustation du logo (0,5 j)

**Pourquoi ce lot existe.** Il comble un trou constaté à la fin du lot 4 :
l'incrustation du logo n'appartenait à aucun lot. Or l'ADR en fait un usage de
**premier rang** — « vidéo + logo seul, le gain de temps le plus immédiat face
à un éditeur vidéo, et pas une option secondaire ». Le lot 4 ne le mentionnait
pas, le lot 5 ne couvre que son placement à la souris dans l'aperçu, et le
lot 7 est la finition. Le logo n'aurait donc jamais été gravé.

Incrustation du logo dans la composition : préréglages **4 coins** et
**coordonnées libres** — où `x_pct` / `y_pct` désignent le **centre** du logo,
comme le veut le schéma —, **taille** et **marge** relatives à la hauteur,
**opacité**. Le logo est posé SOUS les sous-titres, comme dans le prototype :
un logo mal placé ne doit jamais masquer une réplique.

Le ratio du logo est **préservé**, conformément au schéma partagé (« plus
grande dimension en % de la hauteur, ratio préservé »), là où le prototype
écrasait toute image en carré. Sur un logo carré — celui de NONP — les deux
donnent le même résultat.

**Acceptation** — les **trois usages** de l'ADR fonctionnent en ligne de
commande : sous-titres seuls, logo seul, les deux. Les quatre coins et les
coordonnées libres placent le logo là où ils l'annoncent, à la marge du profil,
sans jamais sortir de l'image, en 16:9 comme en 9:16 et en 1:1. La position
d'un logo carré est **identique à celle du prototype**, contrôlée. Un fichier
de logo introuvable produit une erreur explicite et **aucun rendu** — jamais un
habillage silencieusement amputé de son logo.

## Lot 5 — Interface (2,5 j)

Zone de dépôt (vidéo seule, ou vidéo + sous-titres), bouton **Habiller**,
progression. Volet « Personnaliser » repliable : logo déplaçable à la souris sur
l'aperçu, curseurs de taille et d'opacité, quatre coins en un clic ; sous-titres
avec tailles nommées, liste courte de polices, sélecteurs de couleur, réglages
de bandeau. Aperçu sur une image fixe extraite de la vidéo, **sur une réplique
réelle** quand un fichier de sous-titres est fourni.

**Acceptation** — les trois usages fonctionnent (sous-titres seuls, logo seul,
les deux) ; l'aperçu reflète chaque réglage sans encoder ; l'écran d'accueil
tient sans défilement et ne montre aucun réglage tant que le volet est fermé.

L'aperçu affiche du texte **en permanence** : phrase de référence calibrée sur
la longueur de ligne cible quand aucun sous-titre n'est chargé, sinon la
**réplique la plus longue du fichier** (pire cas), les autres étant parcourables.
L'image de fond est choisissable parmi plusieurs instants de la vidéo — au moins
un plan clair et un plan sombre — pour juger le contraste des couleurs.

**Ajouté après retour d'usage (25/08)** : disposition en **deux volets** —
aperçu à gauche, grand et toujours visible ; réglages à droite, en colonne
défilante. C'est la seule qui permette de régler en voyant. L'aperçu montre
l'image **entière**, mise à l'échelle, jamais rognée, et grandit avec la
fenêtre, qui est redimensionnable. Le `--make-logo` du prototype est porté sous
forme de réglage « recadrer en cercle », en plus de l'acceptation d'un PNG déjà
détouré.

**Acceptation complémentaire** — à taille par défaut comme en fenêtre agrandie,
l'aperçu affiche l'image entière et tous les réglages restent atteignables.

## Lot 6 — Profils (1 j)

Lecture, écriture et validation du schéma (champs inconnus refusés, messages en
français), mémorisation du dernier profil utilisé, import et export d'un `.json`.

**Plus de préréglages** (tranché le 28/08). Le lot annonçait des « préréglages
livrés (**Neutre** par défaut, **NONP**) ». Deux retours d'usage l'ont défait,
le même jour : un préréglage au nom d'une association n'a pas sa place dans une
application destinée au téléchargement public ; et la notion de profil était
mise en avant bien au-delà de ce qu'elle sert, la plupart des utilisateurs
n'ayant qu'un seul habillage dont ils attendent seulement qu'il se mémorise.

Ce qui est livré à la place :

- **des réglages par défaut** (l'ancien « Neutre »), point de départ à la
  première ouverture, puis les réglages mémorisés ;
- **des fichiers d'exemple** dans `Resources/profils-exemples/` —
  `bandeau-colore.json` et `nonp.json` —, que le panneau d'import ouvre par
  défaut ;
- **trois commandes au menu Fichier** : « Importer un profil… », « Exporter le
  profil… », « Revenir aux réglages par défaut ».

Voir ADR-0001 §2, amendements du 28/08.

**Ce que la mémorisation doit couvrir** (précisé le 25/08). Le dernier profil
utilisé, et avec lui **le chemin du fichier de logo** : on ne redépose pas son
logo à chaque lancement. Le schéma prévoit déjà `logo.fichier`, « absolu, ou
relatif au fichier de profil ». Deux points à trancher en même temps :

- un chemin absolu casse dès que le fichier est déplacé — prévoir un message
  clair, et proposer d'en choisir un autre plutôt que de graver sans logo
  (invariant nº4 vaut aussi ici) ;
- un profil **partagé** ne peut pas porter le chemin d'un logo qui n'existe que
  sur la machine de l'expéditeur. Le profil mémorisé localement et le profil
  exporté n'ont donc pas les mêmes besoins.

**Trois réglages de l'interface n'ont pas de champ dans le schéma** et leur
persistance se décide ici : `longueurLigneCible` (la taille nommée),
`logoRecadreEnCercle` (le recadrage rond), et la taille de police que pose une
taille nommée — le schéma stocke bien `taille_pct_hauteur`, mais le lien entre
les deux reste à écrire.

**Tranché dans ce lot** (28/08/2026) : `espaces_lateraux`, héritage de l'ASS
adossé à la taille de police alors qu'il consomme de la largeur. Remplacé par un
champ unique, `bandeau.marge_texte_pct_largeur`, qui commande la largeur de la
colonne dans les deux modes de bandeau. **Le schéma passe en version 2** ;
`longueur_ligne_cible` et `logo.recadre_en_cercle` y entrent avec lui. Voir
ADR-0001, décisions nº5 et nº6, et `docs/divergences-prototype.md` D-9 et D-10.

**Retours d'usage sur exports réels** (06/09/2026). Trois corrections, aucune
sur le rendu : le **nom proposé** à l'enregistrement vient du fichier de
sous-titres quand il y en a un — la vidéo garde souvent le nom automatique de
son téléchargement, le `.srt` porte le nom voulu ; le **suffixe** `_habillee`
est confirmé et sa neutralité devient une règle écrite, la même que pour les
préréglages ; une sortie **ne peut jamais remplacer un fichier d'entrée**, refus
posé dans le moteur ; et « **Habiller une autre vidéo** » décharge la vidéo et
ses sous-titres en gardant les réglages et le logo. Voir ADR-0001, « Tranché le
06/09 ».

**Acceptation** — un profil écrit par le prototype Python est accepté sans
retouche ; un fichier corrompu produit un message clair et aucun rendu.

Le second critère annoncé — « un profil produit par l'app est accepté par le
prototype » — **n'est plus tenu, et c'est délibéré** : le schéma est passé en
version 2 (décision nº6) et le prototype ne sera pas amendé (décision nº5). Le
sens qui compte reste sans restriction, et il est mesuré à chaque exécution.
Voir `docs/divergences-prototype.md`, D-9.

## Lot 7 — Parité, finition, release (1,5 j)

Campagne de comparaison prototype / natif sur vidéos réelles, corrections,
`docs/release-checklist.md`, README public, textes d'aide.

**Ce qu'un refus doit dire** (06/09/2026). Deux défauts trouvés en enquêtant sur
un contrôle en échec, aucun là où on le cherchait. Le message « format non pris
en charge » servait de fourre-tout à toute erreur de chargement — fichier
introuvable, droits refusés, dossier déposé, fichier tronqué : chaque cause se
nomme désormais elle-même, et le conseil de conversion est réservé au seul cas
où il aide. Et le périmètre MP4/MOV/M4V, appliqué par la zone de dépôt seule,
laissait passer un AVI par la ligne de commande : une seule règle vaut désormais
pour les deux portes. Voir ADR-0001, « Tranché le 06/09 — ce qu'un refus doit
dire ».

**Fait le 06/09** — dette technique résorbée (plus un seul avertissement à la
compilation, sur un `.build` effacé), « Fond de l'aperçu » allégé de son nom,
première campagne de parité sur vidéos réelles ([`campagne-parite.md`](campagne-parite.md)),
[`release-checklist.md`](release-checklist.md), `README.md` public, et une
infobulle par réglage — obligatoire au compilateur, éprouvée par le harnais.

**Acceptation** — Éric juge le rendu indiscernable à l'usage en 16:9 **et** en
9:16 ; la checklist de release est déroulable de bout en bout.

**Reste à faire** — le jugement d'Éric sur la campagne, et les sources vierges
qui lui manquent (aucun 16:9 vierge sur la machine de travail). Tant qu'il n'a
pas eu lieu, l'invariant nº5 tient et le prototype reste l'outil de production.

---

## Améliorations différées

À traiter après le lot 7, jamais pendant : profil adapté automatiquement au
format détecté, contrôle de cohérence sous-titres/vidéo à l'ouverture, ombre
portée en alternative au bandeau, traitement par lot, révélation du fichier
dans le Finder.
