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
8. **Le jour du tag, juste avant de le poser** — quatre textes datent, et ils
   ne peuvent pas être justes avant ce moment :
   - **La date de l'entrée `[1.0.0]` du `CHANGELOG.md`** se fixe ici. L'entrée
     porte « non publiée » jusqu'à ce moment — un journal public qui affiche une
     date annonce une version téléchargeable, et il n'y en a aucune tant que le
     tag n'est pas posé. Remplacer « non publiée » par la date du jour.
   - **La phrase « Rien n'est encore publié »** du bloc « État du projet » du
     `README.md` est remplacée par l'état réel de la release. Vraie jusqu'ici,
     elle devient fausse à la seconde où le tag est poussé.
   - **Le commentaire de `Resources/Info.plist`** au-dessus de
     `CFBundleShortVersionString` — « Version 1.0.0, en préparation. Rien n'est
     publié. » — perd sa seconde phrase et cesse d'annoncer une préparation.
     Même famille que la précédente : vraie tant que le tag n'est pas posé.
   - **L'encadré « La première version n'est pas encore publiée »** de la
     section « Télécharger » du `README.md` se RETIRE. Il protège le visiteur
     d'un lien `releases/latest` vide ; le tag posé et la release créée, il
     devient faux à son tour.
   - **L'encart « About » du dépôt** : quand la page `/habillage` existera sur
     nonp.fr, resserrer le site de `https://nonp.fr` vers
     `https://nonp.fr/habillage`. Ce n'est pas un texte daté mais une
     imprécision qui se corrige au même moment.
   - **Sujet `privacy`, CONDITIONNEL.** Il n'est pas posé aujourd'hui : le
     dépôt porte `offline`, qui dit un fait mesuré — zéro appel réseau dans
     tout `Sources/` —, là où `privacy` dirait une intention que le `README.md`
     ne revendique pas. **Si** le README gagne la phrase « 100 % local, aucun
     accès réseau » que portera la page `/habillage`, **alors** le sujet
     s'ajoute, justifié par la documentation et non par une interprétation.
     L'ordre ne s'inverse jamais : **la métadonnée suit la documentation, qui
     suit le code.**
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

## Les vidéos de test — la recette, pour que rien ne se saute

> Le harnais exige une vidéo réelle pour trois rubriques. Sans elle, elles
> s'annoncent « non exécutées » — et une rubrique sautée n'est pas une rubrique
> réussie. **La rubrique du blanc de tête n'avait jamais tourné jusqu'au
> 20/09**, faute d'une source qui en porte un ; elle a échoué à sa première
> exécution. Une donnée manquante se fabrique : elle est ci-dessous.

- [ ] **Une vidéo ordinaire** pour la recopie de l'audio et le compte d'images.
      N'importe quel MP4 réel avec une piste son.
- [ ] **Une vidéo à blanc de tête**, que rien ne fournit naturellement. Elle se
      fabrique en deux commandes, depuis n'importe quelle source :

```sh
# 1. une base à espacement d'images RÉGULIER, audio RECOPIÉ
#    · -r fixe la cadence et régularise l'espacement
#    · -c:a copy est indispensable : réencoder en AAC ajoute ~0,024 s
#      d'amorçage, et le vide de l'audio ne vaut alors plus celui de la vidéo
ffmpeg -y -i <source.mp4> -t 8 -r 30 -c:v libx264 -preset ultrafast -g 48 \
       -c:a copy base-30.mp4

# 2. le vide de tête, posé sur LES DEUX PISTES par la liste d'édition
ffmpeg -y -itsoffset 0.5 -i base-30.mp4 -map 0:v -map 0:a -c copy \
       blanc-de-tete.mp4

# contrôle : les deux pistes doivent démarrer après zéro, À LA MÊME VALEUR
ffprobe -v error -show_entries stream=codec_type,start_time -of csv=p=0 \
        blanc-de-tete.mp4
#   attendu :  video,0.500000
#              audio,0.500000
```

⚠︎ **Les deux valeurs doivent être ÉGALES.** Si l'audio affiche 0,476 au lieu de
0,500, c'est qu'il a été réencodé quelque part : le vide effectif devient celui
de l'audio, par la règle du min, et la source n'éprouve plus le cas symétrique.
La première version de cette recette avait ce défaut — elle réencodait en AAC —
et produisait sans le dire des sources asymétriques.

⚠︎ **Les deux pistes, pas seulement la vidéo.** Un `-itsoffset` appliqué au seul
flux vidéo produit une source asymétrique : l'exportateur ne retire alors rien,
par la règle du min qui protège la synchronisation du son, et la sortie fait
bien la durée de la source. C'est voulu — mais cela ne met pas la rubrique à
l'épreuve de ce qu'elle mesure.

