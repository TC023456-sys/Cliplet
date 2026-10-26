import Foundation
import SwiftData

@MainActor
class Storage {
  static let shared = Storage()

  var container: ModelContainer
  var context: ModelContext { container.mainContext }
  private var checkedOrphanedContents = false

  func removeOrphanedContentsOnce() throws {
    guard !checkedOrphanedContents else { return }
    context.processPendingChanges()
    try context.save()
    // Only unowned payloads from older duplicate merges are removed. Never
    // delete a history row, a pin, or a payload still belonging to a live row.
    try context.delete(model: HistoryItemContent.self, where: #Predicate { $0.item == nil })
    context.processPendingChanges()
    try context.save()
    checkedOrphanedContents = true
  }
  var size: String {
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).allValues.first?.value as? Int64, size > 1 else {
      return ""
    }

    return ByteCountFormatter().string(fromByteCount: size)
  }

  private let url = URL.applicationSupportDirectory.appending(path: "Maccy/Storage.sqlite")

  init() {
    var config = ModelConfiguration(url: url)

    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      config = ModelConfiguration(isStoredInMemoryOnly: true)
    }
    #endif

    do {
      container = try ModelContainer(for: HistoryItem.self, configurations: config)
    } catch let error {
      fatalError("Cannot load database: \(error.localizedDescription).")
    }
  }
}
