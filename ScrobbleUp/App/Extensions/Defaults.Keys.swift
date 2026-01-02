//
//  Defaults.Keys.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/29/25.
//

import Defaults

extension Defaults.Keys {
  static let playerSwitching = Key<PlayerSwitching>(
    "playerSwitching", default: PlayerSwitching.automatic)
  static let playerOverride = Key<PlayerOverride>("playerOverride", default: PlayerOverride.none)
  static let openLinksWith = Key<OpenLinksWith>(
    "openLinksWith", default: OpenLinksWith.alwaysInAppleMusic)

  static let showIconInDock = Key<Bool>("showIconInDock", default: true)
  static let showArtworkInDock = Key<Bool>("showArtworkInDock", default: false)

  static let hideNonEssentialNotifications = Key<Bool>(
    "hideNonEssentialNotifications", default: false)
  static let ratingAndLoveStatusInHUD = Key<Bool>("ratingAndLoveStatusInHUD", default: true)
  static let infoCopiedToClipboardInHUD = Key<Bool>("infoCopiedToClipboardInHUD", default: true)
  static let currentPlayerChangedInHUD = Key<Bool>("currentPlayerChangedInHUD", default: true)

  static let syncLikes = Key<Bool>("syncLikes", default: true)
  static let scrobbleTrackAt = Key<Int>("scrobbleTrackAt", default: 50)

  static let listenBrainzEnabled = Key<Bool>("listenBrainzEnabled", default: false)
  static let listenBrainzBaseURL = Key<String>(
    "listenBrainzBaseURL",
    default: ListenBrainzManager.defaultBaseURL
  )

  static let lastFmEnabled = Key<Bool>("lastFmEnabled", default: false)
}
