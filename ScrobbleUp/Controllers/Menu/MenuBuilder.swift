//
//  MenuBuilder.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/5/26.
//

import AppKit

final class MenuBuilder {

	// MARK: - Icons

	struct Icons {
		let scroll = NSImage(systemSymbolName: "scroll.fill", accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		let gear = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		let quit = NSImage(systemSymbolName: "xmark.rectangle", accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		let checkmark = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		let automatic = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		let appleMusic = NSImage(named: "Apple.Music.icon")?.configureForMenu(size: 20)
		let spotify = NSImage(named: "Spotify.logo")?.configureForMenu(size: 20)
	}

	let icons = Icons()

	private let headerAttributes: [NSAttributedString.Key: Any] = [
		.font: NSFont.systemFont(ofSize: 12, weight: .semibold),
		.foregroundColor: NSColor.secondaryLabelColor,
	]

	// MARK: - Section Headers

	func createSectionHeader(title: String) -> NSMenuItem {
		let item = NSMenuItem.sectionHeader(title: title)
		item.attributedTitle = NSAttributedString(
			string: title,
			attributes: headerAttributes
		)
		return item
	}

	// MARK: - Recent Track Placeholders

	func createRecentTrackPlaceholders(count: Int) -> [NSMenuItem] {
		return (0..<count).map { _ in
			let item = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
			let view = RecentlyPlayedMenuItemView(width: 260)
			view.configure(title: "—", subtitle: nil, image: nil)
			item.view = view
			return item
		}
	}

	// MARK: - Player Selection Section

	func createPlayerSelectionSection(target: AnyObject, action: Selector) -> [NSMenuItem] {
		var items: [NSMenuItem] = []

		let header = createSectionHeader(title: "Active Player")
		items.append(header)

		let playerOverride = UserDefaults.standard.get(\.playerOverride)

		let automaticItem = NSMenuItem(
			title: "Automatic",
			action: action,
			keyEquivalent: ""
		)
		automaticItem.target = target
		automaticItem.tag = 0
		automaticItem.image = playerOverride == .none ? icons.checkmark : icons.automatic
		items.append(automaticItem)

		let appleMusicItem = NSMenuItem(
			title: "Apple Music",
			action: action,
			keyEquivalent: ""
		)
		appleMusicItem.target = target
		appleMusicItem.tag = 1
		appleMusicItem.image = playerOverride == .appleMusic ? icons.checkmark : icons.appleMusic
		items.append(appleMusicItem)

		let spotifyItem = NSMenuItem(
			title: "Spotify",
			action: action,
			keyEquivalent: ""
		)
		spotifyItem.target = target
		spotifyItem.tag = 2
		spotifyItem.image = playerOverride == .spotify ? icons.checkmark : icons.spotify
		items.append(spotifyItem)

		return items
	}
    
    // MARK: - Scrobbler Section (Unified)
    
    func createScrobblerSection(for service: ScrobblerService, target: AnyObject, profileAction: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: service.displayName, action: nil, keyEquivalent: "")
        let subMenu = NSMenu()
        subMenu.autoenablesItems = false

        let width: CGFloat = 260

        // Profile button
        let profileItem = NSMenuItem(title: "Open profile...", action: profileAction, keyEquivalent: "")
        profileItem.target = target
        subMenu.addItem(profileItem)

        // Top separator
        subMenu.addItem(NSMenuItem.separator())

        // Scrobbles row
        let scrobblesRow = MenuItemStatsRowView(width: width, leftText: "Scrobbles")
        let scrobblesItem = NSMenuItem()
        scrobblesItem.view = scrobblesRow
        subMenu.addItem(scrobblesItem)

        // Artists row
        let artistsRow = MenuItemStatsRowView(width: width, leftText: "Artists")
        let artistsItem = NSMenuItem()
        artistsItem.view = artistsRow
        subMenu.addItem(artistsItem)

        // Loved tracks row
        let lovedTracksRow = MenuItemStatsRowView(width: width, leftText: "Loved tracks")
        let lovedTracksItem = NSMenuItem()
        lovedTracksItem.view = lovedTracksRow
        subMenu.addItem(lovedTracksItem)

        // Bottom separator
        subMenu.addItem(NSMenuItem.separator())

        // Top Albums header - get period from appropriate key
        let currentPeriod: TopAlbumPeriod
        switch service {
        case .lastFm:
            currentPeriod = UserDefaults.standard.get(\.lastFmTopAlbumPeriod)
        case .listenBrainz:
            currentPeriod = UserDefaults.standard.get(\.listenBrainzTopAlbumPeriod)
        }
        
        let topAlbumsHeader = MenuItemHeaderView(
            width: width,
            title: "Top Albums",
            rightText: currentPeriod.rawValue
        )
        let headerItem = NSMenuItem()
        headerItem.view = topAlbumsHeader
        subMenu.addItem(headerItem)

        // Top albums grid
        let gridView = TopAlbumsGridView(width: width)
        let gridItem = NSMenuItem()
        gridItem.view = gridView
        subMenu.addItem(gridItem)

        item.submenu = subMenu
        return item
    }

	// MARK: - Generic Menu Items

	func createMenuItem(
		title: String,
		icon: String,
		keyEquivalent: String = "",
		target: AnyObject,
		action: Selector
	) -> NSMenuItem {
		let item = NSMenuItem(
			title: title,
			action: action,
			keyEquivalent: keyEquivalent
		)
		item.target = target
		item.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?
			.configureForMenu(size: 20)
		return item
	}
}