- [ ] Lancer le harnais avec les deux :
      `./Scripts/verifier.sh --corpus <dossier> --video blanc-de-tete.mp4`
- [ ] **Vérifier qu'il ne reste AUCUNE rubrique non exécutée.** Si l'une le
      reste, son motif nomme la donnée qui manque : la fabriquer, pas l'accepter.

**Ce que la campagne du 20/09 a établi**, sur des bases à espacement régulier :
16 sources croisant les offsets 0,3 / 0,5 / 0,7 / 1,0 s et les cadences
24 / 25 / 30 / 60 i/s, plus le cas symétrique exact. Le résidu de durée vaut
0,000 à 0,001 s et **ne croît ni avec l'offset ni avec la cadence**. C'est un
arrondi de frontière. La tolérance du contrôle vaut donc **une image**,
proportionnelle à la granularité du média, et non un seuil en secondes.

⚠︎ **Ce que la campagne ne couvre PAS, et qui reste ouvert.** Un extrait pris en
`-c copy` d'une vidéo réelle hérite de son espacement d'images irrégulier
— images manquantes, ordre de décodage entrelacé. Sur une telle source,
l'export rend une durée **supérieure de 0,1 s** à celle de l'entrée, à compte
d'images pourtant identique, et **cela ne dépend d'aucun blanc de tête** : le
même écart apparaît sur la source sans vide. Ce n'est donc pas un défaut de
traitement du blanc, mais une dérive de durée sur sources irrégulières, que
cette rubrique est seulement la première à rendre visible. **Non élucidé au
20/09.** Ne pas fabriquer les vidéos de test par `-c copy` d'un extrait tant que
ce point n'est pas tranché : on mesurerait deux choses à la fois.

## Le filet de détection des noms réels — il ne connaît que ce qu'on lui donne

> **Règle, née le 20/09 d'un angle mort.** Le filet avait été construit sur les
> noms trouvés dans le dépôt ce jour-là. Une campagne de mesure a ensuite
> employé **quatre sources nouvelles**, portant des noms de personnes et des
> intitulés du corpus — et un « zéro strict » obtenu avec l'ancien filet ne
> disait rien à leur sujet : **un filet ne peut pas attraper un nom qu'il ne
> connaît pas.** Le contrôle paraissait vert et ne regardait rien.

**Tout nom réel entrant dans une mesure, un banc d'essai ou une fixture
s'ajoute au filet LE JOUR MÊME**, avant la mesure si possible, sinon juste
après — et le scan des trois surfaces est rejoué avec le filet élargi.

⛔ **La liste des noms ne figure PAS dans ce dépôt, et ne doit jamais y
figurer.** L'écrire ici reviendrait à réintroduire en clair, dans un dépôt
public, exactement ce que la réécriture d'historique en a retiré — **le filet
deviendrait la fuite qu'il sert à détecter.** L'erreur a été commise le 20/09,
et c'est le scan lui-même qui l'a trouvée, en se signalant sur son propre
texte. Elle vient du réflexe sain de documenter ce qu'on vérifie : elle se
reproduira si rien ne la nomme.

La liste vit **hors du dépôt public**, dans les notes privées du projet :

```
NONP-traces/session-20260920/filet-noms-reels.txt
```

Ce qui se documente ici, c'est la MÉTHODE, jamais les unités :

- des unités **sans aucune espace**, insécables par un retour à la ligne —
  même raison qu'à la table de substitution ;
- **mesurées sans faux positif** avant d'entrer dans le filet, contre tous les
  blobs de tous les commits ;
- écartées si elles mordent un identifiant légitime, fût-ce une seule fois.

- [ ] **AVANT CHAQUE POUSSÉE — pas seulement la première.** Rejouer le scan
      des trois surfaces avec le filet complet, tenu hors dépôt, commits du
      jour inclus. Le dépôt est public depuis le 2026-09-20 : une erreur qui y
      arrive est définitive, et un `git push` ne se rattrape pas. Un force-push
      ne suffit pas — l'objet reste servi par son empreinte jusqu'au ramassage
      de GitHub, qu'on ne déclenche pas. Mesuré le 20/09 : après un force-push,
      le commit retiré rendait encore 19 672 octets et trois noms lisibles. Il
      a fallu supprimer le dépôt et le recréer.
