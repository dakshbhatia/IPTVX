# IPTVX Apple Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an open-source, native SwiftUI IPTV client with IPTVX-style Live TV, EPG, Movies, Series, metadata, profiles, downloads, and platform-adaptive experiences for iOS/iPadOS, macOS, and tvOS.

**Architecture:** Start from the approved Lume-inspired architecture but keep IPTVX code modular: source adapters feed a local SwiftData catalog, independent EPG/metadata services enrich it, and SwiftUI consumes platform-neutral models. Playback is isolated behind a `PlaybackEngine` protocol so AVPlayer can be shipped first and fallback engines can be added without changing catalog or UI code.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Foundation URLSession, CloudKit, AVFoundation/AVKit, XcodeGen, XCTest/Swift Testing, AVPlayer first with optional VLCKit or FFmpeg-based fallback after dependency validation.

## Global Constraints

- The app is a user-provided-content media client and ships no channels, playlists, subscriptions, or video content.
- The app reproduces functional IPTVX-style capabilities without copying proprietary code, branding, artwork, or pixel-perfect screens.
- Use one SwiftUI codebase with platform adapters for iOS/iPadOS, macOS, and tvOS.
- The initial deployment baseline follows the selected Lume foundation: iOS/tvOS 18 and macOS 15 unless the local Xcode/toolchain proves a lower baseline without significant rework.
- Provider credentials are stored in Keychain; raw passwords and full stream URLs must not appear in analytics or ordinary logs.
- Lume is AGPL-3.0; an IPTVX fork that incorporates its code remains AGPL-3.0 unless a separate licensing review changes the foundation.
- The original FFmpegKit repository is retired; AVPlayer is the first playback path and any fallback engine must pass license and device validation before inclusion.
- Long-running work is cancellable, reports typed progress, and never blocks the main actor.
- The local catalog remains useful when a provider or network is temporarily unavailable.

## File map

Create these boundaries before adding feature code:

- `project.yml`: XcodeGen project definition for iOS, macOS, and tvOS targets.
- `IPTVXApp/`: platform entry points, app assets, entitlements, and root composition.
- `IPTVXCore/Models/`: Sendable DTOs, normalized catalog models, and error types.
- `IPTVXCore/Sources/`: M3U/Xtream adapters, refresh orchestration, EPG, metadata, and playback contracts.
- `IPTVXCore/Stores/`: SwiftData catalog/profile stores and CloudKit abstraction.
- `IPTVXCore/Playback/`: AVPlayer implementation and engine fallback routing.
- `IPTVXUI/`: shared SwiftUI screens, components, navigation, and platform modifiers.
- `IPTVXUI/Platform/`: tvOS focus, macOS commands, iOS background/download behavior.
- `IPTVXTests/`: parser, catalog, EPG, metadata, profile, and playback contract tests.
- `IPTVXUITests/`: launch, import, browsing, playback handoff, profile, and focus tests.
- `Fixtures/`: anonymized M3U, Xtream JSON, XMLTV, and metadata fixtures used only for tests.
- `docs/`: approved design and implementation documentation.
- `THIRD-PARTY-NOTICES.md`: dependency licenses and attribution.

---

### Task 0: Make the Apple build environment usable

**Files:**
- None.

**Interfaces:**
- Consumes: macOS developer tools.
- Produces: Xcode 26.4 or newer selected as the active developer directory and XcodeGen available on `PATH`.

- [ ] **Step 1: Verify the current toolchain**

Run:

```bash
xcodebuild -version
xcode-select -p
xcodegen --version
```

Expected: `xcodebuild` reports Xcode 26.4 or newer, the selected path ends in `/Contents/Developer`, and `xcodegen` reports a version.

Current workspace evidence: `/Applications/Xcode.app` is absent and `xcodebuild` currently resolves only to Command Line Tools, so Apple target compilation cannot start until Xcode is installed and selected.

- [ ] **Step 2: Select the full Xcode toolchain**

After Xcode is installed, run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

Expected: `xcodebuild -version` succeeds without the Command Line Tools-only error.

- [ ] **Step 3: Install XcodeGen**

Run:

```bash
brew install xcodegen
xcodegen --version
```

