//
//  PlayerManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/1/26.
//

import AppKit
import Combine
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

	@Published private(set) var isCurrentTrackFavorited: Bool = false

	@Published private(set) var favoriteState: TrackFavoriteState = .init()

	@Published private(set) var isLoading: Bool = false

	// MARK: - Current Track Cache

	private var currentTrackKey: String?

	private init() {}

	// MARK: - Public API

	func setFavoriteState(favorited: Bool? = nil, title: String? = nil, artist: String? = nil) async {
        let trackTitle: String
        let trackArtist: String
        let isCurrentTrack: Bool
        
        if let title = title, let artist = artist {
            trackTitle = title
            trackArtist = artist
            isCurrentTrack = false
        } else {
            let track = appState.currentTrack
            trackTitle = track.title
            trackArtist = track.artist
            isCurrentTrack = true
        }
        
        guard !trackTitle.isEmpty, trackTitle != "-" else { return }
        
        // If favorited is nil, toggle the current state
        let targetFavorited = favorited ?? !isCurrentTrackFavorited
        
        if isCurrentTrack {
            isLoading = true
        }
        defer { 
            if isCurrentTrack {
                isLoading = false
            }
        }
        
        if isCurrentTrack {
            notifications.favoriteTrack(
                trackName: trackTitle,
                loved: targetFavorited,
                artwork: appState.currentTrack.image
            )
        }
        
        var results = FavoriteOperationResults()
        
        if UserDefaults.standard.get(\.syncLikes) && isCurrentTrack {
            let authorized = await appleMusic.ensureAuthorization()
            if authorized {
                let success = await appleMusic.setFavorite(targetFavorited, track: appState.currentTrack)
                results.appleMusicSuccess = success
            }
        }

		if UserDefaults.standard.get(\.lastFmEnabled) && lastFm.username != nil {
			do {
				if targetFavorited {
					try await lastFm.loveTrack(track: trackTitle, artist: trackArtist)
				} else {
					try await lastFm.unloveTrack(track: trackTitle, artist: trackArtist)
				}
				results.lastFmSuccess = true
				if isCurrentTrack {
					favoriteState.lastFm = targetFavorited
				}
			} catch {
				results.lastFmError = error.localizedDescription
				print("Last.fm love/unlove error: \(error.localizedDescription)")
			}
		}

		if UserDefaults.standard.get(\.listenBrainzEnabled) && listenBrainz.username != nil {
			do {
				if targetFavorited {
					try await listenBrainz.loveTrack(artist: trackArtist, track: trackTitle)
				} else {
					try await listenBrainz.unloveTrack(artist: trackArtist, track: trackTitle)
				}
				results.listenBrainzSuccess = true
				if isCurrentTrack {
					favoriteState.listenBrainz = targetFavorited
				}
			} catch {
				results.listenBrainzError = error.localizedDescription
				print("ListenBrainz love/unlove error: \(error.localizedDescription)")
			}
		}

		if results.anySuccess && isCurrentTrack {
			isCurrentTrackFavorited = targetFavorited
			favoriteState.local = targetFavorited
		}
	}

	func fetchFavoriteStateForCurrentTrack() async {
        let track = appState.currentTrack
        guard !track.title.isEmpty, track.title != "-" else {
            resetFavoriteState()
            return
        }

		let trackKey = makeTrackKey(artist: track.artist, title: track.title)

		if trackKey == currentTrackKey {
			return
		}

		currentTrackKey = trackKey
		isLoading = true
		defer { isLoading = false }

		var newState = TrackFavoriteState()

		if UserDefaults.standard.get(\.lastFmEnabled) && lastFm.username != nil {
			let isLoved = await lastFm.isTrackLoved(artist: track.artist, track: track.title)
			newState.lastFm = isLoved
		}

		if UserDefaults.standard.get(\.listenBrainzEnabled) && listenBrainz.username != nil {
			let isLoved = await listenBrainz.isTrackLoved(artist: track.artist, track: track.title)
			newState.listenBrainz = isLoved
		}

        if UserDefaults.standard.get(\.syncLikes) {
            let isLoved = await appleMusic.currentFavoriteState(track: track)
            newState.appleMusic = isLoved ?? false
        }

		favoriteState = newState
		isCurrentTrackFavorited = newState.isFavoritedOnAnyService
	}

	func onTrackChanged() {
		currentTrackKey = nil
		resetFavoriteState()
	}

	func bringPlayerToFront() {
		guard let bundleID = appState.currentActivePlayer?.rawValue else { return }

		let script = """
			tell application id "\(bundleID)"
			    activate
			    reopen
			end tell
			"""

		Task {
			try await AppleScriptHelper.executeVoid(script)
		}
	}

	// MARK: - Private Helpers

	private var hasCurrentTrack: Bool {
		let track = appState.currentTrack
		return !track.title.isEmpty && track.title != "-"
	}

	private func resetFavoriteState() {
		favoriteState = .init()
		isCurrentTrackFavorited = false
	}

	private func makeTrackKey(artist: String, title: String) -> String {
		"\(artist.lowercased())|\(title.lowercased())"
	}
}
