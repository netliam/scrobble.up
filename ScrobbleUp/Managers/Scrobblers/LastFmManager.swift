//
//  LastFmManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/25/25.
//

import Combine
import Foundation
import LastFM

@MainActor
final class LastFmManager: ObservableObject {

	// MARK: - Singleton

	static let shared = LastFmManager()

	// MARK: - Published Properties

	@Published private(set) var username: String?

	// MARK: - Properties

	var sessionKey: String?

	private let lastFM: LastFM
	private let api = "https://ws.audioscrobbler.com/2.0/"
	private let apiKey = Secrets.lastFmApiKey
	private let apiSecret = Secrets.lastFmApiSecret
	// MARK: - Initialization

	private init() {
		self.lastFM = LastFM(
			apiKey: apiKey,
			apiSecret: apiSecret
		)

		self.sessionKey = KeychainHelper.shared.get("lastfm_sessionKey")
		self.username = KeychainHelper.shared.get("lastfm_username")
	}

	// MARK: - Authentication Functions

	func getMobileSession(username: String, password: String) async throws {
		do {
			// This isn't actually deprecated, but the LastFM package marks it as such
			let session = try await lastFM.Auth.getMobileSession(
				username: username,
				password: password
			)

			self.sessionKey = session.key
			self.username = session.name
			KeychainHelper.shared.set(session.key, for: "lastfm_sessionKey")
			KeychainHelper.shared.set(username, for: "lastfm_username")
		} catch {
			print("Failed to get mobile session: \(error)")
			throw error
		}
	}

	func signOut() {
		sessionKey = nil
		username = nil
		KeychainHelper.shared.remove("lastfm_sessionKey")
		KeychainHelper.shared.remove("lastfm_username")
	}

	// MARK: - Track Functions

	func updateNowPlaying(
		artist: String,
		track: String,
		album: String?,
		duration: Int?
	) async throws {
		guard let sk = sessionKey else { return }
		guard let duration = duration else { return }

		let trackNowPlayingParams = TrackNowPlayingParams(
			artist: artist,
			track: track,
			album: album,
			duration: UInt(duration)
		)

		do {
			_ = try await lastFM.Track.updateNowPlaying(
				params: trackNowPlayingParams,
				sessionKey: sk
			)
		} catch {
			print("Failed to update now playing: \(error)")
		}
	}

	func scrobble(
		artist: String,
		track: String,
		timestamp: Int,
		album: String?,
		duration: Int?
	) async throws {
		guard let sk = sessionKey else { return }
		guard let duration = duration else { return }

		var scrobbleParams = ScrobbleParams()

		let scrobbleParamItem = ScrobbleParamItem(
			artist: artist,
			track: track,
			timestamp: UInt(timestamp),
			album: album,
			duration: UInt(duration)
		)
		try scrobbleParams.addItem(item: scrobbleParamItem)

		do {
			_ = try await lastFM.Track.scrobble(params: scrobbleParams, sessionKey: sk)
		} catch {
			print("Failed to scrobble: \(error)")
		}
	}

	func fetchTrackInfo(artist: String, track: String) async -> TrackInfo? {
		let trackInfoParams = TrackInfoParams(artist: artist, track: track)

		do {
			let trackInfo = try await lastFM.Track.getInfo(params: trackInfoParams)

			return trackInfo
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return nil
		} catch LastFMError.NoData {
			print("No data was returned.")
			return nil
		} catch {
			print("An error ocurred: \(error)")
			return nil
		}
	}

	func loveTrack(track: String, artist: String) async throws {
		guard let sessionKey = sessionKey else { return }

		let loveTrackParams = TrackParams(track: track, artist: artist)

		do {
			try await lastFM.Track.love(params: loveTrackParams, sessionKey: sessionKey)
		} catch {
			print("Failed to love track: \(error)")
		}
	}

	func unloveTrack(track: String, artist: String) async throws {
		guard let sessionKey = sessionKey else { return }

		let unloveTrackParams = TrackParams(track: track, artist: artist)

		do {
			try await lastFM.Track.unlove(params: unloveTrackParams, sessionKey: sessionKey)
		} catch {
			print("Failed to unlove track: \(error)")
		}
	}

