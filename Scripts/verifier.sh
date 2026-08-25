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
PROTOTYPE="$HOME/Developer/NONP-Habillage/nonp_habille.py"
LARGEUR=1920
HAUTEUR=1080

while [[ $# -gt 0 ]]; do
    case "$1" in
        --corpus)    CORPUS="$2"; shift 2 ;;
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

echo "▸ Compilation…"
swift build -c debug
BINAIRE="$(swift build -c debug --show-bin-path)/NONPHabillage"

ARGS=(--verifier)

if [[ -n "$CORPUS" ]]; then
    ARGS+=(--corpus "$CORPUS")

    if [[ -f "$PROTOTYPE" ]]; then
        echo "▸ Interrogation du prototype Python (lecture seule)…"
        # Le JSON contient le texte des sous-titres : dossier temporaire, effacé
        # en sortie, jamais dans l'arborescence du dépôt.
        TMP="$(mktemp -d -t nonp-habillage-parite)"
        trap 'rm -rf "$TMP"' EXIT
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
