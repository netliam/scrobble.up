//
//  HotkeySettingsPane.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/23/25.
//

import Carbon
import KeyboardShortcuts
import Settings
import SwiftUI

struct ShortcutSettingsPane: View {

	var body: some View {
		Form {
			Section("Scrobbler") {
				KeyboardShortcuts.Recorder("Love/Unlove Track", name: .loveTrack)
			}
			Section("Player") {
				KeyboardShortcuts.Recorder(
					"Bring active player to front", name: .bringPlayerToFront)
			}
			Text("Shortcuts work system-wide while the app is running.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.formStyle(.grouped)
	}
}

#Preview {
	ShortcutSettingsPane()
}
