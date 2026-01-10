//
//  MusicBrainzService.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import Foundation

actor MusicBrainzRateLimiter {
    static let shared = MusicBrainzRateLimiter()
    
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval = 1.0
    
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

/// Service for interacting with MusicBrainz API
actor MusicBrainzService {
    private let http: HTTPHelper
    private var mbidCache: [String: String] = [:]
    
    init(http: HTTPHelper) {
        self.http = http
    }
    
    // MARK: - MBID Lookup
    
    func lookupRecordingMBID(artist: String, track: String) async throws -> String? {
        let cacheKey = "\(artist.lowercased()):\(track.lowercased())"
        
        if let cachedMBID = mbidCache[cacheKey] {
            return cachedMBID
        }
        
        await MusicBrainzRateLimiter.shared.waitIfNeeded()
        
        let cleanTrack = cleanSearchString(track)
        let cleanArtist = cleanSearchString(artist)
        
        if let mbid = try await searchMusicBrainz(
            query: "recording:\"\(cleanTrack)\" AND artist:\"\(cleanArtist)\""
        ) {
            mbidCache[cacheKey] = mbid
            return mbid
        }
        
        // Try without quotes
        await MusicBrainzRateLimiter.shared.waitIfNeeded()
        if let mbid = try await searchMusicBrainz(
            query: "recording:\(cleanTrack) AND artist:\(cleanArtist)"
        ) {
            mbidCache[cacheKey] = mbid
            return mbid
        }
        
        // Try simple search
        await MusicBrainzRateLimiter.shared.waitIfNeeded()
        if let mbid = try await searchMusicBrainz(
            query: "\(cleanTrack) \(cleanArtist)"
        ) {
            mbidCache[cacheKey] = mbid
            return mbid
        }
        
        return nil
    }
    
    // MARK: - Recording Info
    
    func fetchRecordingReleases(mbid: String) async throws -> [[String: Any]]? {
        await MusicBrainzRateLimiter.shared.waitIfNeeded()
        
        guard let recordingURL = URL(string: "https://musicbrainz.org/ws/2/recording/\(mbid)?inc=releases&fmt=json") else {
            return nil
        }
        
        do {
            let json = try await http.getJSON(url: recordingURL, headers: nil)
            return json["releases"] as? [[String: Any]]
        } catch {
            if case HTTPError.httpError(let statusCode, _) = error, statusCode != 503 {
                print("Error fetching recording info from MusicBrainz: \(error)")
            }
            return nil
        }
    }
    
    // MARK: - Album Search
    
    func searchRelease(artist: String, album: String) async throws -> String? {
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
            return releases?.first?["id"] as? String
        } catch {
            if case HTTPError.httpError(let statusCode, _) = error, statusCode != 503 {
                print("Error fetching album from MusicBrainz: \(error)")
            }
            return nil
        }
    }
    
    // MARK: - Private Helpers
    
    private func searchMusicBrainz(query: String) async throws -> String? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://musicbrainz.org/ws/2/recording?query=\(encodedQuery)&limit=5&fmt=json")
        else {
            print("Invalid MusicBrainz URL for query: \(query)")
            return nil
        }

        print("MusicBrainz search: \(query)")
        
        do {
            let json = try await http.getJSON(url: url, headers: nil)
            guard let recordings = json["recordings"] as? [[String: Any]], !recordings.isEmpty else {
                print("   ℹ️ No results found")
                return nil
            }
            
            if let mbid = recordings.first?["id"] as? String {
                print("Found MBID: \(mbid)")
                if let title = recordings.first?["title"] as? String {
                    print(" Recording title: \(title)")
                }
                return mbid
            }
            return nil
        } catch {
            if case HTTPError.httpError(let statusCode, _) = error, statusCode != 503 {
                print("MusicBrainz search error: \(error)")
            } else if case HTTPError.httpError(503, _) = error {
                print("MusicBrainz temporarily unavailable (503)")
            }
            return nil
        }
    }
    
    private func cleanSearchString(_ string: String) -> String {
        var cleaned = string
        
        // Remove featuring artists
        let featuringPatterns = ["(feat.", "(ft.", "feat.", "ft.", "featuring"]
        for pattern in featuringPatterns {
            if let range = cleaned.range(of: pattern, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
        // Remove version suffixes
        let suffixPatterns = ["- Remaster", "- Remastered", "(Remaster)", "(Remastered)",
                             "- Live", "(Live)", "- Explicit", "(Explicit)",
                             "- Radio Edit", "(Radio Edit)", "- Single Version", "(Single Version)"]
        for pattern in suffixPatterns {
            if let range = cleaned.range(of: pattern, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
        // Escape special characters
        let specialChars = ["\\", "+", "-", "&&", "||", "!", "(", ")", "{", "}", "[", "]",
                           "^", "~", "*", "?", ":", "/"]
        for char in specialChars {
            cleaned = cleaned.replacingOccurrences(of: char, with: " ")
        }
        
        // Clean up whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        return cleaned
    }
}
