# Journal des modifications

Les versions suivent le [versionnage sémantique](https://semver.org/lang/fr/).
Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

---

## [1.0.0] — 2026-09-19

> ⚠︎ **Date à aligner sur celle du tag.** Elle est posée ici à titre indicatif ;
> si le tag est posé un autre jour, corriger avant publication.

Première version publique.

### Ce que fait l'application

**Sous-titres incrustés.** À partir d'un fichier `.srt` ou `.vtt` : bandeau
plein sur toute la largeur ou ajusté au texte ligne par ligne, contour,
couleurs, marges, taille et police réglables. Les blocs trop longs pour tenir
à l'écran sont redécoupés **pour l'affichage seulement**.

**Logo.** Posé dans l'un des quatre coins ou à des coordonnées libres, avec sa
taille, sa marge et son opacité, et un recadrage rond facultatif. Formats
acceptés : PNG, JPEG, HEIC, TIFF.

**Les deux, ou un seul des deux.** Un logo sans sous-titres est un export
valide, et l'inverse aussi.

**Aperçu en direct** sur une image de la vidéo, avec le choix du plan — du plus
sombre au plus clair — pour vérifier que le texte reste lisible partout. Les
avertissements de placement (logo empiétant sur la zone des sous-titres, logo
hors des marges sûres) s'affichent avant l'encodage, et chaque conseil est
simulé avant d'être donné : l'application ne propose jamais une action qui ne
lèverait pas l'avertissement.

**Profils.** L'habillage complet s'enregistre dans un fichier `.json`
échangeable — c'est ce qui permet à un groupe de figer son apparence et de la
diffuser à ses membres. Schéma de profil version 2, documenté dans
`docs/profil-habillage.schema.json`.

### Entrées et sorties

| | |
| --- | --- |
| Vidéo en entrée | MP4, MOV, M4V |
| Sous-titres | SRT, VTT |
| Logo | PNG, JPEG, HEIC, TIFF |
| Vidéo en sortie | MP4 (H.264) |

La piste audio est **recopiée telle quelle**, sans réencodage.

### Ce que l'application ne fait pas

Ni montage, ni coupe, ni transitions, ni titrage, ni musique, ni filtres
d'image, ni transcription, ni traduction. Elle n'exporte **aucun fichier de
sous-titres** : elle grave, elle ne convertit pas. MKV et AVI sont hors
périmètre.

### Ce qu'elle ne fera jamais

**Aucun mot de vos sous-titres n'est modifié** — ni correction orthographique,
ni substitution, ni reformulation. Le texte gravé est exactement celui du
fichier, au caractère près. Les minutages recalculés lors du redécoupage
d'affichage ne sortent jamais du rendu.

**Une police absente produit une erreur explicite**, jamais une substitution
silencieuse.

### Sous le capot

Aucune dépendance : ni FFmpeg, ni bibliothèque tierce, ni gestionnaire de
paquets. Tout passe par AVFoundation, Core Text et VideoToolbox, livrés avec
macOS. Licence [MPL-2.0](LICENSE).

### Configuration requise

macOS 14 (Sonoma) ou plus récent, sur un Mac **Apple Silicon**. Les Mac à
processeur Intel ne sont pas pris en charge.

L'application n'est pas notarisée par Apple : au premier lancement, macOS
affiche un avertissement qui se lève par Réglages Système → Confidentialité et
sécurité. La marche à suivre est dans le [README](README.md).

### Archive publiée

<!--
  À remplir au moment de l'empaquetage, jamais avant : l'empreinte n'existe
  qu'une fois l'archive produite, et un ZIP publié ne se régénère jamais.
  Cette ligne reste au journal même après le retrait de l'archive du site.
-->

- Fichier : `NONP-Habillage-1.0.0.zip`
- SHA-256 : _(à compléter à l'empaquetage)_
