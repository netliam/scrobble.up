//
//  Preferences.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/25/25.
//

import Foundation

// MARK: - PlayerSwitching

enum PlayerSwitching: String, CaseIterable, Codable {
	case automatic = "automatic"
	case preferAppleMusic = "preferAppleMusic"
	case preferSpotify = "preferSpotify"
}

// MARK: - PlayerOverride

enum PlayerOverride: String, CaseIterable, Codable {
	case none = "none"
	case appleMusic = "appleMusic"
	case spotify = "spotify"
}

// MARK: - TrackFetchingMethod

enum TrackFetchingMethod: String, CaseIterable, Codable {
	case perApp = "perApp"
	case mediaRemote = "mediaRemote"
}

// MARK: - OpenLinksWith

enum OpenLinksWith: String, CaseIterable, Codable {
	case alwaysInLastFm = "alwaysInLastFm"
	case alwaysInAppleMusic = "alwaysInAppleMusic"
	case alwaysInSpotify = "alwaysInSpotify"
}

// MARK: - CopiedLink

enum CopiedLink: String, CaseIterable, Codable {
	case artistTitle = "artistTitle"
	case appleMusic = "appleMusic"
	case spotify = "spotify"
}

// MARK: - UpdateChannel

enum UpdateChannel: String, Codable, CaseIterable {
	case stable
	case nightly

	var feedURL: URL {
		let baseURL = "https://netliam.github.io/scrobble.up"

		switch self {
		case .stable:
			return URL(string: "\(baseURL)/appcast.xml")!
		case .nightly:
			return URL(string: "\(baseURL)/appcast-nightly.xml")!
		}
	}

	var displayName: String {
		switch self {
		case .stable:
			return "Stable"
		case .nightly:
			return "Nightly"
		}
	}

	var description: String {
		switch self {
		case .stable:
			return "Recommended. Receive tested, stable updates."
		case .nightly:
			return "For testers only. Daily builds with latest changes. May be unstable."
		}
	}
}
