//
//  ScrobblingSettingsPane.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Settings
import SwiftUI

struct ScrobblerSettingsPane: View {
	@AppStorage(\.playerSwitching) private var playerSwitching
	@AppStorage(\.trackFetchingMethod) private var trackFetchingMethod
	@AppStorage(\.openLinksWith) private var openLinksWith
	@AppStorage(\.syncLikes) private var syncLikes
	@AppStorage(\.scrobbleTrackAt) private var scrobbleTrackAt

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
			Section("Integration") {
				Toggle(
					"Sync likes between Apple Music and scrobbler",
					isOn: $syncLikes
				)
			}
			Section("Scrobbling") {
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text("50%")
							.font(.caption)
							.foregroundColor(.secondary)
						Slider(
							value: Binding(
								get: { Double(scrobbleTrackAt) },
								set: { scrobbleTrackAt = Int($0) }
							),
							in: 50...100,
							step: 5
						)
						Text("100%")
							.font(.caption)
							.foregroundColor(.secondary)
					}
					Text("Scrobble track at \(scrobbleTrackAt)% of its length")
						.font(.caption)
						.foregroundColor(.secondary)
				}
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
