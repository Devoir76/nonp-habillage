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

**Pourquoi les contrôles ne le voient pas.** `libellesDeLaColonne` vérifie que
chaque ligne garde, contrainte, la hauteur qu'elle a libre : il attrape un
libellé qui se REPLIE, pas un titre qui se TRONQUE. Un bouton qui raccourcit
son titre ne change pas de hauteur. Le code appelait cela une « dégradation
acceptable » — un libellé tronqué est visible de l'utilisateur, et ne l'est
pas.

**Où.** `PanneauPersonnaliserView.coinsDuLogo`.

**À décider** — pas dans le chantier où il a été consigné : quelle disposition
pour les quatre coins, et quel contrôle saurait voir une troncature.
