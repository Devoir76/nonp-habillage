#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
# sdk_macos.sh — choisit un SDK macOS capable de compiler SwiftUI.
#
# ┌─ CONTOURNEMENT DATÉ — À RETIRER ─────────────────────────────────────────┐
# │ Constaté le 17/09/2026, Command Line Tools 27.0 (Swift 6.4), macOS 27.   │
# └──────────────────────────────────────────────────────────────────────────┘
#
# LA CAUSE. Le SDK macOS 27.0 déclare `@State` — et les autres propriétés
# SwiftUI — comme des MACROS, dont l'implémentation est un plugin de
# compilateur, `SwiftUIMacros`. Les Command Line Tools 27.0 livrent ce SDK mais
# pas ce plugin : une recherche sur tout le disque ne l'a trouvé nulle part, sur
# une machine sans Xcode. Toute compilation SwiftUI échoue alors sur :
#
#   external macro implementation type 'SwiftUIMacros.StateMacro' could not be
#   found for macro 'State()'; plugin for module 'SwiftUIMacros' not found
#
# Le code n'y est pour rien : `main` compilait le 07/09 et ne compile plus sans
# que rien n'ait changé dans le dépôt.
#
# LE CONTOURNEMENT. Les mêmes Command Line Tools installent aussi le SDK macOS
# 26.5, où `@State` n'est pas une macro. On vérifie donc d'abord que le SDK par
# défaut compile un fichier SwiftUI minimal ; s'il échoue SUR CETTE ERREUR-LÀ,
# on se replie sur le plus récent des autres SDK qui y parvient, et on le dit.
#
# CE QUE LE REPLI NE RÈGLE PAS — constaté le même jour. Le nouveau système de
# build de SwiftPM (Swift 6.4) compile bien contre le SDK 26.5, mais inscrit
# « sdk 14.0 » dans l'en-tête du binaire (LC_BUILD_VERSION), là où l'ancien
# inscrivait « sdk 26.5 ». macOS règle une partie de l'apparence d'AppKit sur
# cette valeur : un binaire marqué 14.0 tourne avec d'anciennes métriques —
# ascenseur permanent de 15 points au lieu de 17, accueil de 369 points au lieu
# de 377. Mesuré, avec le même code, sur les deux marquages. Ce n'est pas le
# choix du SDK qui en décide : c'est le système de build.
#
# QUAND LE RETIRER. Le jour où le script annonce « SDK par défaut… aucun
# contournement » — Command Line Tools corrigés, ou Xcode complet sélectionné —,
# ce fichier et ses deux appels (build_app.sh, verifier.sh) peuvent partir,
# avec la ligne du README.
#
# Usage, depuis un script du dossier :
#   source "$SCRIPT_DIR/sdk_macos.sh"
#   choisir_sdk_macos || exit 1
#
# SDKROOT déjà défini est respecté : il est éprouvé, jamais remplacé en silence.

# Compile — vérification des types seulement — un fichier SwiftUI qui utilise
# `@State`. Rend 0 si le SDK passe ; sinon écrit la sortie du compilateur dans
# le fichier donné en second argument.
_sonde_swiftui() {
    local sdk="$1" sortie="$2" source
    source="$(mktemp -t nonp-sonde-sdk).swift"
    cat > "$source" <<'SWIFT'
import SwiftUI
struct SondeSDK: View {
    @State private var n = 0
    var body: some View { Text("\(n)") }
}
SWIFT
    local rc=0
    xcrun swiftc -typecheck -sdk "$sdk" -target "$(uname -m)-apple-macosx14.0" \
        "$source" > "$sortie" 2>&1 || rc=$?
    rm -f "$source" "${source%.swift}"
    return "$rc"
}

# « macOS 26.5 » d'après le SDK lui-même.
_version_sdk() {
    local v
    v="$(plutil -extract Version raw "$1/SDKSettings.plist" 2>/dev/null)" || v="?"
    echo "macOS $v"
}

# L'erreur connue : un plugin de macro introuvable.
_erreur_de_macro() {
    grep -q "external macro implementation type .* could not be found" "$1"
}

