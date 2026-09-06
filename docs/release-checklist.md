# Checklist de release

Documentation uniquement : la procédure et les vérifications à dérouler avant
de poser un tag. Aucune automatisation ici — un script qui coche des cases à
votre place ne prouve rien.

Calquée sur celle de NONP Transcription, **moins tout ce qui concernait les
binaires embarqués**. Il n'y en a aucun ici et il n'y en aura jamais : pas de
FFmpeg, donc pas de source correspondante LGPL à distribuer, pas de
`SHA256SUMS.txt` à tenir pour une dépendance tierce. C'est l'invariant nº3, et
c'est la moitié de cette checklist en moins.

---

## Avant tout — le verrou qui reste

Ce point n'est pas une case parmi d'autres. Tant qu'il tient, **il n'y a pas de
release publique.**

- [ ] **L'icône existe.** `Resources/AppIcon.icns` est absent : la build le
      signale et pose une icône générique. Une application publiée sans icône
      se remarque immédiatement, dans le Dock comme dans le Finder.

Les deux autres sont tombés le 06/09 :

- [x] **L'invariant nº5 est levé.** La campagne de parité a fait la preuve, et
      Éric a tranché : l'app native est l'outil de production, le prototype
      reste un filet. Motif dans [`campagne-parite.md`](campagne-parite.md) et
      à l'ADR, « Levé le 06/09 ».
- [x] **Le nom définitif est arrêté** : « NONP Habillage », identifiant
      `com.nonp.habillage`, décidés le 24/08 (ADR-0001, décision nº1). Ils
      apparaissent dans le bundle, dans l'archive et sur la page de
      téléchargement — les changer après coup casserait les liens et les
      installations existantes, et c'est bien pourquoi il fallait les fixer
      avant.

## Séquence de release (ordre impératif)

1. **Validation d'usage** de la version candidate, sur vidéos réelles, en 16:9
   **et** en 9:16. Le prototype n'arbitre plus, mais il reste installé : sur un
   doute de rendu, `./Scripts/campagne_parite.sh` remet les deux côte à côte en
   une commande.
2. **Harnais complet au vert**, corpus et prototype compris :
   `./Scripts/verifier.sh --corpus <dossier de .srt>` — aucun échec, et
   **aucune rubrique non exécutée** ; une rubrique sautée n'est pas une
   rubrique réussie, et le rapport le dit lui-même.
3. **Compilation sans un seul avertissement**, depuis un `.build` effacé.
4. **Fusion** de la branche dans `main`.
5. **Compilation propre depuis `main`** : `./Scripts/build_app.sh --release`.
6. **Vérification du `.app` final** (ci-dessous), sur le bundle réellement
   compilé, jamais sur les sources.
7. **Test du binaire compilé** : lancement, un export court, un export logo
   seul, un export sous-titres seuls.
8. **Tag de version** posé **exactement sur le commit** ayant produit le binaire
   vérifié — jamais en amont de la compilation depuis `main`.

## Vérification du `.app` compilé (avant le tag)

- [ ] Version affichée (`CFBundleShortVersionString`) = la version cible.
      Elle vaut `0.1.0` dans `Resources/Info.plist` tant que rien n'est publié.
- [ ] `CFBundleVersion` (numéro de build) cohérent et **croissant**.
- [ ] Identifiant de bundle = celui de **production**, obtenu par `--release`.
      Une build de test porte `com.nonp.habillage.test` et ne s'installe
      **jamais** dans `/Applications` (CLAUDE.md, « Build »).
- [ ] `LSMinimumSystemVersion` cohérent avec ce qui est annoncé au
      téléchargement (macOS 14 aujourd'hui).
- [ ] Le texte de licence est dans le bundle
      (`Contents/Resources/Licenses/LICENSE`), et c'est bien la MPL-2.0.
- [ ] `codesign --verify --deep --strict` passe sur le bundle final.
- [ ] Commit ayant produit le binaire identifié sans ambiguïté, et tag posé
      exactement dessus.

## Ce qui se contrôle à la main, une fois par release

Le harnais couvre le moteur ; ces points-là demandent un œil.

- [ ] **Un fichier refusé nomme sa vraie cause.** Déposer un dossier, un
      fichier introuvable, un `.mkv`, un fichier de zéro octet : quatre
      messages différents, et aucun qui conseille une conversion inutile.
- [ ] **Aucun fichier d'entrée n'est jamais remplacé**, même en visant
      volontairement la vidéo source dans le panneau d'enregistrement.
- [ ] **Une police absente produit une erreur explicite**, jamais une
      substitution silencieuse (invariant nº4).
- [ ] **Aucun mot des sous-titres n'a bougé** dans le rendu final
      (invariant nº1) — la vérification par corpus le prouve, la relecture
      d'un export le confirme.
- [ ] **Une annulation en cours d'export ne laisse aucun fichier** derrière
      elle.
- [ ] L'interface ne montre **aucun texte anglais**.

## Distribution

Rien n'est publié à ce jour, et rien ne le sera avant les deux verrous du haut.
Quand ce sera le cas, deux canaux, et l'ordre compte : le tag d'abord, la
distribution ensuite — un tag posé ne publie rien.

### Release GitHub (après le tag)

- [ ] Release créée **sur le tag de version**, avec en asset l'archive ZIP
      **réellement validée**, et son empreinte SHA-256.
- [ ] Empreinte vérifiée **après téléversement** : re-télécharger, recalculer,
      comparer.
- [ ] Aucune release ayant distribué un binaire n'est supprimée.

### Publication sur nonp.fr (après le tag)

À dérouler **en une seule fois** : un site qui annonce une version et en sert
une autre est pire que pas de mise à jour du tout.

- [ ] Archive produite avec
      `ditto -c -k --sequesterRsrc --keepParent`, nommée d'après la version.
- [ ] Empreinte SHA-256 calculée sur l'archive **réellement déposée**.
- [ ] `SHA256SUMS.txt` mis à jour.
- [ ] **Alias `-latest` repointé** vers la nouvelle archive. L'oublier laisse
      l'alias servir silencieusement la version précédente.
- [ ] Page de téléchargement : version affichée, nom du fichier (lien **et**
      `aria-label` **et** texte du bouton), poids, empreinte, bloc JSON-LD.
- [ ] Après déploiement : re-télécharger **depuis le site** et vérifier que
      l'empreinte correspond à celle annoncée.
- [ ] Archive de la version précédente retirée du dossier servi ; son empreinte
      reste au CHANGELOG.

## Après une première publication

Ces points n'ont pas lieu d'être tant que rien n'est sorti. Ils le seront à la
deuxième release :

- [ ] **Test de mise à niveau** depuis la version publiée précédente, sur le
      `.app` de production, jamais sur un build `.test` : installation réelle
      dans `/Applications`, version affichée correcte, aucune redirection de
      LaunchServices vers une copie résiduelle.
- [ ] **Les réglages mémorisés de l'ancienne version sont relus** sans perte et
      sans réinitialisation silencieuse.
- [ ] **Les profils écrits par l'ancienne version s'importent** dans la
      nouvelle — le schéma est un contrat partagé avec le prototype
      (invariant nº6).
