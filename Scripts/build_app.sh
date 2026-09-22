#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
# build_app.sh — compile l'app avec SwiftPM et l'assemble en bundle .app.
#
# Pourquoi ce script ? Sans Xcode complet, SwiftPM produit seulement un binaire
# en ligne de commande. macOS a besoin d'un bundle « .app » (dossier structuré
# avec Info.plist) pour lancer une vraie application graphique. Ce script fait
# le pont : il vérifie les invariants, compile, crée la structure du bundle,
# y place le binaire, l'Info.plist et le texte de licence, signe, puis
# (optionnellement) lance l'app.
#
# Calqué sur Scripts/build_app.sh de NONP Transcription, moins tout ce qui
# concernait les binaires embarqués (ffmpeg, whisper) : ici il n'y en a aucun,
# et il ne doit jamais y en avoir — c'est l'invariant nº3.
#
# Usage :
#   ./Scripts/build_app.sh            → build de TEST (identifiant .test) dans dist/
#   ./Scripts/build_app.sh --run      → idem puis lance l'application
#   ./Scripts/build_app.sh --debug    → compilation debug (plus rapide)
#   ./Scripts/build_app.sh --release  → build de PRODUCTION (identifiant normal)
#
# Pourquoi deux identifiants ?
# Deux bundles portant le MÊME CFBundleIdentifier sont indiscernables pour
# LaunchServices : macOS lance alors la copie de /Applications même quand on
# double-clique sur celle de dist/, et ce silencieusement. La build de test
# reçoit donc « com.nonp.habillage.test » pour rester totalement indépendante
# d'une version installée. --release conserve l'identifiant de production
# (à utiliser uniquement pour installer une version de référence).

set -euo pipefail

# --- Emplacements ---------------------------------------------------------
# Racine du projet = dossier parent de ce script (robuste aux espaces du chemin).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="NONP Habillage"          # nom affiché du bundle
EXECUTABLE_NAME="NONPHabillage"    # doit correspondre à CFBundleExecutable
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

# --- Options --------------------------------------------------------------
CONFIG="release"
DO_RUN="no"
FLAVOR="test"                      # test (défaut) | production
for arg in "$@"; do
    case "$arg" in
        --run)     DO_RUN="yes" ;;
        --debug)   CONFIG="debug" ;;
        --release) FLAVOR="production" ;;
        *) echo "Option inconnue : $arg" >&2; exit 1 ;;
    esac
done

# Identifiant appliqué au bundle selon le type de build.
if [[ "$FLAVOR" == "test" ]]; then
    BUNDLE_ID="com.nonp.habillage.test"
else
    BUNDLE_ID="com.nonp.habillage"
fi

# --- 1) Garde-fou : aucune dépendance non-Apple ---------------------------
# Invariant nº3 (ADR-0001). Une dépendance externe introduite par mégarde
# rouvrirait le chantier licences refermé le 12/08 : la cible est MPL-2.0, et
# une bibliothèque GPL contaminerait le binaire distribué. La vérification est
# mécanique plutôt que documentaire, parce qu'un ajout de dépendance passe
# autrement inaperçu jusqu'à la publication.
echo "▸ Vérification des dépendances (invariant nº3)…"
DEPS_JSON="$(mktemp -t nonp-habillage-deps)"
trap 'rm -f "$DEPS_JSON"' EXIT
swift package show-dependencies --format json > "$DEPS_JSON"
DEP_COUNT="$(plutil -extract dependencies raw -o - "$DEPS_JSON")"
if [[ "$DEP_COUNT" != "0" ]]; then
    echo "✗ $DEP_COUNT dépendance(s) externe(s) déclarée(s) dans Package.swift :" >&2
    swift package show-dependencies >&2
    echo "  L'invariant nº3 l'interdit (aucune dépendance non-Apple, licence MPL-2.0)." >&2
    echo "  Lever cet interdit demande un nouvel ADR, pas un commit." >&2
    exit 1
fi
echo "  ✓ aucune dépendance externe — frameworks Apple uniquement"

# --- 1 bis) SDK macOS — contournement daté du 17/09/2026 -----------------
# Les Command Line Tools 27.0 livrent un SDK qui ne compile pas SwiftUI sans
# Xcode, et le système de build décide du marquage du binaire — donc des
# métriques d'AppKit. Le détail, la cause et quand le retirer :
# Scripts/sdk_macos.sh.
source "$SCRIPT_DIR/sdk_macos.sh"
choisir_sdk_macos || exit 1

