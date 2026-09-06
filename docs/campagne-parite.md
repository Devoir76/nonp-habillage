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

## Ce qui manque pour lever l'invariant nº5

1. **Le jugement d'Éric**, sur les trois formats déjà comparés. Rien ne le
   remplace, et il n'a pas encore eu lieu.
2. **Des sources vierges.** Sur les trois vidéos comparées le 06/09, une seule
   l'est — la verticale. Les deux autres sont des vidéos déjà habillées dont le
   suffixe a disparu : elles portent un logo incrusté sous celui que les deux
   moteurs posent. La zone des sous-titres reste nette sur les trois, mais **le
   logo ne se compare vraiment qu'en 9:16**.
3. **Un 16:9 vierge**, qui n'existe pas sur la machine de travail. C'est le
   format le plus courant, et celui où la parité est attendue stricte.

Tant que ces trois points ne sont pas réglés, **l'invariant nº5 tient** : le
prototype reste l'outil de production.

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
