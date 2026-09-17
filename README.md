# NONP Habillage

Application macOS qui grave un **logo** et des **sous-titres** sur une vidéo.
On dépose la vidéo, on dépose le fichier `.srt` ou `.vtt`, on règle, on grave.

> **État du projet.** Rien n'est encore publié, mais l'application est **l'outil
> de production depuis le 06/09** : son rendu a été comparé à celui du prototype
> Python dont elle est le portage, sur vidéos réelles et sur trois formats, et
> jugé équivalent en 16:9 et meilleur en 9:16. Le détail de cette comparaison :
> [`docs/campagne-parite.md`](docs/campagne-parite.md).

## Ce qu'elle fait

- **Sous-titres incrustés** à partir d'un `.srt` ou d'un `.vtt`, avec bandeau
  plein ou ajusté au texte, contour, marges et couleurs réglables.
- **Logo** posé dans un coin ou à des coordonnées libres, avec sa taille, sa
  marge, son opacité, et un recadrage rond facultatif.
- **Les deux, ou un seul des deux.** Un logo sans sous-titres est un export
  valide, et l'inverse aussi.
- **Aperçu en direct** sur une image de la vidéo, avec le choix du plan — du
  plus sombre au plus clair, pour vérifier que le texte reste lisible partout.
- **Profils** enregistrables et partagés avec le prototype Python : un profil
  écrit d'un côté se relit de l'autre.

## Ce qu'elle ne fait pas

Ni montage, ni coupe, ni transitions, ni titrage, ni musique, ni filtres
d'image, ni transcription, ni traduction. Elle n'exporte **aucun fichier de
sous-titres** : elle grave, elle ne convertit pas.

## Ce qu'elle ne fera jamais

**Aucun mot de vos sous-titres n'est modifié.** Ni correction orthographique,
ni substitution, ni reformulation, ni « amélioration ». Le texte gravé est
exactement celui du fichier, au caractère près. C'est la valeur du produit, et
c'est vérifié à chaque compilation sur un corpus réel.

Les blocs trop longs pour tenir à l'écran sont redécoupés **pour l'affichage
seulement**, et les minutages recalculés au prorata ne sortent jamais du rendu.

## Ce qu'il faut

- macOS 14 ou plus récent.
- Rien d'autre. Pas de FFmpeg à installer, pas de bibliothèque tierce : tout
  passe par AVFoundation, Core Text et VideoToolbox, livrés avec macOS.

## Formats acceptés

En entrée : **MP4, MOV, M4V**. MKV et AVI sont hors périmètre — trois
conteneurs éprouvés valent mieux qu'une couverture partielle qui dépend du
codec. Un fichier refusé dit **pourquoi** il l'est, et ce qu'il faut en faire.

Sous-titres : **SRT** et **VTT**. Logo : **PNG, JPEG, HEIC, TIFF**.

En sortie : MP4 (H.264). La piste audio est **recopiée telle quelle**, sans
réencodage — rien n'est perdu au passage.

## Compiler depuis les sources

```sh
./Scripts/build_app.sh            # build de TEST → dist/, identifiant .test
./Scripts/build_app.sh --release  # build de PRODUCTION
./Scripts/verifier.sh             # le harnais de contrôles
```

**Sur macOS 27**, la compilation demande un contournement : les Command Line
Tools 27.0 ne livrent pas le plugin des macros SwiftUI, et les scripts se
replient sur le SDK macOS 26.5 et sur l'ancien système de build de SwiftPM, en
le disant — contournement daté du 17/09/2026, expliqué dans
[`Scripts/sdk_macos.sh`](Scripts/sdk_macos.sh).

Une build de test ne s'installe jamais dans `/Applications` : elle porte un
identifiant distinct pour ne pas se faire prendre pour une version installée.

## Licence

[MPL-2.0](LICENSE). Toute dépendance sous GPL est exclue par construction —
il n'y a d'ailleurs aucune dépendance du tout.

## Pour aller plus loin

| Document | Ce qu'on y trouve |
| --- | --- |
| [`docs/adr/0001-…`](docs/adr/0001-app-compagnon-avfoundation.md) | Les décisions d'architecture et leur pourquoi |
| [`docs/CAHIER-DES-LOTS.md`](docs/CAHIER-DES-LOTS.md) | Le découpage du travail, lot par lot |
| [`docs/divergences-prototype.md`](docs/divergences-prototype.md) | Chaque écart volontaire avec le prototype Python |
| [`docs/campagne-parite.md`](docs/campagne-parite.md) | La comparaison des deux rendus, et ce qu'il en manque |
| [`docs/release-checklist.md`](docs/release-checklist.md) | La procédure de publication |
| [`docs/profil-habillage.schema.json`](docs/profil-habillage.schema.json) | Le format des profils, partagé avec le prototype |
