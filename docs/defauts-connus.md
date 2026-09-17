# Défauts connus

Des défauts **constatés et non corrigés**. Chacun dit ce qu'on voit, ce qui a
été mesuré, et pourquoi les contrôles ne l'attrapent pas — un défaut que le
harnais ne voit pas doit au moins être écrit quelque part.

Un défaut quitte cette liste quand il est corrigé, avec le commit qui le corrige.

---

## DC-2 — « Taille » peut déborder de la colonne après une mesure de taille

**Consigné le 17/09/2026**, en préparant la planche de DC-1, sur une
reproduction en capture. **Confirmé dans l'application le même jour** par Éric,
sur une build correctement marquée (SDK 26.5) : « Très grande » s'affiche
« Très gra », coupé par le bord de la colonne. Ce n'est plus un risque de banc
d'essai.

**Ce qu'on voit.** Le sélecteur segmenté « Taille » des sous-titres dessine ses
quatre segments à sa largeur idéale, environ 386 points, au lieu des 316 de la
colonne : « Très grande » est coupé net au bord, « Très gra ».

**Reproduit** — `--planche-coins <dossier> --dc2`, binaire marqué SDK 26.5 : la
vraie colonne, affichée deux fois telle quelle, puis deux fois après un
`fittingSize` calculé sur la vue avant de l'afficher. Sans mesure préalable,
« Taille » est entier les deux fois ; après la mesure, il déborde les deux
fois. Ni l'apparence, ni l'état actif, ni la hauteur de la fenêtre n'y
changent rien (huit combinaisons capturées).

**Pourquoi l'application le produit.** Elle fait calculer des tailles à sa
fenêtre : `.windowResizability(.contentMinSize)` et `CadreAuContenu`, qui lit la
taille minimale du contenu. C'est le même motif que la colonne rognée — une
disposition calculée une fois, que SwiftUI ne refait pas.

**Pourquoi les contrôles ne le voient pas.** Les segments sont dessinés par
AppKit : `LibelleSurveille` ne peut pas les instrumenter, et `sizeThatFits`
rend 316 points — la largeur que SwiftUI attribue, pas celle qu'AppKit dessine.

**Où.** `PanneauPersonnaliserView.choixSegmente` ; « Largeur du fond » est
construit de la même façon, mais tient dans sa largeur idéale (228 points).

---

## Corrigés

| Défaut | Corrigé par | Le |
| --- | --- | --- |
| DC-1 — Les boutons de coin du logo ont leurs titres tronqués | `5a1374a` — titres abrégés, « Haut G. », « Bas D. » | 17/09/2026 |
