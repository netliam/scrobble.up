//
//  MusicManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/27/25.
//
//  AppleScript from boring.notch
//  https://github.com/TheBoredTeam/boring.notch
//

import AppKit
import Combine
import Foundation

final class AppleMusicManager: ObservableObject {
	static let shared = AppleMusicManager()

	private init() {}
	private var observer: NSObjectProtocol?

	var isRunning: Bool {
		let runningApps = NSRunningApplication.runningApplications(
			withBundleIdentifier: "com.apple.Music")
		return !runningApps.isEmpty
	}

	func start(handler: @escaping (MusicInfo) -> Void) {
		stop()
		observer = DistributedNotificationCenter.default.addObserver(
			forName: NSNotification.Name("com.apple.Music.playerInfo"),
			object: nil,
			queue: .main
		) { [] note in
			Task { [] in
				let info = note.userInfo ?? [:]
				let stateString = info["Player State"] as? String ?? ""
				let name = info["Name"] as? String
				let artist = info["Artist"] as? String
				let album = info["Album"] as? String
				let durationMs = info["Total Time"] as? Int

				let musicState: MusicState? = {
					switch stateString {
					case "Playing": return .playing
					case "Paused": return .paused
					case "Stopped": return .stopped
					default: return nil
					}
				}()

				let musicInfo = await MusicInfo(
					state: musicState,
					title: name,
					artist: artist,
					album: album,
					duration: durationMs,
					source: .appleMusic
				)

				await MainActor.run {
					handler(musicInfo)
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

	@MainActor
	func currentFavoriteState() async -> Bool? {
		guard isRunning else { return nil }
		let script = """
			tell application "Music"
			    if it is running then
			        try
			            return loved of current track
			        on error
			            return missing value
			        end try
			    else
			        return missing value
			    end if
			end tell
			"""
		if let result = try? await AppleScriptHelper.execute(script) {
			return result.booleanValue
		}
		return nil
	}

    @MainActor
	func setFavorite(_ favorite: Bool) async -> Bool? {
		let script = """
			tell application "Music"
			    try
			        set favorited of current track to \(favorite)
			        return favorited of current track
			    end try
			end tell
			"""
		let result = try? await AppleScriptHelper.execute(script)
		try? await Task.sleep(for: .milliseconds(150))
		return result?.booleanValue
	}

	@MainActor
	func requestAutomationPermissionIfNeeded() async -> Bool {
		let script = """
			tell application "Music"
			    if it is running then
			        return true
			    else
			        return true
			    end if
			end tell
			"""
		do {
			_ = try await AppleScriptHelper.execute(script)
			return true
		} catch {
			return false
		}
	}
}
