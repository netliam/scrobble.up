//
//  DesktopWidgetWindowController.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/5/26.
//

import AppKit
import Combine
import SwiftUI

final class DesktopWidgetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class DesktopWidgetWindowController {
	static let shared = DesktopWidgetWindowController()

	private var window: NSWindow?
	private var cancellables = Set<AnyCancellable>()

	private init() {
		observeSettings()

		if UserDefaults.standard.get(\.showDesktopWidget) {
			showWindow()
		}
	}

	private func observeSettings() {
		// Observe widget enabled/disabled
		UserDefaults.standard.observe(\.showDesktopWidget) { [weak self] enabled in
			Task { @MainActor in
				if enabled {
					self?.showWindow()
				} else {
					self?.hideWindow()
				}
			}
		}
		.store(in: &cancellables)

		// Observe window behavior changes
		UserDefaults.standard.observe(\.widgetWindowBehavior) { [weak self] _ in
			Task { @MainActor in
				self?.updateWindowLevel()
			}
		}
		.store(in: &cancellables)
	}

	func showWindow() {
		if let existingWindow = window {
			existingWindow.orderFrontRegardless()
			return
		}

        let contentView = DesktopWidgetView(appState: .shared)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 200)

        let newWindow = DesktopWidgetWindow(
            contentRect: NSRect(x: 100, y: 100, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingView
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = true
        newWindow.isMovableByWindowBackground = true
        newWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        newWindow.ignoresMouseEvents = false
        newWindow.acceptsMouseMovedEvents = true

        self.window = newWindow
        updateWindowLevel()
        newWindow.orderFrontRegardless()
	}

	func hideWindow() {
		window?.orderOut(nil)
	}

	private func updateWindowLevel() {
		guard let window = window else { return }

		let behavior = UserDefaults.standard.get(\.widgetWindowBehavior)

		switch behavior {

		case .above:
			window.level = .floating

		case .stuck:
			window.level = NSWindow.Level(
				rawValue: Int(CGWindowLevelForKey(.desktopWindow))
			)

		case .desktop:
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
		case .standardWindow:
			window.level = .normal
		}
	}
}
