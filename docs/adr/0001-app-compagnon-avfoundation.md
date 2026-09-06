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

> ⚠︎ **Rectifié le 06/09.** « AVI l'est mal » était optimiste sur le mauvais
> point : AVFoundation ouvre un AVI **sans difficulté** — vérifié. AVI reste
> hors périmètre, mais par décision, pas par impuissance. Voir « Tranché le
> 06/09 — ce qu'un refus doit dire ».

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
  Il ne contient **que des réglages** — importer, exporter et revenir aux
  réglages par défaut sont au menu Fichier (amendé le 28/08, voir plus bas).

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

> ⚠︎ **Amendé le 06/09 — le fichier produit, et le retour à l'accueil.** Trois
> retours d'usage sur exports réels, tous sur ce qui encadre l'export plutôt que
> sur le rendu lui-même. Le **nom proposé** vient désormais du fichier de
> sous-titres quand il y en a un, et de la vidéo sinon : une vidéo garde souvent
> le nom automatique de son téléchargement, quand le `.srt` porte un nom choisi
> — celui de la personne filmée. Le **suffixe** `_habillee` est confirmé, et sa
> neutralité devient une règle écrite, la même que pour les préréglages. Aucune
> sortie ne peut plus **remplacer un fichier d'entrée**, quel que soit le chemin
> saisi. Et « **Habiller une autre vidéo** » décharge la vidéo et ses
> sous-titres, en gardant les réglages et le logo. Détail ci-dessous, « Tranché
> le 06/09 ».

- **Interface en français uniquement.** L'anglais pourra s'ajouter plus tard
  sans refonte si l'app trouve un public au-delà — les textes seront donc
  centralisés dès le départ, pas dispersés dans les vues.

**Profil par défaut : neutre.** Au premier lancement, l'app n'applique **aucun
logo** (l'utilisateur n'en a pas encore fourni) et un habillage de sous-titres
sobre et lisible : texte blanc, contour noir, bandeau pleine largeur. Le dernier
profil utilisé est mémorisé — l'usage quotidien d'Éric n'est donc pas alourdi
d'un clic.

**Les préréglages livrés décrivent une APPARENCE, pas une organisation**
(amendé le 28/08/2026 — voir ci-dessous). Deux sont livrés : « Neutre » et
« Bandeau coloré ». L'habillage **NONP** est livré comme **fichier d'exemple**
(`Resources/profils-exemples/nonp.json`), à importer.

