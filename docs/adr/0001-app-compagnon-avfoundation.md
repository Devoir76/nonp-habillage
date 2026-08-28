# ADR-0001 — Habillage : application compagnon native (AVFoundation)

- **Statut** : **Proposé** — en attente de validation par Éric. Aucun code écrit.
- **Date** : 2026-08-23
- **Déclencheur** : constat d'usage du 23/08. Le prototype Python a prouvé le
  design et sert quotidiennement, mais il ne peut pas être partagé sur `nonp.fr`.
  La publication open source de NONP Transcription étant close (release v1.2.3
  du 12/08), le chantier habillage est débloqué.
- **Contexte amont** : note coffre « Habillage multi-utilisateurs » (09/08),
  option C ; addendum du 23/08 (schéma de profils v1.1).

## Contexte

### Ce que le prototype Python ne pourra jamais être

`nonp_habille.py` (297 lignes) + droplet AppleScript fonctionne, et le chantier
`feat/profils-json` en a sorti toute l'identité NONP (profil par défaut généré
depuis les constantes, iso-rendu prouvé octet à octet). Trois obstacles le
rendent malgré tout indistribuable, et aucun ne se corrige par retouche :

1. **Dépendance FFmpeg externe.** L'outil exige `brew install ffmpeg-full`,
   installé manuellement — hors de portée d'un utilisateur non développeur.
2. **Embarquer FFmpeg est interdit ici.** L'habillage impose un **encodeur
   vidéo** : `libx264` est GPL-2.0+, ce qui contaminerait le binaire distribué
   et rouvrirait le chantier licences refermé le 12/08 (MPL-2.0, ADR-0005 de
   NONP Transcription). S'y ajouteraient libass, fribidi, harfbuzz, freetype.
   L'invariant « pas de second FFmpeg » est directement issu de ce constat.
3. **Aucune interface.** Régler son habillage suppose d'éditer un JSON dans un
   éditeur de texte. C'est un fichier de configuration, pas un produit.

### Pourquoi AVFoundation lève les trois obstacles d'un coup

- **Aucun binaire tiers, aucune licence supplémentaire** : AVFoundation, Core
  Text et VideoToolbox sont des frameworks Apple, déjà présents sur le système.
  Le `.app` reste sous **MPL-2.0**, sans notice tierce à maintenir.
- **Encodage H.264/HEVC par VideoToolbox** (accélération matérielle) : plus
  rapide que libx264 sur Apple Silicon, sans le verrou GPL.
- **Rendu du texte par Core Text** : accès exact aux polices système, avec un
  contrôle typographique supérieur à l'ASS de libass.
- **Continuité technique** : du Swift dans un écosystème que NONP Transcription
  connaît déjà (~3 800 lignes SwiftUI, scripts de build éprouvés, checklist de
  release, procédure de publication `nonp.fr` déjà écrite).

### Ce qu'AVFoundation coûte

AVFoundation lit **moins de conteneurs** que FFmpeg : MKV n'est pas pris en
charge, AVI l'est mal. C'est une perte réelle, tranchée ci-dessous.

## Décision

**Public visé** (précisé le 23/08) : **toute personne** souhaitant incruster des
sous-titres sur une vidéo et, si elle le souhaite, son logo — pas seulement le
milieu associatif ou mémoriel. L'app remplace l'usage répétitif qu'on fait
aujourd'hui d'un éditeur vidéo grand public (CapCut et équivalents) pour cette
tâche unique. Ce choix commande les décisions ci-dessous.

**Logo et sous-titres sont deux options indépendantes**, d'où trois usages de
premier rang, à égalité :

1. vidéo + sous-titres (sans logo) ;
2. **vidéo + logo seul** — le gain de temps le plus immédiat face à un éditeur
   vidéo, et pas une option secondaire ;
3. vidéo + logo + sous-titres.

Les sous-titres viennent de l'utilisateur (NONP Transcription ou ailleurs).
L'app ne transcrit pas, ne traduit pas. Durée de référence : de quelques minutes
à une vingtaine — le temps d'encodage doit rester acceptable et **annoncé**.

### 1. Application compagnon distincte — « NONP Habillage »

**Pas** une fonction de NONP Transcription. Motifs :

