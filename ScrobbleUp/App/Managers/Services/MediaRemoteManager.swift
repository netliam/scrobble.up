//
//  MediaRemoteManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/3/26.
//

import AppKit
import Combine
import MediaRemoteAdapter

final class MediaRemoteManager: ObservableObject {
	static let shared = MediaRemoteManager()

	let mediaController = MediaController()

	private static let scrobblableBundleIDs: Set<String> = [
		"com.apple.Music",
		"com.spotify.client",
		"com.tidal.desktop",
		"com.amazon.music",
		"com.deezer.deezer-desktop",
		"com.pandora.desktop",
		"com.soundcloud.desktop",
		"tv.plex.plexamp",
		"com.roon.Roon",
		"com.audirvana.Audirvana-Plus",
		"com.vox.vox",
	]

	private init() {}

	func start(handler: @escaping (MusicInfo) -> Void) {
		stop()

		mediaController.onTrackInfoReceived = { [weak self] trackInfo in
			guard let self = self else { return }

			let musicInfo = self.convertToMusicInfo(trackInfo)
			DispatchQueue.main.async {
				handler(musicInfo)
			}
		}

		mediaController.startListening()
	}

	func stop() {
		mediaController.onTrackInfoReceived = nil
		mediaController.stopListening()
	}

	func fetchCurrentArtwork() async -> NSImage? {
		return await withCheckedContinuation { continuation in
			mediaController.getTrackInfo { trackInfo in
				continuation.resume(returning: trackInfo?.payload.artwork)
			}
		}
	}

	// MARK: - Private Helpers

	private func convertToMusicInfo(_ trackInfo: TrackInfo?) -> MusicInfo {
		guard let trackInfo = trackInfo,
			let bundleID = trackInfo.payload.bundleIdentifier,
			isScrobblableContent(bundleIdentifier: bundleID)
		else {
			return MusicInfo(
				state: .stopped,
				title: nil,
				artist: nil,
				album: nil,
				duration: nil,
				source: nil,
				artwork: nil
			)
		}

		let payload = trackInfo.payload
		let source = mapBundleIDToSource(bundleID)

		let state: MusicState? = {
			if let isPlaying = payload.isPlaying {
				return isPlaying ? .playing : .paused
			}
			if let playbackRate = payload.playbackRate {
				return playbackRate > 0 ? .playing : .paused
			}
			return nil
		}()

		let durationMs: Int? = {
			guard let durationMicros = payload.durationMicros else { return nil }
			return Int(durationMicros / 1000)
		}()

		return MusicInfo(
			state: state,
			title: payload.title,
			artist: payload.artist,
			album: payload.album,
			duration: durationMs,
			source: source,
			artwork: payload.artwork
		)
	}

	private func isScrobblableContent(bundleIdentifier: String) -> Bool {
		return Self.scrobblableBundleIDs.contains(bundleIdentifier)
	}

	private func mapBundleIDToSource(_ bundleID: String) -> MusicSource {
		switch bundleID {
		case "com.apple.Music":
			return .appleMusic
		case "com.spotify.client":
			return .spotify
		default:
			return .other
		}
	}
}
