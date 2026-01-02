import SwiftUI

struct ArtworkWidgetView: View {
  @ObservedObject var appState: AppState
  let artworkManager: ArtworkManager = .shared

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(nsImage: appState.currentTrack.image ?? artworkManager.placeholder())
        .resizable()
        .aspectRatio(1, contentMode: .fill)
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6)

      Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
        GridRow(alignment: .top) {
          Text("Music:")
            .font(.title3)
            .bold()
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text(appState.currentTrack.title)
            .font(.title3)
            .bold()
            .gridColumnAlignment(.leading)
            .truncationMode(.tail)
        }
        GridRow(alignment: .top) {
          Text("Album:")
            .font(.headline)
            .bold()
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text(
            (appState.currentTrack.album?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              == false ? appState.currentTrack.album : "-") ?? "-"
          )
          .font(.headline)
          .bold()
          .gridColumnAlignment(.leading)
          .truncationMode(.tail)
        }
        GridRow(alignment: .top) {
          Text("Artist:")
            .font(.subheadline)
            .bold()
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text(appState.currentTrack.artist)
            .font(.subheadline)
            .bold()
            .gridColumnAlignment(.leading)
            .truncationMode(.tail)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Spacer()
    }
    .padding(10)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

}
