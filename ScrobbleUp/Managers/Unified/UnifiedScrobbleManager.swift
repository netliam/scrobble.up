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
	private var scrobbleTimer: Timer?

	init(context: NSManagedObjectContext) {
		self.context = context
	}

	func handle(_ nowPlaying: MusicInfo) {
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

			if key != currentTrackKey {
				cancelTimer()
				currentSource = source
				currentTrackKey = key
				currentStartDate = Date()
				currentDuration = duration

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
				scheduleScrobbleIfNeeded(duration: duration)
			}

		case .paused:
			cancelTimer()

		case .stopped:
			if let start = currentStartDate,
				let duration = currentDuration,
				duration > 0
			{
				let played = Int(Date().timeIntervalSince(start))
				let threshold = min(
					max(30, duration * UserDefaults.standard.get(\.scrobbleTrackAt) / 100),
					240
				)
				if played >= threshold { fireScrobble() }
			}
			cancelTimer()
			currentSource = nil
			currentTrackKey = nil
			currentStartDate = nil
			currentDuration = nil
			currentEntry = nil

		default:
			break
		}
	}

	// MARK: - Now Playing

	private func sendNowPlaying(
		artist: String,
		track: String,
		album: String?,
		duration: Int
	) async {
		var errors: [String] = []
		var anySent = false

		// Last.fm
		if UserDefaults.standard.get(\.lastFmEnabled) && lastFm.username != nil {
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
		if UserDefaults.standard.get(\.listenBrainzEnabled) && listenBrainz.username != nil {
			do {
				try await listenBrainz.updateNowPlaying(
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

		if let entry = currentEntry {
			if anySent {
				entry.markNowPlayingSent()
			} else if !errors.isEmpty {
				entry.markNowPlayingFailed(errors.joined(separator: "; "))
			}
		}
	}

	// MARK: - Scrobbling

	private func scheduleScrobbleIfNeeded(duration: Int) {
		guard duration > 30 else { return }

		let threshold = min(
			max(30, duration * UserDefaults.standard.get(\.scrobbleTrackAt) / 100),
			240
		)
		scrobbleTimer = Timer.scheduledTimer(
			withTimeInterval: TimeInterval(threshold),
			repeats: false
		) { [weak self] _ in
			Task { @MainActor [weak self] in
				self?.fireScrobble()
			}
		}
	}

	private func fireScrobble() {
		guard let start = currentStartDate,
			let duration = currentDuration,
			let entry = currentEntry
		else { return }

		let artist = entry.artist
		let title = entry.title
		let album = entry.album
		let timestamp = Int(start.timeIntervalSince1970)

		Task {
			await scrobble(
				artist: artist,
				track: title,
				album: album,
				duration: duration,
				timestamp: timestamp
			)
		}
	}

	private func scrobble(
		artist: String,
		track: String,
		album: String?,
		duration: Int,
		timestamp: Int
	) async {
		var errors: [String] = []
		var anyScrobbled = false

		// Last.fm
		if UserDefaults.standard.get(\.lastFmEnabled) && lastFm.username != nil {
			do {
				try await lastFm.scrobble(
					artist: artist,
					track: track,
					timestamp: timestamp,
					album: album,
					duration: duration
				)
				anyScrobbled = true
			} catch {
				errors.append("Last.fm: \(error.localizedDescription)")
			}
		}

		// ListenBrainz
		if UserDefaults.standard.get(\.listenBrainzEnabled) && listenBrainz.username != nil {
			do {
				try await listenBrainz.scrobble(
					artist: artist,
					track: track,
					timestamp: timestamp,
					album: album,
					duration: duration
				)
				anyScrobbled = true
			} catch {
				errors.append("ListenBrainz: \(error.localizedDescription)")
			}
		}

		if let entry = currentEntry {
			if anyScrobbled {
				entry.markScrobbled()
			} else if !errors.isEmpty {
				entry.markScrobbleFailed(errors.joined(separator: "; "))
			}
		}
	}

	private func cancelTimer() {
		scrobbleTimer?.invalidate()
		scrobbleTimer = nil
	}
}