# --- 2) Compilation SwiftPM ----------------------------------------------
echo "▸ Compilation ($CONFIG)…"
swift build -c "$CONFIG" "${OPTIONS_SWIFT_BUILD[@]}"

BUILD_BIN="$(swift build -c "$CONFIG" "${OPTIONS_SWIFT_BUILD[@]}" --show-bin-path)/$EXECUTABLE_NAME"
if [[ ! -f "$BUILD_BIN" ]]; then
    echo "✗ Binaire introuvable : $BUILD_BIN" >&2
    exit 1
fi
verifier_marquage_sdk "$BUILD_BIN" || exit 1

# --- 3) Assemblage du bundle .app ----------------------------------------
echo "▸ Assemblage du bundle…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_BIN" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Applique l'identifiant correspondant au type de build (avant signature).
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP_BUNDLE/Contents/Info.plist"

# --- Garde de langue --------------------------------------------------------
# Mesuré le 22/09 au contrôle 6 : sans langue déclarée, macOS tient
# l'application pour anglaise et affiche en anglais les menus qu'il fournit —
# File, Edit, Window, Help. Aucun contrôle ne le voyait : le harnais tourne sur
# le binaire nu, jamais sur le bundle. La garde porte donc sur l'Info.plist du
# bundle ASSEMBLÉ, celui qui part dans le ZIP, et arrête la fabrication.
verifier_langue_francaise() {
    local plist="$1" region langues
    region=$(plutil -extract CFBundleDevelopmentRegion raw "$plist" 2>/dev/null || true)
    langues=$(plutil -extract CFBundleLocalizations json -o - "$plist" 2>/dev/null || true)
    if [[ "$region" != "fr" ]] || ! grep -q '"fr"' <<< "$langues"; then
        echo "✗ L'Info.plist du bundle ne déclare pas le français" >&2
        echo "  (CFBundleDevelopmentRegion = « ${region:-absent} »," \
             "CFBundleLocalizations = ${langues:-absent}) — build interrompue." >&2
        echo "  Sans cette déclaration, les menus fournis par macOS s'affichent" \
             "en anglais." >&2
        return 1
    fi
    echo "  ✓ langue déclarée : français (menus de macOS en français)"
}
verifier_langue_francaise "$APP_BUNDLE/Contents/Info.plist" || exit 1