Expected: a usable XcodeGen executable is available for deterministic project generation.

- [ ] **Step 4: Verify target destinations**

Run:

```bash
xcodebuild -showsdks
xcrun simctl list devices available
```

Expected: iOS, tvOS, and macOS SDKs are listed and at least one iPhone and Apple TV simulator is available.

---

### Task 1: Bootstrap the multi-platform project

**Files:**
- Create: `project.yml`
- Create: `IPTVXApp/IPTVXApp.swift`
- Create: `IPTVXApp/AppEnvironment.swift`
- Create: `IPTVXApp/Assets.xcassets/Contents.json`
- Create: `IPTVXApp/Preview Content/Preview Assets.xcassets/Contents.json`
- Create: `IPTVXCore/Models/AppError.swift`
- Create: `IPTVXUI/RootView.swift`
- Create: `THIRD-PARTY-NOTICES.md`
- Create: `IPTVXTests/SmokeTests.swift`

**Interfaces:**
- Consumes: XcodeGen and the platform SDKs from Task 0.
- Produces: `IPTVX` schemes for iOS, macOS, and tvOS; `RootView`; shared `AppEnvironment` dependency container.

- [ ] **Step 1: Write the smoke test**

Create `IPTVXTests/SmokeTests.swift`:

```swift
import Testing
@testable import IPTVXCore

@Test func appEnvironmentCanBeConstructed() {
    let environment = AppEnvironment.makePreview()
    #expect(environment.catalogStore != nil)
}
```

- [ ] **Step 2: Define the generated targets**

`project.yml` must define one shared source graph and three application targets. The iOS and tvOS targets use `com.iptvx.app` with platform-specific suffixes, while macOS uses `com.iptvx.app.macos`. All targets include `IPTVXCore` and `IPTVXUI`, enable Swift 6, and set the deployment targets from the global constraints.

- [ ] **Step 3: Add the minimal app composition**

`IPTVXApp.swift` creates `AppEnvironment.live()` and injects it into `RootView`. `RootView` displays a platform-neutral empty state with the title `IPTVX` and an `Add Playlist` action represented as a disabled control until Task 2 supplies the import flow.

- [ ] **Step 4: Generate and build the empty targets**

Run:

```bash
xcodegen generate
xcodebuild build -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild build -scheme IPTVX -destination 'platform=tvOS Simulator,name=Apple TV'
xcodebuild build -scheme IPTVX -destination 'platform=macOS'
```

Expected: all three builds succeed and the smoke test target compiles.

- [ ] **Step 5: Record the dependency inventory**

Add every non-system package and its license to `THIRD-PARTY-NOTICES.md`. Do not include a playback package until its license and target support are verified.

---

### Task 2: Implement M3U/M3U8 source ingestion

**Files:**
- Create: `IPTVXCore/Models/PlaylistModels.swift`
- Create: `IPTVXCore/Models/MediaKind.swift`
- Create: `IPTVXCore/Sources/M3U/M3UParser.swift`
- Create: `IPTVXCore/Sources/M3U/M3UAttributeParser.swift`
- Create: `IPTVXCore/Sources/Sources/PlaylistSource.swift`
- Create: `IPTVXCore/Sources/Sources/PlaylistFetcher.swift`
- Create: `Fixtures/m3u/standard.m3u`
- Create: `Fixtures/m3u/headers-catchup.m3u`
- Create: `IPTVXTests/M3UParserTests.swift`
- Create: `IPTVXTests/PlaylistFetcherTests.swift`

**Interfaces:**
- Consumes: `AppEnvironment` from Task 1.
- Produces: `M3UParser.parse(_:) throws -> [PlaylistEntry]`, `PlaylistFetcher.fetch(_:) async throws -> AsyncThrowingStream<PlaylistEntry, Error>`, and normalized `PlaylistEntry` values with headers, logos, groups, EPG ids, and catch-up metadata.

- [ ] **Step 1: Write parser tests for the required playlist variants**

