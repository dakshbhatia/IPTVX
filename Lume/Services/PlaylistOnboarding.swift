//
//  PlaylistOnboarding.swift
//  Lume
//
//  The small, shared write path used when a provider is added. Keeping this
//  outside SwiftUI makes the same onboarding behavior available on every
//  platform and gives it a direct persistence test.
//

import Foundation
import SwiftData

@MainActor
enum PlaylistOnboarding {
    /// Adds an M3U source to the local catalog. Network import deliberately
    /// happens later through `ContentSyncManager`, where users can see progress
    /// and receive a useful provider/import error.
    static func addM3U(
        name: String,
        playlistURL: String,
        epgURL: String,
        in context: ModelContext
    ) throws -> Playlist {
        let normalizedURL = M3UClient.normalizedPlaylistURL(
            playlistURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard let url = URL(string: normalizedURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "file"].contains(scheme)
        else {
            throw M3UError.invalidURL
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEPGURL = epgURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = Playlist(
            name: trimmedName.isEmpty ? "My Playlist" : trimmedName,
            m3uURL: normalizedURL,
            epgURL: trimmedEPGURL
        )
        try persist(playlist, in: context)
        return playlist
    }

    /// Persists a newly-added playlist and its derived guide source together.
    static func persist(_ playlist: Playlist, in context: ModelContext) throws {
        context.insert(playlist)
        _ = EPGSourceReconciler.apply(playlist, in: context)
        try context.save()
    }
}
