#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https:#mozilla.org/MPL/2.0/.
# images_reference.sh — fabrique les images que valide Éric au lot 3.
#
# Deux moteurs, la même réplique, le même instant :
#
#   1. le PROTOTYPE Python grave la vidéo avec ffmpeg-full + libass ;
#   2. le moteur NATIF peint le même habillage avec Core Text sur une image
#      extraite de la vidéo source ;
#   3. les deux images sont assemblées en une planche « côte à côte ».
#
# Le prototype est appelé en LECTURE SEULE, depuis son dossier, sans jamais
# être modifié (invariant nº5). Il lui faut ffmpeg-full — la version avec
# libass — qui n'est PAS embarquée et ne le sera jamais : c'est tout l'objet de
# l'ADR-0001. Ce script est un outil de comparaison, pas un morceau de l'app.
#
# Le logo est écarté des deux côtés (--no-logo) : le lot 3 juge le RENDU DU
# TEXTE. L'incrustation du logo appartient au lot 4.
#
# Usage :
#   ./Scripts/images_reference.sh --sortie <dossier> \
#       --source 16-9 <video.mp4> <sous-titres.srt> \
#       --source 9-16 <video.mp4> <sous-titres.srt>
#
#   --sans-prototype   n'appelle pas le Python (rendus natifs seuls, rapide)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

PROTOTYPE="$HOME/Developer/NONP-Habillage/nonp_habille.py"
SORTIE="$PROJECT_ROOT/Images-reference"
AVEC_PROTOTYPE="oui"
ETIQUETTES=(); VIDEOS=(); SRTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sortie)          SORTIE="$2"; shift 2 ;;
        --prototype)       PROTOTYPE="$2"; shift 2 ;;
        --sans-prototype)  AVEC_PROTOTYPE="non"; shift ;;
        --source)
            [[ $# -ge 4 ]] || { echo "--source attend : étiquette vidéo sous-titres" >&2; exit 1; }
            ETIQUETTES+=("$2"); VIDEOS+=("$3"); SRTS+=("$4"); shift 4 ;;
        *) echo "Option inconnue : $1" >&2; exit 1 ;;
    esac
done

if [[ ${#ETIQUETTES[@]} -eq 0 ]]; then
    echo "Aucune source. Voir l'en-tête du script pour l'usage." >&2
    exit 1
fi

for i in "${!VIDEOS[@]}"; do
    [[ -f "${VIDEOS[$i]}" ]] || { echo "✗ Vidéo introuvable : ${VIDEOS[$i]}" >&2; exit 1; }
    [[ -f "${SRTS[$i]}" ]]   || { echo "✗ Sous-titres introuvables : ${SRTS[$i]}" >&2; exit 1; }
done

echo "▸ Compilation…"
swift build -c release
BINAIRE="$(swift build -c release --show-bin-path)/NONPHabillage"

ARGS=(--images "$SORTIE")

if [[ "$AVEC_PROTOTYPE" == "oui" ]]; then
    # ffmpeg-full : la seule build qui embarque libass, donc la seule capable
    # de graver un ASS. Le ffmpeg ordinaire de Homebrew ne suffit pas.
    FFMPEG=""
    for c in /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg /usr/local/opt/ffmpeg-full/bin/ffmpeg; do
        if [[ -x "$c" ]] && "$c" -hide_banner -filters 2>/dev/null | grep -q libass; then
            FFMPEG="$c"; break
        fi
    done
    if [[ -z "$FFMPEG" ]]; then
        echo "  ⚠️  Aucun ffmpeg avec libass — le côte à côte est impossible."
        echo "     Les rendus natifs seront produits seuls."
        AVEC_PROTOTYPE="non"
    elif [[ ! -f "$PROTOTYPE" ]]; then
        echo "  ⚠️  Prototype introuvable ($PROTOTYPE) — côte à côte impossible."
        AVEC_PROTOTYPE="non"
    fi
fi

TMP="$(mktemp -d -t nonp-habillage-images)"
trap 'rm -rf "$TMP"' EXIT

for i in "${!ETIQUETTES[@]}"; do
    ARGS+=(--source "${ETIQUETTES[$i]}" "${VIDEOS[$i]}" "${SRTS[$i]}")

    if [[ "$AVEC_PROTOTYPE" == "oui" ]]; then
        RENDU="$TMP/${ETIQUETTES[$i]}-prototype.mp4"
        echo "▸ Gravure par le prototype : ${ETIQUETTES[$i]} — cela prend une minute ou deux…"
        # PYTHONDONTWRITEBYTECODE : aucun .pyc ne doit apparaître dans le
        # dossier du prototype, qui doit ressortir bit pour bit identique.
        PYTHONDONTWRITEBYTECODE=1 python3 "$PROTOTYPE" \
            "${VIDEOS[$i]}" "${SRTS[$i]}" \
            --no-logo --ffmpeg "$FFMPEG" --out "$RENDU"
        ARGS+=(--prototype-rendu "$RENDU")
    fi
done

echo
"$BINAIRE" "${ARGS[@]}"
