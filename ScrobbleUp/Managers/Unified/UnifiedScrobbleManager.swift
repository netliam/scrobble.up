import AppKit
import Combine
import CoreData
import Foundation

@MainActor
final class UnifiedScrobbleManager: ObservableObject {
	private let appState: AppState = .shared
	private let lastFm: LastFmManager = .shared
	private let listenBrainz: ListenBrainzManager = .shared
	private let dockIconManager: DockIconManager = .shared
	private let artworkManager: ArtworkManager = .shared
	private let playerManager: PlayerManager = .shared

	private let context: NSManagedObjectContext

	private var currentSource: MusicSource?
	private var currentTrackKey: String?
	private var currentStartDate: Date?
	private var currentDuration: Int?
	private var currentEntry: LogEntry?
	private var playTime = PlayTime()
	private var didScrobble = false
	private var scrobbleTimer: Timer?
	private var isRetrying = false

	init(context: NSManagedObjectContext) {
		self.context = context
		Task { await retryFailedScrobbles() }
	}

	func handle(_ nowPlaying: MusicInfo) {
		// Players may send "stopped" without track info, so handle it before the title check.
		if nowPlaying.state == .stopped {
			if nowPlaying.source != nil && nowPlaying.source == currentSource {
				endCurrentTrack()
			}
			return
		}

		guard let title = nowPlaying.title,
			let artist = nowPlaying.artist,
			let source = nowPlaying.source,
			!title.isEmpty,
			!artist.isEmpty
		else {
			return
		}

		switch nowPlaying.state {
		case .playing:
			let album = nowPlaying.album
			let duration = max(0, (nowPlaying.duration ?? 0) / 1000)
			let key = "\(artist)|\(title)|\(album ?? "")"

			if key == currentTrackKey && !playTime.isRepeat(duration: duration, at: Date()) {
				resume()
			} else {
				if currentTrackKey != nil { endCurrentTrack() }
				currentSource = source
				currentTrackKey = key
				currentStartDate = Date()
				currentDuration = duration
				playTime.resume(at: Date())

				let entry = LogEntry.findOrCreate(
					artist: artist,
					title: title,
					album: album,
					source: source.rawValue,
					context: context
				)
				entry.duration = Int32(duration)
				try? context.save()
				currentEntry = entry

				appState.currentTrack.title = title
				appState.currentTrack.artist = artist
				appState.currentTrack.album = album

				Task {
					var artworkImage = nowPlaying.artwork
					var artworkSource: String?

					if artworkImage == nil {
						artworkImage = await MediaRemoteManager.shared.fetchCurrentArtwork()
						if artworkImage != nil {
							artworkSource = "MediaRemote"
						}
					} else {
						artworkSource = "Player"
					}

					if artworkImage == nil {
						artworkImage = await artworkManager.fetchArtwork(
							artist: entry.artist, track: entry.title, album: entry.album)
						if artworkImage != nil {
							artworkSource = UserDefaults.standard.get(\.artworkSource).rawValue
						}
					}

					if artworkSource == "MediaRemote", let artwork = artworkImage {
						await artworkManager.cacheArtwork(
							artwork,
							artist: entry.artist,
							track: entry.title,
							album: entry.album
						)
					}

					appState.currentTrack.image = artworkImage

					await sendNowPlaying(
						entry: entry,
						artist: artist,
						track: title,
						album: album,
						duration: duration
					)

					await playerManager.fetchFavoriteStateForCurrentTrack()

					if UserDefaults.standard.get(\.showArtworkInDock) {
						DockIconManager.shared.updateDockIcon(
							with: appState.currentTrack.image
						)
					}
				}
				scheduleScrobble()
			}

		case .paused:
			guard source == currentSource, playTime.isPlaying else { return }
			playTime.pause(at: Date())
			cancelTimer()

		default:
			break
		}
	}

	private func resume() {
		guard !playTime.isPlaying else { return }  // already playing; duplicate event
		playTime.resume(at: Date())
		scheduleScrobble()
	}

	/// Scrobbles the current track if it played long enough, then clears all track state.
	private func endCurrentTrack() {
		if let duration = currentDuration, duration > 30,
			playTime.played(at: Date()) >= threshold(for: duration)
		{
			fireScrobble()
		}
		cancelTimer()
		currentSource = nil
		currentTrackKey = nil
		currentStartDate = nil
		currentDuration = nil
		currentEntry = nil
		playTime = PlayTime()
		didScrobble = false
	}

	private func threshold(for duration: Int) -> TimeInterval {
		PlayTime.threshold(duration: duration, percent: UserDefaults.standard.get(\.scrobbleTrackAt))
	}