- Chaque application garde un propos qu'on énonce en une phrase.
- L'encodage vidéo est un autre métier que la transcription : autres pannes,
  autre support, autres temps de traitement. Une régression d'habillage ne doit
  **jamais** pouvoir affecter l'outil de transcription, qui sert au devoir de
  mémoire.
- Le périmètre de NONP Transcription reste gelé — cohérent avec ses garde-fous.

Conséquence : deux téléchargements sur `nonp.fr`, deux dépôts, deux cycles de
version. Assumé.

### 2. Interface : simple d'abord, personnalisable ensuite

- **Écran principal minimal** : zone de dépôt (vidéo + sous-titres facultatifs),
  un bouton **Habiller**, une barre de progression avec durée restante estimée.
  Rien d'autre.
- **Volet « Personnaliser » repliable**, fermé par défaut, avec **aperçu sur une
  image fixe extraite de la vidéo** (aucun encodage) rafraîchi à chaque réglage.

**Aperçu : ce qu'on y voit** (précisé le 23/08). Régler une taille, une couleur
ou une police à l'aveugle n'a pas de sens — il faut voir le résultat sur **sa**
vidéo, immédiatement. L'aperçu affiche donc du texte en permanence, même quand
aucun sous-titre n'est encore chargé :

- **Sans fichier de sous-titres** : une **phrase de référence** calibrée sur la
  longueur de ligne cible de la taille choisie, contenant accents, majuscules,
  jambages et ponctuation — de quoi juger lisibilité, contraste et césure. Une
  variante longue montre le passage à deux lignes.
- **Avec fichier de sous-titres** : la **réplique la plus longue du fichier**,
  c'est-à-dire le pire cas. Si elle passe, tout passe. Les flèches permettent de
  parcourir les autres répliques.
- **Image de fond choisissable** : plusieurs instants de la vidéo (une image
  claire, une sombre), car un blanc à contour noir qui convient sur un plan
  sombre peut devenir illisible sur un plan clair. C'est le seul moyen honnête
  de choisir une couleur de texte ou de bandeau.
- Tout réglage — taille, police, couleurs, contour, bandeau, position du logo —
  se répercute **instantanément**, sans encodage.
- **Logo placé à la souris sur l'aperçu**, avec curseur de taille et d'opacité à
  côté. Les quatre coins restent accessibles en un clic. Saisir des pourcentages
  reste possible, mais n'est jamais imposé — le profil enregistré, lui, stocke
  bien des valeurs relatives (voir schéma).
- **Couleurs au sélecteur macOS**, avec quelques teintes prêtes à l'emploi (dont
  le bleu NONP `#0067F6`) et un réglage d'opacité, pour le texte, le contour et
  le fond des sous-titres.
- **Taille des sous-titres : quatre tailles nommées** — *Petite*, *Normale*,
  *Grande*, *Très grande* — plutôt qu'un pourcentage à saisir. Chaque taille
  correspond à une **longueur de ligne cible** (≈ 42, 37, 32 et 28 caractères) :
  l'utilisateur choisit une apparence, le moteur en déduit la taille réelle
  selon le format de la vidéo. C'est ce qui rend le même profil correct en 16:9
  comme en 9:16. Le profil enregistré continue de stocker une **valeur relative
  précise** : les tailles nommées sont une commodité d'interface, pas une
  contrainte du format de fichier — un profil réglé finement reste possible.
- **Polices : liste courte et sûre** (8 à 10 familles présentes sur tout Mac,
  choisies pour la lisibilité en sous-titre), affichées avec aperçu du rendu.
  Un choix « autre police du système » reste accessible, signalé comme risqué
  pour le partage. Motif : un profil partagé doit s'afficher **à l'identique**
  chez le destinataire ; une police absente casse cette promesse.
> ⚠︎ **Amendé le 27/08 — « Habiller » vit dans une barre d'action au bas de la
> fenêtre**, aligné à droite, hors de toute zone défilante. Il était en haut à
> droite, dans la barre des dépôts, où l'action finale se lisait comme un
> accessoire du dépôt. La colonne des réglages était exclue d'emblée : elle
> défile, et un bouton qui disparaît au défilement n'est plus une action. La
> convention macOS tranche pour le pied de fenêtre, et c'est la seule place qui
> tienne dans les trois états de l'écran. Chaque hauteur de fenêtre lui rend sa
> place (`Fenetre.hauteurBarreAction`) plutôt que de la prendre sur l'accueil ou
> sur l'aperçu ; le contrôle de disposition compare cette réserve à la hauteur
> réellement occupée. « Il n'y a rien à graver » descend avec le bouton : la
> phrase n'explique qu'un bouton grisé.