> ##### Amendement du 28/08 — « NONP en préréglage » ne tient plus
>
> La formulation du 23/08 livrait l'habillage NONP comme préréglage
> sélectionnable, « au même titre que d'autres ». Le motif tenait au logo :
> imposer celui d'une association à l'ouverture serait déroutant. Le motif était
> juste, la conclusion trop courte — **elle ne regardait que le logo, alors que
> c'est le bouton lui-même qui pose le problème.**
>
> Une application destinée au téléchargement public ne peut pas offrir, dans sa
> colonne de réglages, un bouton au nom d'une association. Le nom de
> l'application dit déjà son origine ; un préréglage qui la répète impose une
> identité visuelle à quelqu'un qui ne la connaît pas, et ne lui dit même pas ce
> qu'il choisit — « NONP » ne décrit aucune apparence.
>
> **Règle retenue** : un préréglage livré porte un nom qui décrit ce qu'il rend.
> « Bandeau coloré » remplace « NONP », **aux mêmes valeurs exactement** — ce
> sont toujours les constantes de `nonp_habille.py`, et le profil de référence
> des tests de parité n'a pas bougé d'une décimale.
>
> *(Dépassé le jour même par l'amendement suivant : il n'y a plus de préréglages
> du tout, et les deux apparences sont livrées comme fichiers d'exemple. La
> règle, elle, reste vraie de ce que l'application nomme.)*
>
> **Et l'habillage NONP y gagne sa vraie place.** Livré comme fichier
> d'exemple, il devient la démonstration de ce que le paragraphe « Profils »
> ci-dessous annonce : « le mécanisme qui permet à une association de figer son
> habillage et de le diffuser à ses bénévoles ». Un fichier qu'on s'échange le
> démontre ; un bouton câblé dans l'application ne le démontrait pas, il
> l'imposait. Le panneau « Importer… » s'ouvre sur le dossier des exemples.
>
> **Aucun profil enregistré n'est touché.** Le nom d'un profil mémorisé,
> importé ou exporté est une donnée de l'utilisateur : renommer un préréglage
> livré ne renomme rien chez personne, et les réglages en cours survivent au
> changement. Contrôlé.

**Profils** : enregistrer, charger, partager (`.json`). C'est le mécanisme qui
permet à une association de figer son habillage et de le diffuser à ses
bénévoles, qui obtiennent alors tous le même rendu.

> ##### Amendement du 28/08 — le profil n'est pas un élément du volet
>
> Le §2 décrivait les profils comme une pièce de l'interface, et le lot 5 leur
> avait donné une section en tête du volet Personnaliser : nom du profil courant,
> deux boutons de préréglage, Importer, Exporter.
>
> **C'était mettre en avant une notion bien au-delà de ce qu'elle sert.** La
> plupart des utilisateurs n'auront qu'un seul habillage, et la seule chose
> qu'ils en attendent est qu'il se retrouve d'une session à l'autre — ce que la
> mémorisation fait déjà, sans qu'on ait à nommer quoi que ce soit. Une section
> en tête de colonne demandait de comprendre un concept pour se servir de
> réglages qui n'en avaient pas besoin.
>
> **Ce que devient l'interface :**
>
> - **Le volet ne contient plus que des réglages.** Plus de section « Profil »,
>   plus de boutons de préréglage. « Neutre » est le point de départ à la
>   première ouverture ; ensuite ce sont les réglages mémorisés.
> - **Les trois gestes passent au menu Fichier** — « Importer un profil… »,
>   « Exporter le profil… », « Revenir aux réglages par défaut ». Ce sont des
>   gestes rares et délibérés, et le menu est fait pour ça : c'est la convention
>   macOS, et elle apporte des raccourcis clavier qu'un bouton perdu dans une
>   colonne défilante ne pouvait pas porter.
> - **Les apparences livrées deviennent des fichiers d'exemple**
>   (`Resources/profils-exemples/`), et le panneau d'import s'ouvre dessus. Un
>   préréglage qui n'est qu'un exemple n'a pas besoin d'un bouton : il a besoin
>   d'être trouvable.
>
> Le mécanisme de partage décrit ci-dessus n'est pas affaibli — il est rendu à
> sa forme naturelle. Un profil qui circule est un fichier ; il n'a jamais eu
> besoin d'une place dans la colonne des réglages.
>
> **Aucun profil enregistré n'est touché**, et c'est contrôlé : le fichier de
> mémoire garde sa forme, un profil relu s'applique tel quel, et rien ne se
> réinitialise tout seul — seule la commande « Revenir aux réglages par défaut »
> remplace les réglages, et elle garde le logo.

### 3. Formats d'entrée : MP4, MOV, M4V

MKV et AVI sont **hors périmètre**. Un fichier refusé produit un message
explicite (« format non pris en charge par le moteur vidéo de macOS ») assorti
d'une marche à suivre — jamais un échec silencieux ni un plantage. Pas de remux
automatique : couverture partielle, échecs dépendants du codec, code de repli à
maintenir. À reconsidérer si l'usage réel le demande.

> ⚠︎ **Amendé le 06/09 — le message nomme la cause, et le périmètre vaut pour
> les deux portes.** Voir « Tranché le 06/09 — ce qu'un refus doit dire ».

### 4. Bandeau des sous-titres : deux modes, pleine largeur par défaut

Le rendu actuel ajuste le bandeau à la longueur de **chaque ligne** : une ligne
courte produit une pastille étroite. Deux défauts, constatés à l'usage le 23/08 :
elle ne masque pas un sous-titre déjà incrusté dans la vidéo source, et la
largeur saute d'une réplique à l'autre.

- **Mode `pleine-largeur`** (défaut du profil neutre) : bande de largeur
  constante sur toute la vidéo, texte centré avec une marge intérieure réglable.
- **Mode `ajuste`** : comportement historique, conservé — c'est le rendu NONP
  actuel, et le préréglage « Bandeau coloré » le garde pour ne rien changer à
  l'existant.
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
exactement le **7,2 % du prototype**, pour que le préréglage « Bandeau coloré »
ne bouge pas
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
neutre (amendé le 28/08 : plus de préréglages du tout, le volet ne contient que
des réglages et les gestes de profil sont au menu Fichier), bandeau pleine
largeur par défaut, liste de polices sûres, interface en français, entrées
MP4/MOV/M4V.

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

## Tranché le 06/09 — retours d'usage du lot 6

Trois retours issus d'exports réels. Aucun ne porte sur le rendu : tous portent
sur ce qui l'entoure — le nom du fichier produit, et le retour à l'accueil.

**§2 amendé — le nom proposé vient du fichier de sous-titres.** Il venait de la
vidéo. Or une vidéo garde souvent le nom automatique que lui a donné son
téléchargement (« 21 Atelier ORVA reunion publique extrait complet sans
montage.mp4 ») quand le `.srt`, lui, porte un nom délibéré : celui de la personne
filmée (« Atelier ORVA Exemple.srt »). **Quand les deux diffèrent, le second est
presque toujours celui qu'on veut.** À défaut de sous-titres, la vidéo reprend
la main. Une supposition inexacte ne coûte rien : le champ du panneau
d'enregistrement reste libre, et il s'ouvre sur la proposition.

Le **dossier**, lui, reste celui de la vidéo. Le retour ne porte que sur le nom,
et le fichier de sous-titres vit souvent ailleurs que la vidéo : écrire dans son
dossier déplacerait la sortie sans que rien ne le dise.

**§2 amendé — le suffixe est neutre, et c'est une règle.** `_habillee` est
confirmé : il reprend le verbe du bouton, et s'écrit sans accent ni espace, un
nom qui traverse des dossiers partagés et des lignes de commande. Ce qui change
est qu'il **ne peut plus dériver** : un suffixe `_NONP` est exclu au même titre
qu'un préréglage « NONP » — rien, dans une application destinée au
téléchargement public, n'applique l'identité d'une association aux fichiers d'un
inconnu. C'est la règle de l'amendement du 28/08, étendue de ce que l'application
*nomme* à ce qu'elle *écrit*. Une seule constante la porte, et un contrôle la
tient.

**§2 amendé — une sortie ne peut jamais remplacer une entrée.** L'export efface
sa destination puis y déplace son résultat : pointée sur la vidéo source, cette
destination est l'original, et il n'existe nulle part ailleurs. Le nom proposé
ne tombe jamais dessus — le suffixe n'étant jamais vide, la base venue du `.srt`
est ramenée à celle de la vidéo dans le seul cas où elle s'y rejoindrait. Mais
le champ du panneau d'enregistrement est libre, et la ligne de commande prend
n'importe quel chemin. **Le refus est donc dans le moteur**, le seul point que
les deux traversent, et il compare les fichiers, pas les chaînes : un détour par
`..` ou un lien symbolique ne le contourne pas. Le fichier de sous-titres est
protégé de la même façon — c'est une entrée lui aussi.

**§2 amendé — « Habiller une autre vidéo » remet l'application à zéro.** Le
bouton de fin de course laissait la vidéo précédente chargée : il fallait
cliquer « Retirer » pour déposer la suivante, ce qui contredisait son libellé et
ajoutait deux gestes à chaque enchaînement — alors que les vidéos se traitent à
la chaîne. **Partent avec la vidéo : ses sous-titres.** Une autre vidéo appelle
un autre texte, et les garder ferait justement le rendu qu'on ne veut pas, celui
de la précédente sur l'image de la suivante. **Restent : les réglages et le
logo.** Ce sont l'habillage, pas le document ; ils ne changent pas d'une vidéo à
l'autre, et les redemander à chaque fichier viderait de son sens la mémorisation
du profil.

Le bouton « Retirer » de chaque zone de dépôt ne bouge pas : il sert à corriger
un dépôt, pas à enchaîner. Les deux gestes restent distincts.

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
6. ~~**Remplacer `espaces_lateraux` par une marge en % de la largeur** —
   constaté au lot 3, à trancher au lot 6.~~ — **TRANCHÉE le 28/08/2026 :
   option C, un champ unique et un schéma en version 2.** Voir ci-dessous.

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

### Décision nº6 — qui commande la largeur de la colonne de texte ?

**Instruite puis TRANCHÉE le 28/08/2026 (lot 6). Option C.** Les mesures qui
suivent ont été produites sur le code d'alors par une commande
`--mesures-decision6`, retirée après application — son sujet était la décision,
et la décision est prise. Les chiffres qui comptent encore sont repris par les
contrôles permanents : `ControlesRegressionV2` les refait à chaque exécution.

#### La décision

**Un champ unique commande la largeur de la colonne de texte, dans les deux
modes de bandeau : `sous_titre.bandeau.marge_texte_pct_largeur`, en pourcentage
de la LARGEUR vidéo, valeur par défaut 5,61 %.** `espaces_lateraux` et
`marge_interieure_pct_largeur` disparaissent. `longueur_ligne_cible` et
`logo.recadre_en_cercle` deviennent des champs. **Le schéma passe en version 2.**

**Motif d'Éric.** L'argument de compatibilité qui plaidait pour la v1 est caduc
depuis la décision nº5 : le prototype ne relit déjà plus les profils sortant du
préréglage « Bandeau coloré ». L'option B reconduirait le désordre qu'on cherche
à finir, avec
deux champs décrivant la même chose « pendant la transition ». Et le coût d'une
v2 est presque nul maintenant : aucun profil ne circule, rien n'est publié.
C'est la fenêtre repérée le 23/08, et elle se referme à la première diffusion
publique.

**Ce que la taille nommée devient.** Pas un champ, et c'est délibéré : elle est
entièrement déterminée par `taille_pct_hauteur` et `longueur_ligne_cible`, tous
deux au fichier. Un champ de plus permettrait à un profil de se contredire —
« Grande » avec une taille de 5 %. Elle reste ce qu'Éric en a dit : une
commodité d'interface qui écrit ces deux valeurs.

**Ce que le recadrage rond devient.** Un champ, `logo.recadre_en_cercle`. Il
change ce qui est GRAVÉ : deux profils qui n'en diffèrent que par lui rendent
différemment. Laissé hors du fichier, un profil partagé donnait un logo carré
chez le destinataire sans que rien ne le dise — exactement ce que le schéma
existe pour empêcher. L'argument contraire — le prototype en faisait une
propriété du fichier, via `--make-logo` — décrit un outil qui fabriquait une
image ; l'app, elle, laisse le fichier intact et applique le cercle au rendu.
C'est donc une instruction de rendu, et les instructions de rendu sont le profil.

#### Non-régression, mesurée

**Le texte ne bouge à aucune définition 16:9.** Même taille de police, mêmes
coupures, sur les **1 567 répliques gravées du corpus réel**, à cinq
définitions — 1024×576, 1280×720, 1920×1080, 2560×1440, 3840×2160.

**Le rendu, au pixel.** Sur 1024, 1280 et 1920, **aucun pixel ne bouge**. Sur
2560 et 3840, le bord du bandeau se déplace de 1,4 px au plus : 1 180 pixels
touchés sur 3,7 millions (0,032 %) en 1440p, 1 768 sur 8,3 millions (0,021 %) en
2160p. Le contrôle est vérifié SENSIBLE — un seul pixel de retrait en plus, et
il le voit.

**Pourquoi cet écart, et pourquoi il n'était pas évitable.** La mesure a appris
quelque chose qui n'était pas prévu : **le débord de la v1 n'était pas
proportionnel à la largeur.** Il empruntait au `padding_pct_hauteur`, arrondi au
pixel sur la HAUTEUR. 1080 × 1,9 % arrondit à 21 px (1,944 % de la hauteur),
1440 × 1,9 % arrondit à 27 (1,875 %). Le débord valait donc 5,609 % de la
largeur sur une 1080p et 5,569 % sur une 1440p : **la v1 dérivait avec la
définition, sur un format pourtant identique**, jusqu'à 1,0 px d'écart à sa
propre proportion. Aucun pourcentage unique ne peut donc retomber sur elle
partout — rester à un demi-pixel sur une 1440p demanderait entre 5,551 et
5,590 %, et sur une 1080p entre 5,583 et 5,635 % : les intervalles ne se
recoupent pas. 5,61 % est exact aux définitions où le profil a été réglé, et
la v2, elle, ne dérive plus.

**Le gain en vertical, consigné.** Profil NONP :

| format | v1 | v2 |
|---|---|---|
| 9:16 1080×1920 | 61 px | **68 px** (+11 %) |
| 1:1 1080×1080 | 63 px | **68 px** (+7 %) |
| 4:5 1080×1350 | 63 px | **68 px** (+7 %) |

#### La correspondance arithmétique, pour un lecteur venu de la v1

- **mode `pleine-largeur`** : `marge_texte_pct_largeur = marge_interieure_pct_largeur`.
  Exact, sans condition — les deux étaient déjà des pourcentages de largeur.
- **mode `ajuste`** :
  `marge_texte_pct_largeur = 100 × (padding_px + espaces_lateraux × largeur_d_une_espace) / largeur_vidéo`,
  calculé sur le format de référence **16:9 1920×1080**, avec la **police du
  profil**. Pour NONP : `100 × (21 + 86,7) / 1920 = 5,61`.

Un format de référence est nécessaire, et c'est tout le dossier : la v1
exprimait ce retrait en largeurs d'espace, donc en fraction de la taille de
police, donc de la hauteur. Le convertir en fraction de la largeur n'a de sens
qu'à un format donné.

**Le seul refus de conversion** est la police absente : mesurer une espace exige
la police du profil, et la mesurer dans une autre donnerait un retrait faux —
l'invariant nº4 interdit toute substitution silencieuse. Le message le dit et
propose d'installer la police. Partout ailleurs la conversion est automatique,
et **elle est annoncée** : une conversion silencieuse est une modification
silencieuse.

#### Ce qui a mené là — la mesure, avant la décision

##### Le constat de départ (lot 3)

`sous_titre.bandeau.espaces_lateraux` élargit le fond du mode `ajuste` en
collant *n* espaces durs de chaque côté du texte. C'est un procédé d'ASS : faute
de pouvoir dessiner un rectangle, libass n'avait que le texte pour agir sur la
boîte. L'unité qui en découle est la **largeur d'une espace**, donc une fraction
de la **taille de police**, elle-même dérivée de la **hauteur** de la vidéo. Or
ce que cette marge consomme, c'est de la **largeur**. Le réglage est adossé à la
mauvaise dimension — même défaut de conception que celui corrigé au §5, à un
autre endroit.

##### Ce que la mesure ajoute au constat

Quatre réglages prétendent gouverner la largeur de la colonne de texte :

| réglage | unité | mode concerné | au schéma ? |
|---|---|---|---|
| `sous_titre.marge_laterale_pct_largeur` | % de la largeur | `ajuste` seul | oui |
| `bandeau.espaces_lateraux` | largeur d'espace (→ hauteur) | `ajuste` | oui |
| `bandeau.marge_interieure_pct_largeur` | % de la largeur | `pleine-largeur` | oui |
| `longueurLigneCible` | caractères | les deux | **non** |

**Premier résultat — la longueur de ligne cible les bat tous les trois.** En
16:9 1080p, profil NONP, en balayant chaque réglage sur toute sa course et en
comptant les IMAGES distinctes (taille de police appliquée et endroits de
césure — pas la capacité de ligne, nombre intermédiaire qui bouge sans que rien
ne change à l'écran) :

| réglage, course entière | 16:9 1080p | 9:16 1080×1920 |
|---|---|---|
| `espaces_lateraux` 0 → 12 | **aucun effet**, 1 image | 13 images, effet dès 1 |
| `marge_interieure` 0 → 25 % | 7 images, 1er effet à **23,2 %** | 37 images, 1er effet à 3,5 % |
| `marge_laterale` 0 → 20 %, `ajuste` | 7 images, 1er effet à **17,9 %** | 28 images, 1er effet à 1,4 % |
| `marge_laterale` 0 → 20 %, `pleine-largeur` | **aucun effet** | 29 images, 1er effet à 3,5 % |
| `longueurLigneCible` 28 → 42 | 5 images, effet dès 29 | **15 images sur 15** |

En 16:9 — le format de référence — `espaces_lateraux` ne produit **aucun effet
visible sur la totalité de sa course**, et les deux marges n'en produisent que
dans leur dernier dixième. Une seule commande agit partout : la longueur de
ligne cible, celle qui n'a pas de champ au schéma.

La raison est mécanique. La taille demandée n'est réduite que si la capacité de
ligne n'atteint pas la cible. En 16:9 elle l'atteint largement — 49 caractères
pour 32 visés — et tant qu'elle l'atteint, retirer de la largeur ne change
rien. En 9:16 la police, dérivée de la hauteur, vaut 138 px demandés : la cible
n'est jamais atteinte, la taille est réduite à 61 px, et **chaque pixel de
largeur repris se lit sur la taille du texte**.

Corrigé au passage : la mesure du lot 5 concluait que 89 % de la course de la
marge intérieure était inerte. Elle ne regardait que la largeur de découpe. En
regardant l'image, le chiffre exact est **93 % en 16:9** (premier effet à
23,2 % sur 25) — et **14 % en 9:16**. Le réglage n'est pas inutile : il est
inutile *sur un seul format*.

**Deuxième résultat — le coût de l'unité mal choisie, chiffré.** Débord du fond
en mode `ajuste`, profil NONP, décomposé en `padding + 4 × largeur d'espace` :

| format | taille | padding | 4 × espace | côté | % de la largeur |
|---|---|---|---|---|---|
| 16:9 1920×1080 | 78 px | 21 px | 87 px | 108 px | **5,61 %** |
| 9:16 1080×1920 | 61 px | 36 px | 68 px | 104 px | **9,61 %** |
| 1:1 1080×1080 | 63 px | 21 px | 70 px | 91 px | 8,43 % |
| 4:5 1080×1350 | 63 px | 26 px | 70 px | 96 px | 8,89 % |

Le même réglage coûte **5,61 % de la largeur en 16:9 et 9,61 % en 9:16**.

**Troisième résultat — la question posée au lot 3 a une réponse.** « Quelle
valeur par défaut donne, en 16:9, un fond visuellement identique ? » →
**5,61 % de la largeur.** Et voici ce que ce défaut donnerait ailleurs :

| format | côté aujourd'hui | côté à 5,61 % | taille aujourd'hui | taille alors |
|---|---|---|---|---|
| 16:9 1920×1080 | 108 px | 108 px | 78 px | 78 px — inchangé |
| 9:16 1080×1920 | 104 px | 61 px | 61 px | **68 px** |
| 1:1 1080×1080 | 91 px | 61 px | 63 px | **68 px** |
| 4:5 1080×1350 | 96 px | 61 px | 63 px | **68 px** |

Le 16:9 ne bouge pas — c'est la condition. Les formats étroits récupèrent la
largeur que l'unité « largeur d'espace » leur prenait, et la police y remonte
de 11 %.

##### Les deux réglages sans champ

**`longueurLigneCible`.** Le lot 6 lui a donné une règle provisoire : elle se
DÉDUIT de `taille_pct_hauteur` par la table des quatre tailles nommées. Ne rien
déduire laissait un profil importé porter la police du fichier et la longueur de
ligne de la session précédente — deux réglages qui ne se sont jamais rencontrés.
Ce que la déduction coûte, mesuré en 16:9 1080p :

| `taille_pct` | taille nommée déduite | cible posée | capacité réelle | écart |
|---|---|---|---|---|
| 4,2 % | Petite | 42 | 90 | +48 |
| 6,0 % | Normale | 37 | 60 | +23 |
| 7,2 % | Grande | 32 | 49 | +17 |
| 9,0 % | Très grande | 28 | 39 | +11 |

L'écart est toujours positif : en 16:9 la cible est atteinte de très loin, donc
la déduction ne fait aucun mal — quelle que soit la valeur déduite, le rendu est
le même. **C'est en 9:16 qu'elle décide de tout**, puisque la cible y commande la
taille. Un profil venu du prototype, qui n'a jamais entendu parler de longueur de
ligne, y reçoit donc une cible que personne n'a choisie.

**`logo.recadre_en_cercle`.** Il vit dans `reglages_app` de la mémoire locale et
**ne part pas** avec un profil partagé : le destinataire obtient un logo carré là
où l'expéditeur voyait un rond, et rien ne le dit. À noter, parce que cela
oriente : le prototype en faisait une propriété du **fichier** (`--make-logo`
fabriquait une image ronde à côté), jamais du profil. L'app en a fait un réglage
réversible (lot 5, D-8) — c'est ce changement, et non un oubli, qui crée le
besoin d'un champ.

##### Les trois options soumises à Éric

**Option A — ne rien ajouter au schéma.**

- *Rendu* : inchangé partout, aujourd'hui comme demain.
- *Prototype* : compatibilité maximale — l'app n'écrit rien de neuf, et le
  tableau de D-9 ne s'allonge pas.
- *Schéma v1* : trivialement tenu.
- *Ce que cela laisse* : `espaces_lateraux` reste adossé à la hauteur, et les
  formats verticaux gardent une police 11 % plus petite qu'elle n'aurait besoin
  d'être. La longueur de ligne cible reste déduite, donc un profil partagé ne
  porte pas la cible que son auteur a choisie. Le recadrage rond ne voyage pas.

**Option B — trois champs facultatifs, schéma toujours en version 1.**

`bandeau.marge_laterale_pct_largeur`, `sous_titre.longueur_ligne_cible`,
`logo.recadre_en_cercle`. La règle de la v1 s'applique à chacun : **absent =
comportement d'aujourd'hui.** Donc `marge_laterale_pct_largeur` absente ⇒ on
retombe sur `espaces_lateraux` ; `longueur_ligne_cible` absente ⇒ on la déduit
comme aujourd'hui ; `recadre_en_cercle` absent ⇒ faux.

- *Rendu* : strictement inchangé tant que les champs ne sont pas écrits. Un
  profil qui les écrit rend mieux en vertical (+11 % de taille) et porte enfin sa
  cible et son rond.
- *Prototype* : chaque champ écrit rend le profil illisible pour lui. D-9
  s'allonge de trois lignes. Assumé par la décision nº5.
- *Schéma v1* : tenable, mais au prix d'une **double commande** pendant toute la
  transition — `espaces_lateraux` et la nouvelle marge décrivent la même chose,
  et il faut dire lequel gagne. C'est exactement le désordre que la question
  cherchait à finir.

**Option C — un seul champ commande la colonne, schéma en version 2.**

`sous_titre.largeur_colonne_pct_largeur` : la largeur de la colonne de texte, en
pourcentage de la largeur vidéo, **quel que soit le mode de bandeau**. Elle
remplace à l'écriture `espaces_lateraux` et `marge_interieure_pct_largeur`, tous
deux conservés **en lecture** et convertis à l'ouverture.
`longueur_ligne_cible` et `recadre_en_cercle` entrent avec elle.

- *Rendu* : identique si la conversion est exacte — c'est à vérifier format par
  format, et c'est le vrai travail de cette option. Le passage de
  `espaces_lateraux: 4` à 5,61 % de largeur laisse le 16:9 au pixel près (mesuré
  ci-dessus) ; les autres formats changent, dans le sens voulu.
- *Prototype* : un profil écrit par l'app lui devient **systématiquement**
  illisible, plus seulement quand il emploie le bandeau pleine largeur. C'est le
  coût le plus lourd — et le moins grave depuis la décision nº5 : le prototype
  part à la retraite, et le sens qui compte (ses profils lus par l'app) reste
  intact.
- *Schéma* : **v2**. Prétendre le contraire serait un mensonge de forme — l'app
  écrirait toujours le nouveau champ, donc l'absence ne serait plus jamais le cas
  courant. Une v2 assumée coûte une migration (v1 → v2 à la lecture), qui est
  simple ici puisque la conversion est arithmétique.

##### Ce que la mesure retenait

Le désordre n'est pas dans le nombre de réglages : il est dans le fait que
**trois d'entre eux sont muets sur le format de référence** et que le seul qui
parle partout n'est pas au fichier. Une décision qui ne ferait qu'ajouter des
champs sans dire qui commande laisserait ce défaut intact. C'est ce qui a écarté
l'option B.

**Hors périmètre du lot 3**, qui n'a touché à aucun profil : le rendu actuel
applique `espaces_lateraux` tel que le schéma le définit. Seule la façon de
l'appliquer a changé — c'est le rectangle qui s'élargit, plus le texte (voir
`docs/divergences-prototype.md`, D-4).

## Tranché le 06/09 — ce qu'un refus doit dire

Une enquête partie d'un contrôle en échec, et qui a trouvé deux défauts sans
rapport avec ce qu'elle cherchait.

### Le message nommait la mauvaise cause

**Ce qui a été vérifié.** Le soupçon portait sur l'interopérabilité : si
l'application ne relisait pas les vidéos produites par le prototype, c'est toute
la bibliothèque existante qui lui échappait. Elle les relit. Le fichier mis en
cause — un MP4 H.264/AAC sorti du prototype — s'ouvre sans réserve : `isPlayable`
vrai, une piste `avc1` en 1920×1080 à 30 im/s, une piste `mp4a`, 105,0 s de
durée, et un export complet avec l'audio recopié sans réencodage.

**Le vrai défaut était dans le message.** Toute erreur de chargement sortait sous
un seul texte : « format non pris en charge […] convertissez la vidéo ». Quatre
causes reproduites, quatre fois le même message, faux dans trois cas :

| Ce qui se passait vraiment | Ce que l'application annonçait |
| --- | --- |
| le fichier n'est plus là | format non pris en charge |
| macOS refuse l'accès au fichier | format non pris en charge |
| un dossier a été déposé | format non pris en charge |
| le fichier est tronqué | format non pris en charge |

Dans une application destinée au public, **un message qui nomme la mauvaise
cause est un défaut à part entière** : l'utilisateur part convertir un fichier
qui n'a aucun problème de format, et le vrai problème reste entier. Le §3
exigeait « une marche à suivre » ; il faut lire aussi qu'elle doit mener quelque
part.

**Pourquoi le diagnostic ne peut pas venir d'AVFoundation seule.** Ses codes ne
distinguent pas ce qui compte. À `loadTracks`, sur macOS 15 : un fichier
introuvable ressort en `−11800` « erreur inconnue », un dossier en `−11828`
« format not supported », un fichier de zéro octet en `−11828` lui aussi. L'état
du **fichier**, lui, est sans ambiguïté. Le diagnostic interroge donc le disque
d'abord — existe, est un fichier, est lisible, n'est pas vide — puis le code
d'AVFoundation pour ce que le disque ne dit pas : `−11828` reste un problème de
format, `−11829` un contenu illisible, `NSCocoaErrorDomain 257` un problème de
droits. Faute de mieux, la raison rendue par macOS est **citée telle quelle** :
une raison technique vaut mieux qu'une cause inventée.

Le diagnostic ne tourne qu'**après** un échec — un chargement qui réussit ne paie
rien — et il sert les deux portes d'entrée. Le conseil de conversion est réservé
au seul cas où il aide, et un contrôle le tient.

### Le périmètre annoncé n'était pas le périmètre appliqué

Second écart, trouvé en chemin. La zone de dépôt refusait MKV et AVI ; la ligne
de commande les passait au moteur, **et un AVI y aboutissait**. AVFoundation le
lit sans difficulté — contrairement à ce qu'affirmait le commentaire du code, et
à ce que laisse entendre « AVI l'est mal » plus haut. L'application avait donc
deux périmètres : celui qu'elle annonce, et celui qu'une autre porte accepte.

Ce qu'AVFoundation **sait** lire et ce que l'application **accepte** sont deux
questions distinctes. La seconde est une décision d'architecture : trois
conteneurs éprouvés plutôt qu'une couverture partielle dépendante du codec —
c'est déjà l'argument du §3 contre le remux. Elle vit désormais en un seul
endroit, que les deux portes lisent.

Le refus se prononce sur l'**extension**, avant tout chargement : c'est la règle
que l'utilisateur voit déjà — le sélecteur de fichiers grise les autres
extensions — et refuser un conteneur après cinq minutes de gravure serait
inutilement cruel. Un fichier sans extension du tout reçoit un autre conseil :
le renommer, pas le convertir. Il est peut-être un MP4 valide.

## Tranché le 06/09 — le fond de l'aperçu s'efface encore

Le réglage a déjà maigri une fois : ses deux phrases d'escorte — la réserve
« n'affecte que l'aperçu » et le conseil de contraste — ont quitté la ligne
pour l'infobulle du menu. Il restait le nom, « Fond de l'aperçu », affiché en
permanence à gauche d'un menu de 210 points.

**Le nom part à son tour, par le même raisonnement.** Dans un volet dont la
valeur est l'image, un réglage dont l'ÉTAT se lit seul n'a pas besoin d'être
annoncé en permanence : « 3/6 — moyen » dit le rang, donc qu'il y a six choix,
et le qualificatif, donc lequel on regarde. Le nom ne servait qu'à la première
rencontre — c'est exactement ce que porte une infobulle. Il y rejoint les deux
phrases, entier, mot pour mot.

Ce qui l'autorisait tient en une condition, et elle est tenue par un contrôle :
**chaque libellé du menu se lit sans son nom**. C'est la même condition qui
avait autorisé le premier allègement. Si elle tombait — un libellé redevenu
« 3/6 » nu —, le nom devrait revenir sur la ligne.

Le menu passe en petite taille et à sa largeur naturelle. **La ligne entière
réclame désormais 161 points**, contre la largeur minimale du volet qui en fait
528 : elle ne contraint plus rien.

Rien n'est perdu pour VoiceOver, qui ne survole pas : le nom reste l'étiquette
d'accessibilité du menu.
