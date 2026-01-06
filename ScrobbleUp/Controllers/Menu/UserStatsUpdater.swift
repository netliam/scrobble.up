//
//  UserStatsUpdater.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 1/6/26.
//

import AppKit
import Foundation
import LastFM

final class UserStatsUpdater {
    
    private let lastFm = LastFmManager.shared
    private let listenBrainz = ListenBrainzManager.shared
    
    func updateUserStats(
        profileItem: NSMenuItem,
        scrobblesRow: MenuItemStatsRowView,
        artistsRow: MenuItemStatsRowView,
        lovedTracksRow: MenuItemStatsRowView,
        service: ScrobblerService
    ) {
        switch service {
        case .lastFm:
            updateLastFmStats(profileItem: profileItem, scrobblesRow: scrobblesRow, artistsRow: artistsRow, lovedTracksRow: lovedTracksRow)
        case .listenBrainz:
            updateListenBrainzStats(profileItem: profileItem, scrobblesRow: scrobblesRow, artistsRow: artistsRow, lovedTracksRow: lovedTracksRow)
        }
    }
    
    // MARK: - Last.fm
    
    private func updateLastFmStats(
        profileItem: NSMenuItem,
        scrobblesRow: MenuItemStatsRowView,
        artistsRow: MenuItemStatsRowView,
        lovedTracksRow: MenuItemStatsRowView
    ) {
        Task {
            async let userInfoTask = lastFm.fetchUserInfo()
            async let lovedTracksCountTask = lastFm.fetchLovedTracksCount()
            
            guard let userInfo = await userInfoTask else {
                await MainActor.run {
                    profileItem.title = "Open profile..."
                    scrobblesRow.updateValue("—")
                    artistsRow.updateValue("—")
                    lovedTracksRow.updateValue("—")
                }
                return
            }
            
            let lovedTracksCount = await lovedTracksCountTask
            
            await MainActor.run {
                profileItem.title = "Open \(userInfo.name)'s profile..."
                scrobblesRow.updateValue(formatNumber(userInfo.playcount))
                artistsRow.updateValue(formatNumber(userInfo.artistCount))
                lovedTracksRow.updateValue(formatNumber(lovedTracksCount))
            }
        }
    }
    
    // MARK: - ListenBrainz
    
    private func updateListenBrainzStats(
        profileItem: NSMenuItem,
        scrobblesRow: MenuItemStatsRowView,
        artistsRow: MenuItemStatsRowView,
        lovedTracksRow: MenuItemStatsRowView
    ) {
        Task {
            guard let username = listenBrainz.username else {
                await MainActor.run {
                    profileItem.title = "Open profile..."
                    scrobblesRow.updateValue("—")
                    artistsRow.updateValue("—")
                    lovedTracksRow.updateValue("—")
                }
                return
            }
            
            // ListenBrainz doesn't have a user info endpoint like Last.fm
            // So we just update the profile title with the username
            await MainActor.run {
                profileItem.title = "Open \(username)'s profile..."
                // Stats not available via ListenBrainz API - hide or show dashes
                scrobblesRow.updateValue("—")
                artistsRow.updateValue("—")
                lovedTracksRow.updateValue("—")
            }
        }
    }
    
    private func formatNumber(_ number: UInt) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
