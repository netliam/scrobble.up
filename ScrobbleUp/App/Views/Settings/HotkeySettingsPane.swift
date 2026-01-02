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

struct HotkeysSettingsPane: View {

	var body: some View {

		Form {
			Section("Keyboard Shortcuts") {

				HStack {
					KeyboardShortcuts.Recorder("Love/Unlove Track", name: .loveTrack)
				}

				Text("Hotkeys work system-wide while the app is running.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
	}
}

#Preview {
	HotkeysSettingsPane()
}
