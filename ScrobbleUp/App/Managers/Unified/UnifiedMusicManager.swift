//
//  UnifiedMusicManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/30/25.
//

import AppKit
import Foundation
import Combine
import ScriptingBridge

final class UnifiedMusicManager {
    static let shared = UnifiedMusicManager()

    private let appState: AppState = .shared

    private init() {
        setupObservers()
    }

    private var lastAcceptedSource: MusicSource?
    private var currentFetchingMethod: TrackFetchingMethod?
    private var currentHandler: ((MusicInfo) -> Void)?
    private var cancellables = Set<AnyCancellable>()

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
        currentFetchingMethod = fetchingMethod

        let filteringHandler: (MusicInfo) -> Void = { [weak self] info in
            guard let self = self else { return }

            if self.shouldAcceptTrack(info) {
                handler(info)
                if let source = info.source {
                    Task { @MainActor in
                        self.appState.currentActivePlayer = source
                    }
                }
                self.lastAcceptedSource = info.source
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

        currentFetchingMethod = nil
        Task { @MainActor in
            self.appState.currentActivePlayer = nil
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
            if source == .appleMusic {
                return true
            }
            if source == .other {
                return !isAppleMusicActive()
            }
            return !isAppleMusicActive()

        case .preferSpotify:
            if source == .spotify {
                return true
            }
            if source == .other {
                return !isSpotifyActive()
            }
            return !isSpotifyActive()
        }
    }

    // MARK: - Helpers

    private func isAppleMusicActive() -> Bool {
        guard
            !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
                .isEmpty
        else {
            return false
        }

        let script = """
            tell application "Music"
                if it is running then
                    return player state is playing
                else
                    return false
                end if
            end tell
            """

        if let result = NSAppleScript(source: script)?.executeAndReturnError(nil) {
            return result.booleanValue
        }
        return false
    }

    private func isSpotifyActive() -> Bool {
        guard SpotifyManager.shared.isRunning else {
            return false
        }

        if let spotify = SBApplication(bundleIdentifier: "com.spotify.client")
            as? SpotifyApplication,
            let state = spotify.playerState
        {
            return state == "playing"
        }
        return false
    }
}
