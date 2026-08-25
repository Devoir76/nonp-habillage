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

## Décisions restant ouvertes

1. **Dépôt public dès le départ**, ou après une première version utilisable ?
   (La leçon du 12/08 : réécrire un historique coûte moins cher avant publication.)
2. **Icône** de l'application, à produire (`logo_circle.png` du prototype n'en
   est pas une). Son absence ne bloque rien : la build le signale et macOS
   affiche l'icône générique.
3. **Sortie HEVC** en plus de H.264 : fichiers plus légers, compatibilité moindre.
4. **Aperçu animé** (lecture avec habillage) : confortable, mais coûteux — à
   trancher au lot 5, l'aperçu sur image fixe étant le minimum retenu.
5. **Amender le prototype Python** dès maintenant pour le bandeau pleine largeur
   (bénéfice immédiat sur l'outil de production), ou attendre l'app native ?
