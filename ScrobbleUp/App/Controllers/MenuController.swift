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

	let menu = MainMenu()

	private var globalHoverMonitor: Any?
	private var localHoverMonitor: Any?
	private var hoverCloseWorkItem: DispatchWorkItem?

	private var contextObserver: NSObjectProtocol?

	private var mainWindow: NSWindow?

	let core: CoreDataStack = .shared
	let appState: AppState = .shared
	let lastFm: LastFmManager = .shared

	override init() {
		super.init()
		statusBarSetup()
		startObservingCoreDataChanges()
	}

	deinit {
		if let contextObserver {
			NotificationCenter.default.removeObserver(contextObserver)
		}
	}

	func statusBarSetup() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		if let button = statusItem?.button {
			let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
			let image = NSImage(named: "ScrobbleUp.menu")
			button.image = image?.withSymbolConfiguration(config)
			button.target = self
			button.action = #selector(showMenu)
		}
	}

	// MARK: NSMenu

	private func startObservingCoreDataChanges() {
		let ctx = core.container.viewContext
		contextObserver = NotificationCenter.default.addObserver(
			forName: .NSManagedObjectContextObjectsDidChange,
			object: ctx,
			queue: .main
		) { [weak self] notification in
			self?.menu.refresh()
		}
	}

	// MARK: Open Menu

	@objc private func showMenu() {
		menu.ensureSkeleton()
		menu.refresh()
		statusItem?.menu = menu.mainMenu
		statusItem?.button?.performClick(nil)
	}
}
