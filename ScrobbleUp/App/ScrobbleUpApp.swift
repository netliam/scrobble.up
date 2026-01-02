import AppKit
import CoreData
import Defaults
import Sparkle
import SwiftUI

@main
struct ScrobbleUpApp: App {
  private var appState: AppState = .shared
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
  }

  var body: some Scene {
    Settings {
      EmptyView()
    }
    .commands {
      CommandGroup(replacing: .newItem) {}

      CommandGroup(replacing: CommandGroupPlacement.appSettings) {
        Button {
          appState.openPreferences()
        } label: {
          Label("Preferences...", systemImage: "gear")
        }
        .keyboardShortcut(",", modifiers: .command)
      }
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  static weak var shared: AppDelegate?

  private var statusItem: NSStatusItem?
  private var mainWindowController: NSWindowController?

  private let core: CoreDataStack = .shared
  private let appState: AppState = .shared
  private let lastFm: LastFmManager = .shared
  private let dockIconManager: DockIconManager = .shared

  var menuController = MenuController()

  var scrobbleManager: UnifiedScrobbleManager!

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.shared = self

    updateActivationPolicy()

    scrobbleManager = UnifiedScrobbleManager(
      context: core.container.viewContext,
    )
    UnifiedMusicManager.shared.start { [weak self] musicInfo in
      self?.scrobbleManager.handle(musicInfo)
    }

    // Observe showIconInDock changes
    Defaults.observe(.showIconInDock) { [weak self] change in
      self?.updateActivationPolicy()
    }
    .tieToLifetime(of: self)

    // Observe showArtworkInDock changes
    Defaults.observe(.showArtworkInDock) { [weak self] change in
      if !change.newValue {
        DockIconManager.shared.resetToDefaultIcon()
      } else {
        self?.updateDockIconWithCurrentTrack()
      }
    }
    .tieToLifetime(of: self)

    // Observe app launches/quits
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(appDidLaunchOrTerminate),
      name: NSWorkspace.didLaunchApplicationNotification,
      object: nil
    )

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(appDidLaunchOrTerminate),
      name: NSWorkspace.didTerminateApplicationNotification,
      object: nil
    )
  }

  private func updateDockIconWithCurrentTrack() {
    let currentTrack = appState.currentTrack

    dockIconManager.updateDockIcon(with: currentTrack.image)
  }

  @objc private func appDidLaunchOrTerminate(_ notification: Notification) {
    guard
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    else {
      return
    }

    if app.bundleIdentifier == "com.spotify.client" || app.bundleIdentifier == "com.apple.Music" {
      menuController.menu.refresh()
    }
  }

  // MARK: - Window Mangement

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    if !flag {
      openMainWindow()
    }
    return true
  }

  private func updateActivationPolicy() {
    if Defaults[.showIconInDock] {
      NSApp.setActivationPolicy(.regular)
    } else {
      NSApp.setActivationPolicy(.accessory)
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    // Hide instead of close
    sender.orderOut(nil)

    if !Defaults[.showIconInDock] {
      NSApp.setActivationPolicy(.accessory)
    }

    return false
  }

  func openMainWindow() {
    NSApp.setActivationPolicy(.regular)

    if let windowController = mainWindowController {
      windowController.showWindow(nil)
      windowController.window?.makeKeyAndOrderFront(nil)
      windowController.window?.orderFrontRegardless()
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.title = "ScrobbleUp"
    window.delegate = self
    window.setFrameAutosaveName("MainWindow")

    let contentView = ContentView()
      .environment(\.managedObjectContext, core.container.viewContext)
      .environmentObject(appState)
      .environmentObject(lastFm)

    window.contentView = NSHostingView(rootView: contentView)

    let windowController = NSWindowController(window: window)
    mainWindowController = windowController

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
  }
}
