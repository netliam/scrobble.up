//
//  UnifiedMusicManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/30/25.
//

import AppKit
import ScriptingBridge

final class UnifiedMusicManager {
  static let shared = UnifiedMusicManager()

  private let appState: AppState = .shared

  private init() {}
  private var lastAcceptedSource: MusicSource?

  func start(handler: @escaping (MusicInfo) -> Void) {
    stop()

    let filteringHandler: (MusicInfo) -> Void = { [weak self] info in
      guard let self = self else { return }
      guard let source = info.source else { return }

      if self.shouldAcceptTrack(from: source) {
        handler(info)
        if let source = info.source {
          Task { @MainActor in
            switch source {
            case .appleMusic:
              self.appState.currentActivePlayer = .appleMusic
            case .spotify:
              self.appState.currentActivePlayer = .spotify
            }
          }
        }
        self.lastAcceptedSource = info.source
      } else {
        print("0 Ignoring track from \(source.rawValue) due to player preference")
      }
    }

    AppleMusicManager.shared.start(handler: filteringHandler)
    SpotifyManager.shared.start(handler: filteringHandler)
  }

  func stop() {
    AppleMusicManager.shared.stop()
    SpotifyManager.shared.stop()
    Task { @MainActor in
      self.appState.currentActivePlayer = nil
    }
  }

  // MARK: - Player Selection Logic

  private func shouldAcceptTrack(from source: MusicSource) -> Bool {
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
      return !isAppleMusicActive()

    case .preferSpotify:
      if source == .spotify {
        return true
      }
      return !isSpotifyActive()
    }
  }

  // MARK: - Helpers

  private func isAppleMusicActive() -> Bool {
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
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

    if let spotify = SBApplication(bundleIdentifier: "com.spotify.client") as? SpotifyApplication,
      let state = spotify.playerState
    {
      return state == "playing"
    }
    return false
  }
}
