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
	@AppStorage(\.openLinksWith) private var openLinksWith
	@AppStorage(\.showIconInDock) private var showIconInDock
	@AppStorage(\.showArtworkInDock) private var showArtworkInDock

	var body: some View {
		Form {
			Section("Player") {
				Picker("Player switching", selection: $playerSwitching) {
					Text("Automatic").tag(PlayerSwitching.automatic)
					Divider()
					Text("Prefer Apple Music").tag(PlayerSwitching.preferAppleMusic)
					Text("Prefer Spotify").tag(PlayerSwitching.preferSpotify)
				}
				Picker("Open links in", selection: $openLinksWith) {
					Text("Current active player or last.fm").tag(
						OpenLinksWith.currentActivePlayerOrLastFm)
					Text("Current active player or Apple Music").tag(
						OpenLinksWith.currentActivePlayerOrAppleMusic)
					Text("Current active player or Spotify").tag(
						OpenLinksWith.currentActivePlayerOrSpotify)
					Divider()
					Text("Always in Apple Music").tag(OpenLinksWith.alwaysInAppleMusic)
					Text("Always in Spotify").tag(OpenLinksWith.alwaysInSpotify)
				}
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
}

#Preview {
	GeneralSettingsPane()
}
