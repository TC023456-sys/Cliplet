import SwiftUI

#if !CLIPLET_DATA_TESTS
@main
struct MaccyApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  // It's impossible to create sceneless application,
  // so we are hacking this around by creating a menubar
  // scene that is always hidden.
  @State private var hiddenMenu: Bool = false

  init() {
    ClipletData.importLegacyPreferences()
  }

  var body: some Scene {
    MenuBarExtra("", isInserted: $hiddenMenu) {
      EmptyView()
    }
  }
}
#endif

enum ClipletData {
  static func databaseURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    let legacy = home.appending(path: "Library/Containers/com.tc023456.Cliplet/Data/Library/Application Support/Maccy/Storage.sqlite")
    if FileManager.default.fileExists(atPath: legacy.path) { return legacy }
    return home.appending(path: "Library/Application Support/Maccy/Storage.sqlite")
  }

  static func importLegacyPreferences(
    home: URL = FileManager.default.homeDirectoryForCurrentUser,
    defaults: UserDefaults = .standard,
    domain: String = Bundle.main.bundleIdentifier ?? "com.tc023456.Cliplet"
  ) {
    guard domain == "com.tc023456.Cliplet",
          !defaults.bool(forKey: "clipletDesktopPreferencesImported") else { return }
    let legacy = home.appending(path: "Library/Containers/com.tc023456.Cliplet/Data/Library/Preferences/com.tc023456.Cliplet.plist")
    if FileManager.default.fileExists(atPath: legacy.path) {
      guard let data = try? Data(contentsOf: legacy),
            let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        return // Never overwrite existing settings with unreadable legacy data.
      }
      for (key, value) in values { defaults.set(value, forKey: key) }
    }
    defaults.set(true, forKey: "clipletDesktopPreferencesImported")
  }
}
