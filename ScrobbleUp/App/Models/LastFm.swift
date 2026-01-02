//
//  LastFMClient.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/25/25.
//

import Foundation

struct Secrets {
  static var lastFmApiKey: String {
    return Bundle.main.object(forInfoDictionaryKey: "LastFmApiKey") as? String ?? ""
  }

  static var lastFmApiSecret: String {
    return Bundle.main.object(forInfoDictionaryKey: "LastFmApiSecret") as? String ?? ""
  }
}
