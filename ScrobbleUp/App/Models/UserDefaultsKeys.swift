//
//  UserDefaultsKeys.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/2/26.
//

import Foundation

enum Keys {
	static let hasCompletedOnboarding = UserDefaultsKey(
		"hasCompletedOnboarding", defaultValue: false)

	static let playerSwitching = UserDefaultsKey(
		"playerSwitching", defaultValue: PlayerSwitching.automatic)
	static let playerOverride = UserDefaultsKey("playerOverride", defaultValue: PlayerOverride.none)
	static let openLinksWith = UserDefaultsKey(
		"openLinksWith", defaultValue: OpenLinksWith.currentActivePlayerOrAppleMusic)

	static let showIconInDock = UserDefaultsKey("showIconInDock", defaultValue: false)
	static let showArtworkInDock = UserDefaultsKey("showArtworkInDock", defaultValue: false)

	static let ratingAndLoveStatus = UserDefaultsKey("ratingAndLoveStatus", defaultValue: true)
	static let infoCopiedToClipboard = UserDefaultsKey("infoCopiedToClipboard", defaultValue: true)
	static let currentPlayerChanged = UserDefaultsKey("currentPlayerChanged", defaultValue: true)

	static let syncLikes = UserDefaultsKey("syncLikes", defaultValue: true)
	static let scrobbleTrackAt = UserDefaultsKey("scrobbleTrackAt", defaultValue: 50)

	static let listenBrainzEnabled = UserDefaultsKey("listenBrainzEnabled", defaultValue: true)
	static let listenBrainzBaseURL = UserDefaultsKey(
		"listenBrainzBaseURL", defaultValue: "https://api.listenbrainz.org")

	static let lastFmEnabled = UserDefaultsKey("lastFmEnabled", defaultValue: true)
}
