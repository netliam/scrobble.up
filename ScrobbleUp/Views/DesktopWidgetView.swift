//
//  DesktopWidgetView.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 1/5/26.
//

import SwiftUI

@MainActor
struct DesktopWidgetView: View {
	@ObservedObject var appState: AppState
	@ObservedObject var playerManager: PlayerManager = .shared

	@State private var isHovering: Bool = false
	@State private var showFullInfo: Bool = false
	@State private var trackInfoOpacity: Double = 1
	@State private var loveButtonOpacity: Double = 0

	@State private var displayedTitle: String = ""
	@State private var displayedArtist: String = ""
	@State private var hideTask: Task<Void, Never>?

	private let animationDuration: Double = 0.5
	private let widgetSize: CGFloat = 160

	var body: some View {
		ZStack(alignment: .bottom) {
			Image(nsImage: appState.currentTrack.image ?? placeholder)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.frame(width: widgetSize, height: widgetSize)

			trackInfoOverlay
				.opacity(trackInfoOpacity)

			if canLoveTrack {
				loveButton
					.opacity(loveButtonOpacity)
			}
		}
		.frame(width: widgetSize, height: widgetSize)
		.shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
		.clipShape(RoundedRectangle(cornerRadius: 16))
		.background {
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(.ultraThinMaterial)
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.white.opacity(0.35),
							Color.white.opacity(0.10),
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 1
				)
		}
		.onHover { hovering in
			isHovering = hovering
			updateVisibility()
		}
		.onAppear {
			displayedTitle = appState.currentTrack.title
			displayedArtist = appState.currentTrack.artist
		}
		.onDisappear {
			hideTask?.cancel()
		}
		.onChange(of: appState.currentTrack.title) { oldTitle, newTitle in
			guard newTitle != oldTitle else { return }
			onTrackChanged()
		}
	}

	// MARK: - Track Info Overlay

	private var trackInfoOverlay: some View {
		VStack(alignment: .center, spacing: 2) {
			if showFullInfo {
				Spacer()
			}

			Text(displayedTitle)
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(.white)
				.lineLimit(1)

			if showFullInfo {
				Text(displayedArtist)
					.font(.system(size: 11, weight: .regular))
					.foregroundStyle(.white.opacity(0.8))
					.lineLimit(1)

				Spacer()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: showFullInfo ? .infinity : nil, alignment: .center)
		.padding(.horizontal, 12)
		.padding(.vertical, 5)
		.background(
			UnevenRoundedRectangle(topLeadingRadius: 0, topTrailingRadius: 0)
				.fill(.ultraThinMaterial)
		)
		.clipShape(
			UnevenRoundedRectangle(
				bottomLeadingRadius: 16,
				bottomTrailingRadius: 16
			)
		)
	}
	// MARK: - Love Button

	private var loveButton: some View {
		VStack {
			HStack {
				Spacer()
				Button {
					loveCurrentTrack()
				} label: {
					Image(systemName: playerManager.isCurrentTrackLoved ? "heart.fill" : "heart")
						.font(.system(size: 16, weight: .medium))
						.foregroundStyle(playerManager.isCurrentTrackLoved ? .pink : .white)
						.padding(8)
						.background(
							ZStack {
								Color.black.opacity(0.3)
							}
						)
						.clipShape(Circle())
				}
				.buttonStyle(.plain)
				.padding(8)
			}
			Spacer()
		}
	}

	// MARK: - Helpers

	private var placeholder: NSImage {
		ArtworkManager.shared.placeholder()
	}

	private var canLoveTrack: Bool {
		let source = appState.currentActivePlayer
		return source == .appleMusic
			|| source == .spotify
			|| UserDefaults.standard.get(\.lastFmEnabled)
			|| UserDefaults.standard.get(\.listenBrainzEnabled)
	}

	private func loveCurrentTrack() {
		let source = appState.currentActivePlayer

		if source == .appleMusic || source == .spotify {
			playerManager.toggleLoveCurrentTrack()
		} else {
			Task {
				await playerManager.setLoveState(loved: !playerManager.isCurrentTrackLoved)
			}
		}
	}

	private func updateVisibility() {
		withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
			loveButtonOpacity = isHovering ? 1 : 0
		}
	}

	private func onTrackChanged() {
		hideTask?.cancel()

		displayedTitle = appState.currentTrack.title
		displayedArtist = appState.currentTrack.artist

		withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
			showFullInfo = true
		}

		hideTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 5_000_000_000)
			guard !Task.isCancelled else { return }

			withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
				showFullInfo = false
			}
		}
	}
}
