import AppKit
import Combine
import CoreData
import Foundation
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
					appState.openSettings()
				} label: {
					Label("Settings...", systemImage: "gear")
				}
				.keyboardShortcut(",", modifiers: .command)
			}

			CommandGroup(replacing: CommandGroupPlacement.appInfo) {
				Button {
					appDelegate.showAboutWindow()
				} label: {
					Label("About scrobble.up", systemImage: "info.circle")
				}
			}
		}
	}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
	static weak var shared: AppDelegate?

	private var widgetController: DesktopWidgetWindowController?
	private var aboutWindowController: NSWindowController?
	private var cancellables = Set<AnyCancellable>()

	private let core: CoreDataStack = .shared
	private let appState: AppState = .shared
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

		widgetController = DesktopWidgetWindowController.shared

		// Observe showIconInDock changes
		UserDefaults.standard.observe(\.showIconInDock) { [weak self] newValue in
			self?.updateActivationPolicy()
		}
		.store(in: &cancellables)

		// Observe showArtworkInDock changes
		UserDefaults.standard.observe(\.showArtworkInDock) { [weak self] newValue in
			if !newValue {
				DockIconManager.shared.resetToDefaultIcon()
			} else {
				self?.updateDockIconWithCurrentTrack()
			}
		}
		.store(in: &cancellables)

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

	func showAboutWindow() {
		if let windowController = aboutWindowController {
			windowController.showWindow(nil)
			windowController.window?.makeKeyAndOrderFront(nil)
			windowController.window?.orderFrontRegardless()
			NSApp.activate(ignoringOtherApps: true)
			return
		}

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.center()
		window.title = "About ScrobbleUp"
		window.isReleasedWhenClosed = false

		let aboutView = AboutView()
		window.contentView = NSHostingView(rootView: aboutView)

		let windowController = NSWindowController(window: window)
		aboutWindowController = windowController

		windowController.showWindow(nil)
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}

	private func updateDockIconWithCurrentTrack() {
		let currentTrack = appState.currentTrack

		dockIconManager.updateDockIcon(with: currentTrack.image)
	}

	@objc private func appDidLaunchOrTerminate(_ notification: Notification) {
		guard
			let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
				as? NSRunningApplication
		else {
			return
		}

		if app.bundleIdentifier == "com.spotify.client" || app.bundleIdentifier == "com.apple.Music"
		{
			menuController.refresh()
		}
	}

	// MARK: - Activation Policy

	private func updateActivationPolicy() {
		let shouldShow = UserDefaults.standard.get(\.showIconInDock)

		if shouldShow {
			NSApp.setActivationPolicy(.regular)
			if let window = appState.settingsWindowController?.window {
				window.level = .floating
			}
		} else {
			let settingsWasVisible = NSApp.windows.contains {
				$0.isVisible && $0.canBecomeKey && $0.title.contains("General")
			}
			let windowFrame = appState.settingsWindowController?.window?.frame

			NSAnimationContext.beginGrouping()
			NSAnimationContext.current.duration = 0

			NSApp.setActivationPolicy(.accessory)

			if settingsWasVisible {
				AppState.shared.openSettings()
				if let window = appState.settingsWindowController?.window {
					window.level = .floating
					if let frame = windowFrame {
						window.setFrame(frame, display: false, animate: false)
					}
					window.orderFrontRegardless()
				}
				NSApp.activate(ignoringOtherApps: true)
			}

			NSAnimationContext.endGrouping()
		}
	}
}