	func isTrackLoved(artist: String, track: String) async -> Bool {
		guard let username = username else { return false }

		var components = URLComponents(string: api)!
		components.queryItems = [
			URLQueryItem(name: "method", value: "track.getInfo"),
			URLQueryItem(name: "api_key", value: apiKey),
			URLQueryItem(name: "artist", value: artist),
			URLQueryItem(name: "track", value: track),
			URLQueryItem(name: "username", value: username),
			URLQueryItem(name: "format", value: "json"),
		]

		guard let url = components.url else { return false }

		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
			let trackData = json?["track"] as? [String: Any]

			if let userloved = trackData?["userloved"] as? String {
				return userloved == "1"
			}
			return false
		} catch {
			print("Error checking track love state: \(error)")
			return false
		}
	}

	func fetchSimilarTracks(artist: String, track: String, autocorrect: Bool, limit: Int) async
		-> [TrackSimilar]?
	{
		let trackSimilarParams = TrackSimilarParams(
			track: track, artist: artist, autocorrect: autocorrect, limit: UInt(limit))

		do {
			let similarTracks = try await lastFM.Track.getSimilar(params: trackSimilarParams)

			return Array(similarTracks.items)
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return nil
		} catch LastFMError.NoData {
			print("No data was returned.")
			return nil
		} catch {
			print("An error ocurred: \(error)")
			return nil
		}
	}

	// MARK: - Artist Functions

	func fetchArtistInfo(artist: String, autocorrect: Bool = true) async -> ArtistInfo? {
		let artistInfoParams = ArtistInfoParams(
			term: artist, criteria: .artist, autocorrect: autocorrect)

		do {
			let artistInfo = try await lastFM.Artist.getInfo(params: artistInfoParams)

			return artistInfo
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return nil
		} catch LastFMError.NoData {
			print("No data was returned.")
			return nil
		} catch {
			print("An error ocurred: \(error)")
			return nil
		}
	}

	func fetchSimilarArtists(artist: String, autocorrect: Bool, limit: Int) async
		-> [ArtistSimilar]?
	{
		let artistSimilarParams = ArtistSimilarParams(
			artist: artist, autocorrect: autocorrect, limit: UInt(limit))

		do {
			let similarArtists = try await lastFM.Artist.getSimilar(params: artistSimilarParams)

			return Array(similarArtists.items)
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return nil
		} catch LastFMError.NoData {
			print("No data was returned.")
			return nil
		} catch {
			print("An error ocurred: \(error)")
			return nil
		}
	}

	// MARK: - Album Functions

	func fetchAlbumInfo(artist: String, album: String) async -> AlbumInfo? {
		let albumInfoParams = AlbumInfoParams(artist: artist, album: album)

		do {
			let albumInfo = try await lastFM.Album.getInfo(params: albumInfoParams)

			return albumInfo
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return nil
		} catch LastFMError.NoData {
			print("No data was returned.")
			return nil
		} catch {
			print("An error ocurred: \(error)")
			return nil
		}
	}

	// MARK: - User Functions

	func fetchUserInfo() async -> UserInfo? {
		guard let sessionKey = sessionKey else { return nil }
		do {
			let userInfo = try await lastFM.User.getInfo(sessionKey: sessionKey)

			return userInfo
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return nil
		} catch {
			print("An error ocurred: \(error)")
			return nil
		}
	}

	func fetchLovedTracksCount() async -> UInt {
		guard let username = username else { return 0 }

		var components = URLComponents(string: api)!
		components.queryItems = [
			URLQueryItem(name: "method", value: "user.getLovedTracks"),
			URLQueryItem(name: "api_key", value: apiKey),
			URLQueryItem(name: "user", value: username),
			URLQueryItem(name: "limit", value: "1"),
			URLQueryItem(name: "format", value: "json"),
		]

		guard let url = components.url else { return 0 }

		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
			let lovedtracks = json?["lovedtracks"] as? [String: Any]
			let attr = lovedtracks?["@attr"] as? [String: Any]

			if let totalString = attr?["total"] as? String, let total = UInt(totalString) {
				return total
			}
			return 0
		} catch {
			print("Error fetching loved tracks count: \(error)")
			return 0
		}
	}

	func fetchRecentTracks(limit: Int = 30) async throws -> [RecentTrack?] {
		let recentTrackParams = RecentTracksParams(user: username ?? "", limit: UInt(limit))

		do {
			let recentTracks = try await lastFM.User.getRecentTracks(params: recentTrackParams)

			return Array(recentTracks.items)
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return []
		} catch LastFMError.NoData {
			print("No data was returned.")
			return []
		} catch {
			print("An error ocurred: \(error)")
			return []
		}
	}

	func fetchTopAlbums(period: TopAlbumPeriod, limit: Int = 9) async -> [UserTopAlbum]? {
		guard let username = username else { return nil }

		var periodParam: UserTopItemsParams.Period

		switch period {
		case .overall:
			periodParam = .overall
		case .week:
			periodParam = .last7Days
		case .month:
			periodParam = .last30days
		case .quarter:
			periodParam = .last90days
		case .halfYear:
			periodParam = .last180days
		case .year:
			periodParam = .lastYear
		}

		let topAlbumParams = UserTopItemsParams(
			user: username, period: periodParam, limit: UInt(limit))

		do {
			let topAlbums = try await lastFM.User.getTopAlbums(params: topAlbumParams)

			return Array(topAlbums.items)
		} catch LastFMError.LastFMServiceError(let errorType, let message) {
			print(errorType, message)
			return []
		} catch LastFMError.NoData {
			print("No data was returned.")
			return []
		} catch {
			print("An error ocurred: \(error)")
			return []
		}
	}

	// MARK: - Misc Functions

	func fetchArtworkURL(artist: String, track: String, album: String?) async -> URL? {
		// Try album artwork first if album is provided
		if let album = album, !album.isEmpty {
			let albumInfo = await fetchAlbumInfo(artist: artist, album: album)
			if let images = albumInfo?.image,
				let artwork = bestImageURL(images: images)
			{
				return artwork
			}
		}

		// Fallback to track artwork
		let trackInfo = await fetchTrackInfo(artist: artist, track: track)
		if let images = trackInfo?.album?.image,
			let artwork = bestImageURL(images: images)
		{
			return artwork
		}

		return nil
	}
}