```swift
@Test func parsesQuotedAttributesAndGroups() throws {
    let entries = try M3UParser().parse("""
    #EXTM3U
    #EXTINF:-1 tvg-id="news.us" tvg-name="News" tvg-logo="https://logo" group-title="News",News
    https://stream.example/news.m3u8
    """)

    #expect(entries.count == 1)
    #expect(entries[0].name == "News")
    #expect(entries[0].groupTitle == "News")
    #expect(entries[0].epgID == "news.us")
}

@Test func preservesCatchupTemplateAndHeaders() throws {
    let entries = try M3UParser().parse(contentsOf: fixture("headers-catchup.m3u"))
    #expect(entries[0].headers["User-Agent"] == "IPTVX-Test")
    #expect(entries[0].catchup?.days == 7)
}
```

- [ ] **Step 2: Run the parser tests and verify failure**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXTests/M3UParserTests
```

Expected: failure because the parser and fixture helpers do not exist.

- [ ] **Step 3: Implement streaming-safe parsing**

Implement `M3UParser` as a line-oriented parser. It must accept `#EXTM3U`, `#EXTINF`, `#EXTGRP`, `#EXTVLCOPT`, `url-tvg`, `x-tvg-url`, `tvg-*`, `group-title`, `catchup`, `catchup-days`, and `catchup-source`. Blank lines and unknown tags are ignored; an entry without a URL is rejected with `PlaylistError.missingURL(line:)`.

- [ ] **Step 4: Implement remote and local fetching**

`PlaylistFetcher` uses `URLSession.bytes(for:)` for remote URLs, enforces a 32 MB metadata limit per line, supports custom request headers, and emits entries incrementally. Local file imports use `FileHandle.bytes`. Network errors map to `PlaylistError.networkUnavailable`, `PlaylistError.httpStatus(Int)`, or `PlaylistError.invalidEncoding`.

- [ ] **Step 5: Run parser and fetcher tests**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXTests/M3UParserTests -only-testing:IPTVXTests/PlaylistFetcherTests
```

Expected: all parser and fetcher tests pass, including malformed input and cancellation cases.

---

### Task 3: Add normalized catalog persistence and phased refresh

**Files:**
- Create: `IPTVXCore/Models/CatalogModels.swift`
- Create: `IPTVXCore/Stores/CatalogStore.swift`
- Create: `IPTVXCore/Sources/Sync/RefreshCoordinator.swift`
- Create: `IPTVXCore/Sources/Sync/RefreshProgress.swift`
- Create: `IPTVXTests/CatalogStoreTests.swift`
- Create: `IPTVXTests/RefreshCoordinatorTests.swift`

**Interfaces:**
- Consumes: `PlaylistFetcher`, `PlaylistEntry`, and `MediaKind` from Task 2.
- Produces: `CatalogStore`, `RefreshCoordinator.refresh(playlistID:) -> AsyncThrowingStream<RefreshProgress, Error>`, and SwiftData-backed queries for home rails, categories, search, and recent items.

- [ ] **Step 1: Write catalog identity and refresh tests**

```swift
@Test func refreshPublishesCachedItemsBeforeFullPlaylist() async throws {
    let store = try CatalogStore.inMemory()
    let coordinator = RefreshCoordinator(store: store, source: FakePlaylistSource.large)
    let phases = try await coordinator.collect(playlistID: FakePlaylistSource.large.id)
    #expect(phases.first == .cachedCatalogPublished)
    #expect(phases.contains(.entriesPersisted(count: 3)))
}

@Test func successfulRefreshPrunesRemovedEntries() async throws {
    let store = try CatalogStore.inMemory(seed: [.movie(id: "removed")])
    try await store.applySuccessfulRefresh(entries: [])
    #expect(try store.movie(id: "removed") == nil)
}
```

- [ ] **Step 2: Implement SwiftData models and stable identities**

Use stable source identity formed from playlist id plus provider id when present, otherwise a normalized URL hash. Persist playlists, categories, live channels, movies, series, seasons, episodes, stream variants, and refresh metadata. Do not use display names as primary keys.

- [ ] **Step 3: Implement `CatalogStore`**

Provide `CatalogStore.live()`, `CatalogStore.inMemory(seed:)`, `search(query:kind:profileID:)`, `homeRails(profileID:)`, `categories(playlistID:)`, and `applySuccessfulRefresh(entries:)`. The store runs writes in bounded batches and exposes read-only snapshots to SwiftUI.

- [ ] **Step 4: Implement `RefreshCoordinator`**

Refresh in this order: validate source, publish cached state, parse entries, persist batches, publish categories, schedule artwork/metadata, then publish completion. Cancellation leaves the last successful catalog intact. Failed refreshes never prune existing content.

- [ ] **Step 5: Run catalog tests**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXTests/CatalogStoreTests -only-testing:IPTVXTests/RefreshCoordinatorTests
```

