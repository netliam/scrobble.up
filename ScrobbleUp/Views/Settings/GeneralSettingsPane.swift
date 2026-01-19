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
	@AppStorage(\.showDesktopWidget) private var showDesktopWidget
	@AppStorage(\.widgetWindowBehavior) private var widgetWindowBehavior
	@AppStorage(\.showCurrentTrackInStatusBar) private var showCurrentTrack
	@AppStorage(\.showAlbumNameInStatusBar) private var showAlbumName

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
					.onChange(of: showIconInDock) { oldValue, newValue in
						if !newValue {
							showArtworkInDock = false
						}
					}
				Toggle("Show artwork in dock", isOn: $showArtworkInDock)
					.disabled(!showIconInDock)
				if !showIconInDock {
					Text("To enable show artwork in dock you must also enable show icon in dock.")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			Section("Widget") {
				Toggle("Show widget", isOn: $showDesktopWidget)

				if showDesktopWidget {
					Picker("Widget window behavior", selection: $widgetWindowBehavior) {
						Text("Desktop").tag(WidgetWindowBehavior.desktop)
						Divider()
						Text("Above").tag(WidgetWindowBehavior.above)
						Text("Stuck").tag(WidgetWindowBehavior.stuck)
						Text("Standard Window").tag(WidgetWindowBehavior.standardWindow)
					}
					Text(widgetWindowBehaviorDescription)
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			Section("Status Bar") {
				Toggle("Show current track in status bar", isOn: $showCurrentTrack)
					.onChange(of: showCurrentTrack) { oldValue, newValue in
						if !newValue {
							showAlbumName = false
						}
					}

				Toggle("Show album name", isOn: $showAlbumName)
					.disabled(!showCurrentTrack)
			}
		}
		.formStyle(.grouped)
		.frame(width: 450)
	}

	private var widgetWindowBehaviorDescription: String {
		switch widgetWindowBehavior {
		case .above:
			return
				"The widget will always stay on top of all other windows, floating above your workspace."
		case .stuck:
			return
				"The widget will stick to one position on the desktop and cannot be moved or interacted with."
		case .desktop:
			return
				"The widget will stick to the desktop and will never go over another window, staying behind your active apps."
		case .standardWindow:
			return
				"The widget will behave like a regular window with the ability to go over other windows."
		}
	}
}

#Preview {
	GeneralSettingsPane()
}
