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

## Avant tout — les verrous

Ces points ne sont pas des cases parmi d'autres : tant qu'un seul tient, **il
n'y a pas de release publique.** Les trois sont tombés le 06/09.

- [x] **L'icône a été vue dans un vrai Dock, le 06/09**, en clair **et** en
      sombre. C'est la date qui fait preuve, pas la case.
      `Resources/AppIcon.icns` — l'inversion nue, fond `#0B0B0E`, marque
      bleue — avait été choisi sur mesure et sur planche, mais une planche est
      une simulation : un Dock réel est translucide et prend la couleur du fond
      d'écran. C'était le seul point que ni la mesure ni la simulation ne
      pouvaient trancher ; il fallait regarder, sur une vraie machine.
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
   doute de rendu, l'outil local de campagne de parité remet les deux côte à
   côte en une commande. Il ne fait pas partie du dépôt — il pointe un chemin
   de machine et un prototype non publié.
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
8. **Le jour du tag, juste avant de le poser** — trois textes datent, et ils
   ne peuvent pas être justes avant ce moment :
   - **La date de l'entrée `[1.0.0]` du `CHANGELOG.md`** se fixe ici. Elle y est
     posée à titre indicatif et porte son propre avertissement ; une date de
     journal qui ne tombe pas le jour du tag fait mentir les deux.
   - **La phrase « Rien n'est encore publié »** du bloc « État du projet » du
     `README.md` est remplacée par l'état réel de la release. Vraie jusqu'ici,
     elle devient fausse à la seconde où le tag est poussé.
   - **Le commentaire de `Resources/Info.plist`** au-dessus de
     `CFBundleShortVersionString` — « Version 1.0.0, en préparation. Rien n'est
     publié. » — perd sa seconde phrase et cesse d'annoncer une préparation.
     Même famille que la précédente : vraie tant que le tag n'est pas posé.
9. **Tag de version** posé **exactement sur le commit** ayant produit le binaire
   vérifié — jamais en amont de la compilation depuis `main`.

## Vérification du `.app` compilé (avant le tag)

- [ ] Version affichée (`CFBundleShortVersionString`) = la version cible.
      Elle vaut `1.0.0` dans `Resources/Info.plist` depuis la préparation de
      la première publication.
- [ ] `CFBundleVersion` (numéro de build) cohérent et **croissant**.
- [ ] Identifiant de bundle = celui de **production**, obtenu par `--release`.
      Une build de test porte `com.nonp.habillage.test` et ne s'installe
      **jamais** dans `/Applications`.
