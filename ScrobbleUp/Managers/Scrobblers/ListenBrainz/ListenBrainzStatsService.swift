//
//  ListenBrainzStatsService.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/10/26.
//

import Foundation

/// Service for fetching user statistics and top content from ListenBrainz
final class ListenBrainzStatsService {
    private let config: ListenBrainzConfig
    
    init(config: ListenBrainzConfig) {
        self.config = config
    }
    
    // MARK: - Top Content
    
    func fetchTopAlbums(period: TopAlbumPeriod, limit: Int = 9) async -> [ListenBrainzTopAlbum]? {
        guard let username = config.username else { return nil }

        let rangeParam = mapPeriodToRange(period)

        guard
            let url = URL(
                string: "\(config.baseURL)/1/stats/user/\(username)/release-groups?range=\(rangeParam)&count=\(limit)"
            )
        else {
            return nil
        }

        do {
            let (data, response) = try await config.http.getRaw(url: url, headers: nil)

            if response.statusCode == 204 {
                return []
            }

            guard response.statusCode == 200 else {
                return nil
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let payload = json?["payload"] as? [String: Any]
            let releaseGroups = payload?["release_groups"] as? [[String: Any]]

            return releaseGroups?.compactMap { album -> ListenBrainzTopAlbum? in
                guard let releaseName = album["release_group_name"] as? String,
                      let artistName = album["artist_name"] as? String,
                      let listenCount = album["listen_count"] as? Int
                else {
                    return nil
                }

                return ListenBrainzTopAlbum(
                    releaseName: releaseName,
                    artistName: artistName,
                    listenCount: listenCount,
                    releaseGroupMbid: album["release_group_mbid"] as? String,
                    caaId: album["caa_id"] as? Int,
                    caaReleaseMbid: album["caa_release_mbid"] as? String
                )
            }
        } catch {
            print("Error fetching top albums from ListenBrainz: \(error)")
            return nil
        }
    }
    
    // MARK: - User Stats
    
    func fetchUserStats() async -> ListenBrainzUserStats? {
        guard let username = config.username else { return nil }

        async let listenCountTask = fetchListenCount(username: username)
        async let lovedTracksCountTask = fetchLovedTracksCount(username: username)

        let listenCount = await listenCountTask
        let lovedTracksCount = await lovedTracksCountTask

        return ListenBrainzUserStats(
            listenCount: listenCount ?? 0,
            lovedTracksCount: lovedTracksCount ?? 0
        )
    }
    
    // MARK: - Private Implementation
    
    private func mapPeriodToRange(_ period: TopAlbumPeriod) -> String {
        switch period {
        case .overall:
            return "all_time"
        case .week:
            return "week"
        case .month:
            return "month"
        case .quarter:
            return "quarter"
        case .halfYear:
            return "half_yearly"
        case .year:
            return "year"
        }
    }
    
    private func fetchListenCount(username: String) async -> UInt? {
        guard let url = URL(string: "\(config.baseURL)/1/user/\(username)/listen-count") else {
            return nil
        }

        do {
            let json = try await config.http.getJSON(url: url, headers: nil)
            let payload = json["payload"] as? [String: Any]
            if let count = payload?["count"] as? Int {
                return UInt(count)
            }
            return nil
        } catch {
            print("Error fetching listen count from ListenBrainz: \(error)")
            return nil
        }
    }

    private func fetchLovedTracksCount(username: String) async -> UInt? {
        guard let url = URL(string: "\(config.baseURL)/1/feedback/user/\(username)/get-feedback?score=1&count=0") else {
            return nil
        }

        do {
            let json = try await config.http.getJSON(url: url, headers: nil)
            if let totalCount = json["total_count"] as? Int {
                return UInt(totalCount)
            }
            return nil
        } catch {
            print("Error fetching loved tracks count from ListenBrainz: \(error)")
            return nil
        }
    }
}
