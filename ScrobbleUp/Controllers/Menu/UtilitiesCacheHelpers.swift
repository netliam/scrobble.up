//
//  CacheHelpers.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import AppKit

/// Provides centralized helper functions for cache key generation and other common caching utilities
enum CacheHelpers {
	
	/// Creates a normalized cache key for a track with artist, title, and optional album
	/// - Parameters:
	///   - artist: The artist name
	///   - track: The track title
	///   - album: Optional album name
	/// - Returns: A lowercase, pipe-separated cache key string
	static func makeCacheKey(artist: String, track: String, album: String? = nil) -> String {
		if let album = album, !album.isEmpty {
			return "\(artist)|\(track)|\(album)".lowercased()
		}
		return "\(artist)|\(track)".lowercased()
	}
	
	/// Creates a normalized cache key from a LogEntry
	/// - Parameter entry: The log entry to create a cache key for
	/// - Returns: A lowercase, pipe-separated cache key string
	static func makeCacheKey(for entry: LogEntry) -> String {
		return makeCacheKey(artist: entry.artist, track: entry.title, album: entry.album)
	}
}
// MARK: - Image Helpers

enum ImageHelpers {
	
	/// Standard artwork size for menu items (32x32 with 4pt corner radius)
	static let menuArtworkSize = NSSize(width: 32, height: 32)
	static let menuArtworkCornerRadius: CGFloat = 4
	
	/// Creates a styled image for use in menu items with standard dimensions
	/// - Parameter image: The source image to style
	/// - Returns: A styled image with standard menu dimensions
	static func styleForMenu(_ image: NSImage) -> NSImage {
		return image.styled(size: menuArtworkSize, cornerRadius: menuArtworkCornerRadius)
	}
}

// MARK: - URL Helpers

enum URLHelpers {
	
	/// Safely creates a URL-encoded search query
	/// - Parameter terms: The search terms to encode
	/// - Returns: URL-encoded string, or empty string if encoding fails
	static func encodeSearchQuery(_ terms: String...) -> String {
		let combined = terms.joined(separator: " ")
		return combined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
	}
	
	/// Creates an iTunes Search API URL
	/// - Parameters:
	///   - query: The search query
	///   - entity: The entity type (song, album, artist, etc.)
	///   - limit: Maximum number of results
	/// - Returns: The constructed URL, or nil if invalid
	static func makeITunesSearchURL(query: String, entity: String, limit: Int = 1) -> URL? {
		let encodedQuery = encodeSearchQuery(query)
		return URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&entity=\(entity)&limit=\(limit)")
	}
}

// MARK: - JSON Helpers

enum JSONHelpers {
	
	/// Fetches and decodes JSON from a URL
	/// - Parameters:
	///   - url: The URL to fetch from
	///   - timeout: Request timeout interval (default: 10 seconds)
	/// - Returns: Decoded JSON as a dictionary, or nil if request fails
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
	
	/// Extracts a nested value from JSON
	/// - Parameters:
	///   - json: The JSON dictionary
	///   - keys: Sequence of keys to traverse
	/// - Returns: The value if found and type matches, or nil
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

