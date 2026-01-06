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
    case week = "last7Days"
    case month = "last30days"
    case quarter = "last90days"
    case halfYear = "last180days"
    case year = "lastYear"
    case overall = "overall"
}
