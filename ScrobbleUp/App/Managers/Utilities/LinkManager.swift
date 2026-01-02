//
//  LinkManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/29/25.
//

import AppKit
import Foundation
import LastFM

final class LinkManager {
	static let shared = LinkManager()

	private let lastFm: LastFmManager = .shared

	private init() {}

	// MARK: - Public API

	func openArtist(artist: String) async {
		let preference = UserDefaults.standard.get(\.openLinksWith)

		guard let url = await resolveArtistURL(artist: artist, preference: preference) else {
			print("Failed to resolve artist URL")
			return
		}

		openURL(url, forPreference: preference)
	}

	func openTrack(artist: String, track: String, album: String? = nil) async {
		let preference = UserDefaults.standard.get(\.openLinksWith)

		guard
			let url = await resolveTrackURL(
				track: track,
				artist: artist,
				album: album,
				preference: preference
			)
		else {
			print("Failed to resolve track URL")
			return
		}

		openURL(url, forPreference: preference)
	}

	// MARK: - URL Resolution

	private func resolveArtistURL(artist: String, preference: OpenLinksWith) async -> URL? {
		switch preference {
		case .currentActivePlayerOrLastFm:
			if let url = await artistURLForCurrentPlayer(artist: artist) {
				return url
			}
			return await fetchArtistLinkLastFm(artist: artist)

		case .currentActivePlayerOrAppleMusic:
			if let url = await artistURLForCurrentPlayer(artist: artist) {
				return url
			}
			return await fetchArtistLinkMusic(artist: artist)

		case .currentActivePlayerOrSpotify:
			if let url = await artistURLForCurrentPlayer(artist: artist) {
				return url
			}
			return await fetchArtistLinkSpotify(artist: artist)

		case .alwaysInAppleMusic:
			return await fetchArtistLinkMusic(artist: artist)

		case .alwaysInSpotify:
			return await fetchArtistLinkSpotify(artist: artist)
		}
	}

	private func resolveTrackURL(
		track: String,
		artist: String,
		album: String?,
		preference: OpenLinksWith
	) async -> URL? {
		switch preference {
		case .currentActivePlayerOrLastFm:
			if let url = await trackURLForCurrentPlayer(track: track, artist: artist, album: album)
			{
				return url
			}
			return await fetchTrackLinkLastFm(artist: artist, track: track)

		case .currentActivePlayerOrAppleMusic:
			if let url = await trackURLForCurrentPlayer(track: track, artist: artist, album: album)
			{
				return url
			}
			return await fetchTrackLinkMusic(artist: artist, track: track, album: album)

		case .currentActivePlayerOrSpotify:
			if let url = await trackURLForCurrentPlayer(track: track, artist: artist, album: album)
			{
				return url
			}
			return await fetchTrackLinkSpotify(artist: artist, title: track, album: album)

		case .alwaysInAppleMusic:
			return await fetchTrackLinkMusic(artist: artist, track: track, album: album)

		case .alwaysInSpotify:
			return await fetchTrackLinkSpotify(artist: artist, title: track, album: album)
		}
	}

	private func artistURLForCurrentPlayer(artist: String) async -> URL? {
		guard let currentPlayer = AppState.shared.currentActivePlayer else { return nil }

		switch currentPlayer {
		case .appleMusic:
			return await fetchArtistLinkMusic(artist: artist)
		case .spotify:
			return await fetchArtistLinkSpotify(artist: artist)
		}
	}

	private func trackURLForCurrentPlayer(
		track: String,
		artist: String,
		album: String?
	) async -> URL? {
		guard let currentPlayer = AppState.shared.currentActivePlayer else { return nil }

		switch currentPlayer {
		case .appleMusic:
			return await fetchTrackLinkMusic(artist: artist, track: track, album: album)
		case .spotify:
			return await fetchTrackLinkSpotify(artist: artist, title: track, album: album)
		}
	}

	// MARK: - Open URL

	private func openURL(_ url: URL, forPreference preference: OpenLinksWith) {
		let appURL = applicationURL(for: url, preference: preference)

		let configuration = NSWorkspace.OpenConfiguration()
		configuration.activates = true

		if let appURL = appURL {
			NSWorkspace.shared.open(
				[url],
				withApplicationAt: appURL,
				configuration: configuration
			) { _, error in
				if let error = error {
					print("Failed to open link: \(error)")
				}
			}
		} else {
			NSWorkspace.shared.open(url)
		}
	}

	private func applicationURL(for url: URL, preference: OpenLinksWith) -> URL? {
		switch url.scheme {
		case "music":
			return URL(fileURLWithPath: "/System/Applications/Music.app")
		case "spotify":
			return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client")
		default:
			switch preference {
			case .alwaysInAppleMusic, .currentActivePlayerOrAppleMusic:
				if url.host?.contains("apple.com") == true || url.host?.contains("itunes") == true {
					return URL(fileURLWithPath: "/System/Applications/Music.app")
				}
			case .alwaysInSpotify, .currentActivePlayerOrSpotify:
				if url.host?.contains("spotify.com") == true {
					return NSWorkspace.shared.urlForApplication(
						withBundleIdentifier: "com.spotify.client")
				}
			case .currentActivePlayerOrLastFm:
				break
			}
			return nil
		}
	}

	// MARK: - Last.Fm Links

	private func fetchArtistLinkLastFm(artist: String) async -> URL? {
		do {
			return try await lastFm.fetchArtistInfo(artist: artist)?.url
		} catch {
			print("Error fetching Last.fm artist: \(error)")
			return nil
		}
	}

	private func fetchTrackLinkLastFm(artist: String, track: String) async -> URL? {
		do {
			return try await lastFm.fetchTrackInfo(artist: artist, track: track)?.url
		} catch {
			print("Error fetching Last.fm track: \(error)")
			return nil
		}
	}

	// MARK: - Apple Music Links

	private func fetchArtistLinkMusic(artist: String) async -> URL? {
		let query = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		let searchURL = "https://itunes.apple.com/search?term=\(query)&entity=allArtist&limit=1"

		guard let url = URL(string: searchURL) else { return nil }

		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

			guard let results = json?["results"] as? [[String: Any]],
				let firstResult = results.first,
				let artistID = firstResult["artistId"] as? Int
			else {
				return nil
			}

			return URL(string: "music://music.apple.com/artist/\(artistID)")
		} catch {
			print("Error fetching Apple Music artist: \(error)")
			return nil
		}
	}

	private func fetchTrackLinkMusic(artist: String, track: String, album: String? = nil) async
		-> URL?
	{
		var searchTerm = "\(artist) \(track)"
		if let album = album, !album.isEmpty {
			searchTerm += " \(album)"
		}

		let query = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		let searchURL = "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1"

		guard let url = URL(string: searchURL) else { return nil }

		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

			guard let results = json?["results"] as? [[String: Any]],
				let firstResult = results.first,
				let trackID = firstResult["trackId"] as? Int
			else {
				return nil
			}

			return URL(string: "music://music.apple.com/song/\(trackID)")
		} catch {
			print("Error fetching Apple Music track: \(error)")
			return nil
		}
	}

	// MARK: - Spotify Links

	private func fetchArtistLinkSpotify(artist: String) async -> URL? {
		let query = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		return URL(string: "spotify:search:\(query)")
	}

	private func fetchTrackLinkSpotify(artist: String, title: String, album: String? = nil) async
		-> URL?
	{
		var query = "\(artist) \(title)"
		if let album = album {
			query += " \(album)"
		}
		let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
		return URL(string: "spotify:search:\(encoded)")
	}
}