# Icône de l'application. Elle reste à produire (décision d'Éric) : son absence
# ne doit pas casser la build, macOS affiche alors l'icône générique.
if [[ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "  ⚠️  Resources/AppIcon.icns absent — icône générique (icône à produire)."
fi

# --- 4) Texte de licence embarqué ----------------------------------------
# Aucune dépendance tierce ici, donc aucune obligation LGPL comme dans NONP
# Transcription : reste le texte MPL-2.0 de l'app elle-même. Source de vérité =
# le LICENSE du dépôt, copié au build. Aucune copie n'est maintenue dans
# Resources/ : elle divergerait en silence.
echo "▸ Copie du texte de licence…"
if [[ ! -s "$PROJECT_ROOT/LICENSE" ]]; then
    echo "✗ LICENSE manquant ou vide — build interrompue." >&2
    exit 1
fi
# --- Profils d'exemple ----------------------------------------------------
# Des fichiers à IMPORTER, pas des préréglages câblés dans l'application : un
# préréglage livré décrit une apparence, jamais une organisation (ADR §2,
# reformulé le 28/08/2026). Le bouton « Importer… » s'ouvre sur ce dossier.
if [[ -d "$PROJECT_ROOT/Resources/profils-exemples" ]]; then
    echo "▸ Copie des profils d'exemple…"
    rm -rf "$APP_BUNDLE/Contents/Resources/profils-exemples"
    cp -R "$PROJECT_ROOT/Resources/profils-exemples" \
          "$APP_BUNDLE/Contents/Resources/profils-exemples"
    echo "  ✓ $(ls "$PROJECT_ROOT/Resources/profils-exemples"/*.json 2>/dev/null | wc -l | tr -d ' ') profil(s) d'exemple"
fi

mkdir -p "$APP_BUNDLE/Contents/Resources/Licenses"
cp "$PROJECT_ROOT/LICENSE" "$APP_BUNDLE/Contents/Resources/Licenses/LICENSE"
echo "  ✓ MPL-2.0 embarquée"

# --- 5) Table de débogage : extraite, puis RETIRÉE du binaire --------------
# Mesuré le 21/09/2026 : le binaire livré portait 53 entrées de débogage
# « N_OSO », chacune un chemin absolu de la machine de compilation, avec le nom
# d'utilisateur et le dossier personnel. 109 occurrences de « /Users/ » au
# total, dont 106 porteuses du nom d'utilisateur. Rien dans le dépôt ne fuyait :
# la fuite était dans la FABRICATION, sur une surface que personne ne scannait.
#
# L'ordre compte, et il n'est pas interchangeable :
#   1. dsymutil  — extrait la table AVANT de la détruire, sinon elle est perdue
#   2. strip -S  — retire la table du binaire (mesuré : 109 → 3 « /Users/ »,
#                  53 → 0 entrées OSO, et les 3 restants sont des chemins
#                  d'exemple présents tels quels dans les sources publiques)
#   3. codesign  — EN DERNIER : strip invalide la signature, il le dit lui-même
#                  en avertissement. Signer avant, c'est livrer un bundle que
#                  macOS déclare « endommagé ».
#
# Le dSYM ne va NI dans dist/ NI dans le ZIP : il porte les mêmes chemins. Il
# vit hors dépôt, à côté des traces de session, pour pouvoir symboliser un
# rapport de plantage après coup.
DSYM_DIR="${NONP_DSYM_DIR:-$HOME/Developer/NONP-traces/dsym}"
BIN_APP="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

echo "▸ Extraction de la table de débogage…"
mkdir -p "$DSYM_DIR"
if dsymutil "$BIN_APP" -o "$DSYM_DIR/$EXECUTABLE_NAME-$FLAVOR.dSYM" 2>/dev/null; then
    echo "  ✓ dSYM conservé hors dépôt"
else
    echo "  ⚠️  dsymutil n'a rien produit — poursuite, le strip reste nécessaire"
fi

echo "▸ Retrait de la table de débogage…"
AVANT=$(LC_ALL=C grep -c '/Users/' "$BIN_APP" 2>/dev/null || echo 0)
strip -S "$BIN_APP"
APRES=$(LC_ALL=C grep -c '/Users/' "$BIN_APP" 2>/dev/null || echo 0)
OSO=$(nm -ap "$BIN_APP" 2>/dev/null | grep -c ' OSO ' || true)
echo "  ✓ lignes contenant « /Users/ » : $AVANT → $APRES · entrées OSO restantes : $OSO"
if [[ "$OSO" -ne 0 ]]; then
    echo "✗ La table de débogage n'a pas été retirée — build interrompue." >&2
    exit 1
fi

# --- 6) Signature ad-hoc --------------------------------------------------
# Signature locale « ad-hoc » : suffisante pour un usage personnel quotidien,
# évite les blocages Gatekeeper au lancement local. (Pas de compte développeur requis.)
# APRÈS le strip, jamais avant : voir l'ordre ci-dessus.
echo "▸ Signature ad-hoc…"
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || {
    echo "  (signature ad-hoc ignorée — non bloquant en local)"
}
codesign --verify --deep --strict "$APP_BUNDLE" 2>/dev/null || {
    echo "✗ Signature invalide après strip — build interrompue." >&2
    exit 1
}

VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_BUNDLE/Contents/Info.plist")
echo "✓ Application prête : $APP_BUNDLE"
if [[ "$FLAVOR" == "test" ]]; then
    echo "  ┌──────────────────────────────────────────────────────────────┐"
    echo "  │ BUILD DE TEST — version $VERSION — identifiant $BUNDLE_ID"
    echo "  │ Indépendante de toute version installée dans /Applications.   │"
    echo "  │ Ne PAS installer telle quelle : utiliser --release pour cela. │"
    echo "  └──────────────────────────────────────────────────────────────┘"
else
    echo "  ┌──────────────────────────────────────────────────────────────┐"
    echo "  │ BUILD DE PRODUCTION — version $VERSION — identifiant $BUNDLE_ID"
    echo "  │ Destinée à remplacer la version de référence (/Applications). │"
    echo "  └──────────────────────────────────────────────────────────────┘"
fi

# --- 6) Lancement optionnel ----------------------------------------------
if [[ "$DO_RUN" == "yes" ]]; then
    echo "▸ Lancement…"
    open "$APP_BUNDLE"
fi
