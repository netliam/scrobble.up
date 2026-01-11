//
//  ListenBrainzAuthService.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import Foundation

/// Service for handling ListenBrainz authentication
final class ListenBrainzAuthService {
	private let config: ListenBrainzConfig

	init(config: ListenBrainzConfig) {
		self.config = config
	}

	// MARK: - Token Validation

	func validateToken(_ token: String, baseURL: String? = nil) async throws -> String {
		let url = baseURL ?? config.baseURL

		guard let requestURL = URL(string: "\(url)/1/validate-token") else {
			throw ListenBrainzError.invalidURL
		}

		let headers = ["Authorization": "Token \(token)"]

		do {
			let json = try await config.http.getJSON(url: requestURL, headers: headers)

			guard let valid = json["valid"] as? Bool, valid,
				let username = json["user_name"] as? String
			else {
				throw ListenBrainzError.invalidToken
			}

			return username
		} catch HTTPError.unauthorized {
			throw ListenBrainzError.invalidToken
		} catch let error as ListenBrainzError {
			throw error
		} catch {
			throw ListenBrainzError.invalidToken
		}
	}

	// MARK: - Configuration

	func configure(token: String, username: String, baseURL: String? = nil) {
		config.token = token
		config.username = username

		if let baseURL = baseURL {
			config.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		}
	}

	func signOut() {
		config.token = nil
		config.username = nil
		config.baseURL = ListenBrainzConfig.defaultBaseURL
	}
}
