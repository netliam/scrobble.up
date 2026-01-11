//
//  TopAlbumsUpdater.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/6/26.
//

import AppKit
import LastFM

final class TopAlbumsUpdater {

	private let lastFmManager: LastFmManager = .shared
	private let listenBrainzManager: ListenBrainzManager = .shared

	func updateTopAlbumsGrid(
		_ gridView: TopAlbumsGridView, headerView: MenuItemHeaderView?, period: TopAlbumPeriod,
		service: ScrobblerService
	) {
		Task { @MainActor in
			headerView?.updateRightLabel(period.rawValue)

			let albumDataArray: [AlbumData]

			switch service {
			case .lastFm:
				albumDataArray = await fetchLastFmAlbums(period: period)
			case .listenBrainz:
				albumDataArray = await fetchListenBrainzAlbums(period: period)
			}

			if albumDataArray.isEmpty {
				gridView.reset()
			} else {
				gridView.configure(albums: albumDataArray)
			}
		}
	}

	// MARK: - Last.fm

	private func fetchLastFmAlbums(period: TopAlbumPeriod) async -> [AlbumData] {
		guard let topAlbums = await lastFmManager.fetchTopAlbums(period: period, limit: 9) else {
			return []
		}

		return topAlbums.map { album -> AlbumData in
			let artworkURL = bestImageURL(images: album.image)
			let playCount = formatPlayCount(Int(album.playcount))

			return AlbumData(
				artworkURL: artworkURL,
				title: album.name,
				artist: album.artist.name,
				playCount: playCount,
				action: { [weak self] in
					self?.handleAlbumClick(
						artist: album.artist.name, album: album.name, service: .lastFm)
				}
			)
		}
	}

	// MARK: - ListenBrainz

	private func fetchListenBrainzAlbums(period: TopAlbumPeriod) async -> [AlbumData] {
		guard let topAlbums = await listenBrainzManager.fetchTopAlbums(period: period, limit: 9)
		else {
			return []
		}

		return topAlbums.map { album -> AlbumData in
			let playCount = formatPlayCount(album.listenCount)

			return AlbumData(
				artworkURL: album.artworkURL,
				title: album.releaseName,
				artist: album.artistName,
				playCount: playCount,
				action: { [weak self] in
					self?.handleAlbumClick(
						artist: album.artistName, album: album.releaseName, service: .listenBrainz,
						mbid: album.releaseGroupMbid)
				}
			)
		}
	}

	// MARK: - Actions

	private func handleAlbumClick(
		artist: String, album: String, service: ScrobblerService, mbid: String? = nil
	) {
		Task {
			switch service {
			case .lastFm:
				await LinkManager.shared.openAlbum(artist: artist, album: album)
			case .listenBrainz:
				if let mbid = mbid {
					// Open MusicBrainz release group page
					if let url = URL(string: "https://musicbrainz.org/release-group/\(mbid)") {
						_ = await MainActor.run {
							NSWorkspace.shared.open(url)
						}
					}
				} else {
					// Fallback to Last.fm
					await LinkManager.shared.openAlbum(artist: artist, album: album)
				}
			}
		}
	}

	private func formatPlayCount(_ count: Int) -> String {
		if count >= 1000 {
			let thousands = Double(count) / 1000.0
			return String(format: "%.1fK plays", thousands)
		} else {
			return "\(count) plays"
		}
	}
}
