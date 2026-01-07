//
//  AboutView.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/6/26.
//

import SwiftUI

struct AboutView: View {
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "music.note.list")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.tint)
            }
            
            VStack(spacing: 8) {
                Text("scrobble.up")
                    .font(.system(size: 28, weight: .semibold))
                
                Text(appVersion)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                Text("A lightweight macOS scrobbler for Last.fm and ListenBrainz")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }
            
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/netliam/scrobble.up")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 14))
                        Text("View on GitHub")
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Additional link - Report an Issue
                Link(destination: URL(string: "https://github.com/yourusername/scrobble.up/issues")!) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 14))
                        Text("Report an Issue")
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Licensed under the GPLv3")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                
                Link("View License", destination: URL(string: "https://github.com/netliam/scrobble.up/blob/main/LICENSE")!)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 32)
        .frame(width: 400, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AboutView()
}