Expected: identity, phased progress, cancellation, stale pruning, and offline-cache tests pass.

---

### Task 4: Implement Xtream, XMLTV EPG, and metadata enrichment

**Files:**
- Create: `IPTVXCore/Sources/Xtream/XtreamClient.swift`
- Create: `IPTVXCore/Sources/Xtream/XtreamDTOs.swift`
- Create: `IPTVXCore/Sources/EPG/XMLTVParser.swift`
- Create: `IPTVXCore/Sources/EPG/EPGMatcher.swift`
- Create: `IPTVXCore/Sources/Metadata/TMDBClient.swift`
- Create: `IPTVXCore/Sources/Metadata/ArtworkCache.swift`
- Create: `Fixtures/xtream/response.json`
- Create: `Fixtures/epg/guide.xml`
- Create: `IPTVXTests/XtreamClientTests.swift`
- Create: `IPTVXTests/EPGTests.swift`
- Create: `IPTVXTests/MetadataTests.swift`

**Interfaces:**
- Consumes: catalog models and refresh coordinator from Task 3.
- Produces: typed Xtream endpoints, `XMLTVParser.parse(_:)`, `EPGMatcher.match(channel:guide:)`, and `TMDBClient.search(title:year:) async throws -> MetadataRecord`.

- [ ] **Step 1: Test Xtream URL construction and decoding**

```swift
@Test func buildsXtreamMovieURL() throws {
    let client = XtreamClient(baseURL: URL(string: "https://provider.example")!, username: "user", password: "pass")
    #expect(client.movieURL(id: "42").absoluteString == "https://provider.example/movie/user/pass/42.mp4")
}
```

- [ ] **Step 2: Implement Xtream adapters**

Support server info, live categories/streams, VOD categories/streams, series/categories/info, and episode stream URLs. Decode unknown provider fields without failing the full refresh. Map transport errors to the shared `SourceError` enum.

- [ ] **Step 3: Test XMLTV parsing and matching**

Cover timezone offsets, gzip input at the fetch boundary, `channel` ids, `display-name`, programmes crossing midnight, and matching priority: explicit `tvg-id`, normalized id, normalized channel name, then call-sign extraction.

- [ ] **Step 4: Implement EPG service**

Parse guide data independently from playlist refresh. Store listings keyed by channel identity and expose `nowPlaying(channelID:at:)`, `upcoming(channelID:from:limit:)`, and `archive(channelID:programme:)`.

- [ ] **Step 5: Implement metadata and artwork cache**

Use a configuration-injected TMDB token. Metadata failures return `nil` enrichment and never fail the catalog refresh. Cache artwork by URL with a disk budget and request de-duplication.

