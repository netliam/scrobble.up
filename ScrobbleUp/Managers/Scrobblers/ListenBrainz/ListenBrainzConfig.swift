//
//  ListenBrainzConfig.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import Foundation

/// Shared configuration for ListenBrainz services
final class ListenBrainzConfig {
	static let shared = ListenBrainzConfig()
	static let defaultBaseURL = "https://api.listenbrainz.org"
	static let userAgent = "scrobble.up/1.0 (liams@tuskmo.com)"

	var token: String? {
		didSet {
			if let token = token {
				KeychainHelper.shared.set(token, for: "listenbrainz_token")
			} else {
				KeychainHelper.shared.remove("listenbrainz_token")
			}
		}
	}

	var username: String? {
		didSet {
			if let username = username {
				KeychainHelper.shared.set(username, for: "listenbrainz_username")
			} else {
				KeychainHelper.shared.remove("listenbrainz_username")
			}
		}
	}

	var baseURL: String {
		didSet {
			UserDefaults.standard.set(baseURL, for: \.listenBrainzBaseURL)
		}
	}

	let http: HTTPHelper
	let musicBrainz: MusicBrainzService

	private init() {
		self.http = HTTPHelper(userAgent: Self.userAgent)
		self.token = KeychainHelper.shared.get("listenbrainz_token")
		self.username = KeychainHelper.shared.get("listenbrainz_username")
		self.baseURL = UserDefaults.standard.get(\.listenBrainzBaseURL)
		self.musicBrainz = MusicBrainzService(http: http)
	}
}
