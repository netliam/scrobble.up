//
//  RecentTracksUpdater.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/5/26.
//

import AppKit
import LastFM

final class RecentTracksUpdater {

	// MARK: - Dependencies

	private let lastFm: LastFmManager = .shared
	private let artworkManager: ArtworkManager = .shared
	private let notifications: NotificationController = .shared
	private let menuActions = MenuActions()

	// MARK: - Cache

	private var trackInfoCache: [String: TrackInfo] = [:]

	// MARK: - Public API

	func removeDuplicates(from entries: [LogEntry]) -> [LogEntry] {
		var seen = Set<String>()
		return entries.filter { entry in
			let key = createCacheKey(for: entry)
			if seen.contains(key) {
				return false
			} else {
				seen.insert(key)
				return true
			}
		}
	}

	func updateRecentTrackItems(_ items: [NSMenuItem], with entries: [LogEntry]) {
		DispatchQueue.main.async {
			// Update items with entries
			for (index, entry) in entries.prefix(items.count).enumerated() {
				let item = items[index]
				self.configureTrackItem(item, with: entry)
				self.loadArtwork(for: entry, into: item)
				self.loadTrackDetails(for: entry, into: item)
			}

			// Hide unused items
			for index in entries.count..<5 {
				let item = items[index]
				self.configureEmptyTrackItem(item)
			}
		}
	}

	// MARK: - Item Configuration

	private func configureTrackItem(_ item: NSMenuItem, with entry: LogEntry) {
		item.target = nil
		item.action = nil
		item.representedObject = createCacheKey(for: entry)
		item.isHidden = false
		item.isEnabled = true

		let placeholderImage = artworkManager.placeholder().styled(
			size: NSSize(width: 32, height: 32),
			cornerRadius: 4
		)

		if let view = item.view as? RecentlyPlayedMenuItemView {
			view.configure(title: entry.title, subtitle: entry.artist, image: placeholderImage)
		} else {
			let view = RecentlyPlayedMenuItemView(width: 260)
			view.configure(title: entry.title, subtitle: entry.artist, image: placeholderImage)
			item.view = view
		}
	}

	private func configureEmptyTrackItem(_ item: NSMenuItem) {
		if let view = item.view as? RecentlyPlayedMenuItemView {
			view.configure(title: "—", subtitle: nil, image: nil)
		}
		item.representedObject = nil
		item.isHidden = true
		item.isEnabled = false
	}

	// MARK: - Artwork Loading

	private func loadArtwork(for entry: LogEntry, into item: NSMenuItem) {
		Task {
			if let artwork = await artworkManager.fetchArtwork(
				artist: entry.artist,
				track: entry.title,
				album: entry.album
			) {
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
	}

	// MARK: - Track Details & Submenu

	private func loadTrackDetails(for entry: LogEntry, into item: NSMenuItem) {
		let key = createCacheKey(for: entry)

		if let cached = trackInfoCache[key] {
			buildSubmenu(for: entry, trackInfo: cached, item: item)
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
					await MainActor.run {
						self.buildSubmenu(for: entry, trackInfo: info, item: item)
					}
				}
			} catch {}
		}
	}

	private func buildSubmenu(for entry: LogEntry, trackInfo: TrackInfo, item: NSMenuItem) {
		let subMenu = NSMenu()

		// Copy action
		let copyItem = NSMenuItem(
			title: "Copy Artist & Title",
			action: #selector(MenuActions.copyArtistAndTitle(_:)),
			keyEquivalent: ""
		)
		copyItem.target = menuActions
		copyItem.representedObject = ["artist": entry.artist, "title": entry.title]
		subMenu.addItem(copyItem)

		subMenu.addItem(NSMenuItem.separator())

		// Similar Artists header
		let artistsHeader = NSMenuItem(title: "Similar Artists", action: nil, keyEquivalent: "")
		artistsHeader.isEnabled = false
		subMenu.addItem(artistsHeader)

		let artistsLoading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
		artistsLoading.isEnabled = false
		subMenu.addItem(artistsLoading)

		subMenu.addItem(NSMenuItem.separator())

		// Similar Tracks header
		let tracksHeader = NSMenuItem(title: "Similar Tracks", action: nil, keyEquivalent: "")
		tracksHeader.isEnabled = false
		subMenu.addItem(tracksHeader)

		let tracksLoading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
		tracksLoading.isEnabled = false
		subMenu.addItem(tracksLoading)

		item.isEnabled = true
		item.submenu = subMenu

		// Load similar artists & tracks
		loadSimilarContent(
			for: entry,
			subMenu: subMenu,
			artistsHeader: artistsHeader,
			artistsLoading: artistsLoading,
			tracksHeader: tracksHeader,
			tracksLoading: tracksLoading
		)
	}

