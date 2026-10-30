import Foundation

@main
struct DataTests {
  static func main() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let suite = "cliplet-data-test-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer {
      defaults.removePersistentDomain(forName: suite)
      try? FileManager.default.removeItem(at: home)
    }
    let fallback = home.appending(path: "Library/Application Support/Maccy/Storage.sqlite")
    precondition(ClipletData.databaseURL(home: home) == fallback)
    let dataDirectory = home.appending(path: "Library/Containers/com.tc023456.Cliplet/Data/Library")
    let database = dataDirectory.appending(path: "Application Support/Maccy/Storage.sqlite")
    try FileManager.default.createDirectory(at: database.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("history-fixture".utf8).write(to: database)
    precondition(ClipletData.databaseURL(home: home) == database)
    let preferences = dataDirectory.appending(path: "Preferences/com.tc023456.Cliplet.plist")
    try FileManager.default.createDirectory(at: preferences.deletingLastPathComponent(), withIntermediateDirectories: true)
    let values: [String: Any] = ["historySize": 20, "pasteByDefault": true, "KeyboardShortcuts_popup": "fixture"]
    let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
    try data.write(to: preferences)
    ClipletData.importLegacyPreferences(home: home, defaults: defaults, domain: "com.tc023456.Cliplet")
    precondition(defaults.integer(forKey: "historySize") == 20)
    precondition(defaults.bool(forKey: "pasteByDefault"))
    precondition(defaults.string(forKey: "KeyboardShortcuts_popup") == "fixture")
    defaults.set(10, forKey: "historySize")
    ClipletData.importLegacyPreferences(home: home, defaults: defaults, domain: "com.tc023456.Cliplet")
    precondition(defaults.integer(forKey: "historySize") == 10)
    let retained = try Data(contentsOf: database)
    precondition(retained == Data("history-fixture".utf8))
    print("PASS: existing history reused without copying; preferences preserved; migration runs once")
  }
}
