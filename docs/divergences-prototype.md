# Divergences assumées avec le prototype Python

Le prototype `nonp_habille.py` reste l'outil de production (invariant nº5) et
fait foi tant que l'app native n'a pas prouvé un rendu équivalent. Le portage
est donc **fidèle par défaut** : quand rien n'est écrit ici, le code Swift
reproduit le comportement Python au caractère près, et les contrôles de parité
le vérifient à chaque exécution.

Ce fichier est le registre du reste : chaque endroit où le comportement diffère
**volontairement**. Une divergence qui n'y figure pas est un bug, pas un choix.

Registre tenu depuis le lot 2. Vérifiable par `./Scripts/verifier.sh`.

---

## D-1 — La longueur de ligne cible pilote la taille (lot 2)

**Origine** : ADR-0001 §5, défaut constaté le 23/08 sur une vidéo verticale.

**Ce que fait le prototype**

```python
size     = max(12, round(h * ratio))
maxchars = max(16, int((w - 2*marge) / (size * 0.72)))
```

La taille dérive de la seule **hauteur**, puis un plancher impose 16 caractères
par ligne quelle que soit la largeur disponible.

**Ce que fait l'app native**

La taille demandée par le profil devient un **maximum**. Une longueur de ligne
cible (32 caractères par défaut ; jamais moins de 28) la contraint : si la
largeur ne permet pas de l'atteindre, c'est la **taille** qui est réduite.
Aucun plancher ne contredit plus la géométrie.

**Où la divergence se manifeste**

| Format | Prototype | App native | |
|---|---|---|---|
| 16:9 1080p | 78 px, 32 car. | 78 px, 32 car. | **identique** |
| 9:16 1080×1920 | 138 px, 16 car. imposés, **10 tiennent** | 44 px, 32 car. | divergent |
| 1:1, 4:5 | plancher actif | capacité tenable | divergent |

En 16:9 la capacité géométrique atteint déjà la cible : rien n'est réduit, et la
parité est **intacte** — c'est ce que mesure le contrôle de parité sur corpus
réel. La divergence n'apparaît que là où le prototype débordait.

**Pourquoi** : sur une vidéo verticale, le plancher réclamait plus de caractères
que la largeur n'en peut porter. libass recoupait alors les lignes lui-même,
hors de toute logique de ponctuation — d'où les lignes en escalier et les
bandeaux de largeurs inégales constatés le 23/08.

**Vérifié par** : `ControlesMiseEnPage`, rubriques « 9:16, divergence voulue »,
« un même profil sur quatre formats » et « la géométrie prime sur le plancher ».
Cette dernière balaie 1 513 résolutions de 320×240 à 3840×2160 : aucune ne
produit une capacité intenable côté Swift, 325 en produisent côté prototype.

**Encore approximatif** : la largeur du texte est estimée par le facteur
« 0,72 × taille » du prototype. L'ADR §5 la condamne et prévoit la mesure exacte
par Core Text au lot 3. Elle entre par le protocole `MesureurLargeur`, sans
toucher au reste du calcul. La parité, elle, continuera de se mesurer avec
l'estimation historique — la seule que le Python connaisse.

---

## D-2 — Un minutage illisible produit une erreur, pas une trace Python (lot 2)

**Ce que fait le prototype** : `_ms()` applique `.groups()` au résultat d'une
recherche qui peut être `None`. Sur une ligne « --> » sans minutage
reconnaissable, l'outil s'arrête sur une `AttributeError` — un message
incompréhensible pour qui n'écrit pas de Python, et qui ne dit pas quel bloc est
en cause.

**Ce que fait l'app native** : elle lève `ErreurSousTitres.timecodeIllisible`,
formulée en français par `Textes.SousTitres`, avec le **numéro du bloc fautif**
et un exemple de la forme attendue.

**Portée** : nulle sur les entrées valides. Les deux implémentations produisent
exactement les mêmes cues partout où le prototype ne plantait pas — la
divergence ne concerne que le cas où il s'arrêtait.

**Vérifié par** : `ControlesParseur`, rubrique « cas limites ».

---

## D-3 — La césure suit la largeur mesurée, pas un nombre de caractères (lot 3)

**Origine** : ADR-0001 §5, « Mesure exacte du texte par Core Text, au lieu de
l'estimation *0,72 × taille* du prototype — approximation grossière, cause
directe du recoupage incontrôlé. »

**Ce que fait le prototype** : `wrap()` compare un nombre de CARACTÈRES à une
limite. Toutes les lettres y valent pareil : un `l` compte comme un `W`.
Mesuré sur Arial 78 px, l'écart est brutal — « lililililil » fait 217 px,
« WMWMWMWMWMW » en fait 866, pour le même nombre de caractères. Une réplique en
capitales dépassait donc la largeur utile sans que le calcul s'en aperçoive, et
libass la recoupait lui-même, hors de toute logique de ponctuation.

**Ce que fait l'app native** : la césure retient **deux** conditions, et il
faut les deux.

