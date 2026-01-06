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
    
    // MARK: - Last.fm Section
    
    

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
