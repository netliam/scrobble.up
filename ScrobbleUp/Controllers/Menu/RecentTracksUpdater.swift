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
	private let playerManager: PlayerManager = .shared
	private let menuActions = MenuActions()

	// MARK: - Cache

	private var trackInfoCache: [String: TrackInfo] = [:]
	private var lastDisplayedTracks: [String] = []

	// MARK: - Public API

	func removeDuplicates(from entries: [LogEntry]) -> [LogEntry] {
		var seen = Set<String>()
		return entries.filter { entry in
			let key = CacheHelpers.makeCacheKey(for: entry)
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
			let visibleEntries = Array(entries.prefix(items.count))
			let newTrackKeys = visibleEntries.map { CacheHelpers.makeCacheKey(for: $0) }

			// Update items with entries
			for (index, entry) in visibleEntries.enumerated() {
				let item = items[index]
				let cacheKey = newTrackKeys[index]
				let isNewTrack =
					index >= self.lastDisplayedTracks.count
					|| self.lastDisplayedTracks[index] != cacheKey

				self.configureTrackItem(item, with: entry)

				// Check if artwork is needed
				let needsArtwork = self.shouldFetchArtwork(for: entry, in: item)

				if isNewTrack || needsArtwork {
					self.loadArtwork(for: entry, into: item)
				}

				self.loadTrackDetails(for: entry, into: item)
			}

			self.lastDisplayedTracks = newTrackKeys

			// Hide unused items
			items.dropFirst(entries.count).prefix(5 - entries.count).forEach {
				self.configureEmptyTrackItem($0)
			}
		}
	}

	private func shouldFetchArtwork(for entry: LogEntry, in item: NSMenuItem) -> Bool {
		guard item.view as? RecentlyPlayedMenuItemView != nil else { return true }
		return artworkManager.getCachedArtwork(
			artist: entry.artist,
			track: entry.title,
			album: entry.album
		) == nil
	}

	// MARK: - Item Configuration

	private func configureTrackItem(_ item: NSMenuItem, with entry: LogEntry) {
		item.target = nil
		item.action = nil
		item.representedObject = CacheHelpers.makeCacheKey(for: entry)
		item.isHidden = false
		item.isEnabled = true

		let artwork = getStyledArtwork(for: entry)
		let view = getOrCreateView(for: item)
		view.configure(
			title: entry.title, subtitle: entry.artist, image: artwork, isScrobbled: entry.scrobbled
		)
	}

	private func getStyledArtwork(for entry: LogEntry) -> NSImage {
		let cachedArtwork =
			artworkManager.getCachedArtwork(
				artist: entry.artist,
				track: entry.title,
				album: entry.album
			) ?? artworkManager.placeholder()

		return ImageHelpers.styleForMenu(cachedArtwork)
	}

	private func getOrCreateView(for item: NSMenuItem) -> RecentlyPlayedMenuItemView {
		if let existingView = item.view as? RecentlyPlayedMenuItemView {
			return existingView
		}
		let view = RecentlyPlayedMenuItemView(width: 260)
		item.view = view
		return view
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
				updateItemArtwork(item, with: artwork, for: entry)
			}
		}
	}

	@MainActor
	private func updateItemArtwork(_ item: NSMenuItem, with artwork: NSImage, for entry: LogEntry) {
		guard verifyItemMatchesEntry(item, entry: entry),
			let view = item.view as? RecentlyPlayedMenuItemView
		else { return }
		view.image = ImageHelpers.styleForMenu(artwork)
	}

	private func verifyItemMatchesEntry(_ item: NSMenuItem, entry: LogEntry) -> Bool {
		let currentKey = item.representedObject as? String
		let entryKey = CacheHelpers.makeCacheKey(for: entry)
		return currentKey == entryKey
	}

	// MARK: - Track Details & Submenu

	private func loadTrackDetails(for entry: LogEntry, into item: NSMenuItem) {
		let key = CacheHelpers.makeCacheKey(for: entry)

		if let cached = trackInfoCache[key] {
			buildSubmenu(for: entry, trackInfo: cached, item: item)
			return
		}

		Task { [weak self] in
			guard let self else { return }
			if let info = await lastFm.fetchTrackInfo(
				artist: entry.artist,
				track: entry.title
			) {
				self.trackInfoCache[key] = info
				await MainActor.run {
					self.buildSubmenu(for: entry, trackInfo: info, item: item)
				}
			}
		}
	}

	private func buildSubmenu(for entry: LogEntry, trackInfo: TrackInfo, item: NSMenuItem) {
		let subMenu = NSMenu()
		subMenu.minimumWidth = 260

		// Copy action
		addCopyMenuItem(to: subMenu, entry: entry)

		// Love/Favorite action
		_ = addLoveMenuItem(to: subMenu, entry: entry, trackInfo: trackInfo)

		subMenu.addItem(NSMenuItem.separator())

		// Similar content sections
		let (artistsHeader, artistsLoading) = addSectionHeaders(
			to: subMenu, title: "Similar Artists")
		subMenu.addItem(NSMenuItem.separator())
		let (tracksHeader, tracksLoading) = addSectionHeaders(to: subMenu, title: "Similar Tracks")

		item.isEnabled = true
		item.submenu = subMenu

		loadSimilarContent(
			for: entry,
			subMenu: subMenu,
			artistsHeader: artistsHeader,
			artistsLoading: artistsLoading,
			tracksHeader: tracksHeader,
			tracksLoading: tracksLoading
		)
	}

	private func addCopyMenuItem(to menu: NSMenu, entry: LogEntry) {
		let copyItem = NSMenuItem(
			title: "Copy Artist & Title",
			action: #selector(MenuActions.copyArtistAndTitle(_:)),
			keyEquivalent: ""
		)
		copyItem.target = menuActions
		copyItem.representedObject = ["artist": entry.artist, "title": entry.title]
		menu.addItem(copyItem)
	}

	private func addLoveMenuItem(to menu: NSMenu, entry: LogEntry, trackInfo: TrackInfo)
		-> NSMenuItem
	{
		let loveItem = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
		loveItem.isEnabled = false
		menu.addItem(loveItem)

		Task { [weak self] in
			guard let self else { return }
			let isFavorited = await playerManager.fetchFavoriteState(
				title: trackInfo.name,
				artist: trackInfo.artist.name
			)

			self.updateLoveMenuItem(loveItem, isFavorited: isFavorited, entry: entry)
		}

		return loveItem
	}

	@MainActor
	private func updateLoveMenuItem(
		_ item: NSMenuItem, isFavorited: TrackFavoriteState, entry: LogEntry
	) {
		let isFavorite = isFavorited.isFavoritedOnAnyService
		item.title = isFavorite ? "Unfavorite Track" : "Favorite Track"
		item.action = #selector(MenuActions.toggleTrackLove(_:))
		item.target = menuActions
		item.representedObject = ["artist": entry.artist, "title": entry.title]
		item.image = NSImage(
			systemSymbolName: isFavorite ? "heart.fill" : "heart",
			accessibilityDescription: nil
		)?.configureForMenu(size: 16)
		item.isEnabled = true
	}

	private func addSectionHeaders(to menu: NSMenu, title: String) -> (
		header: NSMenuItem, loading: NSMenuItem
	) {
		let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
		header.isEnabled = false
		menu.addItem(header)

		let loading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
		loading.isEnabled = false
		menu.addItem(loading)

		return (header, loading)
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

			async let artistsTask = lastFm.fetchSimilarArtists(
				artist: entry.artist,
				autocorrect: true,
				limit: 7
			)
			async let tracksTask = lastFm.fetchSimilarTracks(
				artist: entry.artist,
				track: entry.title,
				autocorrect: true,
				limit: 7
			)

			let (similarArtists, similarTracks) = await (artistsTask, tracksTask)

			await MainActor.run {
				subMenu.removeItem(artistsLoading)
				subMenu.removeItem(tracksLoading)

				self.insertSimilarArtists(
					similarArtists ?? [],
					into: subMenu,
					after: artistsHeader,
					before: tracksHeader
				)

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

		// Clear previous items between header and tracksHeader
		clearMenuItems(in: subMenu, startingAt: headerIndex + 1, until: tracksHeader)

		let insertIndex = headerIndex + 1

		if artists.isEmpty {
			insertEmptyMessage("No similar artists", into: subMenu, at: insertIndex)
		} else {
			insertArtistMenuItems(artists, into: subMenu, startingAt: insertIndex)
		}
	}

	private func insertSimilarTracks(
		_ tracks: [TrackSimilar],
		into subMenu: NSMenu,
		after header: NSMenuItem
	) {
		guard let headerIndex = subMenu.items.firstIndex(of: header) else { return }

		// Clear previous items after header
		clearMenuItems(in: subMenu, startingAt: headerIndex + 1, untilSeparator: true)

		let insertIndex = headerIndex + 1

		if tracks.isEmpty {
			insertEmptyMessage("No similar tracks", into: subMenu, at: insertIndex)
		} else {
			insertTrackMenuItems(tracks, into: subMenu, startingAt: insertIndex)
		}
	}

	private func clearMenuItems(
		in menu: NSMenu, startingAt startIndex: Int, until stopItem: NSMenuItem
	) {
		let index = startIndex
		while index < menu.items.count,
			menu.items[index] !== stopItem,
			!menu.items[index].isSeparatorItem
		{
			menu.removeItem(at: index)
		}
	}

	private func clearMenuItems(in menu: NSMenu, startingAt startIndex: Int, untilSeparator: Bool) {
		let index = startIndex
		while index < menu.items.count, !menu.items[index].isSeparatorItem {
			menu.removeItem(at: index)
		}
	}

	private func insertEmptyMessage(_ message: String, into menu: NSMenu, at index: Int) {
		let item = NSMenuItem(title: message, action: nil, keyEquivalent: "")
		item.isEnabled = false
		menu.insertItem(item, at: index)
	}

	private func insertArtistMenuItems(
		_ artists: [ArtistSimilar], into menu: NSMenu, startingAt startIndex: Int
	) {
		var insertIndex = startIndex
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
			menu.insertItem(menuItem, at: insertIndex)
			insertIndex += 1
		}
	}

	private func insertTrackMenuItems(
		_ tracks: [TrackSimilar], into menu: NSMenu, startingAt startIndex: Int
	) {
		var insertIndex = startIndex
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

			menu.insertItem(menuItem, at: insertIndex)
			insertIndex += 1
		}
	}
}
