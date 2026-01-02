import AppKit
import CoreData
import SwiftUI

struct LogListView: View {
  @Environment(\.managedObjectContext) private var context
  private let artworkManager: ArtworkManager = .shared

  @FetchRequest(
    sortDescriptors: [SortDescriptor(\LogEntry.date, order: .reverse)],
    animation: .default
  )
  private var entries: FetchedResults<LogEntry>

  @State private var filterStatus: LogEntry.Status? = nil
  @State private var search: String = ""

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Picker("Status", selection: $filterStatus) {
          Text("All").tag(LogEntry.Status?.none)
          Text("Now Playing").tag(LogEntry.Status?.some(.nowPlaying))
          Text("Scrobbled").tag(LogEntry.Status?.some(.scrobbled))
          Text("Failed").tag(LogEntry.Status?.some(.failed))
        }
        .pickerStyle(.segmented)
        .frame(width: 360)

        Spacer()

        TextField("Search for artist/track/album…", text: $search)
          .textFieldStyle(.roundedBorder)
          .frame(minWidth: 200)
      }

      List(filteredEntries) { entry in
        LogEntryRow(entry: entry, placeholderArtwork: artworkManager.placeholder())
      }
    }
    .padding(.vertical, 6)
  }

  private var filteredEntries: [LogEntry] {
    entries.filter { entry in
      let matchesStatus = filterStatus == nil || entry.status == filterStatus
      let matchesSearch =
        search.isEmpty
        || "\(entry.artist) \(entry.title) \(entry.album ?? "")"
          .localizedCaseInsensitiveContains(search)
      return matchesStatus && matchesSearch
    }
  }
}

// MARK: - Row View

private struct LogEntryRow: View {
  @ObservedObject var entry: LogEntry
  let placeholderArtwork: NSImage

  @State private var artwork: NSImage? = nil
  private let artworkManager: ArtworkManager = .shared

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(nsImage: artwork ?? placeholderArtwork)
        .resizable()
        .aspectRatio(1, contentMode: .fill)
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6)
        .task {
          if artwork == nil {
            artwork = await artworkManager.fetchFromiTunes(
              artist: entry.artist,
              track: entry.title
            )
          }
        }

      VStack(alignment: .leading, spacing: 2) {
        Text("\(entry.artist) — \(entry.title)")
          .font(.headline)

        HStack(spacing: 8) {
          if let album = entry.album, !album.isEmpty {
            Label(album, systemImage: "opticaldisc")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Label(entry.date.shortHuman(), systemImage: "clock")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text(entry.source)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }

        Spacer()

        HStack(spacing: 6) {
          if entry.nowPlayingSent {
            StatusBadge(text: "NP", color: .blue)
          }
          if entry.scrobbled {
            StatusBadge(text: "SC", color: .green)
          }
          if entry.nowPlayingFailed || entry.scrobbleFailed {
            StatusBadge(text: "ERR", color: .red)
          }
        }

        if let error = entry.errorMessage, !error.isEmpty {
          Text(error)
            .font(.footnote)
            .foregroundStyle(.red)
            .lineLimit(2)
        }
      }

      Spacer()

      statusIndicator
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var statusIndicator: some View {
    Circle()
      .fill(statusColor)
      .frame(width: 10, height: 10)
      .help(entry.status.rawValue.capitalized)
  }

  private var statusColor: Color {
    switch entry.status {
    case .pending:
      return .gray
    case .nowPlaying:
      return .blue
    case .scrobbled:
      return .green
    case .failed:
      return .red
    }
  }
}

// MARK: - Status Badge

private struct StatusBadge: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .bold, design: .rounded))
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.15))
      .foregroundStyle(color)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}
