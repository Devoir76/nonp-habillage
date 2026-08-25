# Cahier des lots — app native d'habillage

Un lot par branche, dans l'ordre. **À donner à Claude Code un lot à la fois** :
copier la section du lot en cours, pas le fichier entier. Un lot n'est terminé
que lorsque **tous** ses critères d'acceptation sont vérifiables.

Référence : `docs/adr/0001-app-compagnon-avfoundation.md`.

---

## Lot 1 — Socle (0,5 j)

Projet SwiftPM produisant un exécutable macOS 14+, structure de dossiers de
l'ADR, `Scripts/build_app.sh` calqué sur NONP Transcription (bundle `.app`,
identifiant `.test` par défaut, signature ad-hoc), `.gitignore`, `LICENSE`
MPL-2.0, en-têtes MPL sur chaque source.

**Acceptation** — `./Scripts/build_app.sh` produit un `.app` qui se lance et
affiche une fenêtre vide ; l'identifiant de test est distinct de la production ;
aucune dépendance externe déclarée dans `Package.swift`.

## Lot 2 — Parseur et segmenteur (1 j)

Portage fidèle depuis `nonp_habille.py` : lecture SRT et VTT, resegmentation à
la ponctuation avec réaffectation des minutages au prorata, calcul des
paramètres de mise en page.

**Nouveauté par rapport au prototype** (ADR §5) : la longueur de ligne cible
pilote la taille, aucun plancher ne contredit la géométrie.

**Acceptation** — tests de parité automatisés contre la sortie Python sur un
corpus de SRT réels : cues identiques (texte **et** minutages) à profil et
résolution 16:9 donnés. Test dédié « fidélité » : chaque mot du SRT d'entrée se
retrouve, inchangé et dans l'ordre, dans les cues produites. Le comportement en
9:16 diverge volontairement du prototype — divergence **documentée et testée**,
pas subie.

## Lot 3 — Rendu du texte (1,5 j)

Core Text : lignes, contour, bandeau (modes `ajuste` et `pleine-largeur`,
hauteur fixe optionnelle), mesure **exacte** du texte, césure prévisible.
Rendu dans un `CALayer`, sans vidéo, sur image fixe.

**Acceptation** — images de référence produites en 16:9, 9:16, 1:1 et 4:5 pour
le profil neutre et le préréglage NONP ; aucune ligne ne déborde de la largeur
utile, quel que soit le format ; en mode `pleine-largeur`, la bande couvre
exactement la largeur et sa hauteur ne varie pas d'une réplique à l'autre quand
`hauteur_fixe_lignes` est renseigné. Validation visuelle par Éric **avant** le
lot suivant.

## Lot 4 — Composition et export vidéo (1,5 j)

`AVMutableVideoComposition` + `AVAssetExportSession`, encodage VideoToolbox
H.264, audio **recopié sans réencodage**, progression réelle et durée restante
estimée, annulation possible.

**Acceptation** — une vidéo de 10 minutes en 1080p s'exporte sans perte audio,
avec une progression qui avance ; l'annulation laisse le disque propre ; le
fichier produit se lit dans QuickTime et VLC ; temps mesuré et consigné.

## Lot 5 — Interface (2,5 j)

Zone de dépôt (vidéo seule, ou vidéo + sous-titres), bouton **Habiller**,
progression. Volet « Personnaliser » repliable : logo déplaçable à la souris sur
l'aperçu, curseurs de taille et d'opacité, quatre coins en un clic ; sous-titres
avec tailles nommées, liste courte de polices, sélecteurs de couleur, réglages
de bandeau. Aperçu sur une image fixe extraite de la vidéo, **sur une réplique
réelle** quand un fichier de sous-titres est fourni.

**Acceptation** — les trois usages fonctionnent (sous-titres seuls, logo seul,
les deux) ; l'aperçu reflète chaque réglage sans encoder ; l'écran d'accueil
tient sans défilement et ne montre aucun réglage tant que le volet est fermé.

L'aperçu affiche du texte **en permanence** : phrase de référence calibrée sur
la longueur de ligne cible quand aucun sous-titre n'est chargé, sinon la
**réplique la plus longue du fichier** (pire cas), les autres étant parcourables.
L'image de fond est choisissable parmi plusieurs instants de la vidéo — au moins
un plan clair et un plan sombre — pour juger le contraste des couleurs.

## Lot 6 — Profils (1 j)

Lecture, écriture et validation du schéma v1 (champs inconnus refusés, messages
en français), préréglages livrés (**Neutre** par défaut, **NONP**), mémorisation
du dernier profil utilisé, import et export d'un `.json`.

**À trancher dans ce lot** : `espaces_lateraux`, héritage de l'ASS adossé à la
taille de police alors qu'il consomme de la largeur — 9,6 % de la largeur utile
en 16:9, 30,2 % en 9:16. Voir ADR-0001, décision ouverte nº6.

**Acceptation** — un profil écrit par le prototype Python est accepté sans
retouche ; un profil produit par l'app est accepté par le prototype ; un fichier
corrompu produit un message clair et aucun rendu.

## Lot 7 — Parité, finition, release (1,5 j)

Campagne de comparaison prototype / natif sur vidéos réelles, corrections,
`docs/release-checklist.md`, README public, textes d'aide.

**Acceptation** — Éric juge le rendu indiscernable à l'usage en 16:9 **et** en
9:16 ; la checklist de release est déroulable de bout en bout.

---

## Améliorations différées

À traiter après le lot 7, jamais pendant : profil adapté automatiquement au
format détecté, contrôle de cohérence sous-titres/vidéo à l'ouverture, ombre
portée en alternative au bandeau, traitement par lot, révélation du fichier
dans le Finder.
