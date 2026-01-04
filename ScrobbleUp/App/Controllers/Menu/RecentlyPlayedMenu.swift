//
//  RecentlyPlayedMenu.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/26/25.
//

import AppKit
import Foundation
import LastFM

final class RecentlyPlayedMenu {
	// Injected Dependencies
	private let mainMenu: NSMenu

	// Dependencies
	private let lastFm: LastFmManager = .shared
	private let artworkManager: ArtworkManager = .shared
	private let notifications: NotificationController = .shared

	private var trackInfoCache: [String: TrackInfo] = [:]
	var recentTrackItems: [NSMenuItem] = []

	init(mainMenu: NSMenu) {
		self.mainMenu = mainMenu
	}

	// MARK: - Public API

	func uniqueRecent(_ entries: [LogEntry]) -> [LogEntry] {
		var seen = Set<String>()
		return entries.filter { entry in
			let key = cacheKey(for: entry)
			if seen.contains(key) {
				return false
			} else {
				seen.insert(key)
				return true
			}
		}
	}

	func applyRecentTracks(_ entries: [LogEntry]) {
		DispatchQueue.main.async {
			guard self.mainMenu.items.contains(where: { $0.title == "Recently Played" }) else {
				return
			}
			for (i, entry) in entries.prefix(5).enumerated() {
				let item = self.recentTrackItems[i]

				item.target = nil
				item.action = nil

				if let view = item.view as? RecentlyPlayedMenuItemView {
					view.configure(
						title: entry.title,
						subtitle: entry.artist,
						image: self.artworkManager.placeholder().styled(
							size: NSSize(width: 32, height: 32),
							cornerRadius: 4
						)
					)
				} else {
					let view = RecentlyPlayedMenuItemView(width: 260)
					view.configure(
						title: entry.title,
						subtitle: entry.artist,
						image: self.artworkManager.placeholder().styled(
							size: NSSize(width: 32, height: 32),
							cornerRadius: 4
						)
					)
					item.view = view
				}

				Task {
					if let artwork = await self.artworkManager.fetchFromiTunes(
						artist: entry.artist, track: entry.title)
					{
						await MainActor.run {
							let view = item.view as? RecentlyPlayedMenuItemView
							view?.image = artwork.styled(
								size: NSSize(width: 32, height: 32),
								cornerRadius: 4
							)
						}
					}
				}
				item.representedObject = self.cacheKey(for: entry)
				item.isHidden = false
				item.isEnabled = true
			}
			for i in entries.count..<5 {
				let item = self.recentTrackItems[i]
				if let view = item.view as? RecentlyPlayedMenuItemView {
					view.configure(title: "—", subtitle: nil, image: nil)
				}
				item.representedObject = nil
				item.isHidden = true
				item.isEnabled = false
			}
		}
	}

	func cacheKey(for entry: LogEntry) -> String {
		"\(entry.artist.lowercased())|\(entry.title.lowercased())|\((entry.album ?? "").lowercased())"
	}

	// MARK: - Private API

	func updateTrackInfoIfNeeded(for entry: LogEntry, at index: Int) {
		let key = cacheKey(for: entry)
		if let cached = trackInfoCache[key] {
			applyTrackInfo(cached, entry: entry, toItemAt: index)
			return
		}
		Task { [weak self] in
			guard let self else { return }
			do {
				if let info = try await lastFm.fetchTrackInfo(
					artist: entry.artist,
					track: entry.title
				) {
					self.trackInfoCache[key] = info
					self.applyTrackInfo(info, entry: entry, toItemAt: index)
				}
			} catch {}
		}
	}

