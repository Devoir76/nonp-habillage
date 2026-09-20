# Divergences assumées avec le prototype Python

Le prototype `nonp_habille.py` a fait foi jusqu'au 06/09 ; depuis, l'app native
est l'outil de production et lui n'est plus qu'un filet (voir ADR-0001, « Levé
le 06/09 »). **Ce fichier ne perd rien à cette levée.** Le portage reste
**fidèle par défaut** : quand rien n'est écrit ici, le code Swift reproduit le
comportement Python au caractère près, et les contrôles de parité le vérifient
à chaque exécution — non plus pour arbitrer, mais pour signaler une régression.

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
   préréglage « Bandeau coloré » ne doit rien changer à l'existant.
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

## D-9 — L'app écrit un schéma que le prototype ne lit pas (lot 6)

**Origine** : lot 6, mesuré le 28/08/2026 en faisant relire par
`charger_profil()` des profils écrits par l'app. **Élargie le même jour** par la
décision nº6.

**Le fait, première version (matin du 28/08).** Le schéma de ce dépôt portait
trois champs ajoutés le 23/08 — `bandeau.mode`, `bandeau.hauteur_fixe_lignes`,
`bandeau.marge_interieure_pct_largeur` — que le prototype refusait comme
inconnus : l'amendement avait été *proposé*, jamais appliqué. Seuls les profils
employant le bandeau pleine largeur étaient concernés.

**Le fait, depuis la décision nº6.** Le schéma est passé en **version 2**. Le
prototype vérifie `schema_version == 1` avant tout le reste : il refuse donc
**tout** profil écrit par l'app, plus seulement ceux qui sortaient du préréglage
NONP.

| Profil écrit par l'app | Relu par le prototype |
|---|---|
| préréglage « Bandeau coloré » | refusé — version 2, `marge_texte_pct_largeur`, `longueur_ligne_cible` |
| « Bandeau coloré » sans logo | refusé, mêmes motifs |
| profil réglé à la main | refusé, mêmes motifs |
| préréglage Neutre | refusé, mêmes motifs + `mode`, `hauteur_fixe_lignes` |

**Pourquoi c'est assumé.** Décision nº5, tranchée le 28/08 : le prototype ne
sera pas amendé — il prend sa retraite quand l'app native sera complète, et le
modifier reviendrait à toucher l'outil de production quotidien pour un besoin
transitoire. Décision nº6, tranchée le même jour : l'argument de compatibilité
qui plaidait pour rester en v1 était déjà caduc, puisque le prototype ne relisait
plus les profils sortant du préréglage « Bandeau coloré ».

**Le sens qui compte n'a aucune restriction** : **tout profil du prototype est lu
par l'app**, converti automatiquement de la v1 vers la v2, et la conversion est
annoncée. Elle n'échoue que si la police du profil est absente du système —
convertir `espaces_lateraux` exige de mesurer une espace dans cette police, et
l'invariant nº4 interdit d'en substituer une autre.

**Ce que cela coûte.** Un profil produit par l'app n'est pas utilisable dans le
prototype. En pratique : on règle dans l'app, on grave dans l'app.

**Contrôlé par** : `profils_python.py`, appelé par `./Scripts/verifier.sh` quand
le prototype **et** le script sont présents. Ce script ne fait pas partie du
dépôt public : il compare à un prototype non publié, et la rubrique s'annonce
« non exécutée » en son absence. Le nom des fichiers porte l'attente — `accepte-*`
doit passer, `amende-*` doit être refusé **et seulement** pour ce que la version 2
a changé. Depuis le 28/08, l'app n'écrit plus que des `amende-*`.

---

## D-10 — Le retrait du texte n'est plus adossé à la taille de police (lot 6)

**Origine** : ADR-0001, décision nº6, tranchée le 28/08/2026.

**Ce que fait le prototype.** Il élargit le fond du mode `ajuste` en collant
`espaces_lateraux` espaces durs de chaque côté du texte. L'unité est la largeur
d'une espace, donc une fraction de la taille de police, donc de la **hauteur**
de la vidéo — pour un retrait qui consomme de la **largeur**.

**Ce que fait l'app native.** Un pourcentage de la largeur,
`bandeau.marge_texte_pct_largeur`, appliqué en pixels entiers, et le même dans
les deux modes de bandeau. Défaut 5,61 % : la valeur mesurée qui reproduit, sur
le format de référence 16:9 1080p, le débord que `espaces_lateraux: 4`
produisait.

**Ce que cela change, mesuré.**

- **16:9** : le texte est identique à toutes les définitions — même taille, mêmes
  coupures, sur les 1 567 répliques du corpus réel. Le rendu est identique au
  pixel sur 1024, 1280 et 1920 ; sur 2560 et 3840 le bord du bandeau se déplace
  de 1,4 px au plus, soit 0,03 % des pixels de l'image.
- **Vertical** : la police remonte de 61 à 68 px en 9:16 (+11 %), de 63 à 68 en
  1:1 et en 4:5 (+7 %). C'est la largeur que l'ancienne unité prenait à des
  formats qu'elle n'avait pas été réglée pour.

**Pourquoi l'écart en 2560 et 3840 n'était pas évitable.** Le débord de la v1
n'était pas proportionnel à la largeur : il empruntait au `padding_pct_hauteur`,
arrondi au pixel sur la hauteur. Il valait 5,609 % de la largeur sur une 1080p et
5,569 % sur une 1440p — la v1 dérivait avec la définition, sur un format pourtant
identique. Aucun pourcentage unique ne peut retomber sur elle partout ; la v2, en
revanche, ne dérive plus.

**Contrôlé par** : `ControlesRegressionV2`, à chaque exécution de
`./Scripts/verifier.sh`.

---

## Rappel — le gras n'est pas une divergence, c'en était l'absence (lot 7)

Le prototype grave le texte en gras (`Bold=-1` dans son style ASS, en dur).
L'app le gravait en romain, et rien ici ne le disait : **une divergence absente
de ce registre est un bug**, c'est la règle posée en tête de fichier, et elle a
servi. Corrigé le 06/09 — l'app grave en gras elle aussi, et il n'y a donc plus
rien à inscrire. Voir `docs/campagne-parite.md`.

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
