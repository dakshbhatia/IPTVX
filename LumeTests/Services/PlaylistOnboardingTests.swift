import Foundation
@testable import Lume
import SwiftData
import Testing

@MainActor
struct PlaylistOnboardingTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Playlist.self, Category.self, EPGSource.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func `adds an M3U playlist and its optional guide source`() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let playlist = try PlaylistOnboarding.addM3U(
            name: "  Music  ",
            playlistURL: " https://example.com/music.m3u ",
            epgURL: " https://example.com/guide.xml ",
            in: context
        )

        let stored = try #require(try context.fetch(FetchDescriptor<Playlist>()).first)
        #expect(stored.id == playlist.id)
        #expect(stored.name == "Music")
        #expect(stored.sourceType == .m3u)
        #expect(stored.serverURL == "https://example.com/music.m3u")
        #expect(stored.epgURL == "https://example.com/guide.xml")

        let source = try #require(try context.fetch(FetchDescriptor<EPGSource>()).first)
        #expect(source.playlistID == playlist.id)
        #expect(source.url == "https://example.com/guide.xml")
    }

    @Test func `rejects a non URL M3U source`() throws {
        let context = ModelContext(try makeContainer())

        do {
            try PlaylistOnboarding.addM3U(
                name: "Broken",
                playlistURL: "not a URL",
                epgURL: "",
                in: context
            )
            Issue.record("Expected an invalid URL error")
        } catch let error as M3UError {
            guard case .invalidURL = error else {
                Issue.record("Expected invalidURL, got \(error.logDescription)")
                return
            }
        } catch {
            Issue.record("Expected M3UError.invalidURL, got \(error.localizedDescription)")
        }
    }
}
