//
//  OnboardingView.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/2/26.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lastFm: LastFmManager = .shared
    @ObservedObject private var listenBrainz: ListenBrainzManager = .shared
    
    var onConnectLastFm: () -> Void
    var onConnectListenBrainz: () -> Void
    var onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text("Welcome to scrobble.up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your music listening history by connecting to your favorite scrobbling service.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 350)
            }
            
            VStack(spacing: 12) {
                Button(action: onConnectLastFm) {
                    HStack {
                        Image("LastFm.logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("Connect Last.fm")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Button(action: onConnectListenBrainz) {
                    HStack {
                        Image("ListenBrainz.logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("Connect ListenBrainz")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .frame(width: 280)
            
            Button("Skip for now") {
                onSkip()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.callout)
        }
        .padding(48)
        .frame(width: 450, height: 420)
        .onChange(of: lastFm.username) { _, newValue in
            if newValue != nil {
                markOnboardingComplete()
                dismiss()
            }
        }
        .onChange(of: listenBrainz.username) { _, newValue in
            if newValue != nil {
                markOnboardingComplete()
                dismiss()
            }
        }
    }
    
    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

#Preview {
    OnboardingView(
        onConnectLastFm: {},
        onConnectListenBrainz: {},
        onSkip: {}
    )
}
