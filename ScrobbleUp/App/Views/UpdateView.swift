//
//  CheckForUpdateView.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//
import Combine
import Sparkle
import SwiftUI

struct UpdateSettingsView: View {
	@ObservedObject var updaterViewModel: UpdaterViewModel
	@AppStorage(\.updateChannel) private var updateChannel

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Picker(
				"Release channel",
				selection: Binding(
					get: { updateChannel },
					set: { newChannel in
						updateChannel = newChannel
						updaterViewModel.channelDidChange(to: newChannel)
					}
				)
			) {
				ForEach(UpdateChannel.allCases, id: \.self) { channel in
					Text(channel.displayName).tag(channel)
				}
			}

			Text(updateChannel.description)
				.font(.caption)
				.foregroundColor(.secondary)
				.fixedSize(horizontal: false, vertical: true)

			Divider()

			Toggle(
				"Automatically check for updates",
				isOn: $updaterViewModel.automaticallyChecksForUpdates
			)

			Toggle(
				"Automatically download updates",
				isOn: $updaterViewModel.automaticallyDownloadsUpdates
			)
			.disabled(!updaterViewModel.automaticallyChecksForUpdates)

			Button("Check for Updates…") {
				updaterViewModel.checkForUpdates()
			}
			.disabled(!updaterViewModel.canCheckForUpdates)
		}
	}
}

// MARK: - Updater Delegate

final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
	func feedURLString(for updater: SPUUpdater) -> String? {
		let channel = UserDefaults.standard.get(\.updateChannel)
		return channel.feedURL.absoluteString
	}
}

// MARK: - Updater ViewModel

final class UpdaterViewModel: ObservableObject {
	@Published var canCheckForUpdates = false
	@Published var automaticallyChecksForUpdates = false {
		didSet {
			updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
		}
	}
	@Published var automaticallyDownloadsUpdates = false {
		didSet {
			updaterController.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
		}
	}

	private let updaterController: SPUStandardUpdaterController
	private var cancellables = Set<AnyCancellable>()

	init() {

		updaterController = SPUStandardUpdaterController(
			startingUpdater: true,
			updaterDelegate: nil,
			userDriverDelegate: nil
		)

		automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
		automaticallyDownloadsUpdates = updaterController.updater.automaticallyDownloadsUpdates

		updaterController.updater.publisher(for: \.canCheckForUpdates)
			.receive(on: DispatchQueue.main)
			.assign(to: &$canCheckForUpdates)

		updaterController.updater.publisher(for: \.automaticallyChecksForUpdates)
			.receive(on: DispatchQueue.main)
			.assign(to: &$automaticallyChecksForUpdates)

		updaterController.updater.publisher(for: \.automaticallyDownloadsUpdates)
			.receive(on: DispatchQueue.main)
			.assign(to: &$automaticallyDownloadsUpdates)
	}

	func checkForUpdates() {
		updaterController.checkForUpdates(nil)
	}

	func channelDidChange(to channel: UpdateChannel) {
		// The delegate will automatically provide the new feed URL on next check
		// Optionally check for updates immediately after switching channels
		// Uncomment if desired:
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
			self?.checkForUpdates()
		}
	}

}
