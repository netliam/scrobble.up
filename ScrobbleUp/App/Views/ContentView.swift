import AppKit
import CoreData
import SwiftUI

struct ContentView: View {
	@Environment(\.managedObjectContext) private var context
	@EnvironmentObject var appState: AppState
	@EnvironmentObject var lastFm: LastFmManager
	@State private var pendingToken: String? = nil
	@State private var authError: String? = nil
	@State private var showingError = false

	let artworkManager: ArtworkManager = .shared

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(alignment: .center, spacing: 16) {
				Image(nsImage: appState.currentTrack.image ?? artworkManager.placeholder())
					.resizable()
					.interpolation(.high)
					.antialiased(true)
					.aspectRatio(1, contentMode: .fill)
					.frame(width: 120, height: 120)
					.clipShape(RoundedRectangle(cornerRadius: 16))
					.shadow(radius: 8)

				Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
					GridRow(alignment: .top) {
						Text("Music:")
							.font(.title2)
							.bold()
							.foregroundStyle(.secondary)
							.gridColumnAlignment(.trailing)
						Text(appState.currentTrack.title)
							.font(.title2)
							.bold()
							.lineLimit(2)
					}
					GridRow(alignment: .top) {
						Text("Album:")
							.font(.title3)
							.bold()
							.foregroundStyle(.secondary)
							.gridColumnAlignment(.trailing)
						Text(
							(appState.currentTrack.album?.trimmingCharacters(
								in: .whitespacesAndNewlines
							).isEmpty
								== false ? appState.currentTrack.album : "-") ?? "-"
						)
						.font(.title3)
						.foregroundColor(.white)
						.lineLimit(2)
					}
					GridRow(alignment: .top) {
						Text("Artist:")
							.font(.headline)
							.bold()
							.foregroundStyle(.secondary)
							.gridColumnAlignment(.trailing)
						Text(appState.currentTrack.artist)
							.font(.headline)
							.foregroundColor(.white)
							.lineLimit(2)
					}
				}
			}
			.padding([.horizontal, .top])

			Divider()

			TabView {
				LogListView()
					.tabItem { Label("Scrobble Log", systemImage: "list.bullet.rectangle") }
			}
			.padding([.horizontal, .bottom])
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
