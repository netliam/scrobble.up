//
//  MenuController.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/26/25.
//

import AppKit
import LastFM
import SwiftUI

final class MenuController: NSObject, NSApplicationDelegate, NSWindowDelegate {

	private var statusItem: NSStatusItem?

	// Menu components
	private let menu = NSMenu()
	private let menuBuilder: MenuBuilder
	private let recentTracksUpdater: RecentTracksUpdater
	private let menuActions: MenuActions

	private var recentTrackItems: [NSMenuItem] = []
	private var isMenuBuilt = false

	private var contextObserver: NSObjectProtocol?

	private var mainWindow: NSWindow?

	let core: CoreDataStack = .shared
	let appState: AppState = .shared

	override init() {
		self.menuBuilder = MenuBuilder()
		self.recentTracksUpdater = RecentTracksUpdater()
		self.menuActions = MenuActions()

		super.init()

		setupStatusBar()
		startObservingCoreDataChanges()
	}

	deinit {
		if let contextObserver {
			NotificationCenter.default.removeObserver(contextObserver)
		}
	}

	// MARK: - Status Bar

	private func setupStatusBar() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		if let button = statusItem?.button {
			let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
			let image = NSImage(named: "ScrobbleUp.menu")
			button.image = image?.withSymbolConfiguration(config)
			button.target = self
			button.action = #selector(showMenu)
		}
	}

	// MARK: - Core Data Observer

	private func startObservingCoreDataChanges() {
		let ctx = core.container.viewContext
		contextObserver = NotificationCenter.default.addObserver(
			forName: .NSManagedObjectContextObjectsDidChange,
			object: ctx,
			queue: .main
		) { [weak self] notification in
			self?.refreshMenu()
		}
	}

	// MARK: - Menu Lifecycle

	func refresh() {
		refreshMenu()
	}

	@objc private func showMenu() {
		buildMenuIfNeeded()
		refreshMenu()
		statusItem?.menu = menu
		statusItem?.button?.performClick(nil)
	}

	private func buildMenuIfNeeded() {
		guard !isMenuBuilt else { return }
		buildMenu()
		isMenuBuilt = true
	}

	private func buildMenu() {
		menu.removeAllItems()
		menu.autoenablesItems = false

		// Recently Played section
		let recentlyPlayedHeader = menuBuilder.createSectionHeader(title: "Recently Played")
		menu.addItem(recentlyPlayedHeader)

		recentTrackItems = menuBuilder.createRecentTrackPlaceholders(count: 5)
		recentTrackItems.forEach { menu.addItem($0) }

		menu.addItem(NSMenuItem.separator())

		// Player selection (if both players running)
		if shouldShowPlayerSelection() {
			let playerItems = menuBuilder.createPlayerSelectionSection(
				target: menuActions,
				action: #selector(MenuActions.handlePlayerOverrideSelection(_:))
			)
			playerItems.forEach { menu.addItem($0) }
			menu.addItem(NSMenuItem.separator())
		}

		// App actions
		let scrobbleLogItem = menuBuilder.createMenuItem(
			title: "Scrobble Log",
			icon: "scroll.fill",
			target: menuActions,
			action: #selector(MenuActions.openMainWindow)
		)
		menu.addItem(scrobbleLogItem)

		let settingsItem = menuBuilder.createMenuItem(
			title: "Settings...",
			icon: "gear",
			keyEquivalent: ",",
			target: menuActions,
			action: #selector(MenuActions.openSettings)
		)
		menu.addItem(settingsItem)

		menu.addItem(NSMenuItem.separator())

		let quitItem = menuBuilder.createMenuItem(
			title: "Quit scrobble.up",
			icon: "xmark.rectangle",
			keyEquivalent: "q",
			target: menuActions,
			action: #selector(MenuActions.quitApp)
		)
		menu.addItem(quitItem)
	}

	private func refreshMenu() {
		// Check if player section visibility changed
		let hasPlayerSection = menu.items.contains { $0.title == "Active Player" }
		if shouldShowPlayerSelection() != hasPlayerSection {
			isMenuBuilt = false
			buildMenu()
		}

		// Update recent tracks
		let recentEntries = LogEntry.fetchRecent(context: core.container.viewContext, limit: 10)
		let uniqueEntries = recentTracksUpdater.removeDuplicates(from: recentEntries)

		recentTracksUpdater.updateRecentTrackItems(
			recentTrackItems,
			with: Array(uniqueEntries.prefix(5))
		)

		// Update player selection checkmarks
		if shouldShowPlayerSelection() {
			updatePlayerSelectionCheckmarks()
		}
	}

	private func shouldShowPlayerSelection() -> Bool {
		let appleMusicRunning = !NSRunningApplication.runningApplications(
			withBundleIdentifier: "com.apple.Music"
		).isEmpty
		let spotifyRunning = !NSRunningApplication.runningApplications(
			withBundleIdentifier: "com.spotify.client"
		).isEmpty
		return appleMusicRunning && spotifyRunning
	}

	private func updatePlayerSelectionCheckmarks() {
		let playerOverride = UserDefaults.standard.get(\.playerOverride)
		let checkmark = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
			.configureForMenu(size: 20)

		for item in menu.items
		where item.action == #selector(MenuActions.handlePlayerOverrideSelection(_:)) {
			switch item.tag {
			case 0:
				item.image = playerOverride == .none ? checkmark : menuBuilder.icons.automatic
			case 1:
				item.image =
					playerOverride == .appleMusic ? checkmark : menuBuilder.icons.appleMusic
			case 2:
				item.image = playerOverride == .spotify ? checkmark : menuBuilder.icons.spotify
			default:
				break
			}
		}
	}
}
