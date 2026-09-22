#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https:#mozilla.org/MPL/2.0/.
# verifier.sh — compile puis exécute tous les contrôles du moteur.
#
# Pourquoi pas `swift test` ? Parce qu'il n'existe pas ici : sur une machine
# équipée des seuls Command Line Tools, la chaîne Swift ne livre ni XCTest ni
# swift-testing. Les contrôles vivent donc dans l'exécutable, derrière
# `--verifier`, comme le `--selftest` de NONP Transcription.
#
# Usage :
#   ./Scripts/verifier.sh                       contrôles internes seuls
#   ./Scripts/verifier.sh --corpus <dossier>    + fidélité et parité sur un
#                                               corpus de sous-titres réels
#   ./Scripts/verifier.sh --video <fichier.mp4> + recopie de l'audio à l'export
#   ./Scripts/verifier.sh --corpus <d> --prototype <nonp_habille.py>
#   ./Scripts/verifier.sh --bundle <chemin.app> bundle à contrôler (défaut : dist/)
#
# La parité exige les deux : un corpus ET le prototype Python. Sans corpus, les
# rubriques concernées sont annoncées « non exécutées » — jamais passées sous
# silence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

CORPUS=""
VIDEO=""
PROTOTYPE="$HOME/Developer/NONP-Habillage/nonp_habille.py"
LARGEUR=1920
HAUTEUR=1080
BUNDLE="$PROJECT_ROOT/dist/NONP Habillage.app"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus)    CORPUS="$2"; shift 2 ;;
        --video)     VIDEO="$2"; shift 2 ;;
        --prototype) PROTOTYPE="$2"; shift 2 ;;
        --largeur)   LARGEUR="$2"; shift 2 ;;
        --hauteur)   HAUTEUR="$2"; shift 2 ;;
        --bundle)    BUNDLE="$2"; shift 2 ;;
        *) echo "Option inconnue : $1" >&2; exit 1 ;;
    esac
done

# Corpus par défaut : ./Corpus s'il existe. Ce dossier n'est jamais versionné —
# le .gitignore exclut les sous-titres par principe, y compris ceux de test.
if [[ -z "$CORPUS" && -d "$PROJECT_ROOT/Corpus" ]]; then
    CORPUS="$PROJECT_ROOT/Corpus"
fi

# SDK macOS et système de build — contournement daté du 17/09/2026. Voir
# Scripts/sdk_macos.sh.
source "$SCRIPT_DIR/sdk_macos.sh"
choisir_sdk_macos || exit 1

echo "▸ Compilation…"
swift build -c debug "${OPTIONS_SWIFT_BUILD[@]}"
BINAIRE="$(swift build -c debug "${OPTIONS_SWIFT_BUILD[@]}" --show-bin-path)/NONPHabillage"
# Un binaire mal marqué mesurerait sous d'autres métriques : les contrôles de
# disposition ne vaudraient rien.
verifier_marquage_sdk "$BINAIRE" || exit 1

ARGS=(--verifier)

# La recopie de l'audio ne se contrôle que sur une vraie piste : sans vidéo
# fournie, la rubrique s'annonce « non exécutée ».
if [[ -n "$VIDEO" ]]; then
    ARGS+=(--video "$VIDEO")
else
    echo "  ⚠️  Aucune vidéo — recopie de l'audio non contrôlée (--video <fichier>)."
fi

# ── Le contrat partagé, éprouvé DANS LES DEUX SENS ──────────────────────────
#
# Critère d'acceptation du lot 6. Le premier sens — un profil du prototype lu
# par l'app — se contrôle en Swift (`ControlesProfils`). Le second — un profil
# de l'app relu par le prototype — ne le peut pas : seul le prototype sait ce
# qu'il accepte. L'app écrit donc des profils, et le prototype les relit.
# LECTURE SEULE : rien n'est écrit dans le dossier du prototype (invariant nº5).
# ⚠️ DEUX conditions, pas une. Le garde ne testait que le prototype : les
# scripts de comparaison ayant été retirés du dépôt le 20/09 (ils pointent un
# chemin local et un prototype non publié), un clone sur une machine QUI A le
# prototype appelait un fichier absent — `set -e`, code 2, et le harnais
# mourait AVANT d'exécuter le moindre contrôle Swift. Mesuré, pas supposé.
if [[ -f "$PROTOTYPE" && -f "$SCRIPT_DIR/profils_python.py" ]]; then
    echo "▸ Profils écrits par l'app, relus par le prototype…"
    TMP_PROFILS="$(mktemp -d -t nonp-habillage-profils)"
    trap 'rm -rf "$TMP_PROFILS"' EXIT
    "$BINAIRE" --profils "$TMP_PROFILS" > /dev/null
    python3 "$SCRIPT_DIR/profils_python.py" \
        --profils "$TMP_PROFILS" --prototype "$PROTOTYPE"
elif [[ ! -f "$SCRIPT_DIR/profils_python.py" ]]; then
    echo "  ⚠️  Scripts/profils_python.py absent — relecture des profils non"
    echo "     exécutée. C'est la moitié du critère d'acceptation du lot 6."
    echo "     Ce script ne fait pas partie du dépôt public : il compare à un"
    echo "     prototype non publié."
else
    echo "  ⚠️  Prototype introuvable ($PROTOTYPE) — relecture des profils non"
    echo "     exécutée. C'est la moitié du critère d'acceptation du lot 6."
