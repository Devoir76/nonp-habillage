# Campagne de parité — prototype Python contre app native

L'invariant nº5 dit que le prototype fait foi **tant que l'app native n'a pas
prouvé un rendu équivalent sur vidéos réelles**. Ce fichier est la preuve en
cours de constitution : ce qui a été comparé, comment, ce qui en est ressorti,
et ce qui manque encore pour lever l'invariant.

Tenu depuis le lot 7. Rejouable par `./Scripts/campagne_parite.sh`.

---

## Le protocole

Une comparaison ne vaut que si la seule variable est le moteur. Le script
impose donc le reste :

- **le même profil**, et c'est celui du prototype en production
  (`profil-nonp-defaut.json`, schéma v1) — pas un préréglage de l'app, qui en
  serait une transcription, donc une source de divergence ;
- **le même logo**, résolu une fois et passé explicitement aux deux ;
- **le même fichier de sous-titres**, **la même vidéo source** ;
- **les mêmes timecodes** d'extraction — le milieu d'une réplique, pour que le
  texte soit affiché des deux côtés — et **le même extracteur**.

Le prototype est **lu, jamais écrit** (invariant nº5) : toutes ses sorties vont
dans le dossier de campagne.

## La moitié qui se mesure

Le découpage des répliques ne se juge pas à l'œil. Sur les 44 fichiers de
sous-titres réels du corpus :

| Ce qui est comparé | Résultat |
| --- | --- |
| répliques lues | 809, identiques |
| répliques gravées, texte et minutages | 1 567, identiques |
| contrôles du harnais, corpus et prototype compris | 831 réussis, aucun échec |

Cette moitié-là est close, et elle se rejoue à chaque exécution de
`./Scripts/verifier.sh --corpus <dossier> --prototype <nonp_habille.py>`.

## Ce que la comparaison d'images a trouvé

Deux défauts, et le second n'aurait pas pu sortir d'un banc d'essai.

**Le texte n'était pas gras.** Le prototype grave en gras — le champ `Bold` de
son style ASS vaut `-1`, en dur, pour les deux styles qu'il écrit — et l'app
gravait en romain. Aucun champ du profil ne porte cette graisse, et le registre
des divergences ne la mentionnait pas : c'était donc un bug, pas un choix, et
le plus visible de tous. Corrigé le 06/09.

La graisse déplace la mesure : un texte plus large tient en moins de
caractères, donc la taille qui atteint la longueur de ligne visée est plus
petite. **Les tailles annoncées à la décision nº6 avaient toutes été calculées
sur une romaine.**

| Format | Annoncé le 28/08 | Corrigé le 06/09 | Gain |
| --- | --- | --- | --- |
| 9:16 — 1080 × 1920 | 61 → 68 px | 57 → 63 px | +10 % |
| 1:1 — 1080 × 1080 | 63 → 68 px | 59 → 63 px | +6 % |
| 4:5 — 1080 × 1350 | 63 → 68 px | 58 → 63 px | +8 % |

Le gain mesuré n'a pas bougé d'un point : c'est la mesure qui était faite sur
la mauvaise graisse, pas le raisonnement qui était faux.

**Un montage vide en tête était compté comme de l'image.** Certains MP4 ouvrent
leurs pistes sur du rien : 80 ms et 66 ms sur les deux sources vierges du
06/09. L'écart se payait deux fois — le fichier produit sortait deux images
plus long que sa source là où le prototype rendait le même compte, et les
minutages des sous-titres, qui comptent depuis la première image, faisaient
paraître chaque réplique d'autant plus tôt qu'elle.

Le vide ne se lit nulle part simplement : `timeRange` d'une telle piste
commence à zéro et le compte dans sa durée. Il faut aller aux **segments**, où
il apparaît pour ce qu'il est. Trois pièces au correctif, et il fallait les
trois : borner la lecture à la première image, ouvrir la session d'écriture à
la même seconde, et chercher les sous-titres à l'instant diminué du vide. Seuls
les segments **de tête** sont retirés : un vide au milieu d'une piste est un
trou voulu, et le refermer raccourcirait la vidéo de quelqu'un.

**C'est l'argument de la campagne en une ligne.** Aucune vidéo d'essai ne
portait ce défaut, et le harnais ne sait pas en fabriquer une qui le porte :
`AVAssetExportSession` aplatit un montage vide en images noires, même en
passthrough. Il aura fallu deux fichiers rapportés d'un réseau social. Les
vidéos réelles portent ce que les bancs d'essai ne savent pas fabriquer.

## La moitié qui se juge

Le rendu ne sera pas identique au pixel près — Core Text n'est pas libass, et
ça n'a jamais été le critère. Le critère est *indiscernable à l'usage*, et
**c'est Éric qui tranche**, sur vidéos réelles, en 16:9 et en 9:16.

La question n'est d'ailleurs pas la même selon le format :

- **en 16:9**, c'est une question de parité — les deux images doivent se
  confondre ;
- **en 9:16 et en 1:1**, elles ne le doivent pas. Le prototype y impose un
  plancher de seize caractères par ligne que la largeur ne peut pas porter, et
  l'app réduit la taille pour tenir la ligne entière (divergence D-1, voulue).
  La question devient « est-ce mieux », pas « est-ce pareil ».

## Ce qui a été comparé le 06/09

| Vidéo | Format | Source vierge |
| --- | --- | --- |
| Combat | 16:9 — 1920 × 1080 | oui |
| Âne et chèvres | 9:16 — 360 × 638 | oui |
| Plateau de télévision | 16:9 — 1920 × 1080 | logo incrusté |
| Face caméra | 9:16 — 540 × 960 | oui |
| Format carré | 1:1 — 720 × 720 | logo et cartouche incrustés |

Le 16:9 vierge, qui manquait à la première passe, est arrivé le soir même. Les
trois sources non vierges gardent une zone de sous-titres nette : c'est le logo
qui ne s'y compare pas, puisque les deux moteurs posent le leur par-dessus un
autre.

## Ce qui manque pour lever l'invariant nº5

**Le jugement d'Éric.** Rien ne le remplace, et il n'a pas encore eu lieu. Les
cinq vidéos sont comparées, les deux formats qui comptent sont couverts par une
source vierge chacun, et les deux défauts trouvés sont corrigés.

Tant que ce jugement n'a pas eu lieu, **l'invariant nº5 tient** : le prototype
reste l'outil de production.

## Rejouer la campagne

```
./Scripts/campagne_parite.sh --sortie <dossier> \
    "<video.mp4>::<soustitres.srt>" ["<video>::<srt>" …]
```

Options : `--profil <fichier.json>` (défaut : celui du prototype),
`--prototype <nonp_habille.py>`, `--images <n>` (défaut : 6).

Chaque dossier produit contient `prototype.mp4`, `natif.mp4` et un dossier
`images/` où chaque instant existe des deux côtés, plus le plan nu — pour voir
sur quoi le texte se pose.

Le script a besoin d'un ffmpeg avec libass : c'est le moteur du prototype, et
il sert aussi à extraire les images **des deux côtés**, un extracteur par
moteur introduisant une différence qui n'est pas celle qu'on mesure.
L'invariant nº3 vise l'application, pas l'outillage qui fait tourner le
prototype.