- [ ] `LSMinimumSystemVersion` cohérent avec ce qui est annoncé au
      téléchargement (macOS 14 aujourd'hui).
- [ ] Le texte de licence est dans le bundle
      (`Contents/Resources/Licenses/LICENSE`), et c'est bien la MPL-2.0.
- [ ] `codesign --verify --deep --strict` passe sur le bundle final. Ce
      contrôle-là ne dit rien de l'archive : l'aller-retour sur le ZIP est à
      « Distribution ».
- [ ] Commit ayant produit le binaire identifié sans ambiguïté, et tag posé
      exactement dessus.

## La règle du couple — profils d'exemple

> **Gelés pour la 1.0.0.** Aucun changement de valeurs, de noms de fichiers, de
> noms de profils ni de `schema_version` pendant la préparation.

`Resources/profils-exemples/nonp.json` et `bandeau-colore.json` ne se modifient
jamais seuls. Toute modification de leur contenu engage **quatre choses
ensemble** :

- [ ] les deux fichiers eux-mêmes ;
- [ ] le préréglage en code `ProfilHabillage.bandeauColore` — `ControlesProfils`
      vérifie que chaque valeur des fichiers lui est identique, seuls le nom et
      l'absence de logo les distinguant ;
- [ ] les **images de référence**, que `ProductionImages` produit à partir de ce
      même préréglage en trois endroits ;
- [ ] `Resources/profils-exemples/LISEZ-MOI.md`, qui **décrit les valeurs en
      prose** — « bandeau bleu opaque qui épouse chaque ligne, texte blanc,
      contour noir, Arial ».

Les trois premiers points, un contrôle les rattrape. **Le quatrième, aucun.**
Le LISEZ-MOI ment en silence dès que les fichiers changent sans lui : c'est la
raison d'être de cette règle.

Sont figés au même titre : les deux noms de fichiers, les deux noms de profils
(`NONP` et `Bandeau coloré`), l'absence de logo, et le fait que les fichiers
soient déjà au schéma courant — une conversion détectée fait échouer le
contrôle.

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

Rien n'est publié à ce jour. Quand ce sera le cas, deux canaux, et l'ordre
compte : le tag d'abord, la distribution ensuite — un tag posé ne publie rien.

> ⛔ **UN ZIP PUBLIÉ NE SE RÉGÉNÈRE JAMAIS.** Son empreinte est publiée et le
> build n'est pas reproductible (horodatages, signature ad-hoc) : régénérer
> produit un fichier **différent** sous le même nom. Toute correction, **même
> d'une ligne**, impose une **version nouvelle** — bump, nouveau ZIP, nouvelle
> empreinte, page mise à jour.

Cette règle commande tout ce qui suit. Le reste de cette section vient du
retour d'expérience de la publication de NONP Transcription : chaque case y a
coûté un incident.

### Signature et archive (ce dépôt)

- [ ] Archive créée avec `ditto -c -k --sequesterRsrc --keepParent` — **jamais**
      `zip -r` : il casse liens symboliques et métadonnées, donc la signature du
      bundle, et l'utilisateur reçoit « l'application est endommagée ».
- [ ] **Une copie de `LICENSE` à la racine du ZIP**, en plus de celle déjà
      présente dans le bundle (`Contents/Resources/Licenses/LICENSE`) — par
      cohérence avec l'archive de NONP Transcription. Le point s'exécute à
      l'empaquetage : il ne modifie pas le bundle, donc pas `build_app.sh`.
- [ ] **Vérification aller-retour sur l'archive réellement produite** :
      décompresser le ZIP final, puis `codesign -v --deep --strict` **et** le
      Designated Requirement sur l'app **extraite**. Vérifier le bundle avant
      compression ne prouve rien sur l'archive.

### Texte de la page / README

- [ ] La page annonce **macOS 14 (Sonoma) minimum** *et* « **Apple Silicon
      requis — non compatible Mac Intel** ». Le binaire est arm64 uniquement
      (contrôle : `lipo -archs` sur chaque exécutable du bundle → `arm64` seul),
      et **rien dans le bundle ne le signale à l'utilisateur avant le
      téléchargement** : sans cette mention, un possesseur de Mac Intel
      télécharge une app qui ne s'ouvrira jamais et conclut qu'elle est cassée.
- [ ] **Aucun repli « clic droit → Ouvrir » présenté pour macOS 15 ou plus
      récent** : invalide depuis macOS 15 pour une app ad-hoc non notarisée.
      L'utilisateur qui l'essaie n'obtient rien, et conclut lui aussi que
      l'app est cassée. Le repli reste valide — et documenté — pour macOS 14.
- [ ] Libellés Gatekeeper vérifiés **en déroulant le parcours réel** avec le ZIP
      téléchargé depuis le site — jamais de mémoire : texte du premier
      avertissement, « Déplacer vers la corbeille », « Ouvrir quand même ».

### Release GitHub (après le tag)

- [ ] Release créée **sur le tag de version**, avec en asset l'archive ZIP
      **réellement validée**, et son empreinte SHA-256.
- [ ] Empreinte vérifiée **après téléversement** : re-télécharger, recalculer,
      comparer.
- [ ] Aucune release ayant distribué un binaire n'est supprimée.

### Publication sur nonp.fr (après le tag)

À dérouler **en une seule fois** : un site qui annonce une version et en sert
une autre est pire que pas de mise à jour du tout.

- [ ] Archive produite et vérifiée selon « Signature et archive » ci-dessus,
      nommée d'après la version.
- [ ] Empreinte SHA-256 calculée sur l'archive **réellement déposée**.
- [ ] `SHA256SUMS.txt` mis à jour.
- [ ] **Alias `-latest` repointé** vers la nouvelle archive. L'oublier laisse
      l'alias servir silencieusement la version précédente. Son contrôle est à
      « Mise en ligne » ci-dessous.
- [ ] Page de téléchargement : version affichée, nom du fichier (lien **et**
      `aria-label` **et** texte du bouton), poids, empreinte, bloc JSON-LD.
- [ ] Après déploiement : re-télécharger **depuis le site** et vérifier que
      l'empreinte correspond à celle annoncée.
- [ ] Archive de la version précédente retirée du dossier servi ; son empreinte
      reste au CHANGELOG.

### Mise en ligne

> ⚠️ Ces points s'exécutent **côté site** (`nonp-unified-src/`, déploiement
> depuis `nonp-unified-deploy/`), **pas dans ce dépôt**. La checklist les liste
> parce qu'ils conditionnent une publication réussie, pas parce qu'ils s'y font.

- [ ] `_headers` : `Content-Disposition: attachment` sur le `.zip` servi — évite
      les manipulations de Safari.
- [ ] `og:image` pointe vers la production, donc **invérifiable en preview**.
      Après mise en production : image en 200, puis « Scrape Again » sur le
      débogueur Facebook (compte connecté) — FB mémorise un 404 plusieurs jours.
- [ ] **Retrait ou purge d'un fichier** : le retirer du dossier ne le retire pas
      du site (il faut un déploiement), et le cache de bord le sert encore après
      le déploiement. Toute vérification de purge se fait **avec un paramètre
      anti-cache** (`?nocache=…` → `BYPASS`) ; sans lui, purge réussie et purge
      ratée sont indiscernables.
- [ ] **Avant déploiement : comparer le dossier servi à la production, pas à
      Git.** Le déploiement est tout ou rien : tout ce qui traîne part avec.
      Exclure de la comparaison les chemins derrière une authentification — ils
      renvoient la page de connexion, pas les fichiers.
- [ ] **Vérifier l'effet, jamais le message** : pas de `| grep` sur une sortie
      de build (il peut masquer un plantage), aucune confiance aux « ✓ » d'un
      outil (une option inexistante peut afficher l'aide et sortir en code 0).
      Contrôler l'état résultant.
- [ ] **Alias `-latest` : redirection 302**, jamais 301 — la cible change à
      chaque version et ne doit pas être mise en cache — et vérifier
      l'**empreinte du fichier servi via l'alias**, pas seulement le code de
      redirection.

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
