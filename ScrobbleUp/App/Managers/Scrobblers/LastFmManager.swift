//
//  LastFmManager.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/25/25.
//

import Combine
import Foundation
import LastFM

final class LastFmManager: ObservableObject {

  static let shared = LastFmManager()

  var sessionKey: String?
  @Published private(set) var username: String?

  private let lastFM: LastFM

  private let api = "https://ws.audioscrobbler.com/2.0/"
  private var apiKey = Secrets.lastFmApiKey
  private var apiSecret = Secrets.lastFmApiSecret

  private init() {
    self.lastFM = LastFM(
      apiKey: apiKey,
      apiSecret: apiSecret
    )

    self.sessionKey = KeychainHelper.shared.get("lastfm_sessionKey")
    self.username = KeychainHelper.shared.get("lastfm_username")
  }

  // MARK: - Authentication Functions

  func getMobileSession(username: String, password: String) async throws {
    do {
      let session = try await lastFM.Auth.getMobileSession(username: username, password: password)

      self.sessionKey = session.key
      self.username = session.name
      KeychainHelper.shared.set(session.key, for: "lastfm_sessionKey")
      KeychainHelper.shared.set(username, for: "lastfm_username")
    } catch LastFMError.NoData {
      print("No data was returned.")
    } catch {
      print("Unexpected Error: \(error)")
    }
  }

  func getToken() async throws -> String {
    do {
      let token = try await lastFM.Auth.getToken()

      return token
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print("LastFM Error: \(errorType.rawValue) - \(message)")
      return ""
    } catch {
      print("Unexpected Error: \(error)")
      return ""
    }
  }

  func authURL(token: String) -> URL {
    var c = URLComponents()
    c.scheme = "https"
    c.host = "www.last.fm"
    c.path = "/api/auth"
    c.queryItems = [
      .init(name: "api_key", value: apiKey),
      .init(name: "token", value: token),
    ]
    return c.url ?? URL(string: "https://www.last.fm/api/auth?api_key=\(apiKey)&token=\(token)")!
  }

  func getSession(with token: String) async throws {
    do {
      let session = try await lastFM.Auth.getSession(token: token)

      self.sessionKey = session.key
      self.username = session.name
      KeychainHelper.shared.set(session.key, for: "lastfm_sessionKey")
      KeychainHelper.shared.set(session.name, for: "lastfm_username")
    } catch LastFMError.NoData {
      print("No data was returned.")
    } catch {
      print("Unexpected Error: \(error)")
    }
  }

  func signOut() {
    sessionKey = nil
    username = nil
    KeychainHelper.shared.remove("lastfm_sessionKey")
    KeychainHelper.shared.remove("lastfm_username")
  }

  // MARK: - Track Functions

  func updateNowPlaying(artist: String, track: String, album: String?, duration: Int?) async throws
  {
    guard let sk = sessionKey else { return }

    let trackNowPlayingParams = TrackNowPlayingParams(
      artist: artist, track: track, album: album, duration: UInt(duration!))

    do {
      _ = try await lastFM.Track.updateNowPlaying(params: trackNowPlayingParams, sessionKey: sk)
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print("LastFM Error: \(errorType.rawValue) - \(message)")
    } catch {
      print("Unexpected Error: \(error)")
    }
  }

  func scrobble(artist: String, track: String, timestamp: Int, album: String?, duration: Int?)
    async throws
  {
    guard let sk = sessionKey else { return }

    var scrobbleParams = ScrobbleParams()

    let scrobbleParamItem = ScrobbleParamItem(
      artist: artist, track: track, timestamp: UInt(timestamp), album: album,
      duration: UInt(duration!))
    try scrobbleParams.addItem(item: scrobbleParamItem)

    do {
      _ = try await lastFM.Track.scrobble(params: scrobbleParams, sessionKey: sk)
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print("LastFM Error: \(errorType.rawValue) - \(message)")
    } catch {
      print("Unexpected Error: \(error)")
    }

  }

  func fetchRecentTracks(limit: Int = 30) async throws -> [RecentTrack?] {
    let recentTrackParams = RecentTracksParams(user: username ?? "", limit: UInt(limit))

    do {
      let recentTracks = try await lastFM.User.getRecentTracks(params: recentTrackParams)

      return Array(recentTracks.items)
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print(errorType, message)
      return []
    } catch LastFMError.NoData {
      print("No data was returned.")
      return []
    } catch {
      print("An error ocurred: \(error)")
      return []
    }
  }

  func fetchTrackInfo(artist: String, track: String) async throws -> TrackInfo? {
    let trackInfoParams = TrackInfoParams(artist: artist, track: track)

    do {
      let trackInfo = try await lastFM.Track.getInfo(params: trackInfoParams)

      return trackInfo
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print(errorType, message)
      return nil
    } catch LastFMError.NoData {
      print("No data was returned.")
      return nil
    } catch {
      print("An error ocurred: \(error)")
      return nil
    }
  }

