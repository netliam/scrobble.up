//
//  Utilities+CacheHelpers.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import AppKit

enum CacheHelpers {

	static func makeCacheKey(artist: String, track: String, album: String? = nil) -> String {
		if let album = album, !album.isEmpty {
			return "\(artist)|\(track)|\(album)".lowercased()
		}
		return "\(artist)|\(track)".lowercased()
	}

	static func makeCacheKey(for entry: LogEntry) -> String {
		return makeCacheKey(artist: entry.artist, track: entry.title, album: entry.album)
	}
}
// MARK: - Image Helpers

enum ImageHelpers {

	static let menuArtworkSize = NSSize(width: 32, height: 32)
	static let menuArtworkCornerRadius: CGFloat = 4

	static func styleForMenu(_ image: NSImage) -> NSImage {
		return image.styled(size: menuArtworkSize, cornerRadius: menuArtworkCornerRadius)
	}
}

// MARK: - URL Helpers

enum URLHelpers {

	static func encodeSearchQuery(_ terms: String...) -> String {
		let combined = terms.joined(separator: " ")
		return combined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
	}

	static func makeITunesSearchURL(query: String, entity: String, limit: Int = 1) -> URL? {
		let encodedQuery = encodeSearchQuery(query)
		return URL(
			string:
				"https://itunes.apple.com/search?term=\(encodedQuery)&entity=\(entity)&limit=\(limit)"
		)
	}
}

// MARK: - JSON Helpers

enum JSONHelpers {

	static func fetchJSON(from url: URL, timeout: TimeInterval = 10) async -> [String: Any]? {
		do {
			var request = URLRequest(url: url)
			request.timeoutInterval = timeout
			let (data, _) = try await URLSession.shared.data(for: request)
			return try JSONSerialization.jsonObject(with: data) as? [String: Any]
		} catch {
			print("JSON fetch error from \(url): \(error)")
			return nil
		}
	}

	static func extractValue<T>(_ json: [String: Any]?, keys: String...) -> T? {
		guard let json = json else { return nil }
		var current: Any? = json

		for key in keys {
			guard let dict = current as? [String: Any] else { return nil }
			current = dict[key]
		}

		return current as? T
	}
}

// MARK: - String Helpers

extension String {
	var isNotEmpty: Bool {
		!isEmpty
	}
}
