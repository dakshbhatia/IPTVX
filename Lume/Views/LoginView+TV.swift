import SwiftUI

#if os(tvOS)
    /// tvOS keeps the same provider inputs as iOS/macOS but puts the controls in
    /// a focus-friendly, single-column layout. Keeping it separate also makes
    /// the shared login controller small enough to remain easy to reason about.
    struct TVLoginForm: View {
        @Binding var sourceType: PlaylistSourceType
        @Binding var name: String
        @Binding var serverURL: String
        @Binding var username: String
        @Binding var password: String
        @Binding var m3uURL: String
        @Binding var epgURL: String
        @Binding var portalURL: String
        @Binding var macAddress: String
        let isFormValid: Bool
        let isLoading: Bool
        let errorMessage: String?
        let isModal: Bool
        let addPlaylist: () -> Void
        let dismiss: DismissAction

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add Playlist")
                            .font(.system(size: 38, weight: .bold))
                        Text("Connect to your IPTV provider")
                            .font(.system(size: TVSettingsMetrics.secondaryFontSize))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, TVSettingsMetrics.rowHPadding)

                    Picker("Playlist Type", selection: $sourceType) {
                        Text("Xtream").tag(PlaylistSourceType.xtream)
                        Text("M3U").tag(PlaylistSourceType.m3u)
                        Text("Stalker").tag(PlaylistSourceType.stalker)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, TVSettingsMetrics.rowHPadding)

                    VStack(spacing: 22) {
                        TVSettingsField(title: "Name", placeholder: "e.g. My IPTV", text: $name, contentType: .name)
                        switch sourceType {
                        case .xtream:
                            TVSettingsField(title: "Server URL", placeholder: "e.g. http://example.com:8080", text: $serverURL, contentType: .URL)
                            TVSettingsField(title: "Username", placeholder: "Username", text: $username, contentType: .username)
                            TVSettingsField(title: "Password", placeholder: "Password", text: $password, isSecure: true, contentType: .password)
                        case .m3u:
                            TVSettingsField(title: "Playlist URL", placeholder: "e.g. http://example.com/playlist.m3u", text: $m3uURL, contentType: .URL)
                            TVSettingsField(title: "EPG URL (optional)", placeholder: "e.g. http://example.com/guide.xml", text: $epgURL, contentType: .URL)
                        case .stalker:
                            TVSettingsField(title: "Portal URL", placeholder: "e.g. http://example.com:8080/c/", text: $portalURL, contentType: .URL)
                            TVSettingsField(title: "MAC Address", placeholder: "00:1A:79:xx:xx:xx", text: $macAddress, contentType: nil)
                            TVSettingsField(title: "Username (optional)", placeholder: "Username", text: $username, contentType: .username)
                            TVSettingsField(title: "Password (optional)", placeholder: "Password", text: $password, isSecure: true, contentType: .password)
                        }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: TVSettingsMetrics.secondaryFontSize))
                            .foregroundStyle(.red)
                            .padding(.horizontal, TVSettingsMetrics.rowHPadding)
                    }

                    HStack(spacing: 16) {
                        Button(action: addPlaylist) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Label("Add Playlist", systemImage: "plus")
                            }
                        }
                        .buttonStyle(TVSettingsActionButtonStyle(prominent: true))
                        .disabled(!isFormValid || isLoading)

                        if isModal {
                            Button("Cancel") { dismiss() }
                                .buttonStyle(TVSettingsActionButtonStyle())
                                .disabled(isLoading)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, TVSettingsMetrics.rowHPadding)
                }
                .frame(maxWidth: TVSettingsMetrics.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 48)
                .padding(.vertical, 72)
            }
            .tvSettingsBackground()
        }
    }
#endif
