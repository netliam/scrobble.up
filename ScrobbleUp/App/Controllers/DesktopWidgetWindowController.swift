//
//  DesktopWidgetWindowController.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/5/26.
//

import AppKit
import Combine
import SwiftUI

final class DesktopWidgetPanel: NSPanel {

	override var canBecomeKey: Bool { false }
	override var canBecomeMain: Bool { false }
}

@MainActor
final class DesktopWidgetWindowController {
	static let shared = DesktopWidgetWindowController()

	private var window: NSPanel?
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
		guard window == nil else {
			window?.orderFrontRegardless()
			return
		}

		let contentView = DesktopWidgetView(appState: .shared)

		let hostingView = NSHostingView(rootView: contentView)
		hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 200)

		let window = DesktopWidgetPanel(
			contentRect: NSRect(x: 100, y: 100, width: 200, height: 200),
			styleMask: [.borderless],
			backing: .buffered,
			defer: false
		)

		window.contentView = hostingView
		window.isFloatingPanel = false
		window.hidesOnDeactivate = false

		window.isOpaque = false
		window.backgroundColor = .clear
		window.hasShadow = true

		window.isMovableByWindowBackground = true
		window.acceptsMouseMovedEvents = true
		window.ignoresMouseEvents = false

		window.collectionBehavior = [
			.canJoinAllSpaces,
			.stationary,
			.ignoresCycle,
		]

		self.window = window
		updateWindowLevel()
		window.orderFrontRegardless()
	}

	func hideWindow() {
		window?.orderFrontRegardless()
		window = nil
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
			window.level = .normal - 1

		case .standardWindow:
			window.level = .normal
		}
	}
}
