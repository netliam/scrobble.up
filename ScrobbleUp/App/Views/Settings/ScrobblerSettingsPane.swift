//
//  ScrobblingSettingsPane.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Defaults
import Settings
import SwiftUI

struct ScrobblerSettingsPane: View {
  @Default(.syncLikes) private var syncLikes
  @Default(.scrobbleTrackAt) private var scrobbleTrackAt

  var body: some View {
    Form {
      Section("Intergration") {
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
}
