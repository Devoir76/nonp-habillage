// swift-tools-version: 5.9
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Package.swift — description du projet pour Swift Package Manager.
//
// SwiftPM compile un exécutable en ligne de commande ; c'est Scripts/build_app.sh
// qui l'assemble ensuite en un véritable bundle .app lançable. Ce découpage
// évite d'exiger Xcode complet, comme dans NONP Transcription.
//
// INVARIANT nº3 (ADR-0001) : aucune dépendance non-Apple. Le tableau
// `dependencies` du package doit rester VIDE — pas de FFmpeg, pas de
// bibliothèque tierce, pas de gestionnaire de paquets. La licence cible étant
// MPL-2.0, toute dépendance GPL est exclue par construction. Le script de build
// vérifie mécaniquement cette absence à chaque compilation.

import PackageDescription

let package = Package(
    name: "NONPHabillage",
    // macOS 14 minimum, aligné sur NONP Transcription et sur LSMinimumSystemVersion.
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Cible exécutable = le binaire de l'application.
        .executableTarget(
            name: "NONPHabillage",
            path: "Sources/NONPHabillage"
        )
    ]
)