	private func applyTrackInfo(_ trackInfo: TrackInfo, entry: LogEntry, toItemAt index: Int) {
		let key = cacheKey(for: entry)
		guard
			let item = recentTrackItems.first(where: {
				($0.representedObject as? String) == key
			})
		else { return }

		if let view = item.view as? RecentlyPlayedMenuItemView {
			view.image = artworkManager.placeholder().styled(
				size: NSSize(width: 32, height: 32),
				cornerRadius: 4
			)
		}

		Task { [weak self] in
			guard let self else { return }
			if let artwork = await artworkManager.fetchFromiTunes(
				artist: entry.artist, track: entry.title)
			{
				await MainActor.run {
					if let view = item.view as? RecentlyPlayedMenuItemView {
						view.image = artwork.styled(
							size: NSSize(width: 32, height: 32),
							cornerRadius: 4
						)
					}
				}
			}
		}

		let subMenu = NSMenu()

		let copyArtistTrack = NSMenuItem(
			title: "Copy Artist & Title",
			action: #selector(copyArtistTrack),
			keyEquivalent: ""
		)
		copyArtistTrack.target = self
		copyArtistTrack.representedObject = ["artist": entry.artist, "title": entry.title]
		subMenu.addItem(copyArtistTrack)

		subMenu.addItem(NSMenuItem.separator())

		let artistsHeader = NSMenuItem(
			title: "Similar Artists",
			action: nil,
			keyEquivalent: ""
		)
		artistsHeader.isEnabled = false
		subMenu.addItem(artistsHeader)
		let artistsLoading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
		artistsLoading.isEnabled = false
		subMenu.addItem(artistsLoading)

		subMenu.addItem(NSMenuItem.separator())

		let tracksHeader = NSMenuItem(
			title: "Similar Tracks",
			action: nil,
			keyEquivalent: ""
		)
		tracksHeader.isEnabled = false
		subMenu.addItem(tracksHeader)
		let tracksLoading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
		tracksLoading.isEnabled = false
		subMenu.addItem(tracksLoading)

		item.isEnabled = true
		item.submenu = subMenu

		Task { [weak self] in
			guard let self else { return }
			async let artists = lastFm.fetchSimilarArtists(
				artist: entry.artist,
				autocorrect: true,
				limit: 7
			)
			async let tracks = lastFm.fetchSimilarTracks(
				artist: entry.artist,
				track: entry.title,
				autocorrect: true,
				limit: 7
			)
			let (similarArtists, similarTracks) = await (artists, tracks)

			await MainActor.run {
				guard let submenu = item.submenu else { return }

				// Remove loading indicator for artists
				if let loadingIndex = submenu.items.firstIndex(of: artistsLoading) {
					submenu.removeItem(at: loadingIndex)
				}

				// Clear previous artist items
				if let artistsHeaderIndex = submenu.items.firstIndex(of: artistsHeader) {
					let i = artistsHeaderIndex + 1
					while i < submenu.items.count,
						submenu.items[i] !== tracksHeader,
						!submenu.items[i].isSeparatorItem
					{
						submenu.removeItem(at: i)
					}
				}

				// Insert artist results
				let artistsList = similarArtists ?? []
				if let artistsHeaderIndex = submenu.items.firstIndex(of: artistsHeader) {
					var insertIndex = artistsHeaderIndex + 1
					if !artistsList.isEmpty {
						for artist in artistsList {
							let menuItem = NSMenuItem(
								title: artist.name,
								action: #selector(self.openArtist),
								keyEquivalent: ""
							)
							menuItem.target = self
							menuItem.representedObject = ["artist": artist.name]
							menuItem.isEnabled = true
							menuItem.truncateTitle(maxWidth: 200)
							submenu.insertItem(menuItem, at: insertIndex)
							insertIndex += 1
						}
					} else {
						let menuItem = NSMenuItem(
							title: "No similar artists",
							action: nil,
							keyEquivalent: ""
						)
						menuItem.isEnabled = false
						submenu.insertItem(menuItem, at: insertIndex)
					}
				}

				// Remove loading indicator for tracks
				if let loadingIndex = submenu.items.firstIndex(of: tracksLoading) {
					submenu.removeItem(at: loadingIndex)
				}

				// Clear previous track items
				if let tracksHeaderIndex = submenu.items.firstIndex(of: tracksHeader) {
					let i = tracksHeaderIndex + 1
					while i < submenu.items.count, !submenu.items[i].isSeparatorItem {
						submenu.removeItem(at: i)
					}
				}

				// Insert track results
				let tracksList = similarTracks ?? []
				if let tracksHeaderIndex = submenu.items.firstIndex(of: tracksHeader) {
					var insertIndex = tracksHeaderIndex + 1
					if !tracksList.isEmpty {
						for track in tracksList {
							let menuItem = NSMenuItem(
								title: track.name,
								action: #selector(self.openTrack),
								keyEquivalent: ""
							)
							menuItem.target = self
							menuItem.representedObject = [
								"artist": track.artist.name,
								"title": track.name,
							]
							menuItem.isEnabled = true

							let view = RecentlyPlayedMenuItemView(width: 260)
							view.configure(
								title: track.name, subtitle: track.artist.name, image: nil)
							menuItem.view = view

							submenu.insertItem(menuItem, at: insertIndex)
							insertIndex += 1
						}
					} else {
						let menuItem = NSMenuItem(
							title: "No similar tracks",
							action: nil,
							keyEquivalent: ""
						)
						menuItem.isEnabled = false
						submenu.insertItem(menuItem, at: insertIndex)
					}
				}
			}
		}
	}

	@objc private func copyArtistTrack(_ sender: NSMenuItem) {
		if let payload = sender.representedObject as? [String: String],
			let artist = payload["artist"],
			let title = payload["title"]
		{
			let text = "\(artist) — \(title)"
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(text, forType: .string)
			notifications.infoCopiedToClipboard(type: .artistTitle)
		}
	}

	@objc func openArtist(_ sender: NSMenuItem) {
		if let payload = sender.representedObject as? [String: String],
			let artist = payload["artist"]
		{
			Task {
				await LinkManager.shared.openArtist(artist: artist)
			}
		}
	}

	@objc func openTrack(_ sender: NSMenuItem) {
		if let payload = sender.representedObject as? [String: String],
			let artist = payload["artist"],
			let title = payload["title"]
		{
			Task {
				await LinkManager.shared.openTrack(artist: artist, track: title)
			}
		}
	}
}
