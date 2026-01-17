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

	let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {

			Toggle(
				"Automatically check for updates",
				isOn: $updaterViewModel.automaticallyChecksForUpdates
			)

			Button("Check for Updates…") {
				updaterViewModel.checkForUpdates()
			}
			.disabled(!updaterViewModel.canCheckForUpdates)
			Divider()
			Text("Version: \(version ?? "Unknown")")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}

// MARK: - Updater ViewModel

final class UpdaterViewModel: ObservableObject {
	@Published var canCheckForUpdates = false
	@Published var automaticallyChecksForUpdates = false {
		didSet {
			updaterController?.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
		}
	}

	private var updaterController: SPUStandardUpdaterController? {
		AppDelegate.shared?.updaterController
	}
	private var cancellables = Set<AnyCancellable>()

	init() {
		DispatchQueue.main.async { [weak self] in
			guard let self = self, let updater = self.updaterController?.updater else {
				return
			}

			self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates

			updater.publisher(for: \.canCheckForUpdates)
				.receive(on: DispatchQueue.main)
				.assign(to: &self.$canCheckForUpdates)

			updater.publisher(for: \.automaticallyChecksForUpdates)
				.receive(on: DispatchQueue.main)
				.assign(to: &self.$automaticallyChecksForUpdates)

			if self.automaticallyChecksForUpdates {
				updater.checkForUpdatesInBackground()
			}
		}
	}

	func checkForUpdates() {
		updaterController?.checkForUpdates(nil)
	}

}
