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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus)    CORPUS="$2"; shift 2 ;;
        --video)     VIDEO="$2"; shift 2 ;;
        --prototype) PROTOTYPE="$2"; shift 2 ;;
        --largeur)   LARGEUR="$2"; shift 2 ;;
        --hauteur)   HAUTEUR="$2"; shift 2 ;;
        *) echo "Option inconnue : $1" >&2; exit 1 ;;
    esac
done

# Corpus par défaut : ./Corpus s'il existe. Ce dossier n'est jamais versionné —
# le .gitignore exclut les sous-titres par principe, y compris ceux de test.
if [[ -z "$CORPUS" && -d "$PROJECT_ROOT/Corpus" ]]; then
    CORPUS="$PROJECT_ROOT/Corpus"
fi

# SDK macOS — contournement daté du 17/09/2026 : les Command Line Tools 27.0
# livrent un SDK qui ne compile pas SwiftUI sans Xcode. Voir Scripts/sdk_macos.sh.
source "$SCRIPT_DIR/sdk_macos.sh"
choisir_sdk_macos || exit 1

echo "▸ Compilation…"
swift build -c debug
BINAIRE="$(swift build -c debug --show-bin-path)/NONPHabillage"

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
if [[ -f "$PROTOTYPE" ]]; then
    echo "▸ Profils écrits par l'app, relus par le prototype…"
    TMP_PROFILS="$(mktemp -d -t nonp-habillage-profils)"
    trap 'rm -rf "$TMP_PROFILS"' EXIT
    "$BINAIRE" --profils "$TMP_PROFILS" > /dev/null
    python3 "$SCRIPT_DIR/profils_python.py" \
        --profils "$TMP_PROFILS" --prototype "$PROTOTYPE"
else
    echo "  ⚠️  Prototype introuvable ($PROTOTYPE) — relecture des profils non"
    echo "     exécutée. C'est la moitié du critère d'acceptation du lot 6."
fi

if [[ -n "$CORPUS" ]]; then
    ARGS+=(--corpus "$CORPUS")

    if [[ -f "$PROTOTYPE" ]]; then
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
    else
        echo "  ⚠️  Prototype introuvable ($PROTOTYPE) — parité non exécutée."
    fi
else
    echo "  ⚠️  Aucun corpus — fidélité sur corpus réel et parité non exécutées."
    echo "     Passer --corpus <dossier de .srt/.vtt> pour les activer."
fi

echo
"$BINAIRE" "${ARGS[@]}"
