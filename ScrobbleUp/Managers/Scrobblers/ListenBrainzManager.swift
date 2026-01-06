//
//  ListenBrainzManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Combine
import Foundation

final class ListenBrainzManager: ObservableObject {

	private static let userAgent = "scrobble.up/1.0 (liams@tuskmo.com)"

	private lazy var session: URLSession = {
		let config = URLSessionConfiguration.default
		var headers = config.httpAdditionalHeaders ?? [:]
		headers["User-Agent"] = Self.userAgent
		headers["Accept"] = "application/json"
		config.httpAdditionalHeaders = headers
		return URLSession(configuration: config)
	}()

	static let shared = ListenBrainzManager()
	static let defaultBaseURL = "https://api.listenbrainz.org"

	@Published private(set) var username: String?
	@Published private(set) var baseURL: String

	private var token: String?

	private init() {
		self.token = KeychainHelper.shared.get("listenbrainz_token")
		self.username = KeychainHelper.shared.get("listenbrainz_username")
		self.baseURL = UserDefaults.standard.get(\.listenBrainzBaseURL)
	}

	// MARK: - Authentication

	func validateToken(_ token: String, baseURL: String? = nil) async throws -> String {
		let url = baseURL ?? self.baseURL

		guard let requestURL = URL(string: "\(url)/1/validate-token") else {
			throw ListenBrainzError.invalidURL
		}

		var request = URLRequest(url: requestURL)
		request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

		let (data, response) = try await session.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse,
			httpResponse.statusCode == 200
		else {
			throw ListenBrainzError.invalidToken
		}

		let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

		guard let valid = json?["valid"] as? Bool, valid,
			let username = json?["user_name"] as? String
		else {
			throw ListenBrainzError.invalidToken
		}

		self.token = token

		return username
	}

	func configure(token: String, username: String, baseURL: String? = nil) {
		self.token = token
		self.username = username

		if let baseURL = baseURL {
			self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
			UserDefaults.standard.set(self.baseURL, for: \.listenBrainzBaseURL)
		}

		KeychainHelper.shared.set(token, for: "listenbrainz_token")
		KeychainHelper.shared.set(username, for: "listenbrainz_username")
	}

	func signOut() {
		token = nil
		username = nil
		baseURL = Self.defaultBaseURL

		KeychainHelper.shared.remove("listenbrainz_token")
		KeychainHelper.shared.remove("listenbrainz_username")
		UserDefaults.standard.set(Self.defaultBaseURL, forKey: "listenBrainzBaseURL")
	}

	// MARK: - Scrobbling

	func scrobble(artist: String, track: String, timestamp: Int, album: String?, duration: Int?)
		async throws
	{
		try await submitListen(
			artist: artist,
			track: track,
			album: album,
			duration: duration,
			listenType: "single",
			timestamp: timestamp
		)
	}

	func updateNowPlaying(artist: String, track: String, album: String?, duration: Int?)
		async throws
	{
		try await submitListen(
			artist: artist,
			track: track,
			album: album,
			duration: duration,
			listenType: "playing_now",
			timestamp: nil
		)
	}

	// MARK: - Feedback

	func loveTrack(artist: String, track: String) async throws {
		guard let mbid = try await lookupRecordingMBID(artist: artist, track: track) else {
			throw ListenBrainzError.recordingNotFound
		}
		try await submitFeedback(recordingMBID: mbid, score: .love)
	}

	func unloveTrack(artist: String, track: String) async throws {
		guard let mbid = try await lookupRecordingMBID(artist: artist, track: track) else {
			throw ListenBrainzError.recordingNotFound
		}
		try await submitFeedback(recordingMBID: mbid, score: .none)
	}

	func isTrackLoved(artist: String, track: String) async -> Bool {
		guard let mbid = try? await lookupRecordingMBID(artist: artist, track: track) else {
			return false
		}
		let feedback = try? await getFeedback(recordingMBID: mbid)
		return feedback == .love
	}
    
    // MARK: - Tracks

    func fetchTopAlbums(period: TopAlbumPeriod, limit: Int = 9) async -> [ListenBrainzTopAlbum]? {
        guard let username = username else { return nil }

        let rangeParam = mapPeriodToRange(period)

        guard
            let url = URL(
                string: "\(baseURL)/1/stats/user/\(username)/release-groups?range=\(rangeParam)&count=\(limit)"
            )
        else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            // 204 means no statistics available yet
            if httpResponse.statusCode == 204 {
                return []
            }

            guard httpResponse.statusCode == 200 else {
                return nil
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let payload = json?["payload"] as? [String: Any]
            let releaseGroups = payload?["release_groups"] as? [[String: Any]]

            return releaseGroups?.compactMap { album -> ListenBrainzTopAlbum? in
                guard let releaseName = album["release_group_name"] as? String,
                      let artistName = album["artist_name"] as? String,
                      let listenCount = album["listen_count"] as? Int
                else {
                    return nil
                }

                return ListenBrainzTopAlbum(
                    releaseName: releaseName,
                    artistName: artistName,
                    listenCount: listenCount,
                    releaseGroupMbid: album["release_group_mbid"] as? String,
                    caaId: album["caa_id"] as? Int,
                    caaReleaseMbid: album["caa_release_mbid"] as? String
                )
            }
        } catch {
            print("Error fetching top albums from ListenBrainz: \(error)")
            return nil
        }
    }
    
