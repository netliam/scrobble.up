import AppKit
import Foundation
import os.lock
import CryptoKit

final class ArtworkManager: @unchecked Sendable {
	
	// MARK: - Singleton
	
	static let shared = ArtworkManager()
	
	// MARK: - Cache Configuration
	
	private static let imageCacheSizeLimit = 20 * 1024 * 1024
	private static let imageCacheCountLimit = 100
	private static let urlCacheCountLimit = 150
	private static let artworkFetchTimeout: TimeInterval = 10.0
	private static let imageLoadTimeout: TimeInterval = 5.0
	
	// MARK: - Properties
	
	@MainActor
	private let imageCache = NSCache<NSString, NSImage>()
	@MainActor
	private let urlCache = NSCache<NSString, NSURL>()
	
	nonisolated(unsafe) private var notFoundCache = Set<String>()
	private let notFoundLock = OSAllocatedUnfairLock<Void>(initialState: ())
	
	nonisolated(unsafe) private var keyToHashMap: [String: String] = [:]
	private let hashMapLock = OSAllocatedUnfairLock<Void>(initialState: ())

	private init() {
		MainActor.assumeIsolated {
			imageCache.totalCostLimit = Self.imageCacheSizeLimit
			imageCache.countLimit = Self.imageCacheCountLimit
			urlCache.countLimit = Self.urlCacheCountLimit
		}
	}

	// MARK: - Public Methods
	
	@MainActor
	func getCachedArtwork(artist: String, track: String, album: String? = nil) -> NSImage? {
		let cacheKey = makeCacheKey(artist: artist, track: track, album: album)
		
		let isNotFound = notFoundLock.withLock {
			notFoundCache.contains(cacheKey)
		}
		
		if isNotFound {
			return nil
		}
		
		let imageHash = hashMapLock.withLock {
			keyToHashMap[cacheKey]
		}
		
		if let hash = imageHash {
			return imageCache.object(forKey: hash as NSString)
		}
		
		return imageCache.object(forKey: cacheKey as NSString)
	}

	func fetchArtwork(artist: String, track: String, album: String? = nil) async -> NSImage? {
		let cacheKey = makeCacheKey(artist: artist, track: track, album: album)
		
		let isNotFound = notFoundLock.withLock {
			notFoundCache.contains(cacheKey)
		}
		
		if isNotFound {
			return nil
		}
		
		let existingHash = hashMapLock.withLock {
			keyToHashMap[cacheKey]
		}
		
		if let hash = existingHash,
		   let cachedImage = getCachedImage(forKey: hash) {
			return cachedImage
		}
		
		if let cachedImage = getCachedImage(forKey: cacheKey) {
			return cachedImage
		}
		
		if let cachedURL = getCachedURL(forKey: cacheKey),
		   let image = await loadNSImage(from: cachedURL) {
			cacheImageWithHash(image, for: cacheKey)
			return image
		}
		
		let artworkSource = UserDefaults.standard.get(\.artworkSource)
		
		let artworkURL = await withTimeout(seconds: Self.artworkFetchTimeout) {
			await self.fetchArtworkURL(
				artist: artist,
				track: track,
				album: album,
				source: artworkSource
			)
		}
		
		guard let artworkURL = artworkURL else {
			_ = notFoundLock.withLock {
				notFoundCache.insert(cacheKey)
			}
			return nil
		}
		
		cacheURL(artworkURL, forKey: cacheKey)
		
		guard let image = await loadNSImage(from: artworkURL) else {
			return nil
		}
		
		cacheImageWithHash(image, for: cacheKey)
		
		return image
	}

	
	@MainActor
	func clearCache() {
		imageCache.removeAllObjects()
		urlCache.removeAllObjects()
		notFoundLock.withLock {
			notFoundCache.removeAll()
		}
		hashMapLock.withLock {
			keyToHashMap.removeAll()
		}
	}
	
	func cacheArtwork(_ image: NSImage, artist: String, track: String, album: String?) async {
		let cacheKey = makeCacheKey(artist: artist, track: track, album: album)
        cacheImageWithHash(image, for: cacheKey)
	}

	@MainActor
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
		async let primaryURL = fetchFromSource(source: source, artist: artist, track: track, album: album)
		
		if let album = album, !album.isEmpty {
			let fallbackSource: ArtworkSource = source == .lastFm ? .musicBrainz : .lastFm
			async let fallbackURL = fetchFromSource(source: fallbackSource, artist: artist, track: track, album: album)
			
			let primary = await primaryURL
			if let primary = primary {
				return primary
			}
			return await fallbackURL
		} else {
			return await primaryURL
		}
	}
	
	private func fetchFromSource(
		source: ArtworkSource,
		artist: String,
		track: String,
		album: String?
	) async -> URL? {
		switch source {
		case .lastFm:
			return await LastFmManager.shared.fetchArtworkURL(
				artist: artist,
				track: track,
				album: album
			)
		case .musicBrainz:
			return await ListenBrainzManager.shared.fetchArtworkURL(
				artist: artist,
				track: track,
				album: album
			)
		}
	}

	private func loadNSImage(from url: URL) async -> NSImage? {
		do {
			try Task.checkCancellation()
			
			var request = URLRequest(url: url)
			request.timeoutInterval = Self.imageLoadTimeout
			
			let (data, _) = try await URLSession.shared.data(for: request)
			try Task.checkCancellation()
			
			return await MainActor.run {
				NSImage(data: data)
			}
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
	
	private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T?) async -> T? {
		await withTaskGroup(of: T?.self) { group in
			group.addTask {
				await operation()
			}
			
			group.addTask {
				try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
				return nil
			}
			
			if let result = await group.next() {
				group.cancelAll()
				return result
			}
			return nil
		}
	}
	
	// MARK: - Hash-based Deduplication
	
	@MainActor
	private func cacheImageWithHash(_ image: NSImage, for cacheKey: String) {
		guard let tiffData = image.tiffRepresentation else {
			let cost = Int(image.size.width * image.size.height * 4)
			imageCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
			return
		}
		
		let hash = SHA256.hash(data: tiffData)
		let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
		
		if imageCache.object(forKey: hashString as NSString) == nil {
			let cost = Int(image.size.width * image.size.height * 4)
			imageCache.setObject(image, forKey: hashString as NSString, cost: cost)
		}
		
		hashMapLock.withLock {
			keyToHashMap[cacheKey] = hashString
		}
	}
	
	// MARK: - Cache Helpers
	
	@MainActor
	private func getCachedImage(forKey key: String) -> NSImage? {
		return imageCache.object(forKey: key as NSString)
	}
	
	@MainActor
	private func getCachedURL(forKey key: String) -> URL? {
		return urlCache.object(forKey: key as NSString) as URL?
	}
	
	@MainActor
	private func cacheURL(_ url: URL, forKey key: String) {
		urlCache.setObject(url as NSURL, forKey: key as NSString)
	}
}
