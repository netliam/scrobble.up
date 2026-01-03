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

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Toggle(
				"Automatically check for updates",
				isOn: $updaterViewModel.automaticallyChecksForUpdates)

			Button("Check for Updates…") {
				updaterViewModel.checkForUpdates()
			}
			.disabled(!updaterViewModel.canCheckForUpdates)
		}
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

	private let updaterController: SPUStandardUpdaterController

	init() {
		updaterController = SPUStandardUpdaterController(
			startingUpdater: true,
			updaterDelegate: nil,
			userDriverDelegate: nil
		)

		automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates

		updaterController.updater.publisher(for: \.canCheckForUpdates)
			.receive(on: DispatchQueue.main)
			.assign(to: &$canCheckForUpdates)

		updaterController.updater.publisher(for: \.automaticallyChecksForUpdates)
			.receive(on: DispatchQueue.main)
			.assign(to: &$automaticallyChecksForUpdates)
	}

	func checkForUpdates() {
		updaterController.checkForUpdates(nil)
	}
}