choisir_sdk_macos() {
    echo "▸ Choix du SDK macOS…"
    local journal
    journal="$(mktemp -t nonp-sonde-sdk-journal)"

    # 1. SDKROOT imposé : on l'éprouve, on ne le remplace pas.
    if [[ -n "${SDKROOT:-}" ]]; then
        if _sonde_swiftui "$SDKROOT" "$journal"; then
            echo "  ✓ SDK imposé par SDKROOT : $(_version_sdk "$SDKROOT") ($SDKROOT)"
            rm -f "$journal"
            return 0
        fi
        echo "✗ SDKROOT désigne un SDK qui ne compile pas SwiftUI : $SDKROOT" >&2
        grep -m1 "error:" "$journal" | sed 's/^.*error: /error: /; s/^/    /' >&2
        echo "  Retirer SDKROOT pour laisser le script choisir, ou désigner un" >&2
        echo "  SDK macOS 26.x." >&2
        rm -f "$journal"
        return 1
    fi

    # 2. Le SDK par défaut.
    local defaut
    defaut="$(xcrun --sdk macosx --show-sdk-path)"
    if _sonde_swiftui "$defaut" "$journal"; then
        echo "  ✓ SDK par défaut : $(_version_sdk "$defaut") ($defaut) — aucun contournement"
        rm -f "$journal"
        return 0
    fi

    # Une autre erreur que celle qu'on sait contourner : ne rien masquer. La
    # compilation la montrera en entier.
    if ! _erreur_de_macro "$journal"; then
        echo "  ⚠️  La sonde SwiftUI échoue sur le SDK par défaut ($defaut)," >&2
        echo "     mais pas sur l'erreur de macro connue. Aucun repli :" >&2
        grep -m1 "error:" "$journal" | sed 's/^.*error: /error: /; s/^/     /' >&2
        rm -f "$journal"
        return 0
    fi

    echo "  ⚠️  SDK par défaut inutilisable : $(_version_sdk "$defaut") ($defaut)"
    echo "     Il déclare @State comme une macro, et ces Command Line Tools ne"
    echo "     livrent pas le plugin SwiftUIMacros qui l'implémente."

    # 3. Les autres SDK du même dossier : vrais dossiers seulement (les liens
    #    MacOSX.sdk, MacOSX27.sdk… désignent les mêmes), du plus récent au plus
    #    ancien.
    local dossier reel_defaut
    reel_defaut="$(cd "$defaut" && pwd -P)"
    dossier="$(dirname "$reel_defaut")"
    local candidats
    candidats="$(
        for sdk in "$dossier"/MacOSX*.sdk; do
            [[ -d "$sdk" && ! -L "$sdk" && "$sdk" != "$reel_defaut" ]] || continue
            printf '%s\t%s\n' "$(plutil -extract Version raw "$sdk/SDKSettings.plist" 2>/dev/null || echo 0)" "$sdk"
        done | sort -t. -k1,1nr -k2,2nr -k3,3nr | cut -f2
    )"

    local sdk
    while IFS= read -r sdk; do
        [[ -n "$sdk" ]] || continue
        if _sonde_swiftui "$sdk" "$journal"; then
            export SDKROOT="$sdk"
            echo "  ✓ Repli sur $(_version_sdk "$sdk") ($sdk) — sonde SwiftUI réussie"
            echo "     Contournement daté du 17/09/2026, à retirer quand le SDK par"
            echo "     défaut compilera de nouveau : voir Scripts/sdk_macos.sh."
            rm -f "$journal"
            return 0
        fi
    done <<< "$candidats"

    # 4. Rien d'utilisable : expliquer, et nommer les issues.
    cat >&2 <<MESSAGE
✗ Aucun SDK macOS ne permet de compiler SwiftUI sur cette machine.

  Le SDK par défaut ($(_version_sdk "$defaut")) déclare @State et les autres
  propriétés SwiftUI comme des macros. Leur implémentation, le plugin
  SwiftUIMacros, n'est pas livrée par ces Command Line Tools, et aucun autre
  SDK de $dossier
  ne compile SwiftUI. Le code du projet n'est pas en cause.

  Issues :
    1. Désigner un SDK macOS 26.x conservé ailleurs :
         SDKROOT=~/MacOSX26.5.sdk $0
    2. Installer Xcode complet, puis le sélectionner :
         sudo xcode-select -s /Applications/Xcode.app
    3. Installer des Command Line Tools qui livrent ce plugin, quand Apple
       les publiera.

  Détail : Scripts/sdk_macos.sh (contournement daté du 17/09/2026).
MESSAGE
    rm -f "$journal"
    return 1
}