- [ ] Vérifier que le scan SAIT VOIR avant de croire ses zéros : planter une
      aiguille sur une branche jetable, la faire trouver, puis la retirer. Un
      « zéro » par environnement cassé est indiscernable d'un « zéro » par
      absence — c'est arrivé le 20/09, une variable `path` écrasée en zsh ayant
      vidé le `PATH` au milieu d'un scan.

**Vérifié le 2026-09-20**, filet élargi aux quatre sources du banc de mesure :
zéro occurrence sur les trois surfaces. Les noms n'étaient jamais entrés — les
vidéos vivent hors de l'arborescence, et les messages de commit décrivent les
sources par leur provenance. C'est la bonne habitude : **nommer une source par
ce qu'elle est, pas par qui elle montre.**

## Vérifier ce que GitHub sert — présence et absence ne se mesurent pas pareil

Deux moitiés, et confondre les deux fait conclure à l'envers.

**Une PRÉSENCE se vérifie par l'API `contents`, jamais par
`raw.githubusercontent.com`.** Le CDN sert une version périmée pendant un
temps qu'on ne contrôle pas : un fichier fraîchement poussé y apparaît encore
sans sa modification. Mesuré le 2026-09-20 — `raw` rendait 6 411 octets quand
le fichier en faisait 6 514, et j'ai failli en conclure à une poussée
incomplète. L'API `contents` ne passe pas par ce cache et rendait déjà les
6 514 octets attendus.

**Une ABSENCE se vérifie sur les DEUX, CDN compris — et se revérifie plus
tard.** C'est la moitié qui compte, parce qu'elle est celle du jour où l'on
retire quelque chose qui ne doit plus être lisible. Le même cache qui retarde
une nouveauté **continue de servir ce qu'on vient d'effacer**. Un `raw` en 404
juste après le retrait ne prouve rien de durable ; un `raw` en 200 sur du
contenu retiré prouve, lui, que ce n'est pas fini.

- [ ] Présence : `api.github.com/repos/…/contents/<chemin>` — jamais `raw`.
- [ ] Absence : `contents`, **et** `raw.githubusercontent.com`, **et** l'accès
      par empreinte (`/commits/<sha>`), en requête **non authentifiée** — une
      session connectée voit un dépôt privé exactement comme un dépôt public.
- [ ] Absence : **recontrôler après quelques heures.** Le cache expire seul, et
      c'est seulement au second passage qu'on sait.

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

> ### ⚖️ Arbitrage en attente — le libellé Gatekeeper concerne DEUX pages
>
> Les deux applications voisineront sur le même site, et elles ne citent pas le
> même message système.
>
> - `/transcription`, **déjà publiée**, écrit : « macOS affiche *…ne peut pas
>   être ouverte car Apple ne peut pas vérifier…* ».
> - Le texte d'Habillage écrit : « un message dit qu'elle n'a pas pu être
>   vérifiée ».
>
> Les deux disent la même chose ; un seul peut être le libellé réel. Une copie
> de l'application a reçu l'attribut `com.apple.quarantine` le 20/09 pour qu'Éric
> déroule le vrai parcours et relève les mots exacts — c'est le contrôle nº 7 de
> la fiche de test.
>
> **Quand ce relevé existera, la vérité mesurée s'appliquera AUX DEUX PAGES.**
> Si `/transcription` s'écarte du dialogue réel, elle se corrige au même moment,
> bien qu'elle soit déjà en ligne : deux pages du même site qui décrivent
> différemment le même écran d'Apple, c'est l'une des deux qui se trompe.
>
> **Aucun des deux textes n'a été modifié** — ce sont ceux d'Éric. La correction
> lui sera proposée, il tranchera.

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
- [ ] **Les deux mentions de compatibilité, VERBATIM.** Reprises telles quelles
      de `/transcription`, déjà publiée et déjà relue, pour que les deux pages
      du site disent la chose d'une seule manière. À placer aux mêmes endroits :

      ligne 1, à côté du bouton de téléchargement —
      > pour macOS 14 (Sonoma) ou plus récent, Mac Apple Silicon (puce M1, M2, M3…)

      ligne 2, sous le poids du fichier —
      > Non compatible avec les Mac Intel.

      **Ce sont des citations, pas des modèles à reformuler.** Mesuré le
      2026-09-20 sur l'artefact publié de Transcription : ses trois binaires
      Mach-O — l'exécutable, FFmpeg et whisper-cli — sont `arm64` seul, et sa
      page l'annonce exactement ainsi. Habillage est dans le même cas, vérifié
      au `lipo` sur le bundle compilé. Rien à changer dans le `README.md` ni
      dans le `CHANGELOG.md` : ils portent déjà les deux informations côte à
      côte, jamais la version de macOS seule.
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
