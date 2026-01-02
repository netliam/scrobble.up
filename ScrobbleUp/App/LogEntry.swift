import AppKit
import CoreData
import Foundation

@objc(LogEntry)
class LogEntry: NSManagedObject {
  @NSManaged var id: UUID
  @NSManaged var date: Date
  @NSManaged var scrobbledAt: Date?
  @NSManaged var title: String
  @NSManaged var artist: String
  @NSManaged var source: String
  @NSManaged var album: String?
  @NSManaged var duration: Int32

  @NSManaged var nowPlayingSent: Bool
  @NSManaged var nowPlayingFailed: Bool
  @NSManaged var scrobbled: Bool
  @NSManaged var scrobbleFailed: Bool
  @NSManaged var errorMessage: String?

  var status: Status {
    if scrobbleFailed || nowPlayingFailed { return .failed }
    if scrobbled { return .scrobbled }
    if nowPlayingSent { return .nowPlaying }
    return .pending
  }

  enum Status: String {
    case pending, nowPlaying, scrobbled, failed
  }
}

extension LogEntry: Identifiable {}

// MARK: - Find or Create

extension LogEntry {
  static func findOrCreate(
    artist: String,
    title: String,
    album: String?,
    source: String,
    context: NSManagedObjectContext
  ) -> LogEntry {
    let request = NSFetchRequest<LogEntry>(entityName: "LogEntry")
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(format: "artist ==[c] %@", artist),
      NSPredicate(format: "title ==[c] %@", title),
      NSPredicate(format: "scrobbled == NO"),
      NSPredicate(format: "date > %@", Date().addingTimeInterval(-600) as NSDate),
    ])
    request.fetchLimit = 1
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

    if let existing = try? context.fetch(request).first {
      return existing
    }

    let entry = LogEntry(context: context)
    entry.id = UUID()
    entry.date = Date()
    entry.artist = artist
    entry.title = title
    entry.album = album
    entry.source = source
    entry.nowPlayingSent = false
    entry.nowPlayingFailed = false
    entry.scrobbled = false
    entry.scrobbleFailed = false
    return entry
  }
}

// MARK: - Status Updates

extension LogEntry {
  func markNowPlayingSent() {
    nowPlayingSent = true
    nowPlayingFailed = false
    errorMessage = nil
    save()
  }

  func markNowPlayingFailed(_ error: String?) {
    nowPlayingSent = false
    nowPlayingFailed = true
    errorMessage = error
    save()
  }

  func markScrobbled() {
    scrobbled = true
    scrobbleFailed = false
    scrobbledAt = Date()
    errorMessage = nil
    save()
  }

  func markScrobbleFailed(_ error: String?) {
    scrobbled = false
    scrobbleFailed = true
    errorMessage = error
    save()
  }

  private func save() {
    try? managedObjectContext?.save()
  }
}

// MARK: - Fetch Helpers

extension LogEntry {
  static func fetchRequestRecent(limit: Int = 200) -> NSFetchRequest<LogEntry> {
    let request = NSFetchRequest<LogEntry>(entityName: "LogEntry")
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    request.fetchLimit = limit
    return request
  }

  static func fetchRecent(context: NSManagedObjectContext, limit: Int = 200) -> [LogEntry] {
    let request = fetchRequestRecent(limit: limit)
    return (try? context.fetch(request)) ?? []
  }

  static func fetchFailed(context: NSManagedObjectContext) -> [LogEntry] {
    let request = NSFetchRequest<LogEntry>(entityName: "LogEntry")
    request.predicate = NSPredicate(format: "scrobbleFailed == YES")
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    return (try? context.fetch(request)) ?? []
  }
}