> ⚠︎ **Amendé le 27/08 — le choix d'image de fond s'appelle « Fond de
> l'aperçu ».** « Image de fond », puis « Image de la vidéo » : les deux ont été
> compris comme touchant à la vidéo qui sera gravée, et le paragraphe qui
> détrompait vivait au bas du volet, trop loin du menu pour être lu. Le contrôle
> se dit désormais lui-même — nom, réserve « n'affecte que l'aperçu, pas la vidéo
> exportée » **sur la même ligne** que le menu, et **chaque** entrée libellée
> (« 1/6 — le plus sombre » … « 6/6 — le plus clair »), là où seuls les deux
> extrêmes l'étaient et où les quatre du milieu restaient des numéros nus. Les
> qualificatifs intermédiaires viennent de la luminosité **mesurée**, non du
> rang : le libellé décrit l'image, pas sa place dans la liste. Du paragraphe
> supprimé ne survit que le conseil d'usage — regarder les deux extrêmes —, qui
> est le critère de contraste de ce même §2.

- **Interface en français uniquement.** L'anglais pourra s'ajouter plus tard
  sans refonte si l'app trouve un public au-delà — les textes seront donc
  centralisés dès le départ, pas dispersés dans les vues.

**Profil par défaut : neutre, NONP en préréglage.** Au premier lancement, l'app
n'applique **aucun logo** (l'utilisateur n'en a pas encore fourni) et un
habillage de sous-titres sobre et lisible : texte blanc, contour noir, bandeau
pleine largeur. L'habillage **NONP** est livré comme **préréglage sélectionnable**,
au même titre que d'autres. Motif : l'app s'adressant à tous, imposer le logo
d'une association à l'ouverture serait déroutant. Le dernier profil utilisé est
mémorisé — l'usage quotidien d'Éric n'est donc pas alourdi d'un clic.

**Profils** : enregistrer, charger, partager (`.json`). C'est le mécanisme qui
permet à une association de figer son habillage et de le diffuser à ses
bénévoles, qui obtiennent alors tous le même rendu.

### 3. Formats d'entrée : MP4, MOV, M4V

MKV et AVI sont **hors périmètre**. Un fichier refusé produit un message
explicite (« format non pris en charge par le moteur vidéo de macOS ») assorti
d'une marche à suivre — jamais un échec silencieux ni un plantage. Pas de remux
automatique : couverture partielle, échecs dépendants du codec, code de repli à
maintenir. À reconsidérer si l'usage réel le demande.

### 4. Bandeau des sous-titres : deux modes, pleine largeur par défaut

Le rendu actuel ajuste le bandeau à la longueur de **chaque ligne** : une ligne
courte produit une pastille étroite. Deux défauts, constatés à l'usage le 23/08 :
elle ne masque pas un sous-titre déjà incrusté dans la vidéo source, et la
largeur saute d'une réplique à l'autre.

- **Mode `pleine-largeur`** (défaut du profil neutre) : bande de largeur
  constante sur toute la vidéo, texte centré avec une marge intérieure réglable.
- **Mode `ajuste`** : comportement historique, conservé — c'est le rendu NONP
  actuel, et le préréglage « NONP » le garde pour ne rien changer à l'existant.
- **Hauteur stabilisable** : option de hauteur fixée à *n* lignes, pour que la
  bande ne saute pas entre une réplique d'une ligne et une réplique de deux.
- Marges et marge intérieure réglables dans les deux modes.

> ⚠︎ **Amendé le 26/08 — la marge intérieure n'est plus réglable dans
> l'interface.** Le champ `bandeau.marge_interieure_pct_largeur` reste au schéma,
> dans le profil et dans la géométrie, qui l'applique toujours : un fichier de
> profil rend exactement comme avant. Seul le curseur a quitté le volet
> Personnaliser. Mesure à l'appui, sur 16:9 1080p avec une cible de 32
> caractères : la marge doit atteindre **22,3 %** pour changer quoi que ce soit,
> soit **89 %** d'une course de 0 à 25 % sans le moindre effet — la longueur de
> ligne cible coupe le texte bien avant que la marge ne le touche. L'interface
> avait d'abord affiché un avertissement expliquant cette inertie ; s'excuser
> d'un réglage inutile ne vaut pas mieux que de le retirer. Le curseur pourra
> revenir au lot 6 si la **décision nº6** — qui gouverne la largeur de la colonne
> de texte — lui rend un effet.

