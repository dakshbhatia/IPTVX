import SwiftData
import SwiftUI
#if !os(tvOS)
    import UniformTypeIdentifiers
#endif

struct LoginView: View {
    /// Whether this view is presented modally (the Settings "Add Playlist"
    /// sheet / cover) and should therefore offer a Cancel button and dismiss
    /// itself once a playlist is added. False when it's the window's root
    /// content on first launch — there is nothing to cancel to, and on macOS
    /// calling `dismiss()` on root content closes the whole window (the app
    /// keeps running but loses its only window, forcing a relaunch from the
    /// Dock). Adding the playlist swaps the root to MainTabView on its own via
    /// ContentView's @Query, so no dismissal is needed there.
    ///
    /// This is passed explicitly rather than read from `@Environment(\.isPresented)`
    /// because on macOS that value is `true` even for non-presented root content.
    var isModal = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sourceType: PlaylistSourceType = .xtream

    @State private var name = ""
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""

    // m3u fields
    @State private var m3uURL = ""
    @State private var epgURL = ""
    #if !os(tvOS)
        @State private var showFileImporter = false
    #endif

    // Stalker portal fields. The MAC defaults to a freshly generated MAG-style
    // address so a user without a provider-issued MAC still gets a valid one.
    @State private var portalURL = ""
    @State private var macAddress = StalkerMAC.generate()

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        switch sourceType {
        case .xtream:
            !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !password.isEmpty
        case .m3u:
            !m3uURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .stalker:
            !portalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && StalkerMAC.isValid(macAddress.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    var body: some View {
        #if os(tvOS)
            tvBody
        #else
            formBody
        #endif
    }

    #if !os(tvOS)
        private var formBody: some View {
            NavigationStack {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    #if os(macOS)
                        setupContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.vertical, 28)
                    #else
                        ScrollView {
                            setupContent
                                .padding(.horizontal, 24)
                                .padding(.vertical, 28)
                        }
                    #endif
                }
                .navigationTitle("DBStream")
                .preferredColorScheme(.dark)
                #if os(macOS)
                    .toolbarBackground(Color.black, for: .windowToolbar)
                    .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
                #endif
                    .toolbar {
                        // Only offer Cancel when presented modally (the Settings
                        // sheet). On first launch there is nothing to cancel to.
                        if isModal {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { dismiss() }
                                    .disabled(isLoading)
                            }
                        }
                    }
                    .interactiveDismissDisabled(isLoading)
                    .fileImporter(
                        isPresented: $showFileImporter,
                        allowedContentTypes: Self.playlistFileTypes
                    ) { result in
                        handleFileImport(result)
                    }
            }
        }

        private var setupContent: some View {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add your provider")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }

                playlistTypeCard
                connectionCard

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.red.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.red.opacity(0.35), lineWidth: 1)
                        }
                }

                Button(action: addPlaylist) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "plus")
                                .font(.body.weight(.bold))
                        }
                        Text("Add Playlist")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color(red: 0.90, green: 0.04, blue: 0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .opacity(isFormValid && !isLoading ? 1 : 0.45)
                .disabled(!isFormValid || isLoading)
            }
            .frame(maxWidth: 520, alignment: .leading)
            #if os(macOS)
                .frame(width: 520, alignment: .leading)
            #endif
        }

        private var playlistTypeCard: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("PLAYLIST TYPE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Picker("Playlist Type", selection: $sourceType) {
                    Text("Xtream").tag(PlaylistSourceType.xtream)
                    Text("M3U").tag(PlaylistSourceType.m3u)
                    Text("Stalker").tag(PlaylistSourceType.stalker)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }

        private var connectionCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(connectionTitle)
                    .font(.title3.weight(.semibold))

                switch sourceType {
                case .xtream:
                    xtreamFields
                case .m3u:
                    m3uFields
                case .stalker:
                    stalkerFields
                }
            }
            .playlistCinemaCard()
        }

        private var connectionTitle: LocalizedStringKey {
            switch sourceType {
            case .xtream: "Server Connection"
            case .m3u: "M3U Playlist"
            case .stalker: "Stalker Portal"
            }
        }

        private var xtreamFields: some View {
            VStack(spacing: 8) {
                TextField("e.g. My IPTV", text: $name)
                    .textContentType(.name)
                    .playlistFieldSurface()

                TextField("e.g. http://example.com:8080", text: $serverURL)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                #endif
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .playlistFieldSurface()

                TextField("Username", text: $username)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .playlistFieldSurface()

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .playlistFieldSurface()
            }
        }

        private var m3uFields: some View {
            VStack(spacing: 8) {
                TextField("e.g. My IPTV", text: $name)
                    .textContentType(.name)
                    .playlistFieldSurface()

                TextField("e.g. http://example.com/playlist.m3u", text: $m3uURL)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                #endif
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .playlistFieldSurface()

                Button("Choose Local File…") { showFileImporter = true }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                TextField("EPG URL (optional)", text: $epgURL)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                #endif
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .playlistFieldSurface()
            }
        }

        private var stalkerFields: some View {
            VStack(spacing: 8) {
                TextField("e.g. My IPTV", text: $name)
                    .textContentType(.name)
                    .playlistFieldSurface()

                TextField("e.g. http://example.com:8080/c/", text: $portalURL)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                #endif
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .playlistFieldSurface()

                HStack {
                    TextField("MAC Address", text: $macAddress)
                    #if os(iOS)
                        .textInputAutocapitalization(.characters)
                    #endif
                        .autocorrectionDisabled()
                    Button {
                        macAddress = StalkerMAC.generate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Generate a new MAC address")
                }
                .playlistFieldSurface()

                TextField("Username (optional)", text: $username)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .playlistFieldSurface()

                SecureField("Password (optional)", text: $password)
                    .textContentType(.password)
                    .playlistFieldSurface()
            }
        }
    #endif

    #if os(tvOS)
        private var tvBody: some View {
            TVLoginForm(
                sourceType: $sourceType,
                name: $name,
                serverURL: $serverURL,
                username: $username,
                password: $password,
                m3uURL: $m3uURL,
                epgURL: $epgURL,
                portalURL: $portalURL,
                macAddress: $macAddress,
                isFormValid: isFormValid,
                isLoading: isLoading,
                errorMessage: errorMessage,
                isModal: isModal,
                addPlaylist: addPlaylist,
                dismiss: dismiss
            )
        }
    #endif

    // MARK: - Add playlist

    private func addPlaylist() {
        switch sourceType {
        case .xtream: loginXtream()
        case .m3u: addM3UPlaylist()
        case .stalker: addStalkerPlaylist()
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loginXtream() {
        isLoading = true
        errorMessage = nil

        let playlistName = trimmedName.isEmpty ? "My Playlist" : trimmedName

        Task {
            let playlist = Playlist(
                name: playlistName,
                serverURL: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            let client = XtreamClient()
            do {
                try await withConnectionTimeout {
                    let info = try await client.getInfo(playlist: playlist)
                    playlist.serverTimezone = info.serverInfo.timezone
                    playlist.userStatus = info.userInfo.status
                    playlist.maxConnections = String(info.userInfo.maxConnections ?? "0")
                    playlist.activeConnections = String(info.userInfo.activeCons ?? "0")
                    playlist.expDate = info.userInfo.expDate
                    try insertAndFinish(playlist)
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func addM3UPlaylist() {
        isLoading = true
        errorMessage = nil

        do {
            _ = try PlaylistOnboarding.addM3U(
                name: name,
                playlistURL: m3uURL,
                epgURL: epgURL,
                in: modelContext
            )
            finishAddingPlaylist()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func addStalkerPlaylist() {
        isLoading = true
        errorMessage = nil

        let playlistName = trimmedName.isEmpty ? "My Playlist" : trimmedName
        let portal = portalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let mac = macAddress.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        Task {
            let playlist = Playlist(
                name: playlistName,
                portalURL: portal,
                macAddress: mac,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            let client = StalkerClient(configuration: StalkerClient.Configuration(playlist: playlist))
            do {
                try await withConnectionTimeout {
                    // Handshake + profile doubles as the connection test.
                    let profile = try await client.authenticate()
                    playlist.userStatus = profile.status
                    playlist.expDate = profile.expDate
                    try insertAndFinish(playlist)
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func insertAndFinish(_ playlist: Playlist) throws {
        try PlaylistOnboarding.persist(playlist, in: modelContext)
        finishAddingPlaylist()
    }

    private func finishAddingPlaylist() {
        isLoading = false
        // Only dismiss when presented modally (e.g. the Settings
        // sheet). On first launch LoginView is the window's root
        // content, where dismiss() closes the window on macOS and
        // leaves the app with no visible window. Inserting the
        // playlist already swaps the root over to MainTabView via
        // ContentView's @Query.
        if isModal {
            dismiss()
        }
    }
}

// MARK: - Cinema setup surfaces

#if !os(tvOS)
    private extension View {
        /// A simple, low-contrast panel. The setup flow should feel like a
        /// streaming app, not a dashboard full of floating glass widgets.
        func playlistCinemaCard() -> some View {
            padding(16)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }

        /// Low, even field contrast makes long credentials easy to scan without
        /// turning each row into another card.
        func playlistFieldSurface() -> some View {
            textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        }
    }
#endif

// MARK: - Connection-test timeout

private extension LoginView {
    struct ConnectionTimeoutError: LocalizedError {
        var errorDescription: String? {
            String(localized: "The connection timed out. Check the URL and your network, then try again.")
        }
    }

    /// Runs an add-playlist connection test under an overall deadline, cancelling
    /// the in-flight request and surfacing a timeout when it's exceeded.
    ///
    /// Each client has its own per-request timeout and (for Xtream) retry/backoff
    /// tuned for *sync*, where retries matter; left unbounded, a wrong URL or
    /// dead host can hang the add sheet for ~30–90s on a spinner with no way out.
    /// This caps the test (default 20s) without weakening the sync path.
    func withConnectionTimeout(_ seconds: Double = 20, _ operation: @escaping () async throws -> Void) async throws {
        let work = Task { try await operation() }
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(seconds))
            work.cancel()
        }
        defer { watchdog.cancel() }
        do {
            try await work.value
        } catch {
            if work.isCancelled { throw ConnectionTimeoutError() }
            throw error
        }
    }
}

// MARK: - Local file import (iOS / macOS)

#if !os(tvOS)
    private extension LoginView {
        static var playlistFileTypes: [UTType] {
            var types: [UTType] = [.m3uPlaylist]
            if let m3u8 = UTType(filenameExtension: "m3u8") {
                types.append(m3u8)
            }
            return types
        }

        /// Copies the picked file into the app's Application Support directory
        /// so it stays readable across launches (the picker's URL is outside
        /// our sandbox and its security scope doesn't persist), then points the
        /// playlist URL field at the copy.
        func handleFileImport(_ result: Result<URL, Error>) {
            switch result {
            case let .success(pickedURL):
                let accessing = pickedURL.startAccessingSecurityScopedResource()
                defer {
                    if accessing { pickedURL.stopAccessingSecurityScopedResource() }
                }
                do {
                    let directory = try FileManager.default
                        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        .appendingPathComponent("Playlists", isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let destination = directory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(pickedURL.pathExtension.isEmpty ? "m3u" : pickedURL.pathExtension)
                    try FileManager.default.copyItem(at: pickedURL, to: destination)
                    m3uURL = destination.absoluteString
                    if trimmedName.isEmpty {
                        name = pickedURL.deletingPathExtension().lastPathComponent
                    }
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
    }
#endif

#Preview("Empty") {
    LoginView()
}

#Preview("With Error") {
    LoginView()
    // Note: error state is managed internally, shown via the errorMessage field.
    // In previews this can be simulated by setting initial state.
}