1. **La longueur de ligne cible, en caractères** (32 par défaut) — c'est le
   rythme de lecture, et c'est exactement la règle du prototype. La conserver,
   c'est garder la césure aux mêmes endroits sur du texte ordinaire : le
   préréglage NONP ne doit rien changer à l'existant.
2. **La largeur mesurée par Core Text** — le filet de sécurité, et ce que le
   prototype n'avait pas. Quand 32 caractères ne TIENNENT pas, la ligne se
   coupe plus tôt au lieu de déborder et de se faire recouper par libass hors
   de toute ponctuation.

Chacune seule serait fausse. La première seule rouvrirait le défaut du 23/08.
La seconde seule laisserait filer les lignes jusqu'à **55 caractères** sur une
vidéo 16:9 — la mesure exacte est bien plus généreuse que l'estimation à 0,72 —
soit deux fois la densité du rendu actuel.

**L'algorithme, lui, ne change pas.** `Segmenteur.envelopper` prend désormais
un critère de tenue de ligne en paramètre : le remplissage, la coupure à la
ponctuation, le refus des fragments orphelins sont exactement ceux du
prototype. Seul le critère diffère — nombre de caractères pour la parité,
largeur mesurée pour le rendu. Écrire deux fois le remplissage aurait laissé
les deux versions diverger en silence, et la parité n'aurait plus rien prouvé
du code réellement employé au rendu.

**Portée** : la parité du lot 2 se mesure toujours avec le critère par
caractères — le seul que le Python connaisse — et reste intacte, 234 contrôles
au vert.

**Vérifié par** : `ControlesRendu`, rubriques « mesure exacte plutôt
qu'estimation » et « aucune ligne ne déborde, quel que soit le format » — deux
profils × cinq formats, sur le corpus réel, avec les deux moitiés de la règle
contrôlées séparément : la place atteint toujours la cible, et aucune ligne
produite ne la dépasse.

---

## D-4 — Les espaces latéraux du bandeau élargissent le fond, pas le texte (lot 3)

**Ce que fait le prototype** : pour élargir la boîte bleue sous une ligne
courte — et couvrir un sous-titre déjà incrusté dans la source — il colle
`espaces_lateraux` espaces durs `\h` **de chaque côté du texte** avant de
l'écrire dans l'ASS.

**Ce que fait l'app native** : c'est le RECTANGLE qui s'élargit d'autant. La
chaîne gravée reste celle du fichier source.

**Pourquoi** : l'invariant nº1 dit qu'aucun mot n'est jamais modifié. Ajouter
des espaces au texte pour obtenir un effet de fond revient à altérer la chaîne
pour des raisons de décor. Le résultat visuel est le même — l'élargissement
vaut `espaces_lateraux × largeur d'une espace dans la police` — mais le texte
n'est plus touché.

---

## D-5 — En mode `ajuste`, le fond reste dans le cadre (lot 3)

**Ce que fait le prototype** : le fond épouse la ligne, plus les espaces durs.
Sur une ligne remplissant la largeur utile, l'ensemble sort de l'image —
mesuré à **2 002 px de fond pour une vidéo de 1 920**. Le défaut lui était
invisible : il élargissait le fond APRÈS le découpage, quand plus rien ne
pouvait le rattraper.

**Ce que fait l'app native** : le débord du fond est déduit de la largeur utile
**avant** la césure. Le texte se coupe un mot plus tôt et le fond reste dans
les marges du profil.

**Portée** : ne se manifeste que sur les lignes proches de la largeur maximale.
Sur les lignes courantes, le découpage est inchangé.

**Vérifié par** : `ControlesRendu`, rubrique « bandeau pleine largeur »,
contrôle « le fond d'une ligne pleine reste dans le cadre ».

---

## D-6 — Le ratio du logo est préservé (lot 4bis)

**Ce que fait le prototype** : `scale=diam:diam`. Un logo rectangulaire est
**écrasé en carré**, sans avertissement.

**Ce que fait l'app native** : la plus grande dimension vaut le diamètre, la
plus petite suit le ratio de l'image.

**Pourquoi** : le schéma partagé dit « plus grande dimension du logo en % de la
HAUTEUR vidéo, **ratio préservé** ». C'est le contrat (invariant nº6), et c'est
lui qui fait foi.

**Portée** : nulle sur un logo carré. Le logo NONP est un disque dans une image
carrée : les deux implémentations le posent au pixel près au même endroit, ce
que le contrôle de parité vérifie sur les quatre coins et sur des coordonnées
libres, en 16:9, 9:16 et 1:1.

**Vérifié par** : `ControlesLogo`, rubriques « taille, marge, ratio » et
« parité avec le prototype ».

---

## D-7 — L'avertissement de zone regarde les deux dimensions (lot 5)

**Ce que fait le prototype** : `avertissements_zone()` compare le BAS du logo au
HAUT de la zone des sous-titres, sans jamais regarder l'horizontale. Un logo posé
bas mais complètement à droite d'un bandeau `ajuste` étroit déclenchait donc une
alerte pour rien.

**Ce que fait l'app native** : un vrai recoupement de rectangles.

