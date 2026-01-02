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
              (appState.currentTrack.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

      if pendingToken != nil && lastFm.username == nil {
        HStack {
          Button {
            Task { await completeAuth() }
          } label: {
            Label("I've authorized it — Complete login", systemImage: "checkmark.circle")
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          Spacer()
          Button("Cancel") { pendingToken = nil }
        }
        .padding(.horizontal)
      }

      Divider()

      TabView {
        LogListView()
          .tabItem { Label("Scrobble Log", systemImage: "list.bullet.rectangle") }
      }
      .padding([.horizontal, .bottom])

      HStack {
        if let username = lastFm.username {
          Label("Connected to Last.fm - \(username)", systemImage: "checkmark.seal")
            .foregroundStyle(.green)
        } else {
          Label("Not Connected", systemImage: "exclamationmark.triangle").foregroundStyle(
            .secondary)
        }
        Spacer()
        if lastFm.username != nil {
          Button(role: .destructive) {
            lastFm.signOut()
          } label: {
            Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
          }
        } else {
          Button {
            Task { await startAuth() }
          } label: {
            Label("Login to Last.fm", systemImage: "link")
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding([.horizontal, .bottom])
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .alert(
      "Authentication failed", isPresented: $showingError,
      actions: {
        Button("Ok", role: .cancel) {}
      },
      message: {
        Text(authError ?? "Unknown Error")
      })
  }

  private func startAuth() async {
    do {
      let token = try await lastFm.getToken()
      self.pendingToken = token
      let url = lastFm.authURL(token: token)
      NSWorkspace.shared.open(url)
    } catch {
      authError = error.localizedDescription
      showingError = true
    }
  }

  private func completeAuth() async {
    guard let token = pendingToken else { return }
    do {
      try await lastFm.getSession(with: token)
      pendingToken = nil
    } catch {
      authError = error.localizedDescription
      showingError = true
    }
  }
}
