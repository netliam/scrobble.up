//
//  ListenBrainzManager.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Combine
import Foundation

// Rate limiter for MusicBrainz API (1 request per second)
actor MusicBrainzRateLimiter {
    static let shared = MusicBrainzRateLimiter()
    
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval = 1.0 // MusicBrainz requires 1 req/sec
    
    func waitIfNeeded() async {
        if let lastRequest = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastRequest)
            if elapsed < minimumInterval {
                let delay = minimumInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
}

final class ListenBrainzManager: ObservableObject {

    private static let userAgent = "scrobble.up/1.0 (liams@tuskmo.com)"

    private lazy var http: HTTPHelper = {
        HTTPHelper(userAgent: Self.userAgent)
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

        let headers = ["Authorization": "Token \(token)"]

        do {
            let json = try await http.getJSON(url: requestURL, headers: headers)

            guard let valid = json["valid"] as? Bool, valid,
                let username = json["user_name"] as? String
            else {
                throw ListenBrainzError.invalidToken
            }

            self.token = token
            return username
        } catch HTTPError.unauthorized {
            throw ListenBrainzError.invalidToken
        } catch let error as ListenBrainzError {
            throw error
        } catch {
            throw ListenBrainzError.invalidToken
        }
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
    
    // MARK: - Artwork

    func fetchArtworkURL(artist: String, track: String, album: String?) async -> URL? {
        // Try to get recording MBID first
        guard let mbid = try? await lookupRecordingMBID(artist: artist, track: track) else {
            // If no recording found, try album artwork
            if let album = album, !album.isEmpty {
                return await fetchAlbumArtworkURL(artist: artist, album: album)
            }
            return nil
        }
        
        // Rate limit before making request
        await MusicBrainzRateLimiter.shared.waitIfNeeded()
        
        // Fetch recording info from MusicBrainz to get release info
        guard let recordingURL = URL(string: "https://musicbrainz.org/ws/2/recording/\(mbid)?inc=releases&fmt=json") else {
            return nil
        }
        
        do {
            let json = try await http.getJSON(url: recordingURL, headers: nil)
            
            // Get the first release that has cover art
            if let releases = json["releases"] as? [[String: Any]] {
                for release in releases {
                    if let releaseId = release["id"] as? String {
                        // Check if cover art exists via Cover Art Archive
                        if let artworkURL = await fetchCoverArtURL(releaseId: releaseId) {
                            return artworkURL
                        }
                    }
                }
            }
        } catch {
            // Only log non-503 errors (503 is expected when rate limited)
            if case HTTPError.httpError(let statusCode, _) = error, statusCode != 503 {
                print("Error fetching recording info from MusicBrainz: \(error)")
            }
        }
        
        // Fallback to album artwork if available
        if let album = album, !album.isEmpty {
            return await fetchAlbumArtworkURL(artist: artist, album: album)
        }
        
        return nil
    }
    
    private func fetchAlbumArtworkURL(artist: String, album: String) async -> URL? {
        await MusicBrainzRateLimiter.shared.waitIfNeeded()
        
        let query =
            "release:\"\(album)\" AND artist:\"\(artist)\""
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "https://musicbrainz.org/ws/2/release?query=\(query)&limit=1&fmt=json") else {
            return nil
        }
        
        do {
            let json = try await http.getJSON(url: url, headers: nil)
            let releases = json["releases"] as? [[String: Any]]
            
            if let releaseId = releases?.first?["id"] as? String {
                return await fetchCoverArtURL(releaseId: releaseId)
            }
        } catch {
            // Only log non-503 errors
            if case HTTPError.httpError(let statusCode, _) = error, statusCode != 503 {
                print("Error fetching album from MusicBrainz: \(error)")
            }
        }
        
        return nil
    }
    
    private func fetchCoverArtURL(releaseId: String) async -> URL? {
        guard let url = URL(string: "https://coverartarchive.org/release/\(releaseId)") else {
            return nil
        }
        
        do {
            let json = try await http.getJSON(url: url, headers: nil)
            let images = json["images"] as? [[String: Any]]
            
            // Prefer front cover
            if let frontCover = images?.first(where: { image in
                let types = image["types"] as? [String]
                return types?.contains("Front") ?? false
            }), let imageURL = frontCover["image"] as? String {
                // Force HTTPS for image URLs (CoverArtArchive returns HTTP by default)
                let secureURL = imageURL.replacingOccurrences(of: "http://", with: "https://")
                return URL(string: secureURL)
            }
            
            // Fallback to first available image
            if let firstImage = images?.first, let imageURL = firstImage["image"] as? String {
                // Force HTTPS for image URLs (CoverArtArchive returns HTTP by default)
                let secureURL = imageURL.replacingOccurrences(of: "http://", with: "https://")
                return URL(string: secureURL)
            }
        } catch {
            // Cover art not available for this release
            return nil
        }
        
        return nil
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

        do {
            let (data, response) = try await http.getRaw(url: url, headers: nil)

            if response.statusCode == 204 {
                return []
            }

            guard response.statusCode == 200 else {
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
    
    // MARK: - User Stats

    func fetchUserStats() async -> ListenBrainzUserStats? {
        guard let username = username else { return nil }

        async let listenCountTask = fetchListenCount(username: username)
        async let lovedTracksCountTask = fetchLovedTracksCount(username: username)

        let listenCount = await listenCountTask
        let lovedTracksCount = await lovedTracksCountTask

        return ListenBrainzUserStats(
            listenCount: listenCount ?? 0,
            lovedTracksCount: lovedTracksCount ?? 0
        )
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

        let headers = ["Authorization": "Token \(token)"]

        do {
            _ = try await http.postJSON(url: url, json: payload, headers: headers)
        } catch HTTPError.unauthorized {
            throw ListenBrainzError.invalidToken
        } catch HTTPError.rateLimited {
            throw ListenBrainzError.rateLimited
        } catch HTTPError.httpError(let statusCode, let message) {
            throw ListenBrainzError.apiError(statusCode: statusCode, message: message)
        } catch {
            throw ListenBrainzError.invalidResponse
        }
    }

    private func lookupRecordingMBID(artist: String, track: String) async throws -> String? {
        await MusicBrainzRateLimiter.shared.waitIfNeeded()
        
        let query =
            "recording:\"\(track)\" AND artist:\"\(artist)\""
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard
            let url = URL(
                string: "https://musicbrainz.org/ws/2/recording?query=\(query)&limit=1&fmt=json")
        else {
            return nil
        }

        do {
            let json = try await http.getJSON(url: url, headers: nil)
            let recordings = json["recordings"] as? [[String: Any]]
            return recordings?.first?["id"] as? String
        } catch {
            // Don't log 503 errors (rate limiting is expected)
            if case HTTPError.httpError(let statusCode, _) = error, statusCode == 503 {
                return nil
            }
            return nil
        }
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

        do {
            let json = try await http.getJSON(url: url, headers: nil)
            let feedback = json["feedback"] as? [[String: Any]]

            if let first = feedback?.first, let score = first["score"] as? Int {
                return FeedbackScore(rawValue: score) ?? .none
            }

            return .none
        } catch {
            throw ListenBrainzError.invalidResponse
        }
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

        let headers = ["Authorization": "Token \(token)"]

        do {
            _ = try await http.postJSON(url: url, json: payload, headers: headers)
        } catch HTTPError.unauthorized {
            throw ListenBrainzError.invalidToken
        } catch HTTPError.rateLimited {
            throw ListenBrainzError.rateLimited
        } catch HTTPError.httpError(let statusCode, let message) {
            throw ListenBrainzError.apiError(statusCode: statusCode, message: message)
        } catch {
            throw ListenBrainzError.invalidResponse
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
    
    private func fetchListenCount(username: String) async -> UInt? {
        guard let url = URL(string: "\(baseURL)/1/user/\(username)/listen-count") else {
            return nil
        }

        do {
            let json = try await http.getJSON(url: url, headers: nil)
            let payload = json["payload"] as? [String: Any]
            if let count = payload?["count"] as? Int {
                return UInt(count)
            }
            return nil
        } catch {
            print("Error fetching listen count from ListenBrainz: \(error)")
            return nil
        }
    }

    private func fetchLovedTracksCount(username: String) async -> UInt? {
        guard let url = URL(string: "\(baseURL)/1/feedback/user/\(username)/get-feedback?score=1&count=0") else {
            return nil
        }

        do {
            let json = try await http.getJSON(url: url, headers: nil)
            if let totalCount = json["total_count"] as? Int {
                return UInt(totalCount)
            }
            return nil
        } catch {
            print("Error fetching loved tracks count from ListenBrainz: \(error)")
            return nil
        }
    }
}
