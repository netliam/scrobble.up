//
//  NotificationsManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/27/25.
//

import AppKit
import Sparkle
import SwiftUI
import UserNotifications

class NotificationsController: NSObject, UNUserNotificationCenterDelegate,
	SPUStandardUserDriverDelegate
{
	static let shared = NotificationsController()

	private var hudWindow: NSWindow?
	private var hudTimer: Timer?

	private override init() {
		super.init()
		setupNotificationCategories()
		requestNotificationPermission()
	}

	// MARK: - Permission

	private func setupNotificationCategories() {
		let installAction = UNNotificationAction(
			identifier: "INSTALL_UPDATE",
			title: "Install",
			options: [.foreground]
		)

		let laterAction = UNNotificationAction(
			identifier: "LATER",
			title: "Later",
			options: []
		)

		let updateCategory = UNNotificationCategory(
			identifier: "UPDATE_AVAILABLE",
			actions: [installAction, laterAction],
			intentIdentifiers: [],
			options: []
		)

		UNUserNotificationCenter.current().setNotificationCategories([updateCategory])
	}

	private func requestNotificationPermission() {
		guard UserDefaults.standard.get(\.showNotifications) else { return }
		UNUserNotificationCenter.current().delegate = self
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
			granted, error in
			if let error = error {
				print("Notification permission error: \(error)")
			}
			print("Notification permission granted: \(granted)")
		}
	}

	// MARK: - SPUStandardUserDriverDelegate

	var supportsGentleScheduledUpdateReminders: Bool {
		return UserDefaults.standard.get(\.updateNotifications)
	}

	func standardUserDriverShouldHandleShowingScheduledUpdate(
		_ update: SUAppcastItem,
		andInImmediateFocus immediateFocus: Bool
	) -> Bool {
		guard UserDefaults.standard.get(\.updateNotifications) else {
			return true
		}

		if !immediateFocus {
			showUpdateNotification(for: update)
			return false
		}

		return true
	}

	private func showUpdateNotification(for update: SUAppcastItem) {
		let content = UNMutableNotificationContent()
		content.title = "Update Available"
		content.body = "Version \(update.displayVersionString) is ready to install"
		content.sound = .default
		content.categoryIdentifier = "UPDATE_AVAILABLE"
		content.userInfo = ["updateItem": update.versionString]

		let request = UNNotificationRequest(
			identifier: "sparkle-update-\(update.versionString)",
			content: content,
			trigger: nil
		)

		UNUserNotificationCenter.current().add(request) { error in
			if let error = error {
				print("Failed to show update notification: \(error)")
			}
		}
	}

	// MARK: - HUD Notifications

	func favoriteTrack(trackName: String, favorited: Bool, artwork: NSImage? = nil) {
		guard UserDefaults.standard.get(\.ratingStatus) else { return }
		if favorited {
			showHUD(symbol: "heart", text: "Loved", subtitle: trackName, artwork: artwork)
		} else {
			showHUD(symbol: "heart.slash", text: "Removed", subtitle: trackName, artwork: artwork)
		}

	}

	func infoCopied(type: CopiedLink) {
		guard UserDefaults.standard.get(\.infoCopied) else { return }
		var text: String

		switch type {
		case .artistTitle:
			text = "Copied Artist & Title"
		case .appleMusic:
			text = "Copied Apple Music Link"
		case .spotify:
			text = "Copied Spotify Link"
		}
		showHUD(symbol: "document.on.document.fill", text: text)
	}

	// MARK: - HUD Window

	private func showHUD(
		symbol: String, text: String, subtitle: String? = nil, artwork: NSImage? = nil
	) {
		DispatchQueue.main.async { [weak self] in
			self?.displayHUD(symbol: symbol, text: text, subtitle: subtitle, artwork: artwork)
		}
	}

	private func displayHUD(
		symbol: String, text: String, subtitle: String? = nil, artwork: NSImage? = nil
	) {
		hudTimer?.invalidate()

		if hudWindow == nil {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
				styleMask: [.borderless],
				backing: .buffered,
				defer: false
			)
			window.isOpaque = false
			window.backgroundColor = .clear
			window.level = .floating
			window.ignoresMouseEvents = true
			window.collectionBehavior = [.canJoinAllSpaces, .stationary]
			window.hasShadow = true
			hudWindow = window
		}

		guard let window = hudWindow else { return }

		let hudView = HUDView(symbol: symbol, text: text, subtitle: subtitle, artwork: artwork)
		let hostingView = NSHostingView(rootView: hudView)
		hostingView.layer?.backgroundColor = CGColor.clear
		window.contentView = hostingView

		let side: CGFloat = 200
		window.setContentSize(NSSize(width: side, height: side))

		// Center on screen
		if let screen = NSScreen.main {
			let screenFrame = screen.visibleFrame
			let windowFrame = window.frame
			let x = screenFrame.midX - windowFrame.width / 2
			let y = screenFrame.midY - windowFrame.height / 2
			window.setFrameOrigin(NSPoint(x: x, y: y))
		}

		// Show window with fade in
		window.alphaValue = 0
		window.orderFrontRegardless()

		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.2
			window.animator().alphaValue = 1
		}

		// Auto-hide after delay
		hudTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
			self?.hideHUD()
		}
	}

	private func hideHUD() {
		guard let window = hudWindow else { return }

		NSAnimationContext.runAnimationGroup(
			{ context in
				context.duration = 0.3
				window.animator().alphaValue = 0
			},
			completionHandler: { [weak self] in
				self?.hudWindow?.orderOut(nil)
			})
	}

	// MARK: - UNUserNotificationCenterDelegate

	func userNotificationCenter(
		_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
		withCompletionHandler completionHandler:
			@escaping (UNNotificationPresentationOptions) -> Void
	) {
		completionHandler([.banner, .sound])
	}

	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		didReceive response: UNNotificationResponse,
		withCompletionHandler completionHandler: @escaping () -> Void
	) {
		defer { completionHandler() }

		if response.notification.request.content.categoryIdentifier == "UPDATE_AVAILABLE" {
			if response.actionIdentifier == "INSTALL_UPDATE" {
				// Trigger the update installation
				AppDelegate.shared?.updaterController?.checkForUpdates(nil)
			}
			// "LATER" action or default tap - do nothing
		}
	}
}

// MARK: - HUD View

private struct HUDView: View {
	let symbol: String
	let text: String
	var subtitle: String?
	var artwork: NSImage?

	var body: some View {
		VStack(spacing: 9) {
			if let nsImage = artwork {
				ZStack {
					Image(nsImage: nsImage)
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: 80, height: 80)
						.clipped()
					Image(systemName: symbol)
						.font(.system(size: 32, weight: .medium))
						.foregroundStyle(.white)
						.shadow(radius: 2)
				}
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
				.shadow(radius: 2)
			} else {
				Image(systemName: symbol)
					.font(.system(size: 48, weight: .medium))
					.foregroundStyle(.primary)
			}

			VStack(spacing: 5) {
				Text(text)
					.font(.largeTitle)
					.bold()
					.multilineTextAlignment(.center)
					.lineLimit(2)
					.minimumScaleFactor(0.5)

				if let subtitle {
					Text(subtitle)
						.font(.title2)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
						.lineLimit(2)
						.minimumScaleFactor(0.2)
				}
			}
		}
		.padding(20)
		.frame(width: 180, height: 180)
		.background {
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(.ultraThinMaterial)
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.white.opacity(0.35),
							Color.white.opacity(0.10),
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 1
				)
		}
	}
}

#Preview {
	HUDView(symbol: "star", text: "test", subtitle: "test")
}
