//
//  Player.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/14/26.
//

struct TrackFavoriteState {
    var local: Bool = false
    var lastFm: Bool = false
    var listenBrainz: Bool = false
    var appleMusic: Bool = false

    var isFavoritedOnAnyService: Bool {
        lastFm || listenBrainz || appleMusic || local
    }

    var isFavoritedOnAllServices: Bool {
        isFavoritedOnAnyService
    }
}

struct FavoriteOperationResults {
    var appleMusicSuccess: Bool = false
    var lastFmSuccess: Bool = false
    var listenBrainzSuccess: Bool = false

    var appleMusicError: String?
    var lastFmError: String?
    var listenBrainzError: String?

    var anySuccess: Bool {
        appleMusicSuccess || lastFmSuccess || listenBrainzSuccess
    }

    var allSuccess: Bool {
        appleMusicError == nil && lastFmError == nil && listenBrainzError == nil
    }

    var errors: [String] {
        [appleMusicError, lastFmError, listenBrainzError].compactMap { $0 }
    }
}
