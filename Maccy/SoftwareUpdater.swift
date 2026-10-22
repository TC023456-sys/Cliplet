import AppKit
import Observation

private final class ClipletUpdateTimer {
  var value: Timer?
  deinit { value?.invalidate() }
}

/// Only checks this fork. No upstream feed, silent binary downloads or installs.
@MainActor @Observable
class SoftwareUpdater {
  static let repository = "TC023456-sys/Cliplet"
  static let releasesURL = URL(string: "https://github.com/TC023456-sys/Cliplet/releases")!
  static let endpoint = URL(string: "https://api.github.com/repos/TC023456-sys/Cliplet/releases?per_page=30")!
  var automaticallyChecksForUpdates: Bool {
    didSet {
      UserDefaults.standard.set(automaticallyChecksForUpdates, forKey: "ClipletAutomaticUpdates")
      configureTimer()
    }
  }
  private let timer = ClipletUpdateTimer()
  private var checking = false

  init() {
    automaticallyChecksForUpdates = UserDefaults.standard.bool(forKey: "ClipletAutomaticUpdates")
    configureTimer()
  }
  private func configureTimer() {
    timer.value?.invalidate()
    timer.value = nil
    guard automaticallyChecksForUpdates else { return }
    timer.value = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
      Task { @MainActor in await self?.check(manual: false) }
    }
    Task { await check(manual: false) }
  }
  func checkForUpdates() { Task { await check(manual: true) } }

  struct Release: Decodable {
    let tag_name: String
    let html_url: String
    let draft: Bool
    let prerelease: Bool
  }
  static func version(_ tag: String) -> [Int]? {
    guard tag.hasPrefix("cliplet-v") else { return nil }
    let parts = tag.dropFirst("cliplet-v".count).split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    let numbers = parts.compactMap { Int($0) }
    guard numbers.count == 3, numbers.allSatisfy({ $0 >= 0 }) else { return nil }
    return numbers
  }
  static func trustedURL(_ release: Release) -> URL? {
    let expected = "https://github.com/\(repository)/releases/tag/\(release.tag_name)"
    guard !release.draft, !release.prerelease, version(release.tag_name) != nil,
          release.html_url == expected else { return nil }
    return URL(string: expected)
  }
  private func check(manual: Bool) async {
    guard !checking else { return }
    let key = "ClipletLastUpdateCheck"
    if !manual, let last = UserDefaults.standard.object(forKey: key) as? Date,
       Date().timeIntervalSince(last) < 86400 { return }
    checking = true
    defer { checking = false }
    UserDefaults.standard.set(Date(), forKey: key)
    do {
      let config = URLSessionConfiguration.ephemeral
      config.timeoutIntervalForRequest = 15
      let session = URLSession(configuration: config)
      defer { session.invalidateAndCancel() }
      var request = URLRequest(url: Self.endpoint)
      request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
      let (data, response) = try await session.data(for: request)
      guard let status = (response as? HTTPURLResponse)?.statusCode else { throw URLError(.badServerResponse) }
      if status == 404 {
        if manual { show("尚无公开版本", detail: "Cliplet 更新渠道已设为你的独立仓库。", url: Self.releasesURL) }
        return
      }
      guard status == 200, data.count < 2_000_000 else { throw URLError(.badServerResponse) }
      let releases = try JSONDecoder().decode([Release].self, from: data)
      let latest = releases.filter { Self.trustedURL($0) != nil }.max {
        Self.version($0.tag_name)!.lexicographicallyPrecedes(Self.version($1.tag_name)!)
      }
      let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
      let current = Self.version("cliplet-v" + installed) ?? [1, 0, 0]
      if let latest, current.lexicographicallyPrecedes(Self.version(latest.tag_name)!),
         let url = Self.trustedURL(latest) {
        show("发现 Cliplet 新版本", detail: latest.tag_name + "\n打开发布页后由你选择下载安装。", url: url)
      } else if manual {
        show("当前没有更新", detail: "仅检查 TC023456-sys/Cliplet 的正式发布。", url: nil)
      }
    } catch {
      if manual { show("暂时无法检查更新", detail: "请稍后重试，或打开你的 Cliplet 发布页。", url: Self.releasesURL) }
    }
  }
  private func show(_ title: String, detail: String, url: URL?) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = detail
    alert.addButton(withTitle: url == nil ? "好" : "打开发布页")
    if url != nil { alert.addButton(withTitle: "取消") }
    if alert.runModal() == .alertFirstButtonReturn, let url { NSWorkspace.shared.open(url) }
  }
}
