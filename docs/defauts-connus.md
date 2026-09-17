# Défauts connus

Des défauts **constatés et non corrigés**. Chacun dit ce qu'on voit, ce qui a
été mesuré, et pourquoi les contrôles ne l'attrapent pas — un défaut que le
harnais ne voit pas doit au moins être écrit quelque part.

Un défaut quitte cette liste quand il est corrigé, avec le commit qui le corrige.

---

## DC-1 — Les boutons de coin du logo ont leurs titres tronqués

**Consigné le 17/09/2026.** Signalé par Éric à l'usage, en même temps que la
colonne rognée (« Retirer le log ») ; pris d'abord pour le même défaut, il n'en
est pas un.

**Ce qu'on voit.** Dans la colonne des réglages, section Logo, la ligne
« Position » et ses quatre boutons de coin : les titres sont tronqués,
« Haut gau… », « Haut dr… » — sur les captures d'Éric.

**Mesuré** — binaire marqué SDK 26.5, macOS 27.0 :

| Colonne | Contenu reçu | La ligne « Position » voudrait |
| --- | --- | --- |
| 360 points (jusqu'au 17/09) | 313 points | 422 points |
| 365 points (depuis le 17/09) | 316 points | 422 points |

Il manque 106 points. Le défaut existait avant le réétalonnage de la colonne,
et déjà sous les anciennes métriques d'un binaire mal marqué (338 points voulus
pour 313 reçus).

**Pourquoi les contrôles ne le voyaient pas.** `libellesDeLaColonne` vérifie
que chaque ligne garde, contrainte, la hauteur qu'elle a libre : il attrape un
libellé qui se REPLIE, pas un titre qui se TRONQUE. Un bouton qui raccourcit
son titre ne change pas de hauteur. Le code appelait cela une « dégradation
acceptable » — un libellé tronqué est visible de l'utilisateur, et ne l'est
pas.

**Où.** `PanneauPersonnaliserView.coinsDuLogo`.

**Le 17/09, sur `fix/dc1-boutons-de-coin`** :

- Le harnais le voit. `LibelleSurveille` compare ce que chaque libellé reçoit à
  ce que son texte entier demande ; la section « aucun libellé de la colonne
  n'est tronqué » échoue sur les quatre boutons, logo chargé. Le détecteur a
  été validé contre des captures de vraies fenêtres (56 libellés, sept
  largeurs, aucun désaccord), et l'instrumentation de la colonne ne change
  aucun pixel (six captures comparées avant et après).
- La largeur naturelle d'une ligne n'est PAS le seuil de troncature : un bouton
  comprime sa marge avant son texte. « Haut G. » réclame 329 points et reste
  entier jusqu'à 290.
- Le coin choisi EST signalé dans la ligne actuelle, par un texte bleu. Une
  première planche, capturée d'une fenêtre inactive où macOS grise les
  accents, avait fait croire le contraire.
- Propositions sur la planche (`--planche-coins <dossier>`), toutes sans
  troncature à 300 points : A, abréviations ; B, icônes de coin ; C, grille
  figurant l'image ; D, mots entiers disposés en carré. **Le choix revient à
  Éric.**

---

## DC-2 — « Taille » peut déborder de la colonne après une mesure de taille

**Consigné le 17/09/2026**, en préparant la planche de DC-1. **Constaté en
capture ; pas encore observé dans l'application** — à vérifier à l'œil.

**Ce qu'on voit.** Le sélecteur segmenté « Taille » des sous-titres dessine ses
quatre segments à sa largeur idéale, environ 386 points, au lieu des 316 de la
colonne : « Très grande » est coupé net au bord, « Très gra ».

**Reproduit** — `--planche-coins <dossier> --dc2`, binaire marqué SDK 26.5 : la
vraie colonne, affichée deux fois telle quelle, puis deux fois après un
`fittingSize` calculé sur la vue avant de l'afficher. Sans mesure préalable,
« Taille » est entier les deux fois ; après la mesure, il déborde les deux
fois. Ni l'apparence, ni l'état actif, ni la hauteur de la fenêtre n'y
changent rien (huit combinaisons capturées).

**Pourquoi c'est à prendre au sérieux.** L'application fait calculer des
tailles à sa fenêtre : `.windowResizability(.contentMinSize)` et
`CadreAuContenu`, qui lit la taille minimale du contenu. C'est le même motif que
la colonne rognée — une disposition calculée une fois, que SwiftUI ne refait
pas.

**Pourquoi les contrôles ne le voient pas.** Les segments sont dessinés par
AppKit : `LibelleSurveille` ne peut pas les instrumenter, et `sizeThatFits`
rend 316 points — la largeur que SwiftUI attribue, pas celle qu'AppKit dessine.

**Où.** `PanneauPersonnaliserView.choixSegmente` ; « Largeur du fond » est
construit de la même façon, mais tient dans sa largeur idéale (228 points).