- [ ] **Step 6: Run service tests**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXTests/XtreamClientTests -only-testing:IPTVXTests/EPGTests -only-testing:IPTVXTests/MetadataTests
```

Expected: all fixtures decode, EPG matches are deterministic, and metadata failure tests remain non-fatal.

---

### Task 5: Add the playback abstraction and AVPlayer implementation

**Files:**
- Create: `IPTVXCore/Playback/PlaybackEngine.swift`
- Create: `IPTVXCore/Playback/PlaybackState.swift`
- Create: `IPTVXCore/Playback/AVPlayerEngine.swift`
- Create: `IPTVXCore/Playback/PlaybackCoordinator.swift`
- Create: `IPTVXUI/Player/PlayerSurface.swift`
- Create: `IPTVXUI/Player/PlayerOverlay.swift`
- Create: `IPTVXTests/PlaybackCoordinatorTests.swift`
- Create: `IPTVXUITests/PlaybackFlowUITests.swift`

**Interfaces:**
- Consumes: stream variants and watch state from Tasks 3–4.
- Produces: `PlaybackEngine`, `PlaybackCoordinator`, `PlaybackState`, and a SwiftUI player surface with resume, track, subtitle, retry, and dismiss actions.

- [ ] **Step 1: Define the playback contract**

```swift
public protocol PlaybackEngine: AnyObject {
    var state: AsyncStream<PlaybackState> { get }
    func load(_ request: PlaybackRequest) async throws
    func play() async
    func pause() async
    func seek(to seconds: Double) async throws
    func stop() async
}
```

`PlaybackRequest` carries URL, headers, media identity, resume position, live/VOD flag, and preferred tracks. `PlaybackFailure` has cases `network`, `expiredURL`, `unsupportedFormat`, `providerRejected`, `decoder`, `cancelled`, and `unknown`.

- [ ] **Step 2: Write coordinator tests**

Use a fake engine to verify resume position, one retry on expired URL after source refresh, no duplicate load during rapid view transitions, and watch-state persistence at 10-second intervals.

- [ ] **Step 3: Implement `AVPlayerEngine`**

Use `AVURLAsset` with HTTP headers, `AVPlayerItem`, `AVPlayerItemVideoOutput` only where required by overlays, `AVAudioSession` on iOS/tvOS, `AVPictureInPictureController` where supported, and `AVRoutePickerView` on Apple platforms. Observe item status, access logs, error logs, time control status, and end-of-item notifications.

- [ ] **Step 4: Implement the SwiftUI player surface**

Keep controls outside the engine. The overlay provides play/pause, seek for VOD, channel next/previous for live, audio/subtitle selection, EPG now/next, retry, AirPlay, PiP, and close. tvOS uses focusable controls and the Siri Remote back action.

- [ ] **Step 5: Validate fallback dependency before adding it**

Build AVPlayer-only first. Then evaluate VLCKit, LumeEngine, or AetherEngine on iOS, tvOS, and macOS. Add exactly one fallback only if it passes license review, target compilation, and real-stream playback tests. Record the result in `THIRD-PARTY-NOTICES.md`.

- [ ] **Step 6: Run playback tests**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXTests/PlaybackCoordinatorTests
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXUITests/PlaybackFlowUITests
```

Expected: fake-engine state tests pass; UI tests validate player presentation, dismissal, retry, and resume behavior. Real stream/HDR/PiP validation happens on physical devices.

---

### Task 6: Build the IPTVX-style SwiftUI experience

**Files:**
- Create: `IPTVXUI/Navigation/AppShell.swift`
- Create: `IPTVXUI/Home/HomeView.swift`
- Create: `IPTVXUI/Home/HeroCarousel.swift`
- Create: `IPTVXUI/Home/ContentRail.swift`
- Create: `IPTVXUI/LiveTV/LiveTVView.swift`
- Create: `IPTVXUI/LiveTV/EPGTimelineView.swift`
- Create: `IPTVXUI/Library/MoviesView.swift`
- Create: `IPTVXUI/Library/SeriesView.swift`
- Create: `IPTVXUI/Library/DetailView.swift`
- Create: `IPTVXUI/Search/SearchView.swift`
- Create: `IPTVXUI/Settings/SettingsView.swift`
- Create: `IPTVXUI/Components/MediaCard.swift`
- Create: `IPTVXUI/Components/LoadingStateView.swift`
- Create: `IPTVXUI/Platform/TVOSFocusModifiers.swift`
- Create: `IPTVXUI/Platform/MacCommands.swift`
- Create: `IPTVXUITests/HomeAndBrowseUITests.swift`
- Create: `IPTVXUITests/TVOSFocusUITests.swift`

**Interfaces:**
- Consumes: catalog queries, EPG service, metadata cache, playback coordinator, and profile state.
- Produces: complete browse flow from launch to Home, Live TV, Movies, Series, Search, Detail, Player, and Settings.

- [ ] **Step 1: Write UI tests for the browse path**

```swift
func testHomeShowsPrimaryRailsAfterSeededCatalog() {
    launchArguments = ["-ui-testing", "-seed-fixtures"]
    app.launch()
    XCTAssertTrue(app.staticTexts["Continue Watching"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Live TV"].exists)
    XCTAssertTrue(app.staticTexts["Movies"].exists)
}
```

