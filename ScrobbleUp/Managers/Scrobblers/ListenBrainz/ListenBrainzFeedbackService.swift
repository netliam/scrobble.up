//
//  ListenBrainzFeedbackService.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import Foundation

/// Service for managing track feedback (love/unlove) on ListenBrainz
final class ListenBrainzFeedbackService {
    private let config: ListenBrainzConfig
    
    init(config: ListenBrainzConfig) {
        self.config = config
    }
    
    // MARK: - Public Methods
    
    func loveTrack(artist: String, track: String) async throws {
        print("Attempting to love track: \"\(track)\" by \"\(artist)\"")
        guard let mbid = try await config.musicBrainz.lookupRecordingMBID(artist: artist, track: track) else {
            print("Could not find MusicBrainz ID for: \"\(track)\" by \"\(artist)\"")
            throw ListenBrainzError.recordingNotFound
        }
        print("Found MBID: \(mbid)")
        try await submitFeedback(recordingMBID: mbid, score: .love)
        print("Successfully loved track")
    }

    func unloveTrack(artist: String, track: String) async throws {
        print("Attempting to unlove track: \"\(track)\" by \"\(artist)\"")
        guard let mbid = try await config.musicBrainz.lookupRecordingMBID(artist: artist, track: track) else {
            print("Could not find MusicBrainz ID for: \"\(track)\" by \"\(artist)\"")
            throw ListenBrainzError.recordingNotFound
        }
        print("Found MBID: \(mbid)")
        try await submitFeedback(recordingMBID: mbid, score: .none)
        print("Successfully unloved track")
    }

    func isTrackLoved(artist: String, track: String) async -> Bool {
        guard let mbid = try? await config.musicBrainz.lookupRecordingMBID(artist: artist, track: track) else {
            return false
        }
        let feedback = try? await getFeedback(recordingMBID: mbid)
        return feedback == .love
    }
    
    // MARK: - Private Implementation
    
    private func getFeedback(recordingMBID: String) async throws -> FeedbackScore {
        guard let username = config.username else {
            throw ListenBrainzError.notAuthenticated
        }

        guard
            let url = URL(
                string:
                    "\(config.baseURL)/1/feedback/user/\(username)/get-feedback-for-recording?recording_mbid=\(recordingMBID)"
            )
        else {
            throw ListenBrainzError.invalidURL
        }

        do {
            let json = try await config.http.getJSON(url: url, headers: nil)
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
        guard let token = config.token else {
            throw ListenBrainzError.notAuthenticated
        }

        guard let url = URL(string: "\(config.baseURL)/1/feedback/recording-feedback") else {
            throw ListenBrainzError.invalidURL
        }

        let payload: [String: Any] = [
            "recording_mbid": recordingMBID,
            "score": score.rawValue,
        ]

        let headers = ["Authorization": "Token \(token)"]

        do {
            _ = try await config.http.postJSON(url: url, json: payload, headers: headers)
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