fi

if [[ -n "$CORPUS" ]]; then
    ARGS+=(--corpus "$CORPUS")

    if [[ -f "$PROTOTYPE" && -f "$SCRIPT_DIR/parite_python.py" ]]; then
        echo "▸ Interrogation du prototype Python (lecture seule)…"
        # Le JSON contient le texte des sous-titres : dossier temporaire, effacé
        # en sortie, jamais dans l'arborescence du dépôt.
        TMP="$(mktemp -d -t nonp-habillage-parite)"
        # Un seul `trap` : le second effacerait le premier, et le dossier des
        # profils resterait derrière.
        trap 'rm -rf "$TMP" "${TMP_PROFILS:-}"' EXIT
        REFERENCE="$TMP/or-python.json"
        python3 "$SCRIPT_DIR/parite_python.py" \
            --corpus "$CORPUS" --sortie "$REFERENCE" \
            --prototype "$PROTOTYPE" --largeur "$LARGEUR" --hauteur "$HAUTEUR"
        ARGS+=(--or-python "$REFERENCE")
    elif [[ ! -f "$SCRIPT_DIR/parite_python.py" ]]; then
        echo "  ⚠️  Scripts/parite_python.py absent — parité non exécutée."
        echo "     Ce script ne fait pas partie du dépôt public : il compare à"
        echo "     un prototype non publié."
    else
        echo "  ⚠️  Prototype introuvable ($PROTOTYPE) — parité non exécutée."
    fi
else
    echo "  ⚠️  Aucun corpus — fidélité sur corpus réel et parité non exécutées."
    echo "     Passer --corpus <dossier de .srt/.vtt> pour les activer."
fi

echo
SORTIE_SWIFT="$(mktemp -t nonp-habillage-harnais)"
set +e
"$BINAIRE" "${ARGS[@]}" | tee "$SORTIE_SWIFT"
CODE_SWIFT=${PIPESTATUS[0]}
set -e

# ── Contrôles du SCRIPT, sur le bundle assemblé ─────────────────────────────
#
# Le binaire nu ne voit pas son bundle : ce qui ne vit que dans le bundle se
# contrôle ici. Mesuré le 22/09 au contrôle 6 — sans langue déclarée dans
# l'Info.plist, macOS affichait en anglais les menus qu'il fournit, et le
# harnais était vert. Ces contrôles COMPTENT dans le total, comme les autres.
REUSSIS_SCRIPT=0; ECHECS_SCRIPT=0; NON_EXEC_SCRIPT=0
echo
echo "▸ Bundle — la langue déclarée est le français"
if [[ -f "$BUNDLE/Contents/Info.plist" ]]; then
    REGION=$(plutil -extract CFBundleDevelopmentRegion raw "$BUNDLE/Contents/Info.plist" 2>/dev/null || true)
    LANGUES=$(plutil -extract CFBundleLocalizations json -o - "$BUNDLE/Contents/Info.plist" 2>/dev/null || true)
    if [[ "$REGION" == "fr" ]] && grep -q '"fr"' <<< "$LANGUES"; then
        echo "  ✓ l'Info.plist du bundle déclare le français (région et langues)"
        REUSSIS_SCRIPT=$((REUSSIS_SCRIPT + 1))
    else
        echo "  ✗ l'Info.plist du bundle ne déclare pas le français" \
             "(région « ${REGION:-absente} », langues ${LANGUES:-absentes})"
        ECHECS_SCRIPT=$((ECHECS_SCRIPT + 1))
    fi
else
    echo "  — non exécuté : aucun bundle à $BUNDLE (lancer ./Scripts/build_app.sh)"
    NON_EXEC_SCRIPT=$((NON_EXEC_SCRIPT + 1))
fi

# ── Un seul total ───────────────────────────────────────────────────────────
TOTAL_SWIFT=$(grep -oE '[0-9]+ contrôles réussis|sur [0-9]+ contrôles' "$SORTIE_SWIFT" \
              | grep -oE '[0-9]+' | tail -1 || true)
ECHECS_SWIFT=$(grep -oE '[0-9]+ échec\(s\) sur' "$SORTIE_SWIFT" | grep -oE '^[0-9]+' | tail -1 || true)
NON_EXEC_SWIFT=$(grep -oE '[0-9]+ rubrique\(s\) non exécutée' "$SORTIE_SWIFT" | grep -oE '^[0-9]+' | tail -1 || true)
rm -f "$SORTIE_SWIFT"
TOTAL_SWIFT=${TOTAL_SWIFT:-0}; ECHECS_SWIFT=${ECHECS_SWIFT:-0}; NON_EXEC_SWIFT=${NON_EXEC_SWIFT:-0}
REUSSIS=$(( TOTAL_SWIFT - ECHECS_SWIFT + REUSSIS_SCRIPT ))
ECHECS=$(( ECHECS_SWIFT + ECHECS_SCRIPT ))
NON_EXEC=$(( NON_EXEC_SWIFT + NON_EXEC_SCRIPT ))
echo
echo "══════════════════════════════════════════════════════════════════"
echo "Total, contrôles du script compris : $REUSSIS réussi(s) · $ECHECS échec(s) · $NON_EXEC non exécuté(s)"
if [[ "$CODE_SWIFT" -ne 0 || "$ECHECS" -ne 0 ]]; then exit 1; fi