> ⚠︎ **Amendé le 27/08 — la hauteur stabilisable se règle par une case à cocher,
> plus par un nombre de lignes.** « Lignes maximum : 2 » et « Hauteur constante :
> 2 lignes » affichaient le même chiffre et paraissaient faire double emploi ;
> ils ne le font pas — l'un borne le TEXTE, l'autre fige la HAUTEUR DU FOND —,
> mais l'interface ne le disait nulle part. Cochée, la case reprend la valeur de
> « Lignes maximum » et la suit ; c'est exactement ce que le schéma partagé
> recommandait déjà (« même valeur que lignes_max »). Une phrase sous la case
> nomme la valeur reprise, de sorte que les deux réglages se distinguent enfin.
> Comme pour la marge intérieure, **le champ `bandeau.hauteur_fixe_lignes` reste
> au schéma avec sa valeur libre de 0 à 4** : un profil qui dissocie les deux
> valeurs est lu, appliqué et rendu tel quel, et rien ne le réécrit tant qu'on ne
> clique pas. Les contrôles couvrent désormais toute la course du champ, y
> compris les valeurs qu'aucune commande ne sait plus choisir, et vont jusqu'aux
> pixels — un retrait d'interface est le genre de changement qui casse un champ
> en silence.

### 5. La mise en page s'adapte au format de la vidéo

