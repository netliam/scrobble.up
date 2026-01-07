//
//  Settings.swift
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

// MARK: - WidgetWindowBehavior

enum WidgetWindowBehavior: String, CaseIterable, Codable {
	case desktop = "desktop"
	case above = "above"
	case stuck = "stuck"
	case standardWindow = "standardWindow"
}

// MARK: - TopAlbumPeriod

enum TopAlbumPeriod: String, CaseIterable, Codable {
    case overall = "Overall"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case halfYear = "Half Year"
    case year = "Year"
}

// MARK: - ScrobblerService

enum ScrobblerService: String, CaseIterable {
    case lastFm = "Last.fm"
    case listenBrainz = "ListenBrainz"
    
    var displayName: String {
        rawValue
    }
    
    var periodKey: KeyPath<Keys.Type, UserDefaultsKey<TopAlbumPeriod>> {
        switch self {
        case .lastFm:
            return \.lastFmTopAlbumPeriod
        case .listenBrainz:
            return \.listenBrainzTopAlbumPeriod
        }
    }
}

// MARK: - ArtworkSource

enum ArtworkSource: String, CaseIterable, Codable {
    case lastFm = "lastFm"
    case musicBrainz = "musicBrainz"
}
