//
//  ListenBrainz.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Foundation

enum ListenBrainzError: LocalizedError {
	case invalidURL
	case invalidToken
	case notAuthenticated
	case invalidResponse
	case rateLimited
	case networkError
	case recordingNotFound
	case apiError(statusCode: Int, message: String)

	var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "Invalid ListenBrainz URL"
		case .invalidToken:
			return "Invalid or expired token"
		case .notAuthenticated:
			return "Not authenticated with ListenBrainz"
		case .invalidResponse:
			return "Invalid response from server"
		case .rateLimited:
			return "Rate limited, try again later"
		case .networkError:
			return "Network connection failed"
		case .recordingNotFound:
			return "Recording not found on MusicBrainz"
		case .apiError(let code, let message):
			return "API error (\(code)): \(message)"
		}
	}
}

enum FeedbackScore: Int {
	case love = 1
	case hate = -1
	case none = 0
}

struct ListenBrainzTopAlbum {
    let releaseName: String
    let artistName: String
    let listenCount: Int
    let releaseGroupMbid: String?
    let caaId: Int?
    let caaReleaseMbid: String?
    
    /// Returns the Cover Art Archive URL for this album's artwork, if available
    var artworkURL: URL? {
        if let caaReleaseMbid = caaReleaseMbid, let caaId = caaId {
            return URL(string: "https://coverartarchive.org/release/\(caaReleaseMbid)/\(caaId)-250.jpg")
        } else if let releaseGroupMbid = releaseGroupMbid {
            return URL(string: "https://coverartarchive.org/release-group/\(releaseGroupMbid)/front-250")
        }
        return nil
    }
}
