//
//  GeneralSettingsPane.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/23/25.
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsPane: View {
    @StateObject private var updaterViewModel = UpdaterViewModel()

    @AppStorage(\.playerSwitching) private var playerSwitching
    @AppStorage(\.trackFetchingMethod) private var trackFetchingMethod
    @AppStorage(\.openLinksWith) private var openLinksWith
    @AppStorage(\.showIconInDock) private var showIconInDock
    @AppStorage(\.showArtworkInDock) private var showArtworkInDock

    var body: some View {
        Form {
            Section("Player") {
                Picker("Player switching", selection: $playerSwitching) {
                    Text("Automatic").tag(PlayerSwitching.automatic)
                    Divider()
                    Text("Prefer Apple Music").tag(
                        PlayerSwitching.preferAppleMusic
                    )
                    Text("Prefer Spotify").tag(PlayerSwitching.preferSpotify)
                }
                Picker("Open links in", selection: $openLinksWith) {
                    Text("Last.fm").tag(OpenLinksWith.alwaysInLastFm)
                    Text("Apple Music").tag(OpenLinksWith.alwaysInAppleMusic)
                    Text("Spotify").tag(OpenLinksWith.alwaysInSpotify)
                }
                Picker("Fetching method", selection: $trackFetchingMethod) {
                    Text("Per-App (Apple Music & Spotify)").tag(
                        TrackFetchingMethod.perApp
                    )
                    Text("MediaRemote (System-wide)").tag(
                        TrackFetchingMethod.mediaRemote
                    )
                }
                .pickerStyle(.radioGroup)
                Text(trackFetchingMethodDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("General") {
                LaunchAtLogin.Toggle {
                    Text("Launch at login")
                }
                UpdateSettingsView(updaterViewModel: updaterViewModel)
            }
            Section("Dock") {
                Toggle("Show icon in dock", isOn: $showIconInDock)
                Toggle("Show artwork in dock", isOn: $showArtworkInDock)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
    }

    private var trackFetchingMethodDescription: String {
        switch trackFetchingMethod {
        case .perApp:
            return
                "Uses AppleScript to detect tracks from Apple Music and Spotify."
        case .mediaRemote:
            return
                "Uses system-wide MediaRemote to detect tracks from any music player including Tidal, Deezer, and more."
        }
    }
}

#Preview {
    GeneralSettingsPane()
}
