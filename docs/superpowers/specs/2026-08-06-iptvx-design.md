# IPTVX Apple Platforms Design

**Date:** 2026-08-06  
**Status:** Approved design  
**Scope:** Native macOS, iOS/iPadOS, and tvOS IPTV client with full IPTVX-style capability parity.

## Product definition

IPTVX is an open-source, user-provided-content media client. It organizes and plays the user’s M3U/M3U8, Xtream Codes, and local playlist sources with a cohesive, Netflix-style discovery experience across Mac, iPhone/iPad, and Apple TV.

The app will reproduce the functional surface and interaction quality of IPTVX-like products without copying proprietary code, branding, artwork, or pixel-perfect screens. It will ship no channels, playlists, subscriptions, or video content.

## Goals

- Provide a polished, native Apple experience on macOS, iOS/iPadOS, and tvOS.
- Make large IPTV libraries feel like a streaming service rather than a raw channel list.
- Support Live TV, EPG, catch-up/archive, Movies, Series, metadata, search, profiles, progress, favorites, downloads, and parental controls.
- Keep the app local-first so browsing remains useful when a provider or network is temporarily unavailable.
- Keep provider credentials and user data private and avoid logging sensitive stream URLs.
- Preserve clear module boundaries so playback engines, source adapters, and metadata providers can change independently.

## Non-goals for the first implementation pass

- Bundling or recommending third-party streams, channels, or subscriptions.
- Building a provider-management SaaS or content-hosting backend.
- Copying IPTVX’s proprietary visuals or implementation.
- Supporting Android, Windows, web, or smart-TV platforms in this Apple-first project.
- Adding AI, Chromecast, multi-view, DVR recording, or a hosted account service before the core client is stable.

## Foundation and licensing

