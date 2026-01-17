//
//  AppState.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/25/25.
//

import AppKit
import Combine
import KeyboardShortcuts
import Settings

@MainActor
class AppState: ObservableObject {

	static let shared = AppState()

	struct CurrentTrack {
		var image: NSImage? = nil
		var title: String = "-"
		var artist: String = "-"
		var album: String? = nil
	}

	@Published var currentTrack = CurrentTrack()
	@Published var currentActivePlayer: MusicSource?

	var isCurrentTrackFavorited: Bool {
		PlayerManager.shared.isCurrentTrackFavorited
	}

	private let lastFm: LastFmManager = .shared
	private let listenBrainz: ListenBrainzManager = .shared
	private let appleMusic: AppleMusicManager = .shared
	private let notifications: NotificationsController = .shared
	private let playerManager: PlayerManager = .shared

	init() {
		KeyboardShortcuts.onKeyUp(for: .loveTrack) { [self] in
			Task {
				await playerManager.setFavoriteState()
			}
		}
		KeyboardShortcuts.onKeyUp(for: .bringPlayerToFront) { [self] in
			playerManager.bringPlayerToFront()
		}
	}

	var settingsWindowController: SettingsWindowController?

	@MainActor
	func openSettings() {  // swiftlint:disable:this function_body_length

		if settingsWindowController == nil {
			settingsWindowController = SettingsWindowController(
				panes: [
					Settings.Pane(
						identifier: Settings.PaneIdentifier.general,
						title: NSLocalizedString(
							"General", tableName: "GeneralSettings", comment: ""),
						toolbarIcon: NSImage(
							systemSymbolName: "gear", accessibilityDescription: "General")!
					) {
						GeneralSettingsPane()
					},
					Settings.Pane(
						identifier: Settings.PaneIdentifier.notifications,
						title: "Notifications",
						toolbarIcon: NSImage(
							systemSymbolName: "bell.badge.fill",
							accessibilityDescription: "Notifications")!
					) {
						NotificationsSettingsPane()
					},
					Settings.Pane(
						identifier: Settings.PaneIdentifier.shortcuts,
						title: "Shortcuts",
						toolbarIcon: NSImage(
							systemSymbolName: "keyboard", accessibilityDescription: "Shortcuts")!
					) {
						ShortcutSettingsPane()
					},
					Settings.Pane(
						identifier: Settings.PaneIdentifier.lastfm,
						title: "Last.fm",
						toolbarIcon: NSImage(named: "LastFm.logo")!
					) {
						LastFmSettingsPane()
					},
					Settings.Pane(
						identifier: Settings.PaneIdentifier.listenbrainz,
						title: "ListenBrainz",
						toolbarIcon: NSImage(named: "ListenBrainz.logo")!
					) {
						ListenBrainzSettingsPane()
					},
					Settings.Pane(
						identifier: Settings.PaneIdentifier.scrobbler,
						title: "Scrobbler",
						toolbarIcon: NSImage(
							systemSymbolName: "waveform", accessibilityDescription: "Scrobbler")!
					) {
						ScrobblerSettingsPane()
					},
				]
			)
		}
		settingsWindowController?.show()
		settingsWindowController?.window?.orderFrontRegardless()
	}

	@MainActor
	func openSettings(pane: Settings.PaneIdentifier) {
		openSettings()
		settingsWindowController?.show(pane: pane)
	}
}