**Défaut constaté le 23/08** (vidéo verticale 9:16, capture à l'appui). Le
prototype cale toutes ses tailles sur la **hauteur** : correct en 16:9, absurde
en vertical. Chaîne de causes, mesurée :

| Format | Taille police | Largeur utile | Capacité réelle | Limite appliquée | |
|---|---|---|---|---|---|
| 16:9 1080p | 78 px | 1804 px | 32 car. | 32 car. | ok |
| 9:16 vertical | **138 px** | 1016 px | **10 car.** | **16 car.** | **débordement** |

1. La police est dérivée de la hauteur : sur une vidéo verticale, la hauteur est
   la grande dimension → texte démesuré.
2. Le plancher `max(16, …)` impose 16 caractères par ligne alors que 10 seulement
   tiennent → les lignes débordent de la largeur utile.
3. libass **recoupe alors lui-même** les lignes trop longues, en dehors de toute
   logique de ponctuation : d'où les trois lignes en escalier et les bandeaux de
   largeurs inégales visibles sur la capture.

**Décision** : la taille du texte n'est plus dérivée d'une seule dimension. Elle
est contrainte par une **longueur de ligne cible**, exprimée en caractères et
conforme à l'usage du sous-titrage (**32 à 42 caractères**, jamais moins de 28).
Concrètement : la taille demandée par le profil est un **maximum** ; si la
largeur de la vidéo ne permet pas d'atteindre la longueur de ligne cible, la
taille est **réduite** — jamais le texte débordé.

> ⚠︎ **Amendé le 26/08** — voir « Amendement du 26/08 » à la fin de ce §5. La
> réduction décrite ci-dessus reste vraie, mais ce n'est qu'un **filet de
> sécurité** : elle ne fait pas de la longueur de ligne le réglage qui gouverne
> la taille. Ce sont deux réglages distincts.

Trois conséquences :

- **Aucun plancher qui contredise la géométrie.** Un conflit entre taille voulue
  et place disponible se résout en réduisant la taille, pas en laissant déborder.
- **Mesure exacte du texte par Core Text**, au lieu de l'estimation « 0,72 ×
  taille » du prototype — approximation grossière, cause directe du recoupage
  incontrôlé. La césure devient prévisible, et la ponctuation est respectée.
- **Marge basse relative au format** : en vertical, les plateformes affichent
  leur propre interface en bas de l'écran ; le profil neutre remonte donc les
  sous-titres sur les formats portrait.

Un même profil doit pouvoir servir en 16:9, 9:16, 1:1 et 4:5 sans retouche.
Cette exigence fait partie des tests de parité (lot 3).

#### Amendement du 26/08 — taille et longueur de ligne sont deux réglages distincts

**Ce que le texte ci-dessus laissait croire.** Que régler la longueur de ligne
cible suffisait à régler la taille du texte : la taille demandée n'étant qu'un
maximum, viser des lignes plus courtes devait donner un texte plus gros. Le lot 5
a mis quatre tailles nommées derrière cette idée — Petite, Normale, Grande, Très
grande — en ne posant que la longueur de ligne cible.

**Les quatre choix rendaient exactement le même texte** : 78 px dans les quatre
cas, sur une vidéo 16:9. Seule la césure bougeait. Aucun contrôle automatique ne
s'en est aperçu — les images comparées DIFFÉRAIENT bel et bien, puisque les
coupures de ligne changeaient. Il a fallu regarder l'écran.

**Pourquoi le couplage était faux.** Son arithmétique reposait sur l'estimation
« 0,72 × taille » du prototype — celle-là même que ce §5 condamne trois
paragraphes plus haut. Avec elle, une 16:9 1080p n'a de place que pour 32
caractères, et la contrainte mord dès qu'on vise plus court. Avec la **mesure
exacte de Core Text**, que ce §5 impose précisément, la place réelle est tout
autre :

| Taille nommée | Police | Place mesurée | Cible | Réduction |
|---|---|---|---|---|
| Petite | 58 px | 75 car. | 42 car. | aucune |
| Normale | 68 px | 64 car. | 37 car. | aucune |
| Grande | 78 px | 55 car. | 32 car. | aucune |
| Très grande | 91 px | 47 car. | 28 car. | aucune |

(16:9 1080p, Arial, profil neutre.) La place disponible vaut près du double de
la cible : en 16:9, la contrainte de largeur **ne mord jamais**. Le §5 se
corrigeait donc lui-même — en remplaçant l'estimation par la mesure, il retirait
au couplage la seule chose qui le faisait tenir.

**Décision.** Ce sont **deux réglages distincts**, et ils gouvernent deux choses
différentes :

- la **longueur de ligne cible** gouverne la **césure** — le rythme de lecture,
  l'endroit où les lignes se coupent. Elle reste bornée à [28, 42] ;
- la **taille de police** (`taille_pct_hauteur` du schéma) gouverne la **taille
  du texte**.

La **taille nommée de l'interface porte les deux** : chacune pose une cible ET un
ratio de taille — 5,4 %, 6,3 %, 7,2 % et 8,4 % de la hauteur. « Grande » vaut
exactement le **7,2 % du prototype**, pour que le préréglage NONP ne bouge pas
d'un pixel.

**Ce qui ne change pas.** La réduction reste, comme filet de sécurité, et elle
sert encore là où le défaut du 23/08 est né : en 9:16 1080×1920, « Grande »
demande 138 px et le moteur la ramène à **76 px** pour que la ligne tienne. C'est
bien le comportement voulu par ce §5 — simplement, ce n'est pas le mécanisme par
lequel on choisit une taille.

**Vérifié par** : `ControlesInterface`, rubrique « tailles nommées ». Les quatre
polices doivent être distinctes et croissantes, la place mesurée est reportée
format par format dans le rapport, et le contrôle échouerait si le couplage
redevenait vrai.

### 6. Le schéma de profils est commun aux deux implémentations

`profil-habillage.schema.json` est déjà écrit, éprouvé et **consommé par le
prototype Python**. L'app native lit **le même fichier**, sans traduction. Un
profil réglé aujourd'hui dans le prototype fonctionnera dans l'app native.

Les réglages de bandeau ci-dessus **ajoutent des champs**. L'amendement reste en
version **1** : aucun profil tiers ne circule encore, et les nouveaux champs
sont **facultatifs, avec des valeurs par défaut qui reproduisent le comportement
actuel** — un profil existant reste donc valide et rend à l'identique. Cette
fenêtre se referme dès la première diffusion publique : tout changement ultérieur
imposera `schema_version: 2` et une migration.

Amendement proposé : `_adr-20260823/profil-habillage.schema-v1-amende.json`.

## Invariants gravés

Ils ne sont pas négociables et doivent être vérifiés par des tests :

1. **Aucun mot des sous-titres n'est jamais modifié.** Ni correction, ni
   substitution, ni reformulation.
2. **La resegmentation reste confinée à l'incrustation.** `segment()` redécoupe
   les blocs longs et réaffecte les minutages **au prorata** ; les timecodes
   gravés diffèrent donc du SRT source. Ces timecodes ne sont **jamais**
   réinjectés dans un export SRT/VTT — l'app native n'exporte d'ailleurs aucun
   sous-titre.
3. **Aucune dépendance non-Apple.** Pas de second FFmpeg, pas de bibliothèque
   tierce. Licence cible **MPL-2.0**.
4. **Police manquante = erreur explicite.** Jamais de substitution silencieuse
   (libass le faisait ; Core Text ne doit pas le refaire sans le dire).
5. **Le prototype Python reste l'outil de production** tant que l'app native n'a
   pas prouvé un rendu équivalent sur des vidéos réelles.

## Architecture proposée

```
NONPHabillage/
  Models/       Profil (Codable, miroir exact du schéma v1) · Cue · MediaFile
  Engine/       SubtitleParser (SRT/VTT)      ← porté depuis le prototype
                Segmenter (resegmentation)    ← porté, invariant nº2
                LayoutEngine (ratios → points, mêmes formules)
                OverlayRenderer (Core Text + CALayer)
                VideoComposer (AVMutableVideoComposition + AVAssetExportSession)
  Views/        DropZone · PanneauPersonnaliser · Apercu · Progression
  State/        AppState · ProfilStore (charger/enregistrer/valider)
```

Les trois premières briques (`SubtitleParser`, `Segmenter`, `LayoutEngine`) sont
des **portages fidèles** de code déjà éprouvé : elles se testent par comparaison
directe avec le prototype, comme `test_iso_rendu.py` l'a fait pour les profils.

## Stratégie de vérification

- **Parité de découpage** : sur un corpus de SRT réels, les cues produites par
  le `Segmenter` Swift sont **identiques** à celles du `segment()` Python
  (comparaison automatisée, texte et minutages).
- **Parité de mise en page** : mêmes formules, mêmes minima ; les valeurs
  calculées sont comparées sur un balayage de résolutions.
- **Parité visuelle** : rendus côte à côte prototype / natif sur des vidéos de
  référence, en 1080p et 4K. Le rendu ne sera **pas** identique au pixel près
  (Core Text ≠ libass) — le critère est *indiscernable à l'usage*, validé par
  Éric, pas une égalité binaire.
- **Non-régression de fidélité** : test dédié vérifiant qu'aucun mot du SRT
  d'entrée n'est absent ou altéré dans les cues gravées.

## Effort estimé

| Lot | Contenu | Estimation |
|---|---|---|
| 1 | Socle : projet SwiftPM, dépôt, dépôt-modèle calqué sur Transcription | 0,5 j |
| 2 | Portage parseur + segmenteur + tests de parité avec le Python | 1 j |
| 3 | Rendu du texte (Core Text : contour, bandeau, lignes) | 1,5 j |
| 4 | Composition vidéo + export VideoToolbox + progression | 1,5 j |
| 5 | Interface : dépôt, bouton, volet Personnaliser, aperçu, logo à la souris, sélecteurs de couleur et de police | 2,5 j |
| 6 | Profils : lecture/écriture/validation, préréglages livrés, mémorisation du dernier profil | 1 j |
| 7 | Campagne de parité visuelle, corrections, build et checklist release | 1,5 j |
| | **Total** | **≈ 9,5 jours de travail effectif** |

À répartir sur plusieurs sessions. Les lots 1 à 4 produisent un outil utilisable
en ligne de commande avant toute interface : la valeur arrive tôt.

## Risques et atténuations

| Risque | Atténuation |
|---|---|
| Le rendu Core Text diffère visiblement de l'ASS (contour, interlettrage) | Lot 3 traité tôt et validé sur images fixes, avant tout travail d'interface |
| L'export AVFoundation dégrade la qualité ou perd l'audio | Réglages d'export explicites (passthrough audio, débit vidéo contrôlé), vérifiés au lot 4 |
| Périmètre qui s'étend (transitions, titres, musique) | Le présent ADR fixe le périmètre : logo + sous-titres. Tout ajout = nouvel ADR |
| Temps de traitement sur longues vidéos | Mesuré au lot 4 sur un fichier d'une heure ; VideoToolbox devrait battre libx264 |

## Alternatives écartées

- **Embarquer un FFmpeg complet** — contamination GPL, cascade de dépendances,
  rouvre le chantier licences. Écartée dès le 09/08.
- **Distribuer le prototype Python** — les trois obstacles du contexte.
- **Application web** — l'encodage vidéo côté serveur suppose un hébergement,
  des coûts et l'envoi de témoignages sensibles sur un serveur : contraire à la
  promesse de traitement local qui fait la valeur de NONP Transcription.
- **Intégrer à NONP Transcription en V1.3** — doublerait le périmètre d'un outil
  volontairement gelé, et exposerait la transcription aux pannes d'encodage.

## Tranché le 23/08

Public visé (tout public), deux usages de premier rang (logo seul compris),
app compagnon distincte, interface simple + volet repliable, profil par défaut
neutre avec NONP en préréglage, bandeau pleine largeur par défaut, liste de
polices sûres, interface en français, entrées MP4/MOV/M4V.

## Tranché le 24/08

**Décision nº1 — nom et identifiant.** Le nom définitif est **NONP Habillage**,
l'identifiant de bundle **`com.nonp.habillage`** (builds de test :
`com.nonp.habillage.test`). Le nom de travail devient le nom tout court : plus
aucune mention « provisoire » dans le code. Reste à produire l'**icône**, qui
n'a jamais dépendu du nom et suit sa propre échéance.