The implementation should begin from the architecture and feature patterns in [bilipp/Lume](https://github.com/bilipp/Lume), a native SwiftUI IPTV client targeting Apple platforms. Lume is AGPL-3.0; an IPTVX fork that incorporates its code remains AGPL-3.0 unless a separate licensing review changes the foundation.

The project must maintain a third-party notice file for all bundled dependencies. The playback dependency decision is intentionally isolated because the original [FFmpegKit](https://github.com/arthenica/ffmpeg-kit) is retired. The first supported path is AVPlayer with a fallback engine; [LumeEngine](https://github.com/bilipp/LumeEngine) and [AetherEngine](https://github.com/superuser404notfound/AetherEngine) are candidates after build and device validation. [KSPlayer](https://github.com/kingslay/KSPlayer) is technically capable but GPL-3.0 by default and therefore requires explicit license compliance.

## Platform strategy

Use one SwiftUI codebase with platform adapters rather than separate apps. Shared models, services, sync, and playback contracts live in common modules. Views adapt to the platform:

- iOS/iPadOS: tab-based navigation, compact and regular size classes, downloads, PiP, touch gestures, and background transfer support.
- macOS: resizable native window, sidebar navigation, keyboard shortcuts, multi-window-safe state, drag-and-drop playlist import, and desktop download management.
- tvOS: focus-driven navigation, large cards, top-shelf assets, remote-friendly settings, channel zapping, and dedicated EPG/player overlays.

The initial deployment baseline follows the selected Lume foundation: iOS/tvOS 18 and macOS 15 unless the local Xcode/toolchain proves a lower baseline without significant rework.

## System architecture

```text
M3U / Xtream / Local Files
            |
       Source Adapters
            |
  Normalize + classify + persist
            |
     Local SwiftData Catalog
        /             \
   XMLTV EPG       TMDB metadata
        \             /
         Shared SwiftUI UI
                |
       PlaybackEngine protocol
        /        |         \
   AVPlayer   VLCKit   optional FFmpeg engine
```

### App modules

- `AppShell`: launch routing, navigation, platform composition, settings entry points.
- `Sources`: M3U/M3U8 parser, Xtream API client, local file importer, provider credentials, refresh scheduling.
- `Catalog`: normalized entities and SwiftData persistence for playlists, categories, channels, movies, series, seasons, episodes, and source variants.
- `Sync`: phased refresh, stale-item pruning, progress reporting, retry/backoff, and cancellation.
- `EPG`: XMLTV parsing, automatic matching, manual assignment, now/next state, reminders, archive metadata, and time-shift handling.
- `Metadata`: TMDB artwork and details, optional ratings/trailer integrations, caching, and rate-limit handling.
- `Library`: favorites, history, watch progress, Continue Watching, custom ordering, hidden categories, and per-profile state.
- `Profiles`: multiple profiles, child profiles, category restrictions, PIN protection, and profile switching.
- `Playback`: engine abstraction, stream headers, track selection, subtitles, PiP, AirPlay, resume positions, error classification, and fallback.
- `Downloads`: iOS/macOS VOD downloads with queueing, retries, progress, cancellation, and local playback.
- `CloudSync`: CloudKit-backed sync for eligible user state, with local-only fallback when iCloud is unavailable.
- `Platform`: tvOS focus, iOS background behavior, macOS menu/shortcut integration, and platform-specific player surfaces.

## Data model

Core models are normalized around stable identities rather than display names:

- `Profile`: id, name, child flag, PIN policy, hidden categories, restrictions.
- `Playlist`: id, provider type, display name, source URL/file bookmark, refresh policy, EPG configuration.
- `Category`: id, playlist id, type, normalized name, display order, visibility.
- `LiveChannel`: stable source identity, name, logo, group, channel number, stream variants, catch-up template, EPG id.
- `Movie`: stable source identity, title, year, category, artwork, metadata ids, stream variants, progress.
- `Series`, `Season`, `Episode`: normalized hierarchy, artwork, metadata ids, episode stream variants, progress.
- `EPGListing`: channel identity, title, description, start/end time, artwork, archive availability.
- `WatchState`: profile id, media identity, position, duration, last watched, completion state.
- `Favorite`: profile id, media identity, custom list, ordering.

Sensitive credentials are stored in Keychain. Local playlist files use security-scoped bookmarks on macOS/iOS where needed. Raw provider passwords and full stream URLs must not appear in analytics or ordinary logs.

## Refresh and performance behavior

Playlist refresh is asynchronous and phased:

1. Validate the source and load cached catalog state immediately.
2. Stream-download and parse the playlist without blocking the UI.
3. Publish favorites and recently watched items first.
4. Publish categories and core catalog entries incrementally.
5. Refresh artwork and metadata lazily and with bounded concurrency.
6. Refresh EPG separately, prioritizing visible and favorite channels.
7. Prune entries removed by the provider only after a successful refresh.

The app must remain responsive for very large playlists. Search, sorting, and filtering operate over indexed local data. Artwork is cached with memory and disk limits. All long-running work is cancellable and reports typed progress rather than relying on log text.

## User experience

### Home

- Hero carousel or focused featured title.
- Continue Watching.
- Recently Added.
- Favorites and custom lists.
- Recommended/Popular when metadata is available.
- Movies and Series rails.
- Live Now and recently watched channels.

### Live TV

- Category and channel browsing with logos and now-playing text.
- Channel preview where supported, avoiding unnecessary reconnects when entering fullscreen.
- Full EPG timeline with current-time indicator.
- Manual EPG assignment when automatic matching fails.
- Channel zapping and recently watched channels.
- Catch-up/archive actions only when provider metadata supports them.
- Programme reminders using local notifications where platform support permits.

### Movies and Series

- Poster grids with sorting and filtering.
- Detail pages with backdrop, logo, description, cast, ratings, runtime, and trailer when available.
- Season/episode navigation.
- Resume playback, mark watched, next episode, and optional skip-intro overlay.

### Settings and profiles

- Playlist management and refresh status.
- EPG source management.
- Playback engine and subtitle/audio preferences.
- Profile switching, child restrictions, PIN controls.
- Download queue and storage management.
- Privacy, diagnostics, export/import, and reset controls.

## Playback contract

All playback engines conform to a shared `PlaybackEngine` protocol exposing:

- Load, play, pause, stop, seek, and retry.
- Buffering and stream-health events.
- Current position, duration, and live/VOD classification.
- Audio/subtitle track enumeration and selection.
- External subtitle loading.
- Picture-in-picture and AirPlay capability reporting.
- Typed failures such as unsupported format, expired URL, network timeout, provider rejection, and decoder failure.

AVPlayer is preferred for HLS and standard Apple-compatible streams because it provides the strongest system integration. A fallback engine handles formats AVPlayer cannot decode. Engine fallback is explicit, observable, and limited to safe retry conditions so the app does not create duplicate streams or hide provider errors.

## Error handling

- Provider errors show the provider/source context without exposing credentials.
- Expired or unauthorized streams offer refresh/retry rather than generic playback failure.
- Missing EPG distinguishes unavailable guide data from failed channel matching.
- Large refreshes can be cancelled and resumed from cached state.
- Metadata failures never block playback or catalog browsing.
- Offline mode presents cached catalog, local downloads, and a clear source-status indicator.

## Testing and acceptance criteria

### Unit and integration tests

- M3U variants, quoted attributes, malformed rows, custom headers, groups, logos, catch-up tags, and huge playlists.
- Xtream API decoding and URL generation.
- XMLTV parsing, timezone handling, matching, manual overrides, and archive templates.
- Catalog deduplication, stale pruning, sorting, search, and progress persistence.
- Profile isolation, parental restrictions, Keychain storage, and CloudKit conflict resolution.
- Playback state transitions, retry classification, and engine fallback decisions.

### UI tests

- First launch and playlist import.
- Home rails and Continue Watching.
- Live TV → preview → fullscreen → return without unnecessary reconnect.
- EPG navigation and programme actions.
- Movie/series detail → playback → resume.
- Profile switching and child PIN flow.
- tvOS focus traversal and remote back behavior.
- Mac keyboard navigation, resize behavior, and drag/drop import.

### Device validation

Simulator tests validate layout and interaction. Real iPhone/iPad, Mac, and Apple TV testing is required for stream playback, HDR, audio passthrough, AirPlay, PiP, background downloads, focus behavior, and provider-specific failures.

The build is considered V1-complete when all three platforms compile, a user can import an authorized test source, browse the full catalog, play live/VOD content, view EPG data, resume playback, use favorites/profiles, and recover gracefully from source failures.

## External references

- [IPTVX App Store feature surface](https://apps.apple.com/us/app/iptvx/id1451470024?platform=mac)
- [IPTVX FAQ and sync behavior](https://iptvx.app/faq/index.html)
- [Lume](https://github.com/bilipp/Lume)
- [clubTivi](https://github.com/clubanderson/clubTivi)
- [Dispatcharr](https://github.com/Dispatcharr/Dispatcharr)
- [Threadfin](https://github.com/Threadfin/Threadfin)
- [AetherEngine](https://github.com/superuser404notfound/AetherEngine)
