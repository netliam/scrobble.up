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

	static let showIconInDock = UserDefaultsKey("showIconInDock", defaultValue: false)
	static let showArtworkInDock = UserDefaultsKey("showArtworkInDock", defaultValue: false)

	static let showDesktopWidget = UserDefaultsKey("showDesktopWidget", defaultValue: false)
	static let widgetWindowBehavior = UserDefaultsKey(
		"widgetWindowBehavior", defaultValue: WidgetWindowBehavior.desktop)

	static let showCurrentTrackInStatusBar = UserDefaultsKey(
		"showCurrentTrackInStatusBar", defaultValue: false)
	static let showAlbumNameInStatusBar = UserDefaultsKey(
		"showAlbumNameInStatusBar", defaultValue: false)

	static let ratingStatus = UserDefaultsKey("ratingStatus", defaultValue: true)
	static let infoCopied = UserDefaultsKey("infoCopied", defaultValue: true)
	static let playerChanged = UserDefaultsKey("playerChanged", defaultValue: true)

	static let playerSwitching = UserDefaultsKey(
		"playerSwitching", defaultValue: PlayerSwitching.automatic)
	static let playerOverride = UserDefaultsKey("playerOverride", defaultValue: PlayerOverride.none)
	static let trackFetchingMethod = UserDefaultsKey(
		"trackFetchingMethod", defaultValue: TrackFetchingMethod.mediaRemote)
	static let openLinksWith = UserDefaultsKey(
		"openLinksWith", defaultValue: OpenLinksWith.alwaysInAppleMusic)
	static let artworkSource = UserDefaultsKey("artworkSource", defaultValue: ArtworkSource.lastFm)

	static let syncLikes = UserDefaultsKey("syncLikes", defaultValue: true)
	static let scrobbleTrackAt = UserDefaultsKey("scrobbleTrackAt", defaultValue: 50)

	static let listenBrainzEnabled = UserDefaultsKey("listenBrainzEnabled", defaultValue: true)
	static let listenBrainzBaseURL = UserDefaultsKey(
		"listenBrainzBaseURL", defaultValue: "https://api.listenbrainz.org")
	static let listenBrainzTopAlbumPeriod = UserDefaultsKey(
		"listenBrainzTopAlbumPeriod", defaultValue: TopAlbumPeriod.overall)

	static let lastFmEnabled = UserDefaultsKey("lastFmEnabled", defaultValue: true)
	static let lastFmTopAlbumPeriod = UserDefaultsKey(
		"lastFmTopAlbumPeriod", defaultValue: TopAlbumPeriod.overall)
}
