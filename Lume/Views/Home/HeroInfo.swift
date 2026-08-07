//
//  HeroInfo.swift
//  Lume
//
//  The title / overview / action block overlaid on `HomeHeroCarousel` on iOS
//  and macOS, with a Details button. (tvOS renders its own hero surface
//  inside `TVHomeScreen`.)
//

import SwiftUI

// MARK: - Title / overview / buttons

struct HeroInfo: View {
    let hero: HeroItem
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitleLogo(
                url: hero.logoURL,
                title: hero.title,
                maxWidth: isCompact ? 280 : 470,
                maxHeight: isCompact ? 72 : 120
            ) {
                Text(hero.title)
                    .font(.system(size: isCompact ? 32 : 48, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .shadow(radius: 6)
            }

            if !hero.overview.isEmpty {
                Text(hero.overview)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.white.opacity(0.76))
                    .shadow(radius: 4)
            }

            actionButtons
                .controlSize(.large)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(.top, isCompact ? 12 : 36)
        .padding(.horizontal, isCompact ? 20 : 42)
        // Extra bottom inset so the button clears the page indicator instead
        // of colliding with it / clipping at the edge.
        .padding(.bottom, 56)
        // Cap the readable column on wide windows; fill when compact, pin leading.
        .frame(maxWidth: isCompact ? .infinity : 560, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        // Full-width when compact so the button spans the stacked layout.
        detailsButton(fullWidth: isCompact)
    }

    @ViewBuilder
    private func detailsButton(fullWidth: Bool) -> some View {
        if let movie = hero.movie {
            NavigationLink(value: movie) {
                detailsLabel(fullWidth: fullWidth)
            }
            .buttonStyle(.bordered)
            .tint(DBStreamVisual.primaryAction)
        } else if let series = hero.series {
            NavigationLink(value: series) {
                detailsLabel(fullWidth: fullWidth)
            }
            .buttonStyle(.bordered)
            .tint(DBStreamVisual.primaryAction)
        }
    }

    private func detailsLabel(fullWidth: Bool) -> some View {
        Label("Details", systemImage: "info.circle")
            .fontWeight(.semibold)
            .frame(maxWidth: fullWidth ? .infinity : nil)
    }
}

/// A single, restrained brand action colour. It is used only for deliberate
/// play/primary moments, leaving artwork and Liquid Glass surfaces uncluttered.
enum DBStreamVisual {
    static let primaryAction = Color(red: 0.92, green: 0.04, blue: 0.11)
}