**Et surtout, il est enfin lu.** Le prototype imprimait ces avertissements dans
un terminal, juste avant un encodage de plusieurs minutes. L'aperçu du lot 5 les
montre AVANT d'encoder, à côté de l'image, et le logo se déplace à la souris
pour les faire disparaître.

**Vérifié par** : `ControlesInterface`, rubrique « avertissements de zone » —
logo en bas avec sous-titres, logo en haut, logo en bas sans sous-titres, logo
au bord, logo au centre, pas de logo.

---

## D-8 — Le recadrage rond est un réglage, pas un fichier à fabriquer (lot 5)

**Ce que fait le prototype** : `--make-logo mon_logo.png` écrit un
`logo_circle.png` sur le disque. Il faut donc fabriquer le fichier AVANT
d'habiller, et recommencer si le résultat ne convient pas.

**Ce que fait l'app native** : « Recadrer en cercle » est une case à cocher. Le
découpage s'applique au vol, l'aperçu montre le résultat immédiatement, et
décocher revient en arrière. **Aucun fichier n'est écrit à côté du logo de
l'utilisateur.**

**Le procédé, lui, est celui du prototype** : sur-échantillonnage ×4, découpe du
disque sur l'image agrandie, réduction. C'est la réduction qui moyenne les
pixels du bord et lisse le contour.

**Une correction au passage** : le prototype prend `W/2` comme rayon quel que
soit le format, si bien qu'une image plus haute que large voyait son cercle
coupé. Ici l'image est d'abord ramenée à son **carré central**, puis le disque
y est inscrit — un logo rectangulaire donne un vrai rond.

**Vérifié par** : `ControlesInterface`, rubrique « logo recadré en cercle » —
coins transparents, centre opaque, bord lissé (98 pixels de valeur
intermédiaire relevés sur le pourtour), image rectangulaire ramenée au carré.

---

## D-9 — Un profil de l'app peut dépasser ce que le prototype sait lire (lot 6)

**Origine** : lot 6, mesuré le 28/08/2026 en faisant relire par
`charger_profil()` des profils écrits par l'app.

**Le fait.** Le schéma de ce dépôt porte trois champs ajoutés le 23/08 —
`bandeau.mode`, `bandeau.hauteur_fixe_lignes`,
`bandeau.marge_interieure_pct_largeur`. Le prototype ne les connaît pas : ni son
`profil-habillage.schema.json`, ni son `_controler()`, qui les refuse comme
champs inconnus. L'amendement a été **proposé**, jamais appliqué au prototype.

**Ce que l'app fait.** Elle n'écrit un champ facultatif que s'il s'écarte de sa
valeur par défaut. C'est la règle que le schéma se donne à lui-même, et elle
suffit pour que le critère d'acceptation du lot soit tenu partout où il peut
l'être :

| Profil écrit par l'app | Relu par le prototype |
|---|---|
| préréglage **NONP** | accepté sans retouche |
| NONP sans logo | accepté |
| profil réglé à la main, bandeau `ajuste` | accepté |
| préréglage **Neutre** (bandeau pleine largeur) | **refusé** — `mode`, `hauteur_fixe_lignes` |

**Pourquoi ce refus est juste.** Le prototype ne sait pas rendre un bandeau
pleine largeur. Taire `mode` pour lui faire accepter le fichier lui ferait rendre
autre chose que ce que le fichier décrit — un bandeau ajusté là où l'on a
demandé une bande. Mieux vaut un refus lisible qu'un rendu faux.

**Ce que cela coûte.** Un profil « Neutre » exporté depuis l'app n'est pas
utilisable dans le prototype. Un profil issu du prototype, lui, est toujours lu
par l'app — ce sens-là n'a aucune restriction.

**Comment cela se referme.** Le jour où le prototype reçoit l'amendement du
23/08, ces fichiers passent sans changer d'une virgule. C'est la décision
ouverte nº5 de l'ADR (« amender le prototype dès maintenant, ou attendre »).

**Contrôlé par** : `Scripts/profils_python.py`, appelé par `./Scripts/verifier.sh`
quand le prototype est présent. Le nom des fichiers porte l'attente — `accepte-*`
doit passer, `amende-*` doit être refusé **et seulement** sur ces trois champs.

---

## Ce qui n'est **pas** une divergence

- **La resegmentation change les minutages.** Elle le faisait déjà dans le
  prototype : c'est l'invariant nº2, pas un écart. Ces timecodes ne sortent
  jamais du rendu.
- **Les blocs vides disparaissent.** Comportement du prototype, reproduit tel
  quel : un bloc sans mot n'a rien à afficher.
- **Un mot plus long que la ligne déborde.** Comportement du prototype, et le
  bon : l'invariant nº1 interdit de couper un mot.
- **Le logo est posé sous les sous-titres.** Ordre du prototype (`overlay`
  puis `ass`), repris tel quel : un logo mal placé ne doit jamais masquer une
  réplique.
- **Le BOM est conservé.** `open(encoding="utf-8")` ne le retire pas non plus.
  Il reste collé au numéro de bloc, qui est ignoré de toute façon.