	// MARK: - Private

	private func submitListen(
		artist: String,
		track: String,
		album: String?,
		duration: Int?,
		listenType: String,
		timestamp: Int?
	) async throws {
		guard let token = token else {
			throw ListenBrainzError.notAuthenticated
		}

		guard let url = URL(string: "\(baseURL)/1/submit-listens") else {
			throw ListenBrainzError.invalidURL
		}

		var trackMetadata: [String: Any] = [
			"artist_name": artist,
			"track_name": track,
		]

		if let album = album, !album.isEmpty {
			trackMetadata["release_name"] = album
		}

		if let duration = duration, duration > 0 {
			trackMetadata["additional_info"] = [
				"duration_ms": duration * 1000
			]
		}

		var listenData: [String: Any] = [
			"track_metadata": trackMetadata
		]

		if listenType == "single", let timestamp = timestamp {
			listenData["listened_at"] = timestamp
		}

		let payload: [String: Any] = [
			"listen_type": listenType,
			"payload": [listenData],
		]

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONSerialization.data(withJSONObject: payload)

		let (data, response) = try await session.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw ListenBrainzError.invalidResponse
		}

		switch httpResponse.statusCode {
		case 200...299:
			return
		case 401:
			throw ListenBrainzError.invalidToken
		case 429:
			throw ListenBrainzError.rateLimited
		default:
			let message = String(data: data, encoding: .utf8) ?? "Unknown error"
			throw ListenBrainzError.apiError(statusCode: httpResponse.statusCode, message: message)
		}
	}

	private func lookupRecordingMBID(artist: String, track: String) async throws -> String? {
		let query =
			"recording:\"\(track)\" AND artist:\"\(artist)\""
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

		guard
			let url = URL(
				string: "https://musicbrainz.org/ws/2/recording?query=\(query)&limit=1&fmt=json")
		else {
			return nil
		}

		let request = URLRequest(url: url)
		let (data, response) = try await session.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse,
			httpResponse.statusCode == 200
		else {
			return nil
		}

		let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		let recordings = json?["recordings"] as? [[String: Any]]

		return recordings?.first?["id"] as? String
	}

	private func getFeedback(recordingMBID: String) async throws -> FeedbackScore {
		guard let username = username else {
			throw ListenBrainzError.notAuthenticated
		}

		guard
			let url = URL(
				string:
					"\(baseURL)/1/feedback/user/\(username)/get-feedback-for-recording?recording_mbid=\(recordingMBID)"
			)
		else {
			throw ListenBrainzError.invalidURL
		}

		var request = URLRequest(url: url)
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		let (data, response) = try await session.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse,
			httpResponse.statusCode == 200
		else {
			throw ListenBrainzError.invalidResponse
		}

		let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		let feedback = json?["feedback"] as? [[String: Any]]

		if let first = feedback?.first, let score = first["score"] as? Int {
			return FeedbackScore(rawValue: score) ?? .none
		}

		return .none
	}

	private func submitFeedback(
		recordingMBID: String,
		score: FeedbackScore
	) async throws {
		guard let token = token else {
			throw ListenBrainzError.notAuthenticated
		}

		guard let url = URL(string: "\(baseURL)/1/feedback/recording-feedback") else {
			throw ListenBrainzError.invalidURL
		}

		let payload: [String: Any] = [
			"recording_mbid": recordingMBID,
			"score": score.rawValue,
		]

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONSerialization.data(withJSONObject: payload)

		let (data, response) = try await session.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw ListenBrainzError.invalidResponse
		}

		switch httpResponse.statusCode {
		case 200...299:
			return
		case 401:
			throw ListenBrainzError.invalidToken
		case 429:
			throw ListenBrainzError.rateLimited
		default:
			let message = String(data: data, encoding: .utf8) ?? "Unknown error"
			throw ListenBrainzError.apiError(
				statusCode: httpResponse.statusCode,
				message: message
			)
		}
	}
    
    private func mapPeriodToRange(_ period: TopAlbumPeriod) -> String {
        switch period {
        case .overall:
            return "all_time"
        case .week:
            return "week"
        case .month:
            return "month"
        case .quarter:
            return "quarter"
        case .halfYear:
            return "half_yearly"
        case .year:
            return "year"
        }
    }

}
