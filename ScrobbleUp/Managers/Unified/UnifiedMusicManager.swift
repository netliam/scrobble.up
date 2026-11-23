//
//  UnifiedMusicManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/30/25.
//

import AppKit
import Combine
import Foundation

final class UnifiedMusicManager {

	// MARK: - Singleton

	static let shared = UnifiedMusicManager()

	// MARK: - Properties

	private let appState: AppState = .shared
	private var lastState: [MusicSource: MusicState] = [:]
	private var currentHandler: ((MusicInfo) -> Void)?
	private var cancellables = Set<AnyCancellable>()
	// MARK: - Initialization

	private init() {
		setupObservers()
	}

	// MARK: - Observers

	private func setupObservers() {
		UserDefaults.standard.observe(\.trackFetchingMethod) { [weak self] newValue in
			self?.restart()
		}
		.store(in: &cancellables)
	}

	// MARK: - Public API

	func start(handler: @escaping (MusicInfo) -> Void) {
		stop()

		currentHandler = handler
		let fetchingMethod = UserDefaults.standard.get(\.trackFetchingMethod)

		let filteringHandler: (MusicInfo) -> Void = { [weak self] info in
			guard let self = self else { return }
			if let source = info.source, let state = info.state { self.lastState[source] = state }

			if self.shouldAcceptTrack(info) {
				handler(info)

				if let source = info.source {
					Task { @MainActor in
						self.appState.currentActivePlayer = source
					}
				}
			} else {
				print("Ignoring track due to player preference")
			}
		}

		switch fetchingMethod {
		case .perApp:
			AppleMusicManager.shared.start(handler: filteringHandler)
			SpotifyManager.shared.start(handler: filteringHandler)

		case .mediaRemote:
			MediaRemoteManager.shared.start(handler: filteringHandler)
		}
	}

	func stop() {
		AppleMusicManager.shared.stop()
		SpotifyManager.shared.stop()
		MediaRemoteManager.shared.stop()
		lastState = [:]

		Task { @MainActor in
			appState.currentActivePlayer = nil
		}
	}

	func restart() {
		guard let handler = currentHandler else { return }
		start(handler: handler)
	}

	// MARK: - Player Selection Logic

	private func shouldAcceptTrack(_ info: MusicInfo) -> Bool {
		guard let source = info.source else {
			return info.title != nil && info.artist != nil
		}

		let override = UserDefaults.standard.get(\.playerOverride)

		switch override {
		case .appleMusic:
			return source == .appleMusic

		case .spotify:
			return source == .spotify

		case .none:
			return shouldAcceptBasedOnPreference(from: source)
		}
	}

	private func shouldAcceptBasedOnPreference(from source: MusicSource) -> Bool {
		let preference = UserDefaults.standard.get(\.playerSwitching)

		switch preference {
		case .automatic:
			return true

		case .preferAppleMusic:
			return source == .appleMusic || !isPlaying(.appleMusic, bundleID: "com.apple.Music")

		case .preferSpotify:
			return source == .spotify || !isPlaying(.spotify, bundleID: "com.spotify.client")
		}
	}

	// MARK: - Helpers

	/// Uses the last state the player itself reported, so no AppleScript runs on the main thread.
	// shortcut: in MediaRemote mode only the now-playing app reports, so a state can go stale
	// until that player sends its next event or quits.
	private func isPlaying(_ source: MusicSource, bundleID: String) -> Bool {
		lastState[source] == .playing
			&& !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
	}
}
