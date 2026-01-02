//
//  PlayerManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/1/26.
//

import AppKit
import Combine
import Defaults
import Foundation

@MainActor
final class PlayerManager: ObservableObject {

  static let shared = PlayerManager()

  // MARK: - Dependencies

  private var appState: AppState { .shared }
  private let lastFm: LastFmManager = .shared
  private let listenBrainz: ListenBrainzManager = .shared
  private let appleMusic: AppleMusicManager = .shared
  private let notifications: NotificationController = .shared

  // MARK: - Published State

  @Published private(set) var isCurrentTrackLoved: Bool = false

  @Published private(set) var loveState: TrackLoveState = .init()

  @Published private(set) var isLoading: Bool = false

  // MARK: - Current Track Cache

  private var currentTrackKey: String?

  private init() {}

  // MARK: - Public API

  func toggleLoveCurrentTrack() {
    guard hasCurrentTrack else { return }

    let newLoveState = !isCurrentTrackLoved

    Task {
      await setLoveState(loved: newLoveState)
    }
  }

  func setLoveState(loved: Bool) async {
    let track = appState.currentTrack
    guard !track.title.isEmpty, track.title != "-" else { return }

    isLoading = true
    defer { isLoading = false }

    notifications.loveTrack(
      trackName: track.title,
      loved: loved,
      artwork: track.image
    )

    var results = LoveOperationResults()

    if Defaults[.syncLikes] {
      _ = await appleMusic.requestAutomationPermissionIfNeeded()
      await appleMusic.setFavorite(loved)
      results.appleMusicSuccess = true
    }

    if Defaults[.lastFmEnabled] && lastFm.username != nil {
      do {
        if loved {
          try await lastFm.loveTrack(track: track.title, artist: track.artist)
        } else {
          try await lastFm.unloveTrack(track: track.title, artist: track.artist)
        }
        results.lastFmSuccess = true
        loveState.lastFm = loved
      } catch {
        results.lastFmError = error.localizedDescription
        print("Last.fm love/unlove error: \(error.localizedDescription)")
      }
    }

    if Defaults[.listenBrainzEnabled] && listenBrainz.username != nil {
      do {
        if loved {
          try await listenBrainz.loveTrack(artist: track.artist, track: track.title)
        } else {
          try await listenBrainz.unloveTrack(artist: track.artist, track: track.title)
        }
        results.listenBrainzSuccess = true
        loveState.listenBrainz = loved
      } catch {
        results.listenBrainzError = error.localizedDescription
        print("ListenBrainz love/unlove error: \(error.localizedDescription)")
      }
    }

    if results.anySuccess {
      isCurrentTrackLoved = loved
      loveState.local = loved
    }
  }

  func fetchLoveStateForCurrentTrack() async {
    let track = appState.currentTrack
    guard !track.title.isEmpty, track.title != "-" else {
      resetLoveState()
      return
    }

    let trackKey = makeTrackKey(artist: track.artist, title: track.title)

    if trackKey == currentTrackKey {
      return
    }

    currentTrackKey = trackKey
    isLoading = true
    defer { isLoading = false }

    var newState = TrackLoveState()

    if Defaults[.lastFmEnabled] && lastFm.username != nil {
      let isLoved = await lastFm.isTrackLoved(artist: track.artist, track: track.title)
      newState.lastFm = isLoved
    }

    if Defaults[.listenBrainzEnabled] && listenBrainz.username != nil {
      let isLoved = await listenBrainz.isTrackLoved(artist: track.artist, track: track.title)
      newState.listenBrainz = isLoved
    }

    if Defaults[.syncLikes] {
      let isLoved = await appleMusic.currentFavoriteState()
      newState.appleMusic = isLoved ?? false
    }

    loveState = newState
    isCurrentTrackLoved = newState.isLovedOnAnyService
  }

  func onTrackChanged() {
    currentTrackKey = nil
    resetLoveState()
  }

  // MARK: - Private Helpers

  private var hasCurrentTrack: Bool {
    let track = appState.currentTrack
    return !track.title.isEmpty && track.title != "-"
  }

  private func resetLoveState() {
    loveState = .init()
    isCurrentTrackLoved = false
  }

  private func makeTrackKey(artist: String, title: String) -> String {
    "\(artist.lowercased())|\(title.lowercased())"
  }
}

// MARK: - Supporting Types

struct TrackLoveState {
  var local: Bool = false
  var lastFm: Bool = false
  var listenBrainz: Bool = false
  var appleMusic: Bool = false

  var isLovedOnAnyService: Bool {
    lastFm || listenBrainz || appleMusic || local
  }

  var isLovedOnAllServices: Bool {
    isLovedOnAnyService
  }
}

struct LoveOperationResults {
  var appleMusicSuccess: Bool = false
  var lastFmSuccess: Bool = false
  var listenBrainzSuccess: Bool = false

  var appleMusicError: String?
  var lastFmError: String?
  var listenBrainzError: String?

  var anySuccess: Bool {
    appleMusicSuccess || lastFmSuccess || listenBrainzSuccess
  }

  var allSuccess: Bool {
    appleMusicError == nil && lastFmError == nil && listenBrainzError == nil
  }

  var errors: [String] {
    [appleMusicError, lastFmError, listenBrainzError].compactMap { $0 }
  }
}
