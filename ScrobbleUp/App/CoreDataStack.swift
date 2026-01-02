import AppKit
import CoreData
import Foundation

final class CoreDataStack {
  static let shared = CoreDataStack()
  let container: NSPersistentContainer

  private init() {
    let model = NSManagedObjectModel()
    let entity = NSEntityDescription()
    entity.name = "LogEntry"
    entity.managedObjectClassName = NSStringFromClass(LogEntry.self)

    func attr(_ n: String, _ t: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil)
      -> NSAttributeDescription
    {
      let a = NSAttributeDescription()
      a.name = n
      a.attributeType = t
      a.isOptional = optional
      if let defaultValue { a.defaultValue = defaultValue }
      return a
    }

    entity.properties = [
      attr("id", .UUIDAttributeType),
      attr("date", .dateAttributeType),
      attr("scrobbledAt", .dateAttributeType, optional: true),
      attr("title", .stringAttributeType),
      attr("artist", .stringAttributeType),
      attr("album", .stringAttributeType, optional: true),
      attr("source", .stringAttributeType),
      attr("duration", .integer32AttributeType, optional: true),

      attr("nowPlayingSent", .booleanAttributeType),
      attr("nowPlayingFailed", .booleanAttributeType),
      attr("scrobbled", .booleanAttributeType),
      attr("scrobbleFailed", .booleanAttributeType),
      attr("errorMessage", .stringAttributeType, optional: true),
    ]
    model.entities = [entity]

    container = NSPersistentContainer(name: "scrobble.up", managedObjectModel: model)

    let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    let dir = appSup.appendingPathComponent("scrobble.up", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("Scrobble.sqlite")

    let desc = NSPersistentStoreDescription(url: url)

    // Try lightweight migration first
    desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
    desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

    container.persistentStoreDescriptions = [desc]

    container.loadPersistentStores { [weak self] _, error in
      if let error = error {
        // If migration fails, delete the store and try again
        print("Core Data failed to load, attempting to recreate: \(error)")
        self?.deleteAndRecreateStore(at: url)
      } else {
        self?.pruneLogs()
      }
    }
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
  }

  private func deleteAndRecreateStore(at url: URL) {
    // Delete existing store files
    let fileManager = FileManager.default
    let storePath = url.path
    let walPath = storePath + "-wal"
    let shmPath = storePath + "-shm"

    try? fileManager.removeItem(atPath: storePath)
    try? fileManager.removeItem(atPath: walPath)
    try? fileManager.removeItem(atPath: shmPath)

    // Reload persistent stores
    container.loadPersistentStores { _, error in
      if let error = error {
        fatalError("Core Data failed to recreate store: \(error)")
      }
      print("Core Data store recreated successfully")
    }
  }

  func pruneLogs(keepCount: Int = 100) {
    let context = container.viewContext
    let request = NSFetchRequest<LogEntry>(entityName: "LogEntry")
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    request.fetchOffset = keepCount

    do {
      let older = try context.fetch(request)
      guard !older.isEmpty else { return }

      for entry in older {
        context.delete(entry)
      }

      try context.save()
    } catch {
      print("Failed to prune logs: \(error)")
    }
  }
}
