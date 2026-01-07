import AppKit
import Foundation
import os.lock

final class ArtworkManager {

	static let shared = ArtworkManager()

	private let imageCache = NSCache<NSString, NSImage>()
	private let urlCache = NSCache<NSString, NSURL>()
	private var notFoundCache = Set<String>() // Cache tracks with no artwork
	private let notFoundLock = OSAllocatedUnfairLock<Void>(initialState: ())

	private init() {
		imageCache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
		imageCache.countLimit = 100
		urlCache.countLimit = 200
	}

	// MARK: - Public Methods

	func fetchArtwork(artist: String, track: String, album: String? = nil) async -> NSImage? {
		let cacheKey = makeCacheKey(artist: artist, track: track, album: album)
		
		let isNotFound = notFoundLock.withLock {
			notFoundCache.contains(cacheKey)
		}
		
		if isNotFound {
			return nil
		}
		
		if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
			return cachedImage
		}
		
		if let cachedURL = urlCache.object(forKey: cacheKey as NSString) as URL? {
			if let image = await loadNSImage(from: cachedURL) {
				let cost = Int(image.size.width * image.size.height * 4)
				imageCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
				return image
			}
		}
		
		let artworkSource = UserDefaults.standard.get(\.artworkSource)
		let artworkURL = await fetchArtworkURL(
			artist: artist,
			track: track,
			album: album,
			source: artworkSource
		)
		
		guard let artworkURL = artworkURL else {
			notFoundLock.withLock {
				notFoundCache.insert(cacheKey)
			}
			print("No artwork URL found for: \(artist) - \(track)" + (album.map { " (\($0))" } ?? ""))
			return nil
		}
		
		urlCache.setObject(artworkURL as NSURL, forKey: cacheKey as NSString)
		
		guard let image = await loadNSImage(from: artworkURL) else {
			return nil
		}
		
		let cost = Int(image.size.width * image.size.height * 4)
		imageCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
		
		return image
	}

	
	func clearCache() {
		imageCache.removeAllObjects()
		urlCache.removeAllObjects()
		notFoundLock.withLock {
			notFoundCache.removeAll()
		}
	}
	
	func cacheArtwork(_ image: NSImage, artist: String, track: String, album: String?) {
		let cacheKey = makeCacheKey(artist: artist, track: track, album: album)
		let cost = Int(image.size.width * image.size.height * 4) // Approximate byte size
		imageCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
	}

	func placeholder() -> NSImage {
		let size = NSSize(width: 64, height: 64)
		let image = NSImage(size: size)
		image.lockFocus()
		NSColor(calibratedRed: 0.2, green: 0.25, blue: 0.5, alpha: 1).setFill()
		NSRect(origin: .zero, size: size).fill()
		let attrs: [NSAttributedString.Key: Any] = [
			.font: NSFont.systemFont(ofSize: 24, weight: .bold),
			.foregroundColor: NSColor.white.withAlphaComponent(0.8),
		]
		let str = NSAttributedString(string: "♪", attributes: attrs)
		str.draw(at: NSPoint(x: 22, y: 16))
		image.unlockFocus()
		return image
	}

	// MARK: - Private Methods
	
	private func makeCacheKey(artist: String, track: String, album: String?) -> String {
		if let album = album, !album.isEmpty {
			return "\(artist)|\(track)|\(album)".lowercased()
		}
		return "\(artist)|\(track)".lowercased()
	}

	private func fetchArtworkURL(
		artist: String,
		track: String,
		album: String?,
		source: ArtworkSource
	) async -> URL? {
		let primaryURL: URL?
		switch source {
		case .lastFm:
			primaryURL = await LastFmManager.shared.fetchArtworkURL(
				artist: artist,
				track: track,
				album: album
			)
		case .musicBrainz:
			primaryURL = await ListenBrainzManager.shared.fetchArtworkURL(
				artist: artist,
				track: track,
				album: album
			)
		}
		
		if let primaryURL = primaryURL {
			return primaryURL
		}
		
		guard album != nil && !album!.isEmpty else {
			return nil
		}
		
		switch source {
		case .lastFm:
			return await ListenBrainzManager.shared.fetchArtworkURL(
				artist: artist,
				track: track,
				album: album
			)
		case .musicBrainz:
			return await LastFmManager.shared.fetchArtworkURL(
				artist: artist,
				track: track,
				album: album
			)
		}
	}

	private func loadNSImage(from url: URL) async -> NSImage? {
		do {
			try Task.checkCancellation()
			let (data, _) = try await URLSession.shared.data(from: url)
			try Task.checkCancellation()
			return NSImage(data: data)
		} catch is CancellationError {
			return nil
		} catch {
			let nsError = error as NSError
			if nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled {
				print("Image load error: \(error)")
			}
			return nil
		}
	}
}
