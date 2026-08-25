# Mesures d'export — lot 4

Le lot 4 demande que le temps de traitement soit « mesuré et consigné ». Le
voici, avec la méthode qui permet de le refaire.

L'ADR posait le risque : « Temps de traitement sur longues vidéos — mesuré au
lot 4 sur un fichier d'une heure ; VideoToolbox devrait battre libx264. »
La mesure ci-dessous porte sur dix minutes, la durée de référence de l'ADR
(« de quelques minutes à une vingtaine »). L'heure reste à faire.

---

## Relevé du 25/08

**Machine** : Apple M3, macOS 26.6.2. Build `release`.

**Entrée** : 1920×1080, 30 im/s, 10 min 00 s, H.264 + AAC 128 kb/s stéréo
48 kHz. Sous-titres : 14 répliques, resegmentées, profil NONP.

| | |
|---|---|
| Durée de traitement | **1 min 25 s** |
| Rapport au temps réel | **× 7,1** |
| Fichier produit | 541,3 Mo — 7,43 Mb/s vidéo |
| Audio | **recopié sans réencodage** |

**Extrapolation** : à ce rythme, une heure de 1080p demande environ **8 min 30**.
À vérifier plutôt qu'à croire — l'ADR prévoit cette mesure, elle n'est pas faite.

## Ce qui a été vérifié sur le fichier produit

- **Audio bit à bit identique à la source.** Les deux pistes extraites en ADTS
  ont la même empreinte SHA-256 (`526c7c06dfd44a34…`). Ce n'est pas « de la
  même qualité » : ce sont les mêmes octets.
- **Durée conservée** : 600,16 s contre 600,09 s à la source.
- **Nombre d'images conservé** : 17 981 des deux côtés.
- **Décodage intégral sans erreur** (`ffmpeg -f null -`).
- **Lisible par AVFoundation** — le moteur de QuickTime Player : `isPlayable`,
  pistes vidéo et audio décodables.
- **Lu par VLC 3.x**, qui décode le H.264 par VideoToolbox. Les erreurs
  « blending YUVA » du journal viennent de la sortie vidéo factice imposée par
  le mode sans interface : la vidéo source non habillée en produit 147, le
  fichier exporté 146. Elles ne concernent donc pas le fichier.

## Refaire la mesure

```sh
# Fabriquer une entrée de dix minutes à partir d'une vidéo plus courte,
# sans réencoder (ffmpeg n'est utilisé QUE pour préparer le matériel d'essai —
# il n'entre pas dans l'application, invariant nº3).
ffmpeg -stream_loop 6 -i <video>.mp4 -c copy -t 600 essai-10min.mp4

swift build -c release
"$(swift build -c release --show-bin-path)/NONPHabillage" \
    --exporter essai-10min.mp4 <sous-titres>.srt sortie.mp4
```

Vérifier que l'audio n'a pas bougé :

```sh
for f in essai-10min.mp4 sortie.mp4; do
    ffmpeg -v error -i "$f" -map 0:a -c copy -f adts - | shasum -a 256
done
```

## Réglage d'encodage

Le débit vidéo est proportionnel au nombre de pixels par seconde
(`largeur × hauteur × images/s × 0,12`), borné entre 2 et 80 Mb/s. Un même
profil donne ainsi une qualité comparable en 1080p et en 4K, en 30 comme en 60
images. Le coefficient vise la qualité du `crf 18` de libx264 — le réglage du
prototype —, quitte à produire des fichiers un peu lourds : pour du témoignage,
la qualité prime sur la taille. À reconsidérer si les fichiers gênent à l'usage.

Une image-clé toutes les deux secondes, pour que la navigation dans le fichier
produit reste fluide sans gonfler le débit.
