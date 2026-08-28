# Profils d'exemple

Des fichiers de profil prêts à importer, par le bouton **Importer…** du volet
Personnaliser.

Ils ne sont **pas** des préréglages de l'application. C'est la différence qui
compte, et elle a été tranchée le 28/08/2026 : un préréglage livré décrit une
**apparence** — « Neutre », « Bandeau coloré » —, jamais une **organisation**.
Une application destinée au téléchargement public ne peut pas imposer, d'un
bouton, l'identité visuelle d'une association à quelqu'un qui ne la connaît pas.

Un fichier, lui, s'échange. Et c'est précisément l'usage que l'ADR décrit :

> C'est le mécanisme qui permet à une association de figer son habillage et de
> le diffuser à ses bénévoles, qui obtiennent alors tous le même rendu.

## `nonp.json`

L'habillage de l'association NONP : bandeau bleu `#0067F6` opaque épousant
chaque ligne, texte blanc, contour noir, Arial. Ce sont les valeurs du prototype
`nonp_habille.py`, à l'identique.

**Sans logo.** Le fichier décrit l'habillage du texte ; le logo est une image que
chacun dépose. En exportant votre propre profil, l'application recopie le logo à
côté du `.json` et écrit son chemin en relatif — c'est ce qui permet d'envoyer
le couple à quelqu'un d'autre.

## Écrire le vôtre

Réglez dans l'application, puis **Exporter…**. Le fichier produit est au schéma
`docs/profil-habillage.schema.json`, version 2.
