//
//  ListenBrainzManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Combine
import Foundation

@MainActor
final class ListenBrainzManager: ObservableObject {

	// MARK: - Singleton

	static let shared = ListenBrainzManager()
	static let defaultBaseURL = "https://api.listenbrainz.org"

	// MARK: - Published Properties

	@Published private(set) var username: String?
	@Published private(set) var baseURL: String

	// MARK: - Services

	let authentication: ListenBrainzAuthService
	let scrobbling: ListenBrainzScrobblingService
	let feedback: ListenBrainzFeedbackService
	let stats: ListenBrainzStatsService
	let artwork: ListenBrainzArtworkService

	// MARK: - Private Properties

	private let config: ListenBrainzConfig

	private init() {
		self.config = ListenBrainzConfig.shared
		self.username = config.username
		self.baseURL = config.baseURL

		self.authentication = ListenBrainzAuthService(config: config)
		self.scrobbling = ListenBrainzScrobblingService(config: config)
		self.feedback = ListenBrainzFeedbackService(config: config)
		self.stats = ListenBrainzStatsService(config: config)
		self.artwork = ListenBrainzArtworkService(config: config)
	}

	// MARK: - Authentication

	func validateToken(_ token: String, baseURL: String? = nil) async throws -> String {
		let username = try await authentication.validateToken(token, baseURL: baseURL)
		self.username = config.username
		self.baseURL = config.baseURL
		return username
	}

	func configure(token: String, username: String, baseURL: String? = nil) {
		authentication.configure(token: token, username: username, baseURL: baseURL)
		self.username = config.username
	}

	func signOut() {
		authentication.signOut()
		self.username = nil
		self.baseURL = Self.defaultBaseURL
	}
}
