//
//  ListenBrainzSettingsPane.swift
//  scrobble.up
//
//  Created by Liam Smith-Gales on 12/31/25.
//

import Settings
import SwiftUI

struct ListenBrainzSettingsPane: View {
	@ObservedObject private var listenBrainz: ListenBrainzManager = .shared

	var body: some View {

		if (listenBrainz.username) != nil {
			ListenBrainzConnectedView(listenBrainz: listenBrainz)
		} else {
			ListenBrainzTokenInputView(listenBrainz: listenBrainz)
		}
	}
}

// MARK: - Token Input View

struct ListenBrainzTokenInputView: View {
	@ObservedObject var listenBrainz: ListenBrainzManager

	@State private var tokenInput = ""
	@State private var isValidating = false
	@State private var errorMessage: String?
	@State private var showingError = false

	var body: some View {
		HStack(alignment: .top, spacing: 24) {
			// Logo Panel
			VStack {
				Spacer()
				Image(nsImage: NSImage(named: "ListenBrainz.logo")!)
					.resizable()
					.scaledToFit()
					.frame(width: 100)
					.padding(20)
			}
			.frame(width: 160, height: 220)
			.background(
				Color(red: 0.85, green: 0.33, blue: 0.0),
				in: RoundedRectangle(cornerRadius: 12)
			)

			// Token input form
			VStack(alignment: .leading, spacing: 20) {
				VStack(alignment: .leading, spacing: 12) {
					Text("User Token")
						.font(.headline)

					SecureField("Paste your token here", text: $tokenInput)
						.textFieldStyle(.roundedBorder)

					Button {
						Task { await validateAndSave() }
					} label: {
						Label("Connect", systemImage: "link")
					}
					.buttonStyle(.borderedProminent)
					.disabled(tokenInput.isEmpty || isValidating)
				}
				.frame(width: 280)

				Divider()

				VStack(alignment: .leading, spacing: 8) {
					Text(
						"Track, explore, visualise and share the music you listen to. Follow your favourites and discover great new music."
					)
					.font(.callout)

					Text("You'll need your account token to start scrobbling.")
						.font(.callout)
						.foregroundStyle(.secondary)

					Link(
						"Your token can be found here.",
						destination: URL(string: "https://listenbrainz.org/settings/")!
					)
					.font(.callout)
				}
				.frame(width: 280)
			}
		}
		.padding(24)
		.alert("Validation Failed", isPresented: $showingError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(errorMessage ?? "Unknown error")
		}
	}

	private func validateAndSave() async {
		isValidating = true
		defer { isValidating = false }

		do {
			let username = try await listenBrainz.validateToken(tokenInput)
			await MainActor.run {
				listenBrainz.configure(token: tokenInput, username: username)
			}
		} catch {
			errorMessage = error.localizedDescription
			showingError = true
		}
	}
}

// MARK: - Connected View

struct ListenBrainzConnectedView: View {
	@ObservedObject var listenBrainz: ListenBrainzManager

	@AppStorage(\.listenBrainzEnabled) private var listenBrainzEnabled

	var body: some View {
		Form {
			Section {
				HStack(spacing: 16) {
					Circle()
						.fill(Color(red: 0.85, green: 0.33, blue: 0.0))
						.frame(width: 80, height: 80)
						.overlay {
							Image(systemName: "music.note")
								.font(.largeTitle)
								.foregroundColor(.white)
						}

					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Connected as")
								.font(.title2)
							Text(listenBrainz.username ?? "Unknown")
								.font(.title2)
								.fontWeight(.bold)
						}

						HStack(spacing: 12) {
							Button("Profile...") {
								if let user = listenBrainz.username,
									let url = URL(string: "https://listenbrainz.org/user/\(user)")
								{
									NSWorkspace.shared.open(url)
								}
							}

							Button("Disconnect") {
								listenBrainz.signOut()
							}
						}
					}

					Spacer()
				}
			}
			Section {
				Toggle(
					"Enable ListenBrainz",
					isOn: $listenBrainzEnabled
				)
			}
		}
		.formStyle(.grouped)
	}
}
