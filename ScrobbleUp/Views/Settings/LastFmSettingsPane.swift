//
//  LastFmSettingsPane.swift
//  ScrobbleUp
//
//  Created by Liam Smith-Gales on 12/23/25.
//

import Combine
import LastFM
import Settings
import SwiftUI

struct LastFmSettingsPane: View {
	@ObservedObject private var lastFm: LastFmManager = .shared

	var body: some View {

		if (lastFm.username) != nil {
			LastFmProfileView(lastFm: lastFm)
		} else {
			LastFmSignInView(lastFm: lastFm)
		}

	}
}

// MARK: - Sign In View

struct LastFmSignInView: View {
	@ObservedObject var lastFm: LastFmManager

	@State private var username = ""
	@State private var password = ""
	@State private var isLoading = false
	@State private var authError: String?
	@State private var showingError = false

	var body: some View {
		HStack(alignment: .top, spacing: 24) {
			// Logo Panel
			VStack {
				Spacer()
				Image(nsImage: NSImage(named: "LastFm.logo.full")!)
					.resizable()
					.scaledToFit()
					.frame(width: 100)
					.padding(20)
			}
			.frame(width: 160, height: 220)
			.background(.black, in: RoundedRectangle(cornerRadius: 12))

			// Sign In Form
			VStack(alignment: .leading, spacing: 20) {
				VStack(spacing: 12) {
					TextField("username", text: $username)
						.textFieldStyle(.roundedBorder)

					SecureField("password", text: $password)
						.textFieldStyle(.roundedBorder)

					Button {
						Task { await signIn() }
					} label: {
						Text("Sign In")
							.frame(maxWidth: .infinity)
					}
					.buttonStyle(.bordered)
					.disabled(username.isEmpty || password.isEmpty || isLoading)
				}
				.frame(width: 280)

				Divider()

				VStack(alignment: .leading, spacing: 8) {
					Text("Every song you've listened to, all in one place.")
						.font(.callout)

					Text(
						"Access your entire listening history anytime relive specific days, view your all time stats and rediscover forgotten favorites."
					)
					.font(.callout)
					.foregroundStyle(.secondary)

					Link(
						"Don't have an account? Sign Up",
						destination: URL(string: "https://www.last.fm/join")!
					)
					.font(.callout)
				}
				.frame(width: 280)
			}
		}
		.padding(24)
		.alert(
			"Authentication failed",
			isPresented: $showingError,
			actions: {
				Button("OK", role: .cancel) {}
			},
			message: {
				Text(authError ?? "Unknown error")
			}
		)
	}

	private func signIn() async {
		isLoading = true
		defer { isLoading = false }

		do {
			try await lastFm.getMobileSession(username: username, password: password)
		} catch {
			authError = error.localizedDescription
			showingError = true
		}
	}
}

// MARK: - Profile View

struct LastFmProfileView: View {
	@ObservedObject var lastFm: LastFmManager

	@State private var userInfo: UserInfo?
	@State private var isLoading: Bool = true
	@State private var profileImageURL: URL?

	@AppStorage(\.lastFmEnabled) private var lastFmEnabled

	var body: some View {

		Form {
			Section {
				HStack(spacing: 16) {
					AsyncImage(url: userInfo?.image.medium) { phase in
						switch phase {
						case .empty:
							Circle()
								.fill(Color.secondary.opacity(0.3))
								.frame(width: 80, height: 80)
								.overlay {
									ProgressView()
								}
						case .success(let image):
							image
								.resizable()
								.aspectRatio(contentMode: .fill)
								.frame(width: 80, height: 80)
								.clipShape(Circle())
						case .failure:
							Circle()
								.fill(Color.secondary.opacity(0.3))
								.frame(width: 80, height: 80)
								.overlay {
									Image(systemName: "person.fill")
										.font(.largeTitle)
										.foregroundColor(.secondary)
								}
						@unknown default:
							Circle()
								.fill(Color.secondary.opacity(0.3))
								.frame(width: 80, height: 80)
						}
					}

					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Hello,")
								.font(.title2)
							Text(
								userInfo?.name ?? "Couldn't fetch username"
							)
							.font(.title2)
							.fontWeight(.bold)
						}

						HStack(spacing: 12) {
							Button("Profile...") {
								if let url = URL(
									string: userInfo?.url.absoluteString
										?? "https://www.last.fm/user/\(String(describing: lastFm.username))"
								) {
									NSWorkspace.shared.open(url)
								}
							}

							Button("Sign Out") {
								lastFm.signOut()
							}
						}
					}
					Spacer()
				}
			}
			Section {
				Toggle("Enable Last.fm", isOn: $lastFmEnabled)
			}
		}
		.formStyle(.grouped)
		.frame(width: 450, height: 200)
		.task {
			guard userInfo == nil else { return }
			let info = await lastFm.fetchUserInfo()
			self.userInfo = info
			self.isLoading = false
		}
	}
}

private struct LastFmImage: Codable {
	let text: String
	let size: String?

	enum CodingKeys: String, CodingKey {
		case text = "#text"
		case size
	}
}

#Preview {
	LastFmSettingsPane()
		.environmentObject(LastFmManager.shared)
}
