//
//  Preferences.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/25/25.
//

import Defaults

// MARK: - PlayerSwitching

enum PlayerSwitching: String, CaseIterable, Codable, Equatable {
  case automatic = "automatic"
  case preferAppleMusic = "preferAppleMusic"
  case preferSpotify = "preferSpotify"
}

extension PlayerSwitching: Defaults.Serializable {}

// MARK: - PlayerOverride

enum PlayerOverride: String, CaseIterable, Codable, Equatable {
  case none = "none"
  case appleMusic = "appleMusic"
  case spotify = "spotify"
}

extension PlayerOverride: Defaults.Serializable {}

// MARK: - OpenLinksWith

enum OpenLinksWith: String, CaseIterable, Codable, Equatable {
  case currentActivePlayerOrLastFm = "currentActivePlayerOrLastFm"
  case currentActivePlayerOrAppleMusic = "currentActivePlayerOrAppleMusic"
  case currentActivePlayerOrSpotify = "currentActivePlayerOrSpotify"
  case alwaysInAppleMusic = "alwaysInAppleMusic"
  case alwaysInSpotify = "alwaysInSpotify"
}

extension OpenLinksWith: Defaults.Serializable {}

// MARK: - CopiedLink

enum CopiedLink: String, CaseIterable, Codable, Equatable {
  case artistTitle = "artistTitle"
  case appleMusic = "appleMusic"
  case spotify = "spotify"
}

extension CopiedLink: Defaults.Serializable {}