	private func loadSimilarContent(
		for entry: LogEntry,
		subMenu: NSMenu,
		artistsHeader: NSMenuItem,
		artistsLoading: NSMenuItem,
		tracksHeader: NSMenuItem,
		tracksLoading: NSMenuItem
	) {
		Task { [weak self] in
			guard let self = self else { return }

			let artists: [ArtistSimilar]? = await lastFm.fetchSimilarArtists(
				artist: entry.artist,
				autocorrect: true,
				limit: 7
			)
			let tracks: [TrackSimilar]? = await lastFm.fetchSimilarTracks(
				artist: entry.artist,
				track: entry.title,
				autocorrect: true,
				limit: 7
			)

			let similarArtists = artists
			let similarTracks = tracks

			await MainActor.run {
				// Remove loading indicators
				if let index = subMenu.items.firstIndex(of: artistsLoading) {
					subMenu.removeItem(at: index)
				}
				if let index = subMenu.items.firstIndex(of: tracksLoading) {
					subMenu.removeItem(at: index)
				}

				// Insert similar artists
				self.insertSimilarArtists(
					similarArtists ?? [],
					into: subMenu,
					after: artistsHeader,
					before: tracksHeader
				)

				// Insert similar tracks
				self.insertSimilarTracks(
					similarTracks ?? [],
					into: subMenu,
					after: tracksHeader
				)
			}
		}
	}

	private func insertSimilarArtists(
		_ artists: [ArtistSimilar],
		into subMenu: NSMenu,
		after header: NSMenuItem,
		before tracksHeader: NSMenuItem
	) {
		guard let headerIndex = subMenu.items.firstIndex(of: header) else { return }

		// Clear previous items
		let index = headerIndex + 1
		while index < subMenu.items.count,
			subMenu.items[index] !== tracksHeader,
			!subMenu.items[index].isSeparatorItem
		{
			subMenu.removeItem(at: index)
		}

		var insertIndex = headerIndex + 1
		if artists.isEmpty {
			let noResults = NSMenuItem(title: "No similar artists", action: nil, keyEquivalent: "")
			noResults.isEnabled = false
			subMenu.insertItem(noResults, at: insertIndex)
		} else {
			for artist in artists {
				let menuItem = NSMenuItem(
					title: artist.name,
					action: #selector(MenuActions.openArtistPage(_:)),
					keyEquivalent: ""
				)
				menuItem.target = menuActions
				menuItem.representedObject = ["artist": artist.name]
				menuItem.isEnabled = true
				menuItem.truncateTitle(maxWidth: 200)
				subMenu.insertItem(menuItem, at: insertIndex)
				insertIndex += 1
			}
		}
	}

	private func insertSimilarTracks(
		_ tracks: [TrackSimilar],
		into subMenu: NSMenu,
		after header: NSMenuItem
	) {
		guard let headerIndex = subMenu.items.firstIndex(of: header) else { return }

		// Clear previous items
		let index = headerIndex + 1
		while index < subMenu.items.count, !subMenu.items[index].isSeparatorItem {
			subMenu.removeItem(at: index)
		}

		var insertIndex = headerIndex + 1
		if tracks.isEmpty {
			let noResults = NSMenuItem(title: "No similar tracks", action: nil, keyEquivalent: "")
			noResults.isEnabled = false
			subMenu.insertItem(noResults, at: insertIndex)
		} else {
			for track in tracks {
				let menuItem = NSMenuItem(
					title: track.name,
					action: #selector(MenuActions.openTrackPage(_:)),
					keyEquivalent: ""
				)
				menuItem.target = menuActions
				menuItem.representedObject = [
					"artist": track.artist.name,
					"title": track.name,
				]
				menuItem.isEnabled = true

				let view = RecentlyPlayedMenuItemView(width: 260)
				view.configure(title: track.name, subtitle: track.artist.name, image: nil)
				menuItem.view = view

				subMenu.insertItem(menuItem, at: insertIndex)
				insertIndex += 1
			}
		}
	}

	// MARK: - Helpers

	private func createCacheKey(for entry: LogEntry) -> String {
		"\(entry.artist.lowercased())|\(entry.title.lowercased())|\((entry.album ?? "").lowercased())"
	}
}
