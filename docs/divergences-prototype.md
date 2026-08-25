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

## Ce qui n'est **pas** une divergence

- **La resegmentation change les minutages.** Elle le faisait déjà dans le
  prototype : c'est l'invariant nº2, pas un écart. Ces timecodes ne sortent
  jamais du rendu.
- **Les blocs vides disparaissent.** Comportement du prototype, reproduit tel
  quel : un bloc sans mot n'a rien à afficher.
- **Un mot plus long que la ligne déborde.** Comportement du prototype, et le
  bon : l'invariant nº1 interdit de couper un mot.
- **Le BOM est conservé.** `open(encoding="utf-8")` ne le retire pas non plus.
  Il reste collé au numéro de bloc, qui est ignoré de toute façon.