## Tranché le 26/08

**§5 amendé — taille et longueur de ligne sont deux réglages distincts.** Le
couplage des deux ne tenait que par l'imprécision de l'estimation « 0,72 ×
taille », que ce même §5 remplaçait par la mesure exacte. Détail, mesures et
conséquences : « Amendement du 26/08 » au §5.

**§4 amendé — la marge intérieure quitte l'interface, pas le schéma.** 89 % de
la course du curseur restaient sans effet ; le champ reste au profil et au rendu,
la commande disparaît du volet. Elle pourra revenir avec la décision nº6.

## Tranché le 27/08 — retour de test du lot 5

**§2 amendé — « Habiller » descend dans une barre d'action fixe au bas de la
fenêtre**, aligné à droite, hors de toute zone défilante.

**§2 amendé — « Image de la vidéo » devient « Fond de l'aperçu »**, chaque entrée
est libellée, et la réserve « n'affecte que l'aperçu » passe sur la ligne du menu.

**§4 amendé — « Hauteur constante » devient une case à cocher** qui reprend la
valeur de « Lignes maximum ». Le champ `hauteur_fixe_lignes` garde sa valeur
libre au schéma ; seule la commande disparaît, comme pour la marge intérieure.

## Décisions restant ouvertes

1. **Dépôt public dès le départ**, ou après une première version utilisable ?
   (La leçon du 12/08 : réécrire un historique coûte moins cher avant publication.)
