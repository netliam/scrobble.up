import AppKit

struct iTunesResponse: Codable {
	let results: [iTunesResult]
}

struct iTunesResult: Codable {
	let artworkUrl100: String
	let artistName: String
	let trackName: String
	let collectionName: String?
}

final class ArtworkManager {

	static let shared = ArtworkManager()

	private let imageCache = NSCache<NSString, NSImage>()
	private var activeRequests: [String: Task<NSImage?, Never>] = [:]
	private let actor = RequestActor()

	private enum CacheSize {
		case thumbnail
		case small
		case medium
		case large

		var size: CGSize {
			switch self {
			case .thumbnail: return CGSize(width: 64, height: 64)
			case .small: return CGSize(width: 80, height: 80)
			case .medium: return CGSize(width: 200, height: 200)
			case .large: return CGSize(width: 600, height: 600)
			}
		}

		var suffix: String {
			switch self {
			case .thumbnail: return ":thumb"
			case .small: return ":small"
			case .medium: return ":med"
			case .large: return ":large"
			}
		}
	}

	private actor RequestActor {
		var activeRequests: [String: Task<NSImage?, Never>] = [:]

		func getOrCreateTask(for key: String, task: @escaping () -> Task<NSImage?, Never>) -> Task<
			NSImage?, Never
		> {
			if let existing = activeRequests[key] {
				return existing
			}
			let newTask = task()
			activeRequests[key] = newTask
			return newTask
		}

		func removeTask(for key: String) {
			activeRequests.removeValue(forKey: key)
		}
	}

	private init() {
		imageCache.totalCostLimit = 30 * 1024 * 1024
		imageCache.countLimit = 100
	}

	func clearCache() {
		imageCache.removeAllObjects()
	}

	func placeholder() -> NSImage {
		let cacheKey = "placeholder" as NSString
		if let cached = imageCache.object(forKey: cacheKey) {
			return cached
		}

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

		imageCache.setObject(image, forKey: cacheKey, cost: Int(size.width * size.height * 4))
		return image
	}

	func fetchFromiTunes(artist: String, track: String, album: String? = nil) async -> NSImage? {
		return await fetchFromiTunes(artist: artist, track: track, album: album, size: .small)
	}

	private func fetchFromiTunes(
		artist: String,
		track: String,
		album: String? = nil,
		size: CacheSize
	) async -> NSImage? {
		let baseCacheKey = "\(artist)|\(track)"
		let cacheKey = (baseCacheKey + size.suffix) as NSString

		if let cached = imageCache.object(forKey: cacheKey) {
			return cached
		}

		if size != .large {
			let largeCacheKey = (baseCacheKey + CacheSize.large.suffix) as NSString
			if let largeImage = imageCache.object(forKey: largeCacheKey) {
				let resized = resizeImage(largeImage, to: size.size)
				let cost = Int(size.size.width * size.size.height * 4)
				imageCache.setObject(resized, forKey: cacheKey, cost: cost)
				return resized
			}
		}

		let task = await actor.getOrCreateTask(for: baseCacheKey) { [weak self] in
			Task {
				guard let self = self else { return nil }

				defer {
					Task {
						await self.actor.removeTask(for: baseCacheKey)
					}
				}

				return await self.performFetch(
					artist: artist,
					track: track,
					album: album,
					baseCacheKey: baseCacheKey,
					size: size
				)
			}
		}

		return await task.value
	}

	private func performFetch(
		artist: String,
		track: String,
		album: String?,
		baseCacheKey: String,
		size: CacheSize
	) async -> NSImage? {
		var searchTerms = [artist, track]
		if let album = album, !album.isEmpty {
			searchTerms.append(album)
		}

		let query =
			searchTerms.joined(separator: " ")
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

		let urlString =
			"https://itunes.apple.com/search?term=\(query)&media=music&entity=song&limit=10"

		guard let url = URL(string: urlString) else { return nil }

		do {
			try Task.checkCancellation()

			let (data, _) = try await URLSession.shared.data(from: url)

			try Task.checkCancellation()

			let response = try JSONDecoder().decode(iTunesResponse.self, from: data)

			let artworkURL = findBestMatch(
				results: response.results,
				artist: artist,
				track: track,
				album: album
			)

			if let artworkURL = artworkURL {
				let highResURL = artworkURL.replacingOccurrences(of: "100x100", with: "600x600")

				try Task.checkCancellation()

				if let fullImage = await loadNSImage(from: URL(string: highResURL)!) {
					let largeCacheKey = (baseCacheKey + CacheSize.large.suffix) as NSString
					imageCache.setObject(fullImage, forKey: largeCacheKey, cost: 600 * 600 * 4)

					let resized = resizeImage(fullImage, to: size.size)
					let cost = Int(size.size.width * size.size.height * 4)
					let sizedCacheKey = (baseCacheKey + size.suffix) as NSString
					imageCache.setObject(resized, forKey: sizedCacheKey, cost: cost)

					return resized
				}
			}
		} catch is CancellationError {
			return nil
		} catch {
			let nsError = error as NSError
			if nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled {
				print("iTunes API error: \(error)")
			}
		}

		return nil
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

	private func findBestMatch(
		results: [iTunesResult],
		artist: String,
		track: String,
		album: String?
	) -> String? {
		let normalizedArtist = artist.lowercased()
		let normalizedTrack = track.lowercased()
		let normalizedAlbum = album?.lowercased()

		var bestScore = 0
		var bestArtwork: String? = nil

		for result in results {
			var score = 0

			if result.artistName.lowercased().contains(normalizedArtist)
				|| normalizedArtist.contains(result.artistName.lowercased())
			{
				score += 10
			}

			if result.trackName.lowercased().contains(normalizedTrack)
				|| normalizedTrack.contains(result.trackName.lowercased())
			{
				score += 10
			}

			if let normalizedAlbum = normalizedAlbum,
				let resultAlbum = result.collectionName?.lowercased()
			{
				if resultAlbum.contains(normalizedAlbum) || normalizedAlbum.contains(resultAlbum) {
					score += 15
				}

				if resultAlbum.contains("greatest hits") || resultAlbum.contains("best of")
					|| resultAlbum.contains("compilation") || resultAlbum.contains("collection")
				{
					score -= 5
				}
			}

			if result.artistName.lowercased().contains("various") {
				score -= 10
			}

			if score > bestScore {
				bestScore = score
				bestArtwork = result.artworkUrl100
			}
		}

		return bestArtwork ?? results.first?.artworkUrl100
	}

	private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
		let newImage = NSImage(size: size)
		newImage.lockFocus()

		NSGraphicsContext.current?.imageInterpolation = .high

		image.draw(
			in: NSRect(origin: .zero, size: size),
			from: NSRect(origin: .zero, size: image.size),
			operation: .copy,
			fraction: 1.0
		)

		newImage.unlockFocus()
		return newImage
	}
}