- [ ] **Step 2: Implement platform-adaptive navigation**

Use a shared `AppShell` with platform-specific layout: tabs on iOS, sidebar on macOS, and focus-first top navigation on tvOS. Every route must be reachable without relying on a pointer or touch gesture on tvOS.

- [ ] **Step 3: Implement home rails and cards**

Cards use async artwork loading, stable identity, focus scale, accessibility labels, and a defined empty/loading state. Rails consume paginated `CatalogStore` snapshots rather than raw provider arrays.

- [ ] **Step 4: Implement Live TV and EPG**

Show category/channel browsing, preview, now/next, timeline guide, manual EPG assignment, catch-up actions, reminders, favorites, and channel zapping. Preview cancellation must stop the old engine before category changes.

- [ ] **Step 5: Implement Movies, Series, Detail, and Search**

Use poster grids, detail backdrops, season/episode hierarchy, continue-watching actions, filters, debounced local search, and provider/source badges where multiple streams exist.

- [ ] **Step 6: Implement settings and playlist management**

Provide add/edit/delete playlist flows, local file import, URL validation, refresh progress, EPG source configuration, category ordering, hidden categories, playback settings, and diagnostics export without credentials.

- [ ] **Step 7: Run UI tests on all targets**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXUITests/HomeAndBrowseUITests
xcodebuild test -scheme IPTVX -destination 'platform=tvOS Simulator,name=Apple TV' -only-testing:IPTVXUITests/TVOSFocusUITests
xcodebuild test -scheme IPTVX -destination 'platform=macOS' -only-testing:IPTVXUITests/HomeAndBrowseUITests
```

Expected: seeded fixture data is browseable on every platform, focus traversal works on tvOS, and Mac keyboard navigation reaches all primary actions.

---

### Task 7: Add profiles, watch state, CloudKit sync, downloads, and parental controls

**Files:**
- Create: `IPTVXCore/Stores/ProfileStore.swift`
- Create: `IPTVXCore/Stores/WatchStateStore.swift`
- Create: `IPTVXCore/Stores/CloudSyncing.swift`
- Create: `IPTVXCore/Stores/CloudKitSyncService.swift`
- Create: `IPTVXCore/Downloads/DownloadManager.swift`
- Create: `IPTVXUI/Profiles/ProfileSwitcherView.swift`
- Create: `IPTVXUI/Profiles/ParentalControlsView.swift`
- Create: `IPTVXUI/Downloads/DownloadsView.swift`
- Create: `IPTVXTests/ProfileStoreTests.swift`
- Create: `IPTVXTests/CloudSyncTests.swift`
- Create: `IPTVXTests/DownloadManagerTests.swift`
- Modify: `IPTVXApp/IPTVXApp.swift`
- Modify: `IPTVXApp/TVOS.entitlements`
- Modify: `IPTVXApp/iOS.entitlements`
- Modify: `IPTVXApp/macOS.entitlements`

**Interfaces:**
- Consumes: catalog identities and playback progress from Tasks 3, 5, and 6.
- Produces: profile-isolated state, optional CloudKit sync, iOS/macOS VOD downloads, child profiles, PIN protection, and download queue UI.

- [ ] **Step 1: Test profile isolation and PIN behavior**

```swift
@Test func childProfileCannotSeeRestrictedCategory() throws {
    let store = try ProfileStore.inMemory()
    let child = try store.create(name: "Kids", isChild: true, restrictedCategoryIDs: ["adult"])
    #expect(store.visibleCategoryIDs(for: child.id) == [])
}
```

- [ ] **Step 2: Implement local profile and watch-state stores**

Every favorite, progress record, hidden category, and history item includes a profile id. Switching profiles changes queries and clears transient player recommendations without deleting other profiles.

- [ ] **Step 3: Implement CloudKit behind a protocol**

`CloudSyncing` exposes `push(changes:)`, `pull(since:)`, and `resolve(conflict:)`. CloudKit is disabled in previews/tests and when the user has not authorized iCloud. Local state remains authoritative until a successful sync acknowledgement.

- [ ] **Step 4: Implement downloads**

`DownloadManager` supports one active download by default, a bounded concurrent mode on iOS/macOS, retry with exponential backoff, cancellation, storage accounting, and local playback. tvOS exposes no download controls.

- [ ] **Step 5: Implement parental controls**

Require a PIN to leave a child profile, open restricted content management, or reveal hidden categories. Failed PIN attempts do not reveal whether a restricted item exists.

- [ ] **Step 6: Run profile, sync, and download tests**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXTests/ProfileStoreTests -only-testing:IPTVXTests/CloudSyncTests -only-testing:IPTVXTests/DownloadManagerTests
```