2. **Icône** de l'application, à produire (`logo_circle.png` du prototype n'en
   est pas une). Son absence ne bloque rien : la build le signale et macOS
   affiche l'icône générique.
3. **Sortie HEVC** en plus de H.264 : fichiers plus légers, compatibilité moindre.
4. **Aperçu animé** (lecture avec habillage) : confortable, mais coûteux — à
   trancher au lot 5, l'aperçu sur image fixe étant le minimum retenu.
5. ~~**Amender le prototype Python** dès maintenant pour le bandeau pleine
   largeur (bénéfice immédiat sur l'outil de production), ou attendre l'app
   native ?~~ — **TRANCHÉE le 28/08/2026 : on n'amende pas.** Voir ci-dessous.
6. **Remplacer `espaces_lateraux` par une marge en % de la largeur** — constaté
   au lot 3, à trancher au lot 6. Voir ci-dessous.

### Décision nº5 — le prototype ne sera pas amendé (tranchée le 28/08/2026)

**Le constat qui force la décision.** Le lot 6 a fait relire par
`charger_profil()` des profils écrits par l'app. Le prototype refuse les trois
champs ajoutés au schéma le 23/08 — `bandeau.mode`,
`bandeau.hauteur_fixe_lignes`, `bandeau.marge_interieure_pct_largeur` — comme
champs inconnus : l'amendement avait été *proposé*, jamais appliqué. Un profil
« Neutre » exporté depuis l'app n'est donc pas lisible par le prototype.

**Décision d'Éric : l'asymétrie est assumée, le prototype reste intact.**

**Motif.** Le prototype prend sa retraite quand l'app native sera complète. Le
modifier reviendrait à toucher l'outil de production quotidien — celui qui fait
foi (invariant nº5) — pour un besoin transitoire. Le risque est du mauvais
côté : une régression y coûterait un travail réel, alors que le manque coûte, au
pire, un profil qu'on ne peut pas rendre avec l'ancien outil.

**Conséquences, toutes tenues :**

- l'asymétrie est **documentée** (`docs/divergences-prototype.md`, D-9) et
  **mesurée à chaque exécution** de `./Scripts/verifier.sh` ;
- le sens qui compte reste sans restriction : **tout profil du prototype est lu
  par l'app**, sans retouche ;
- l'app n'écrit un champ facultatif que s'il s'écarte de sa valeur par défaut,
  de sorte qu'un profil resté dans ce que le prototype sait rendre lui reste
  lisible ;
- **le panneau d'enregistrement le dit** quand un profil emploie un de ces
  champs : découvrir le refus au moment de s'en servir serait le pire moment.

### Décision nº6 — `espaces_lateraux`, un héritage de l'ASS inadapté au relatif

**Constat, lot 3.** `sous_titre.bandeau.espaces_lateraux` élargit le fond du
mode `ajuste` en collant *n* espaces durs `\h` de chaque côté du texte. C'est
un procédé d'ASS : faute de pouvoir dessiner un rectangle, libass n'avait que
le texte pour agir sur la boîte. L'unité qui en découle est la **largeur d'une
espace**, donc une fraction de la **taille de police** — elle-même dérivée de
la **hauteur** de la vidéo. Or ce que cette marge consomme, c'est de la
**largeur**. Le réglage est adossé à la mauvaise dimension : c'est le même
défaut de conception que celui corrigé au §5, à un autre endroit.

**Mesure** (Arial, profil NONP, `espaces_lateraux: 4`, donc 8 espaces au
total). À la taille que le profil demande, avant toute réduction :

| Format | Taille nominale | Largeur utile | Coût des 8 espaces | |
|---|---|---|---|---|
| 16:9 1080p | 78 px | 1804 px | 173 px — **9,6 %** | supportable |
| 9:16 1080×1920 | 138 px | 1016 px | 307 px — **30,2 %** | intenable |

Trois fois plus cher en vertical, pour un réglage que personne n'a modifié :
la vidéo est plus étroite alors que la police, dérivée de la hauteur, est plus
grande.

**Conséquence observée.** En 9:16, le moteur réduit la police jusqu'à ce que la
longueur de ligne cible tienne dans ce qui reste. Elle descend à **61 px** —
elle atteint bien ses 32 caractères, c'est justement pour les atteindre qu'elle
descend si bas, mais le texte est nettement plus petit qu'il n'aurait besoin de
l'être. Environ un cinquième de la largeur utile part en marge de fond.

**Piste.** Exprimer cette marge comme tout le reste du schéma : un pourcentage
de la largeur vidéo — `bandeau.marge_laterale_pct_largeur`, symétrique du
`marge_interieure_pct_largeur` déjà défini pour le mode `pleine-largeur`.
`espaces_lateraux` resterait **accepté en lecture** pour compatibilité, converti
à l'ouverture, et cesserait d'être écrit.

**À vérifier au moment de trancher**, car cela touche le contrat partagé
(invariant nº6) :

- le prototype Python consomme `espaces_lateraux` ; un profil écrit par l'app
  doit rester lisible par lui tant qu'il fait foi (invariant nº5) ;
- l'ajout doit rester **facultatif, avec une valeur par défaut qui reproduit le
  rendu actuel**, pour que le schéma reste en version 1 ;
- quelle valeur par défaut donne, en 16:9, un fond visuellement identique à
  celui d'aujourd'hui — c'est la condition pour que le préréglage NONP ne
  change pas.

**Hors périmètre du lot 3**, qui n'a touché à aucun profil : le rendu actuel
applique `espaces_lateraux` tel que le schéma le définit. Seule la façon de
l'appliquer a changé — c'est le rectangle qui s'élargit, plus le texte (voir
`docs/divergences-prototype.md`, D-4).
