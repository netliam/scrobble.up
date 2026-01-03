//
//  Music.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/30/25.
//

import AppKit

enum MusicSource: String, Codable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case other = "Other"
}

enum MusicState: String, Codable, Equatable {
    case playing = "playing"
    case paused = "paused"
    case stopped = "stopped"
}

struct MusicInfo {
    let state: MusicState?
    let title: String?
    let artist: String?
    let album: String?
    let duration: Int?
    let source: MusicSource?
    let artwork: NSImage?
    let timestamp: Date = Date()

    init(
        state: MusicState?,
        title: String?,
        artist: String?,
        album: String?,
        duration: Int?,
        source: MusicSource?,
        artwork: NSImage? = nil
    ) {
        self.state = state
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.source = source
        self.artwork = artwork
    }
}
