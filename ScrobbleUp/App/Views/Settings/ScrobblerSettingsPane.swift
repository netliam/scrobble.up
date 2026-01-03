//
//  ScrobblingSettingsPane.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Settings
import SwiftUI

struct ScrobblerSettingsPane: View {
    @AppStorage(\.syncLikes) private var syncLikes
    @AppStorage(\.scrobbleTrackAt) private var scrobbleTrackAt
    @AppStorage(\.trackFetchingMethod) private var trackFetchingMethod

    var body: some View {
        Form {
            Section("Track Detection") {
                Picker("Fetching method", selection: $trackFetchingMethod) {
                    Text("Per-App (AppleScript)").tag(TrackFetchingMethod.perApp)
                    Text("MediaRemote (System-wide)").tag(TrackFetchingMethod.mediaRemote)
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
            return "Uses AppleScript to detect tracks from Apple Music and Spotify. More reliable for these specific apps."
        case .mediaRemote:
            return "Uses system-wide MediaRemote to detect tracks from any music player including Tidal, Deezer, and more."
        }
    }
}