  func loveTrack(track: String, artist: String) async throws {
    guard let sessionKey = sessionKey else { return }

    let loveTrackParams = TrackParams(track: track, artist: artist)

    do {
      try await lastFM.Track.love(params: loveTrackParams, sessionKey: sessionKey)
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print("LastFM Error: \(errorType.rawValue) - \(message)")
    } catch {
      print("Unexpected Error: \(error)")
    }

  }

  func unloveTrack(track: String, artist: String) async throws {
    guard let sessionKey = sessionKey else { return }

    let unloveTrackParams = TrackParams(track: track, artist: artist)

    do {
      try await lastFM.Track.unlove(params: unloveTrackParams, sessionKey: sessionKey)
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print("LastFM Error: \(errorType.rawValue) - \(message)")
    } catch {
      print("Unexpected Error: \(error)")
    }

  }

  func isTrackLoved(artist: String, track: String) async -> Bool {
    guard let username = username else { return false }

    // Use raw API call since the library doesn't expose userloved
    var components = URLComponents(string: api)!
    components.queryItems = [
      URLQueryItem(name: "method", value: "track.getInfo"),
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "artist", value: artist),
      URLQueryItem(name: "track", value: track),
      URLQueryItem(name: "username", value: username),
      URLQueryItem(name: "format", value: "json"),
    ]

    guard let url = components.url else { return false }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let trackData = json?["track"] as? [String: Any]

      // userloved is returned as "0" or "1" string
      if let userloved = trackData?["userloved"] as? String {
        return userloved == "1"
      }
      return false
    } catch {
      print("Error checking track love state: \(error)")
      return false
    }
  }

  func fetchSimilarTracks(artist: String, track: String, autocorrect: Bool, limit: Int) async
    -> [TrackSimilar]?
  {
    let trackSimilarParams = TrackSimilarParams(
      track: track, artist: artist, autocorrect: autocorrect, limit: UInt(limit))

    do {
      let similarTracks = try await lastFM.Track.getSimilar(params: trackSimilarParams)

      return Array(similarTracks.items)
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print(errorType, message)
      return nil
    } catch LastFMError.NoData {
      print("No data was returned.")
      return nil
    } catch {
      print("An error ocurred: \(error)")
      return nil
    }
  }

  // MARK: - Artist Functions

  func fetchArtistInfo(artist: String, autocorrect: Bool = true) async throws -> ArtistInfo? {
    let artistInfoParams = ArtistInfoParams(
      term: artist, criteria: .artist, autocorrect: autocorrect)

    do {
      let artistInfo = try await lastFM.Artist.getInfo(params: artistInfoParams)

      return artistInfo
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print(errorType, message)
      return nil
    } catch LastFMError.NoData {
      print("No data was returned.")
      return nil
    } catch {
      print("An error ocurred: \(error)")
      return nil
    }
  }

  func fetchSimilarArtists(artist: String, autocorrect: Bool, limit: Int) async -> [ArtistSimilar]?
  {
    let artistSimilarParams = ArtistSimilarParams(
      artist: artist, autocorrect: autocorrect, limit: UInt(limit))

    do {
      let similarArtists = try await lastFM.Artist.getSimilar(params: artistSimilarParams)

      return Array(similarArtists.items)
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print(errorType, message)
      return nil
    } catch LastFMError.NoData {
      print("No data was returned.")
      return nil
    } catch {
      print("An error ocurred: \(error)")
      return nil
    }
  }

  // MARK: - Album Functions

  func fetchAlbumInfo(artist: String, album: String) async -> AlbumInfo? {
    let albumInfoParams = AlbumInfoParams(artist: artist, album: album)

    do {
      let albumInfo = try await lastFM.Album.getInfo(params: albumInfoParams)

      return albumInfo
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print(errorType, message)
      return nil
    } catch LastFMError.NoData {
      print("No data was returned.")
      return nil
    } catch {
      print("An error ocurred: \(error)")
      return nil
    }
  }

  // MARK: - User Functions

  func fetchUserInfo() async -> UserInfo? {
    guard let sessionKey = sessionKey else { return nil }
    do {
      let userInfo = try await lastFM.User.getInfo(sessionKey: sessionKey)

      return userInfo
    } catch LastFMError.LastFMServiceError(let errorType, let message) {
      print(errorType, message)
      return nil
    } catch {
      print("An error ocurred: \(error)")
      return nil
    }
  }

  // MARK: - Misc Functions

  func fetchArtworkURL(artist: String, track: String, album: String?) async -> URL? {
    do {
      let trackInfo = try await fetchTrackInfo(artist: artist, track: track)

      guard let images = trackInfo?.album?.image else { return nil }
      print(images)
      if let artwork = bestImageURL(images: images) { return artwork }
    } catch {}
    if let album = album, !album.isEmpty {
      let albumInfo = await fetchAlbumInfo(artist: artist, album: album)

      guard let images = albumInfo?.image else { return nil }
      if let artwork = bestImageURL(images: images) { return artwork }
    }
    return nil
  }
}
