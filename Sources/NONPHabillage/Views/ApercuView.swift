// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// ApercuView.swift — l'image fixe habillée, et le logo qu'on y déplace.
//
// Aucun encodage : l'aperçu est recalculé par `Engine/Apercu`, qui emploie
// exactement le même code que l'export. Ce qu'on voit est ce qu'on obtiendra.
//
// Le déplacement du logo se fait en FRACTIONS de l'image, jamais en pixels
// d'écran : l'aperçu est affiché plus petit que la vidéo, et le profil doit
// enregistrer une position relative — sans quoi le même profil ne vaudrait plus
// rien sur une vidéo d'une autre définition.

import SwiftUI
import CoreGraphics

struct ApercuView: View {

    @EnvironmentObject private var etat: AppState

    var body: some View {
        VStack(spacing: 8) {
            imageOuAttente
            avertissements
            barreDeChoix
        }
    }

    // MARK: - L'image

    @ViewBuilder
    private var imageOuAttente: some View {
        GeometryReader { geo in
            ZStack {
                if let apercu = etat.apercu {
                    let taille = tailleAffichee(image: apercu, dans: geo.size)
                    Image(decorative: apercu, scale: 1)
                        .resizable()
                        .frame(width: taille.width, height: taille.height)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(alignment: .topLeading) {
                            poigneeLogo(image: apercu, affichee: taille)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if etat.apercuEnPreparation {
                    ProgressView(Textes.Interface.chargementApercu)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.08))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // Aucune hauteur imposée : l'aperçu prend toute la place que la colonne
        // de gauche lui laisse, et grandit avec la fenêtre. C'est `tailleAffichee`
        // qui garantit que l'IMAGE ENTIÈRE y tient, sans recadrage.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// La zone saisissable du logo, superposée à l'aperçu.
    ///
    /// Elle épouse le rectangle réel du logo : on attrape ce qu'on voit.
    @ViewBuilder
    private func poigneeLogo(image: CGImage, affichee: CGSize) -> some View {
        if let rect = etat.rectangleLogo {
            let echelle = affichee.width / CGFloat(image.width)
            // Le rectangle vient de Core Graphics (origine en bas) ; SwiftUI
            // compte depuis le haut.
            let x = rect.minX * echelle
            let y = (CGFloat(image.height) - rect.maxY) * echelle
            let l = rect.width * echelle
            let h = rect.height * echelle

            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: max(l, 24), height: max(h, 24))
                .offset(x: x, y: y)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.9),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: max(l, 24), height: max(h, 24))
                        .offset(x: x, y: y)
                        .allowsHitTesting(false)
                )
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .named("apercu"))
                        .onChanged { valeur in
                            etat.deplacerLogo(versFraction: CGPoint(
                                x: valeur.location.x / affichee.width,
                                y: valeur.location.y / affichee.height))
                        }
                )
                .help(Textes.Interface.deplacerLogo)
        }
    }

    private func tailleAffichee(image: CGImage, dans zone: CGSize) -> CGSize {
        Apercu.tailleAffichee(
            image: CGSize(width: image.width, height: image.height), dans: zone)
    }

    // MARK: - Avertissements

    @ViewBuilder
    private var avertissements: some View {
        if !etat.avertissements.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(etat.avertissements) { a in
                    Label(a.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Choix du fond et de la réplique

    @ViewBuilder
    private var barreDeChoix: some View {
        HStack(spacing: 12) {
            if etat.fondsDisponibles.count > 1 {
                Picker(Textes.Interface.fondDeLApercu, selection: $etat.indexFond) {
                    ForEach(Array(etat.fondsDisponibles.enumerated()), id: \.offset) { i, f in
                        Text(nomDuFond(index: i, luminosite: f.luminosite)).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 210)
            }

            Spacer()

            if etat.repliques.isEmpty {
                Text(Textes.Interface.phraseDeReference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Button {
                        etat.indexReplique = max(0, etat.indexReplique - 1)
                    } label: { Image(systemName: "chevron.left") }
                        .disabled(etat.indexReplique == 0)
                        .help(Textes.Interface.repliquePrecedente)

                    VStack(spacing: 0) {
                        Text(Textes.Interface.repliqueSur(
                            etat.indexReplique + 1, etat.repliques.count))
                            .font(.caption)
                        if etat.indexReplique == 0 {
                            Text(Textes.Interface.repliqueLaPlusLongue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150)

                    Button {
                        etat.indexReplique = min(etat.repliques.count - 1,
                                                 etat.indexReplique + 1)
                    } label: { Image(systemName: "chevron.right") }
                        .disabled(etat.indexReplique >= etat.repliques.count - 1)
                        .help(Textes.Interface.repliqueSuivante)
                }
            }
        }
    }

    /// Le plan le plus sombre et le plus clair sont nommés : ce sont eux qui
    /// tranchent une couleur de texte (ADR §2).
    private func nomDuFond(index: Int, luminosite: Double) -> String {
        let numero = "\(index + 1)/\(etat.fondsDisponibles.count)"
        if index == 0 { return "\(numero) — \(Textes.Interface.planSombre)" }
        if index == etat.fondsDisponibles.count - 1 {
            return "\(numero) — \(Textes.Interface.planClair)"
        }
        return numero
    }
}
