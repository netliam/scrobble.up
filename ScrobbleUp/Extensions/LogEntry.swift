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
	// Services this scrobble still has to reach; the retry resends only to these.
	@NSManaged var lastFmPending: Bool
	@NSManaged var listenBrainzPending: Bool

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
        let cleanArtist = artist.trimmingCharacters(in: .whitespaces)
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let cleanAlbum = album?.trimmingCharacters(in: .whitespaces)
        
        guard !cleanArtist.isEmpty && !cleanTitle.isEmpty else {
            print("Warning: Attempted to create LogEntry with empty artist or title. Artist: '\(artist)', Title: '\(title)'")
            let entry = LogEntry(context: context)
            entry.id = UUID()
            entry.date = Date()
            entry.artist = cleanArtist.isEmpty ? "Unknown Artist" : cleanArtist
            entry.title = cleanTitle.isEmpty ? "Unknown Track" : cleanTitle
            entry.album = cleanAlbum
            entry.source = source
            entry.nowPlayingSent = false
            entry.nowPlayingFailed = false
            entry.scrobbled = false
            entry.scrobbleFailed = false
            return entry
        }
        
		let request = NSFetchRequest<LogEntry>(entityName: "LogEntry")
		request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
			NSPredicate(format: "artist ==[c] %@", cleanArtist),
			NSPredicate(format: "title ==[c] %@", cleanTitle),
			NSPredicate(format: "scrobbled == NO"),
			NSPredicate(format: "scrobbleFailed == NO"),  // keep failed plays for the retry
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
		entry.artist = cleanArtist
		entry.title = cleanTitle
		entry.album = cleanAlbum
		entry.source = source
		entry.nowPlayingSent = false
		entry.nowPlayingFailed = false
		entry.scrobbled = false
		entry.scrobbleFailed = false
		return entry
	}
}

// MARK: - Validation & Sanitization

extension LogEntry {
    var isValid: Bool {
        let artistTrimmed = artist.trimmingCharacters(in: .whitespaces)
        let titleTrimmed = title.trimmingCharacters(in: .whitespaces)
        
        // Check if data looks like corrupted/placeholder data
        let isCorrupted = (
            artistTrimmed.isEmpty ||
            titleTrimmed.isEmpty ||
            artistTrimmed.count > 500 ||
            titleTrimmed.count > 500
        )
        
        return !isCorrupted && !artistTrimmed.isEmpty && !titleTrimmed.isEmpty
    }
    
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.count > 500 ? "Unknown Track" : trimmed
    }
    
    var displayArtist: String {
        let trimmed = artist.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.count > 500 ? "Unknown Artist" : trimmed
    }
    
    func cleanIfCorrupted() {
        if !isValid {
            print("Cleaning corrupted LogEntry - Artist: '\(artist)', Title: '\(title)'")
            artist = displayArtist
            title = displayTitle
            try? managedObjectContext?.save()
        }
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
