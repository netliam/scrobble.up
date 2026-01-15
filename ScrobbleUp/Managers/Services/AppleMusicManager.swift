//
//  AppleMusicManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/27/25.
//

import AppKit
import Combine
import Foundation
import MusicKit
import MusadoraKit

@MainActor
final class AppleMusicManager: ObservableObject {
    static let shared = AppleMusicManager()
    
    private init() {}
    private var observer: NSObjectProtocol?
    
    private var cachedSong: Song?
    private var cachedTrackKey: String?
    
    var isAuthorized: Bool {
        MusicAuthorization.currentStatus == .authorized
    }
    
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }
    
    func ensureAuthorization() async -> Bool {
        if isAuthorized {
            return true
        }
        return await requestAuthorization()
    }
    
    // MARK: - Now Playing Notifications
    
    func start(handler: @escaping (MusicInfo) -> Void) {
        stop()
        observer = DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                let info = note.userInfo ?? [:]
                let stateString = info["Player State"] as? String ?? ""
                let name = info["Name"] as? String
                let artist = info["Artist"] as? String
                let album = info["Album"] as? String
                let durationMs = info["Total Time"] as? Int
                
                let musicState: MusicState? = switch stateString {
                    case "Playing": .playing
                    case "Paused": .paused
                    case "Stopped": .stopped
                    default: nil
                }
                
                let musicInfo = MusicInfo(
                    state: musicState,
                    title: name,
                    artist: artist,
                    album: album,
                    duration: durationMs,
                    source: .appleMusic
                )
                
                // Prefetch song in background
                if let title = name, let artist = artist, !title.isEmpty {
                    await self.prefetchSong(title: title, artist: artist, album: album)
                }
                
                handler(musicInfo)
            }
        }
    }
    
    func stop() {
        if let obs = observer {
            DistributedNotificationCenter.default.removeObserver(obs)
            observer = nil
        }
    }
    
    // MARK: - Prefetching
    
    private func prefetchSong(title: String, artist: String, album: String?) async {
        let key = "\(artist.lowercased())|\(title.lowercased())"
        
        guard key != cachedTrackKey else { return }
        
        guard let song = await findSong(title: title, artist: artist, album: album) else {
            return
        }
        
        cachedSong = song
        cachedTrackKey = key
    }
    
    func clearCache() {
        cachedSong = nil
        cachedTrackKey = nil
    }
    
    // MARK: - Favorites
    
    func setFavorite(_ favorite: Bool, track: AppState.CurrentTrack) async -> Bool {
        guard isAuthorized,
              !track.title.isEmpty,
              track.title != "-" else {
            return false
        }
        
        let key = "\(track.artist.lowercased())|\(track.title.lowercased())"
        
        let song: Song?
        if key == cachedTrackKey, let cached = cachedSong {
            song = cached
        } else {
            song = await findSong(title: track.title, artist: track.artist, album: track.album)
            if let song {
                cachedSong = song
                cachedTrackKey = key
            }
        }
        
        guard let song else {
            print("Could not find song: \(track.title) by \(track.artist)")
            return false
        }
        
        return await setFavorite(favorite, for: song)
    }
    
    func setFavorite(_ favorite: Bool, for song: Song) async -> Bool {
        do {
            if favorite {
                _ = try await MCatalog.addRating(for: song, rating: .like)
            } else {
                _ = try await MCatalog.deleteRating(for: song)
            }
            return true
        } catch {
            print("Failed to set favorite: \(error)")
            return false
        }
    }
    
    func currentFavoriteState(track: AppState.CurrentTrack) async -> Bool? {
        guard isAuthorized,
              !track.title.isEmpty,
              track.title != "-" else {
            return nil
        }
        
        let key = "\(track.artist.lowercased())|\(track.title.lowercased())"
        
        let song: Song?
        if key == cachedTrackKey, let cached = cachedSong {
            song = cached
        } else {
            song = await findSong(title: track.title, artist: track.artist, album: track.album)
            if let foundSong = song {
                cachedSong = foundSong
                cachedTrackKey = key
            }
        }
        
        guard let song else { return nil }
        return await getFavoriteState(for: song)
    }
    
    func getFavoriteState(for song: Song) async -> Bool? {
        do {
            let rating = try await MCatalog.getRating(for: song)
            return rating.value == .like
        } catch {
            return false
        }
    }
    
    // MARK: - Search
    
    private func findSong(title: String, artist: String, album: String?) async -> Song? {
        do {
            let searchResponse = try await MCatalog.search(
                for: "\(title) \(artist)",
                types: [.songs],
                limit: 5
            )
            
            return searchResponse.songs.first { song in
                let titleMatch = song.title.localizedCaseInsensitiveCompare(title) == .orderedSame
                let artistMatch = song.artistName.localizedCaseInsensitiveCompare(artist) == .orderedSame
                let albumMatch = album == nil || song.albumTitle?.localizedCaseInsensitiveCompare(album!) == .orderedSame
                return titleMatch && artistMatch && albumMatch
            } ?? searchResponse.songs.first
        } catch {
            print("Search failed: \(error)")
            return nil
        }
    }
}
