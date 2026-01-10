//
//  MenuActions.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/5/26.
//

import AppKit

final class MenuActions: NSObject {

	// MARK: - Dependencies

	private let appState: AppState = .shared
	private let notifications: NotificationController = .shared

	// MARK: - App Actions

	@objc func quitApp() {
		NSApp.terminate(nil)
	}

	@objc func openSettings() {
		appState.openSettings()
	}

	@objc func openAbout() {
		AppDelegate.shared?.showAboutWindow()
	}

	// MARK: - Player Selection

	@objc func handlePlayerOverrideSelection(_ sender: NSMenuItem) {
		let checkmark = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		let automaticIcon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		let appleMusicIcon = NSImage(named: "Apple.Music.icon")?.configureForMenu(size: 20)
		let spotifyIcon = NSImage(named: "Spotify.logo")?.configureForMenu(size: 20)

		// Reset all icons in the menu
		if let menu = sender.menu {
			for item in menu.items where item.action == #selector(handlePlayerOverrideSelection(_:))
			{
				switch item.tag {
				case 0: item.image = automaticIcon
				case 1: item.image = appleMusicIcon
				case 2: item.image = spotifyIcon
				default: break
				}
			}
		}

		// Set checkmark on selected item
		sender.image = checkmark

		// Update preference
		switch sender.tag {
		case 0: UserDefaults.standard.set(.none, for: \.playerOverride)
		case 1: UserDefaults.standard.set(.appleMusic, for: \.playerOverride)
		case 2: UserDefaults.standard.set(.spotify, for: \.playerOverride)
		default: break
		}
	}

	// MARK: - Track Actions

	@objc func copyArtistAndTitle(_ sender: NSMenuItem) {
		guard let payload = sender.representedObject as? [String: String],
			let artist = payload["artist"],
			let title = payload["title"]
		else { return }

		let text = "\(artist) — \(title)"
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
		notifications.infoCopiedToClipboard(type: .artistTitle)
	}

	@objc func openArtistPage(_ sender: NSMenuItem) {
		guard let payload = sender.representedObject as? [String: String],
			let artist = payload["artist"]
		else { return }

		Task {
			await LinkManager.shared.openArtist(artist: artist)
		}
	}

	@objc func openTrackPage(_ sender: NSMenuItem) {
		guard let payload = sender.representedObject as? [String: String],
			let artist = payload["artist"],
			let title = payload["title"]
		else { return }

		Task {
			await LinkManager.shared.openTrack(artist: artist, track: title)
		}
	}

	// MARK: - Last.fm Actions

	@objc func openLastFmProfile() {
		guard let username = LastFmManager.shared.username else { return }
		if let url = URL(string: "https://www.last.fm/user/\(username)") {
			NSWorkspace.shared.open(url)
		}
	}

	// MARK: - ListenBrainz Actions

	@objc func openListenBrainzProfile() {
		guard let username = ListenBrainzManager.shared.username else { return }
		let baseURL = ListenBrainzManager.shared.baseURL
		// Handle both listenbrainz.org and custom instances
		let profileURL: String
		if baseURL.contains("api.listenbrainz.org") {
			profileURL = "https://listenbrainz.org/user/\(username)"
		} else {
			// Custom instance - try to derive web URL from API URL
			let webURL = baseURL.replacingOccurrences(of: "/api", with: "").replacingOccurrences(
				of: "api.", with: "")
			profileURL = "\(webURL)/user/\(username)"
		}
		if let url = URL(string: profileURL) {
			NSWorkspace.shared.open(url)
		}
	}
}
