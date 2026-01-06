//
//  Music.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/30/25.
//

import AppKit

enum MusicSource: String, Codable {
	case appleMusic = "com.apple.Music"
	case spotify = "com.spotify.client"
	case tidal = "com.tidal.desktop"
	case amazonMusic = "com.amazon.music"
	case deezer = "com.deezer.deezer-desktop"
	case pandora = "com.pandora.desktop"
	case soundCloud = "com.soundcloud.desktop"
	case plex = "tv.plex.plexamp"
	case roon = "com.roon.Roon"
	case audirvana = "com.audirvana.Audirvana-Plus"
	case vox = "com.vox.vox"
	case hiFidelity = "vr.HiFidelity"
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
