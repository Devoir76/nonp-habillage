# Profils d'exemple

Des fichiers de profil prêts à importer, par le bouton **Importer…** du volet
Personnaliser.

**L'application n'a plus de préréglages** — décidé le 28/08/2026. Elle s'ouvre
sur des réglages sobres, mémorise les vôtres d'une session à l'autre, et c'est
tout ce dont on a besoin quand on n'a qu'un seul habillage, ce qui est le cas de
presque tout le monde. Les autres apparences sont des **fichiers**, ici.

Un fichier, ça s'échange — et c'est précisément l'usage que l'ADR décrit :

> C'est le mécanisme qui permet à une association de figer son habillage et de
> le diffuser à ses bénévoles, qui obtiennent alors tous le même rendu.

Un préréglage qui n'est qu'un exemple n'a pas besoin d'un bouton : il a besoin
d'être **trouvable**. C'est pourquoi « Importer un profil… » s'ouvre sur ce
dossier.

## `bandeau-colore.json`

Un bandeau bleu opaque qui épouse chaque ligne, texte blanc, contour noir,
Arial. L'autre façon de poser un fond, en regard des réglages par défaut, qui
emploient une bande sombre translucide sur toute la largeur.

## `nonp.json`

L'habillage de l'association NONP. Mêmes valeurs que le précédent — ce sont
celles du prototype `nonp_habille.py`, à l'identique — sous le nom de
l'association : c'est ainsi qu'un profil circule entre ses membres.

## Le logo n'est pas dans ces fichiers

Ils décrivent l'habillage du texte ; le logo est une image que chacun dépose.
En exportant **votre** profil, l'application recopie le logo à côté du `.json`
et écrit son chemin en relatif — c'est ce qui permet d'envoyer le couple à
quelqu'un d'autre, et ce qu'un chemin absolu ne permettrait pas.

## Écrire le vôtre

Réglez dans l'application, puis **Fichier › Exporter le profil…**. Le fichier
produit est au schéma `docs/profil-habillage.schema.json`, version 2.
