//
//  MenuController.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/26/25.
//

import AppKit
import LastFM
import SwiftUI
import Combine

final class MenuController: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var statusItem: NSStatusItem?
    
    private let lastFm: LastFmManager = .shared
    private let listenBrainz: ListenBrainzManager = .shared

    // Menu components
    private let menu = NSMenu()
    private let menuBuilder: MenuBuilder
    private let recentTracksUpdater: RecentTracksUpdater
    private let topAlbumsUpdater: TopAlbumsUpdater
    private let userStatsUpdater: UserStatsUpdater
    private let menuActions: MenuActions

    private var recentTrackItems: [NSMenuItem] = []
    
    // Last.fm views
    private var lastFmTopAlbumsGridView: TopAlbumsGridView?
    private var lastFmTopAlbumsHeaderView: MenuItemHeaderView?
    private var lastFmProfileMenuItem: NSMenuItem?
    private var lastFmScrobblesRowView: MenuItemStatsRowView?
    private var lastFmArtistsRowView: MenuItemStatsRowView?
    private var lastFmLovedTracksRowView: MenuItemStatsRowView?
    
    // ListenBrainz views
    private var listenBrainzTopAlbumsGridView: TopAlbumsGridView?
    private var listenBrainzTopAlbumsHeaderView: MenuItemHeaderView?
    private var listenBrainzProfileMenuItem: NSMenuItem?
    private var listenBrainzScrobblesRowView: MenuItemStatsRowView?
    private var listenBrainzLovedTracksRowView: MenuItemStatsRowView?
    
    private var periodMenuItems: [NSMenuItem] = []
    private var isMenuBuilt = false

    private var contextObserver: NSObjectProtocol?
    private var lastFmPeriodObserver: AnyCancellable?
    private var listenBrainzPeriodObserver: AnyCancellable?

    private var mainWindow: NSWindow?

    let core: CoreDataStack = .shared
    let appState: AppState = .shared

    override init() {
        self.menuBuilder = MenuBuilder()
        self.recentTracksUpdater = RecentTracksUpdater()
        self.topAlbumsUpdater = TopAlbumsUpdater()
        self.userStatsUpdater = UserStatsUpdater()
        self.menuActions = MenuActions()

        super.init()

        setupStatusBar()
        startObservingCoreDataChanges()
        startObservingPeriodChanges()
    }

    deinit {
        if let contextObserver {
            NotificationCenter.default.removeObserver(contextObserver)
        }
        lastFmPeriodObserver?.cancel()
        listenBrainzPeriodObserver?.cancel()
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

    private func startObservingPeriodChanges() {
        lastFmPeriodObserver = UserDefaults.standard.observe(\.lastFmTopAlbumPeriod) { [weak self] _ in
            self?.refreshTopAlbums(for: .lastFm)
        }
        listenBrainzPeriodObserver = UserDefaults.standard.observe(\.listenBrainzTopAlbumPeriod) { [weak self] _ in
            self?.refreshTopAlbums(for: .listenBrainz)
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

        // Last.fm section
        if lastFm.username != nil {
            let lastFmItem = menuBuilder.createScrobblerSection(
                for: .lastFm,
                target: menuActions,
                profileAction: #selector(MenuActions.openLastFmProfile)
            )
            menu.addItem(lastFmItem)
            
            // Store references to Last.fm views for updates
            extractViewReferences(from: lastFmItem, for: .lastFm)
        }
        
        // ListenBrainz section
        if listenBrainz.username != nil {
            let listenBrainzItem = menuBuilder.createScrobblerSection(
                for: .listenBrainz,
                target: menuActions,
                profileAction: #selector(MenuActions.openListenBrainzProfile)
            )
            menu.addItem(listenBrainzItem)
            
            // Store references to ListenBrainz views for updates
            extractViewReferences(from: listenBrainzItem, for: .listenBrainz)
        }

        menu.addItem(NSMenuItem.separator())

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
    
    private func extractViewReferences(from menuItem: NSMenuItem, for service: ScrobblerService) {
        guard let submenu = menuItem.submenu else { return }
        
        var statsRowIndex = 0
        
        for item in submenu.items {
            if let gridView = item.view as? TopAlbumsGridView {
                switch service {
                case .lastFm:
                    lastFmTopAlbumsGridView = gridView
                case .listenBrainz:
                    listenBrainzTopAlbumsGridView = gridView
                }
            } else if let headerView = item.view as? MenuItemHeaderView {
                switch service {
                case .lastFm:
                    lastFmTopAlbumsHeaderView = headerView
                case .listenBrainz:
                    listenBrainzTopAlbumsHeaderView = headerView
                }
            } else if let statsRow = item.view as? MenuItemStatsRowView {
                switch service {
                case .lastFm:
                    if statsRowIndex == 0 {
                        lastFmScrobblesRowView = statsRow
                    } else if statsRowIndex == 1 {
                        lastFmArtistsRowView = statsRow
                    } else if statsRowIndex == 2 {
                        lastFmLovedTracksRowView = statsRow
                    }
                case .listenBrainz:
                    if statsRowIndex == 0 {
                        listenBrainzScrobblesRowView = statsRow
                    } else if statsRowIndex == 1 {
                        listenBrainzLovedTracksRowView = statsRow
                    }
                }
                statsRowIndex += 1
            } else if item.action != nil && statsRowIndex == 0 {
                // This is the profile menu item (first actionable item)
                switch service {
                case .lastFm:
                    lastFmProfileMenuItem = item
                case .listenBrainz:
                    listenBrainzProfileMenuItem = item
                }
            }
        }
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
        
        // Refresh Last.fm
        if lastFm.username != nil {
            refreshUserStats(for: .lastFm)
            refreshTopAlbums(for: .lastFm)
        }
        
        // Refresh ListenBrainz
        if listenBrainz.username != nil {
            refreshUserStats(for: .listenBrainz)
            refreshTopAlbums(for: .listenBrainz)
        }
    }

    private func refreshUserStats(for service: ScrobblerService) {
        switch service {
        case .lastFm:
            guard let profileItem = lastFmProfileMenuItem,
                  let scrobblesRow = lastFmScrobblesRowView,
                  let artistsRow = lastFmArtistsRowView,
                  let lovedTracksRow = lastFmLovedTracksRowView
            else { return }
            
            userStatsUpdater.updateUserStats(
                profileItem: profileItem,
                scrobblesRow: scrobblesRow,
                artistsRow: artistsRow,
                lovedTracksRow: lovedTracksRow,
                service: .lastFm
            )
            
        case .listenBrainz:
            guard let profileItem = listenBrainzProfileMenuItem,
                  let scrobblesRow = listenBrainzScrobblesRowView,
                  let lovedTracksRow = listenBrainzLovedTracksRowView
            else { return }

            userStatsUpdater.updateUserStats(
                profileItem: profileItem,
                scrobblesRow: scrobblesRow,
                lovedTracksRow: lovedTracksRow,
                service: .listenBrainz
            )
        }
    }

    private func refreshTopAlbums(for service: ScrobblerService) {
        switch service {
        case .lastFm:
            guard let gridView = lastFmTopAlbumsGridView else { return }
            let period = UserDefaults.standard.get(\.lastFmTopAlbumPeriod)
            topAlbumsUpdater.updateTopAlbumsGrid(gridView, period: period, service: .lastFm)
            
        case .listenBrainz:
            guard let gridView = listenBrainzTopAlbumsGridView else { return }
            let period = UserDefaults.standard.get(\.listenBrainzTopAlbumPeriod)
            topAlbumsUpdater.updateTopAlbumsGrid(gridView, period: period, service: .listenBrainz)
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
