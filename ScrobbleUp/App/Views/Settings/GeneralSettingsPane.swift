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

	@AppStorage(\.showIconInDock) private var showIconInDock
	@AppStorage(\.showArtworkInDock) private var showArtworkInDock

	var body: some View {
		Form {

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
