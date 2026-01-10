//
//  ListenBrainzScrobblingService.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import Foundation

/// Service for submitting listens and now playing updates to ListenBrainz
final class ListenBrainzScrobblingService {
    private let config: ListenBrainzConfig
    
    init(config: ListenBrainzConfig) {
        self.config = config
    }
    
    // MARK: - Public Methods
    
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
    
    // MARK: - Private Implementation
    
    private func submitListen(
        artist: String,
        track: String,
        album: String?,
        duration: Int?,
        listenType: String,
        timestamp: Int?
    ) async throws {
        guard let token = config.token else {
            throw ListenBrainzError.notAuthenticated
        }

        guard let url = URL(string: "\(config.baseURL)/1/submit-listens") else {
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
            _ = try await config.http.postJSON(url: url, json: payload, headers: headers)
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == -1200 {
            print("ListenBrainz TLS Error: \(error)")
            throw ListenBrainzError.apiError(statusCode: -1200, message: "Secure connection failed. Please check your network connection.")
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
}