Expected: profile isolation, conflict handling, download retry/cancel, and restricted-content tests pass without requiring a real iCloud container.

---

### Task 8: Platform polish, diagnostics, and release verification

**Files:**
- Create: `IPTVXUI/Platform/TVOSTopShelf.swift`
- Create: `IPTVXUI/Platform/iOSBackgroundTasks.swift`
- Create: `IPTVXUI/Platform/MacMenuCommands.swift`
- Create: `IPTVXCore/Diagnostics/DiagnosticsExporter.swift`
- Create: `IPTVXUITests/AccessibilityUITests.swift`
- Modify: `THIRD-PARTY-NOTICES.md`
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: complete app from Tasks 1–7.
- Produces: platform-specific polish, redacted diagnostics, accessibility coverage, and reproducible build instructions.

- [ ] **Step 1: Add diagnostics without secrets**

Export app version, OS, platform, catalog counts, last refresh status, and playback engine state. Redact provider usernames, passwords, tokens, playlist URLs, and stream URLs before writing or sharing diagnostics.

- [ ] **Step 2: Add platform behaviors**

Implement tvOS top shelf and focus restoration, iOS background refresh/download scheduling, and macOS commands for search, refresh, sidebar, and playback controls.

- [ ] **Step 3: Run accessibility and launch tests**

Run:

```bash
xcodebuild test -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IPTVXUITests/AccessibilityUITests
xcodebuild test -scheme IPTVX -destination 'platform=tvOS Simulator,name=Apple TV'
xcodebuild test -scheme IPTVX -destination 'platform=macOS'
```

Expected: primary controls have labels and traits, Dynamic Type does not truncate essential actions, tvOS focus does not escape modal flows, and all schemes pass their test suites.

- [ ] **Step 4: Run a clean build and archive validation**

Run:

```bash
xcodegen generate
xcodebuild clean -scheme IPTVX
xcodebuild build -scheme IPTVX -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild build -scheme IPTVX -destination 'platform=tvOS Simulator,name=Apple TV'
xcodebuild build -scheme IPTVX -destination 'platform=macOS'
```

Expected: all targets build from a clean checkout and dependency notices match the packages actually linked.

- [ ] **Step 5: Validate on physical devices**

Test one authorized source on an iPhone/iPad, Mac, and Apple TV. Verify live playback, VOD playback, EPG, AirPlay, PiP, audio/subtitle selection, HDR where available, background downloads, profile switching, and recovery from expired streams.

- [ ] **Step 6: Update build documentation**

`docs/README.md` must document Xcode version, XcodeGen command, signing/team replacement, optional TMDB configuration, test commands, supported platforms, and the user-provided-content policy.

---

## Plan self-review

- Spec coverage: source ingestion is Task 2; catalog/local-first refresh is Task 3; Xtream, EPG, and metadata are Task 4; playback is Task 5; Home/Live/VOD/Search/Settings are Task 6; profiles/sync/downloads/parental controls are Task 7; platform behavior, diagnostics, accessibility, and release verification are Task 8.
- Scope-marker scan: no unresolved scope markers or unspecified implementation steps remain in this plan.
- Type consistency: `PlaylistEntry` feeds `CatalogStore`; `CatalogStore` feeds `RefreshCoordinator` and UI; `PlaybackRequest` and `PlaybackState` are shared by engines and the player surface; `CloudSyncing` isolates CloudKit from profile and watch-state stores.
- Environment gap: the current machine has Swift 6.4 Command Line Tools but no `/Applications/Xcode.app`; Task 0 must complete before iOS/tvOS/macOS app compilation and simulator tests can run.
