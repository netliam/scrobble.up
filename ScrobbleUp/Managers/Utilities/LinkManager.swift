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

	func openAlbum(artist: String, album: String) async {
		let preference = UserDefaults.standard.get(\.openLinksWith)

		guard let url = await resolveAlbumURL(artist: artist, album: album, preference: preference)
		else {
			print("Failed to resolve album URL")
			return
		}

		openURL(url, forPreference: preference)
	}

	// MARK: - URL Resolution

	private func resolveArtistURL(artist: String, preference: OpenLinksWith) async -> URL? {
		switch preference {
		case .alwaysInLastFm:
			return await fetchArtistLinkLastFm(artist: artist)

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
		case .alwaysInLastFm:
			return await fetchTrackLinkLastFm(artist: artist, track: track)

		case .alwaysInAppleMusic:
			return await fetchTrackLinkMusic(artist: artist, track: track, album: album)

		case .alwaysInSpotify:
			return await fetchTrackLinkSpotify(artist: artist, title: track, album: album)
		}
	}

	private func resolveAlbumURL(artist: String, album: String, preference: OpenLinksWith) async
		-> URL?
	{
		switch preference {
		case .alwaysInLastFm:
			return await fetchAlbumLinkLastFm(artist: artist, album: album)

		case .alwaysInAppleMusic:
			return await fetchAlbumLinkMusic(artist: artist, album: album)

		case .alwaysInSpotify:
			return await fetchAlbumLinkSpotify(artist: artist, album: album)
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
			case .alwaysInAppleMusic:
				if url.host?.contains("apple.com") == true || url.host?.contains("itunes") == true {
					return URL(fileURLWithPath: "/System/Applications/Music.app")
				}
			case .alwaysInSpotify:
				if url.host?.contains("spotify.com") == true {
					return NSWorkspace.shared.urlForApplication(
						withBundleIdentifier: "com.spotify.client")
				}
			case .alwaysInLastFm:
				break
			}
			return nil
		}
	}

	// MARK: - Last.Fm Links

	private func fetchArtistLinkLastFm(artist: String) async -> URL? {
		if let url = await lastFm.fetchArtistInfo(artist: artist)?.url {
			return url
		}
		return nil
	}

	private func fetchTrackLinkLastFm(artist: String, track: String) async -> URL? {
		if let url = await lastFm.fetchTrackInfo(artist: artist, track: track)?.url {
			return url
		}

		return nil
	}

	private func fetchAlbumLinkLastFm(artist: String, album: String) async -> URL? {
		let albumInfo = await lastFm.fetchAlbumInfo(artist: artist, album: album)
		return albumInfo?.url
	}

	// MARK: - Apple Music Links

	private func fetchArtistLinkMusic(artist: String) async -> URL? {
		guard let url = URLHelpers.makeITunesSearchURL(query: artist, entity: "allArtist") else {
			return nil
		}

		if let json = await JSONHelpers.fetchJSON(from: url),
			let results = json["results"] as? [[String: Any]],
			let firstResult = results.first,
			let artistID = firstResult["artistId"] as? Int
		{
			return URL(string: "music://music.apple.com/artist/\(artistID)")
		}

		return nil
	}

	private func fetchTrackLinkMusic(artist: String, track: String, album: String? = nil) async
		-> URL?
	{
		var searchTerms = [artist, track]
		if let album = album, album.isNotEmpty {
			searchTerms.append(album)
		}

		let query = searchTerms.joined(separator: " ")
		guard let url = URLHelpers.makeITunesSearchURL(query: query, entity: "song") else {
			return nil
		}

		if let json = await JSONHelpers.fetchJSON(from: url),
			let results = json["results"] as? [[String: Any]],
			let firstResult = results.first,
			let trackID = firstResult["trackId"] as? Int
		{
			return URL(string: "music://music.apple.com/song/\(trackID)")
		}

		return nil
	}

	private func fetchAlbumLinkMusic(artist: String, album: String) async -> URL? {
		let query = "\(artist) \(album)"
		guard let url = URLHelpers.makeITunesSearchURL(query: query, entity: "album") else {
			return nil
		}

		if let json = await JSONHelpers.fetchJSON(from: url),
			let results = json["results"] as? [[String: Any]],
			let firstResult = results.first,
			let collectionID = firstResult["collectionId"] as? Int
		{
			return URL(string: "music://music.apple.com/album/\(collectionID)")
		}

		return nil
	}

	// MARK: - Spotify Links

	private func fetchArtistLinkSpotify(artist: String) async -> URL? {
		let query = URLHelpers.encodeSearchQuery(artist)
		return URL(string: "spotify:search:\(query)")
	}

	private func fetchTrackLinkSpotify(artist: String, title: String, album: String? = nil) async
		-> URL?
	{
		var searchTerms = [artist, title]
		if let album = album {
			searchTerms.append(album)
		}
		let encoded = URLHelpers.encodeSearchQuery(searchTerms.joined(separator: " "))
		return URL(string: "spotify:search:\(encoded)")
	}

	private func fetchAlbumLinkSpotify(artist: String, album: String) async -> URL? {
		let query = URLHelpers.encodeSearchQuery(artist, album)
		return URL(string: "spotify:search:\(query)")
	}
}
