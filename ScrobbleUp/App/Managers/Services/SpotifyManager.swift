//
//  SpotifyManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/29/25.
//

import AppKit
import Combine
import ScriptingBridge

@objc protocol SpotifyApplication {
	@objc optional var currentTrack: SpotifyTrack? { get }
	@objc optional var playerState: String? { get }
}

@objc protocol SpotifyTrack {
	@objc optional var name: String? { get }
	@objc optional var artist: String? { get }
	@objc optional var album: String? { get }
	@objc optional var duration: Int { get }
}

extension SBApplication: SpotifyApplication {}

final class SpotifyManager: ObservableObject {
	static let shared = SpotifyManager()

	private init() {}
	private var observer: NSObjectProtocol?
	private var lastTrack: MusicInfo?

	private var spotify: SpotifyApplication? {
		guard isRunning else { return nil }
		return SBApplication(bundleIdentifier: "com.spotify.client")
	}

	var isRunning: Bool {
		!NSRunningApplication.runningApplications(
			withBundleIdentifier: "com.spotify.client"
		).isEmpty
	}

	func start(handler: @escaping (MusicInfo) -> Void) {
		stop()

		observer = DistributedNotificationCenter.default.addObserver(
			forName: NSNotification.Name(
				"com.spotify.client.PlaybackStateChanged"
			),
			object: nil,
			queue: .main
		) { [weak self] _ in
			Task { [weak self] in
				guard let self, await self.isRunning else { return }
				if let info = await self.fetchCurrentTrack() {
					await MainActor.run {
						handler(info)
					}
				}
			}
		}

		Task { [weak self] in
			guard let self, self.isRunning else { return }
			if let info = await self.fetchCurrentTrack() {
				await MainActor.run {
					handler(info)
				}
			}
		}
	}

	func stop() {
		if let obs = observer {
			DistributedNotificationCenter.default.removeObserver(obs)
			observer = nil
		}
	}

	func fetchCurrentTrack() async -> MusicInfo? {
		guard isRunning else { return nil }

		let scriptSource = """
			tell application "Spotify"
			    if it is running then
			        set player_state to (player state) as text
			        set track_name to ""
			        set track_artist to ""
			        set track_album to ""
			        set track_duration to 0
			        try
			            set track_name to name of current track as text
			            set track_artist to artist of current track as text
			            set track_album to album of current track as text
			            set track_duration to duration of current track
			        end try
			        return player_state & "\n" & track_name & "\n" & track_artist & "\n" & track_album & "\n" & (track_duration as text)
			    else
			        return "not running\n\n\n\n"
			    end if
			end tell
			"""

		guard
			let resultDescriptor = try? await AppleScriptHelper.execute(
				scriptSource
			),
			let resultString = resultDescriptor.stringValue
		else {
			return nil
		}

		let parts = resultString.components(separatedBy: "\n")
		guard parts.count >= 5 else { return nil }

		let state = parts[0]

		let name = parts[1]
		let artist = parts[2]
		let album = parts[3].isEmpty ? nil : parts[3]
		let durationMs = Int(parts[4]) ?? 0

		if state == "playing" {
			guard !name.isEmpty, !artist.isEmpty else { return nil }
		}

		return MusicInfo(
			state: MusicState(rawValue: state),
			title: name,
			artist: artist,
			album: album,
			duration: durationMs,
			source: .spotify
		)
	}
}