	private var lastFmActive: Bool {
		UserDefaults.standard.get(\.lastFmEnabled) && lastFm.username != nil
	}

	private var listenBrainzActive: Bool {
		UserDefaults.standard.get(\.listenBrainzEnabled) && listenBrainz.username != nil
	}

	// MARK: - Now Playing

	private func sendNowPlaying(
		entry: LogEntry,
		artist: String,
		track: String,
		album: String?,
		duration: Int
	) async {
		var errors: [String] = []
		var anySent = false

		// Last.fm
		if lastFmActive {
			do {
				try await lastFm.updateNowPlaying(
					artist: artist,
					track: track,
					album: album,
					duration: duration > 0 ? duration : nil
				)
				anySent = true
			} catch {
				errors.append("Last.fm: \(error.localizedDescription)")
			}
		}

		// ListenBrainz
		if listenBrainzActive {
			do {
				try await listenBrainz.scrobbling.updateNowPlaying(
					artist: artist,
					track: track,
					album: album,
					duration: duration > 0 ? duration : nil
				)
				anySent = true
			} catch {
				errors.append("ListenBrainz: \(error.localizedDescription)")
			}
		}

		if anySent {
			entry.markNowPlayingSent()
		} else if !errors.isEmpty {
			entry.markNowPlayingFailed(errors.joined(separator: "; "))
		}
	}

	// MARK: - Scrobbling

	/// Sets the timer for the play time still needed; call on start and on every resume.
	private func scheduleScrobble() {
		cancelTimer()
		guard !didScrobble, let duration = currentDuration, duration > 30 else { return }

		let remaining = max(0, threshold(for: duration) - playTime.played(at: Date()))
		scrobbleTimer = Timer.scheduledTimer(
			withTimeInterval: remaining,
			repeats: false
		) { [weak self] _ in
			Task { @MainActor [weak self] in
				self?.fireScrobble()
			}
		}
	}

	private func fireScrobble() {
		guard !didScrobble,
			let start = currentStartDate,
			let duration = currentDuration,
			let entry = currentEntry
		else { return }
		didScrobble = true

		guard lastFmActive || listenBrainzActive else { return }
		entry.date = start  // the retry sends this as the scrobble time
		entry.lastFmPending = lastFmActive
		entry.listenBrainzPending = listenBrainzActive

		Task {
			await submitPending(entry, duration: duration)
			if !entry.scrobbleFailed { await retryFailedScrobbles() }
		}
	}

	/// Sends the entry to each service it is still pending on, and records the result.
	/// A service that is pending but now off or signed out is dropped.
	private func submitPending(_ entry: LogEntry, duration: Int) async {
		let timestamp = Int(entry.date.timeIntervalSince1970)
		var errors: [String] = []

		if entry.lastFmPending {
			if lastFmActive {
				do {
					try await lastFm.scrobble(
						artist: entry.artist,
						track: entry.title,
						timestamp: timestamp,
						album: entry.album,
						duration: duration
					)
					entry.lastFmPending = false
				} catch {
					errors.append("Last.fm: \(error.localizedDescription)")
				}
			} else {
				entry.lastFmPending = false
			}
		}

		if entry.listenBrainzPending {
			if listenBrainzActive {
				do {
					try await listenBrainz.scrobbling.scrobble(
						artist: entry.artist,
						track: entry.title,
						timestamp: timestamp,
						album: entry.album,
						duration: duration
					)
					entry.listenBrainzPending = false
				} catch {
					errors.append("ListenBrainz: \(error.localizedDescription)")
				}
			} else {
				entry.listenBrainzPending = false
			}
		}

		if errors.isEmpty {
			entry.markScrobbled()
		} else {
			entry.markScrobbleFailed(errors.joined(separator: "; "))
		}
	}

	/// Resends failed scrobbles, oldest first. Stops at the first failure (likely still offline).
	// shortcut: only runs at launch and after a successful scrobble, not when the network comes back.
	func retryFailedScrobbles() async {
		guard !isRetrying else { return }
		isRetrying = true
		defer { isRetrying = false }

		let cutoff = Date().addingTimeInterval(-14 * 24 * 3600)  // Last.fm rejects older scrobbles
		let failed = LogEntry.fetchFailed(context: context).reversed().filter {
			($0.lastFmPending || $0.listenBrainzPending) && $0.date > cutoff
		}
		for entry in failed {
			await submitPending(entry, duration: Int(entry.duration))
			if entry.scrobbleFailed { break }
		}
	}

	private func cancelTimer() {
		scrobbleTimer?.invalidate()
		scrobbleTimer = nil
	}
}
