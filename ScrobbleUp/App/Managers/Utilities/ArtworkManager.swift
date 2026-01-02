import AppKit

struct iTunesResponse: Codable {
  let results: [iTunesResult]
}

struct iTunesResult: Codable {
  let artworkUrl100: String
}

final class ArtworkManager {

  static let shared = ArtworkManager()

  private let imageCache = NSCache<NSString, NSImage>()

  private init() {
    imageCache.totalCostLimit = 50 * 1024 * 1024
    imageCache.countLimit = 20
  }

  func clearCache() {
    imageCache.removeAllObjects()
  }

  func placeholder() -> NSImage {
    let size = NSSize(width: 300, height: 300)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor(calibratedRed: 0.2, green: 0.25, blue: 0.5, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    let attrs: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 48, weight: .bold),
      .foregroundColor: NSColor.white.withAlphaComponent(0.8),
    ]
    let str = NSAttributedString(string: "♪", attributes: attrs)
    str.draw(at: NSPoint(x: 130, y: 110))
    image.unlockFocus()
    return image
  }

  func fetchFromiTunes(artist: String, track: String) async -> NSImage? {
    let cacheKey = "\(artist)|\(track)" as NSString

    if let cached = imageCache.object(forKey: cacheKey) {
      return cached
    }

    let query =
      "\(artist) \(track)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&entity=song&limit=1"

    guard let url = URL(string: urlString) else { return nil }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let response = try JSONDecoder().decode(iTunesResponse.self, from: data)

      if let artworkURL = response.results.first?.artworkUrl100 {
        let highResURL = artworkURL.replacingOccurrences(of: "100x100", with: "600x600")
        if let image = await loadNSImage(from: URL(string: highResURL)!) {
          imageCache.setObject(image, forKey: cacheKey, cost: 1_400_000)
          return image
        }
      }
    } catch {
      print("iTunes API error: \(error)")
    }

    return nil
  }

  func loadNSImage(from url: URL) async -> NSImage? {
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      return NSImage(data: data)
    } catch {
      return nil
    }
  }
}
