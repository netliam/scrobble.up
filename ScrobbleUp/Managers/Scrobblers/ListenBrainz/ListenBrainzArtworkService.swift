//
//  ListenBrainzArtworkService.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import Foundation

/// Service for fetching album artwork from Cover Art Archive
final class ListenBrainzArtworkService {
    private let config: ListenBrainzConfig
    
    init(config: ListenBrainzConfig) {
        self.config = config
    }
    
    // MARK: - Public Methods
    
    func fetchArtworkURL(artist: String, track: String, album: String?) async -> URL? {
        if let album = album, !album.isEmpty {
            if let artworkURL = await fetchAlbumArtworkURL(artist: artist, album: album) {
                return artworkURL
            }
        }
        
        guard let mbid = try? await config.musicBrainz.lookupRecordingMBID(artist: artist, track: track) else {
            return nil
        }
        
        guard let releases = try? await config.musicBrainz.fetchRecordingReleases(mbid: mbid) else {
            return nil
        }
        
        let releaseIds = releases.prefix(3).compactMap { $0["id"] as? String }
        
        for releaseId in releaseIds {
            if let artworkURL = await fetchCoverArtURL(releaseId: releaseId) {
                return artworkURL
            }
        }
        
        return nil
    }
    
    // MARK: - Private Implementation
    
    private func fetchAlbumArtworkURL(artist: String, album: String) async -> URL? {
        guard let releaseId = try? await config.musicBrainz.searchRelease(artist: artist, album: album) else {
            return nil
        }
        
        return await fetchCoverArtURL(releaseId: releaseId)
    }
    
    private func fetchCoverArtURL(releaseId: String) async -> URL? {
        guard let url = URL(string: "https://coverartarchive.org/release/\(releaseId)") else {
            return nil
        }
        
        do {
            let json = try await config.http.getJSON(url: url, headers: nil)
            let images = json["images"] as? [[String: Any]]
            
            if let frontCover = images?.first(where: { image in
                let types = image["types"] as? [String]
                return types?.contains("Front") ?? false
            }), let imageURL = frontCover["image"] as? String {
                let secureURL = imageURL.replacingOccurrences(of: "http://", with: "https://")
                return URL(string: secureURL)
            }
            
            if let firstImage = images?.first, let imageURL = firstImage["image"] as? String {
                let secureURL = imageURL.replacingOccurrences(of: "http://", with: "https://")
                return URL(string: secureURL)
            }
        } catch {
            return nil
        }
        
        return nil
    }
}
