# Défauts connus

Des défauts **constatés et non corrigés**. Chacun dit ce qu'on voit, ce qui a
été mesuré, et pourquoi les contrôles ne l'attrapent pas — un défaut que le
harnais ne voit pas doit au moins être écrit quelque part.

Un défaut quitte cette liste quand il est corrigé, avec le commit qui le corrige.

---

Aucun défaut connu à ce jour.

---

## Corrigés

| Défaut | Corrigé par | Le |
| --- | --- | --- |
| DC-1 — Les boutons de coin du logo ont leurs titres tronqués | `5a1374a` — titres abrégés, « Haut G. », « Bas D. » | 17/09/2026 |
| DC-2 — « Taille » débordait de la colonne après une mesure de taille (« Très gra ») | `917817b` — `SelecteurSegmente`, segments taillés à leur libellé ; confirmé entier dans l'application | 17/09/2026 |
