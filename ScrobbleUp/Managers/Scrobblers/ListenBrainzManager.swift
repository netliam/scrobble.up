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

    // MARK: - Convenience Methods (Maintain Backward Compatibility)
    
    // Authentication
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

    // Scrobbling
    func scrobble(artist: String, track: String, timestamp: Int, album: String?, duration: Int?) async throws {
        try await scrobbling.scrobble(artist: artist, track: track, timestamp: timestamp, album: album, duration: duration)
    }

    func updateNowPlaying(artist: String, track: String, album: String?, duration: Int?) async throws {
        try await scrobbling.updateNowPlaying(artist: artist, track: track, album: album, duration: duration)
    }

    // Feedback
    func loveTrack(artist: String, track: String) async throws {
        try await feedback.loveTrack(artist: artist, track: track)
    }

    func unloveTrack(artist: String, track: String) async throws {
        try await feedback.unloveTrack(artist: artist, track: track)
    }

    func isTrackLoved(artist: String, track: String) async -> Bool {
        await feedback.isTrackLoved(artist: artist, track: track)
    }
    
    // Artwork
    func fetchArtworkURL(artist: String, track: String, album: String?) async -> URL? {
        await artwork.fetchArtworkURL(artist: artist, track: track, album: album)
    }
    
    // Stats
    func fetchTopAlbums(period: TopAlbumPeriod, limit: Int = 9) async -> [ListenBrainzTopAlbum]? {
        await stats.fetchTopAlbums(period: period, limit: limit)
    }

    func fetchUserStats() async -> ListenBrainzUserStats? {
        await stats.fetchUserStats()
    }
}


