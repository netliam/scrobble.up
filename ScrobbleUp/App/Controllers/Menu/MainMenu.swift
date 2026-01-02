import AppKit
import Defaults

final class MainMenu {
  let mainMenu: NSMenu

  // Dependencies
  private let core: CoreDataStack = .shared
  private let appState: AppState = .shared

  // Sections
  private let recentlyPlayedMenu: RecentlyPlayedMenu

  // Icons
  let scroll = NSImage(systemSymbolName: "scroll.fill", accessibilityDescription: nil)?
    .configureForMenu(size: 20)
  let gear = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)?.configureForMenu(
    size: 20)
  let xmark = NSImage(systemSymbolName: "xmark.rectangle", accessibilityDescription: nil)?
    .configureForMenu(size: 20)
  let checkmark = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
    .configureForMenu(size: 20)
  let automaticIcon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
    .configureForMenu(size: 20)
  let appleMusicIcon = NSImage(named: "Apple.Music.icon")?.configureForMenu(size: 20)
  let spotifyIcon = NSImage(named: "Spotify.logo")?.configureForMenu(size: 20)

  // Reuse Stuff
  let headerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    .foregroundColor: NSColor.secondaryLabelColor,
  ]

  init() {
    let mainMenu = NSMenu()

    self.recentlyPlayedMenu = RecentlyPlayedMenu(mainMenu: mainMenu)
    self.mainMenu = mainMenu
  }

  // MARK: - Public API

  func ensureSkeleton() {
    if self.recentlyPlayedMenu.recentTrackItems.isEmpty { setupSkeleton() }
  }

  func refresh() {
    let shouldShowPlayerSection = areBothPlayersRunning()
    let currentlyShowingPlayerSection = mainMenu.items.contains {
      $0.title == "Active Player"
    }

    if shouldShowPlayerSection != currentlyShowingPlayerSection {
      setupSkeleton()
    }

    let recent = LogEntry.fetchRecent(context: core.container.viewContext, limit: 10)
    let uniqueRecentTracks = recentlyPlayedMenu.uniqueRecent(recent)

    DispatchQueue.main.async {
      self.recentlyPlayedMenu.applyRecentTracks(Array(uniqueRecentTracks.prefix(5)))
      for (index, entry) in uniqueRecentTracks.prefix(5).enumerated() {
        if self.recentlyPlayedMenu.recentTrackItems.indices.contains(index) {
          self.recentlyPlayedMenu.recentTrackItems[index].representedObject =
            self.recentlyPlayedMenu.cacheKey(for: entry)
        }
        self.recentlyPlayedMenu.updateTrackInfoIfNeeded(for: entry, at: index)
      }
    }

    if shouldShowPlayerSection {
      for item in mainMenu.items where item.action == #selector(setPlayerOverride(_:)) {
        switch item.tag {
        case 0:
          item.image = Defaults[.playerOverride] == .none ? checkmark : automaticIcon
        case 1:
          item.image = Defaults[.playerOverride] == .appleMusic ? checkmark : appleMusicIcon
        case 2:
          item.image = Defaults[.playerOverride] == .spotify ? checkmark : spotifyIcon
        default:
          break
        }
      }
    }
  }

  // MARK: - Building

  private func setupSkeleton() {
    mainMenu.removeAllItems()
    mainMenu.autoenablesItems = false

    let recentlyPlayedHeader = NSMenuItem.sectionHeader(title: "Recently Played")
    recentlyPlayedHeader.attributedTitle = NSAttributedString(
      string: "Recently Played",
      attributes: headerAttributes
    )
    mainMenu.addItem(recentlyPlayedHeader)

    self.recentlyPlayedMenu.recentTrackItems = (0..<5).map { _ in
      let item = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
      mainMenu.addItem(item)
      return item
    }

    mainMenu.addItem(NSMenuItem.separator())
    addPlayerSelectionIfNeeded()

    let logItem = NSMenuItem(
      title: "Scrobble Log",
      action: #selector(openMainWindow),
      keyEquivalent: ""
    )
    logItem.target = self
    logItem.image = scroll
    mainMenu.addItem(logItem)

    let preferencesItem = NSMenuItem(
      title: "Preferences...",
      action: #selector(openPreferences),
      keyEquivalent: ","
    )
    preferencesItem.target = self
    preferencesItem.image = gear
    mainMenu.addItem(preferencesItem)

    mainMenu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: "Quit scrobble.up",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    quitItem.target = self
    quitItem.image = xmark
    mainMenu.addItem(quitItem)
  }

  private func addPlayerSelectionIfNeeded() {
    guard areBothPlayersRunning() else { return }

    let playerHeader = NSMenuItem.sectionHeader(title: "Active Player")
    playerHeader.attributedTitle = NSAttributedString(
      string: "Active Player",
      attributes: headerAttributes
    )
    mainMenu.addItem(playerHeader)

    let automaticItem = NSMenuItem(
      title: "Automatic",
      action: #selector(setPlayerOverride(_:)),
      keyEquivalent: ""
    )
    automaticItem.target = self
    automaticItem.tag = 0
    automaticItem.image = Defaults[.playerOverride] == .none ? checkmark : automaticIcon
    mainMenu.addItem(automaticItem)

    let appleMusicItem = NSMenuItem(
      title: "Apple Music",
      action: #selector(setPlayerOverride(_:)),
      keyEquivalent: ""
    )
    appleMusicItem.target = self
    appleMusicItem.tag = 1
    appleMusicItem.image = Defaults[.playerOverride] == .appleMusic ? checkmark : appleMusicIcon
    mainMenu.addItem(appleMusicItem)

    let spotifyItem = NSMenuItem(
      title: "Spotify",
      action: #selector(setPlayerOverride(_:)),
      keyEquivalent: ""
    )
    spotifyItem.target = self
    spotifyItem.tag = 2
    spotifyItem.image = Defaults[.playerOverride] == .spotify ? checkmark : spotifyIcon
    mainMenu.addItem(spotifyItem)

    mainMenu.addItem(NSMenuItem.separator())
  }

  private func areBothPlayersRunning() -> Bool {
    let appleMusicRunning = !NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.Music"
    ).isEmpty
    let spotifyRunning = !NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.spotify.client"
    ).isEmpty
    return appleMusicRunning && spotifyRunning
  }

  // MARK: - Application Functions

  @objc func quitApp() {
    NSApp.terminate(nil)
  }

  @objc func openPreferences() {
    appState.openPreferences()
  }

  @objc func openMainWindow() {
    AppDelegate.shared?.openMainWindow()
  }

  @objc func setPlayerOverride(_ sender: NSMenuItem) {
    for item in mainMenu.items where item.action == #selector(setPlayerOverride(_:)) {
      switch item.tag {
      case 0:
        item.image = automaticIcon
      case 1:
        item.image = appleMusicIcon
      case 2:
        item.image = spotifyIcon
      default:
        break
      }
    }

    sender.image = checkmark

    switch sender.tag {
    case 0:
      Defaults[.playerOverride] = .none
    case 1:
      Defaults[.playerOverride] = .appleMusic
    case 2:
      Defaults[.playerOverride] = .spotify
    default:
      break
    }

    refresh()
  }
}
