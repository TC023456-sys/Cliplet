import Defaults
import KeyboardShortcuts
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel<ContentView>!

  @objc
  private lazy var statusItem: NSStatusItem = {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.behavior = .removalAllowed
    statusItem.button?.action = #selector(performStatusItemClick)
    statusItem.button?.image = Defaults[.menuIcon].image
    statusItem.button?.imagePosition = .imageLeft
    statusItem.button?.target = self
    return statusItem
  }()

  private var isStatusItemDisabled: Bool {
    Defaults[.ignoreEvents] || Defaults[.enabledPasteboardTypes].isEmpty
  }

  private var statusItemVisibilityObserver: NSKeyValueObservation?

  func applicationWillFinishLaunching(_ notification: Notification) { // swiftlint:disable:this function_body_length
    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      // Start from a clean slate for the isolated testing preferences.
      UserDefaults.standard.removePersistentDomain(forName: Defaults.Keys.testingSuiteName)
    }
    #endif

    ClipletLegacyData.preparePreferences()
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { _ in
      if PinyinFocusRecovery.shared.enabled && PinyinFocusRecovery.shared.tap == nil {
        PinyinFocusRecovery.shared.start()
      }
    }

    // Bridge FloatingPanel via AppDelegate.
    AppState.shared.appDelegate = self

    Clipboard.shared.onNewCopy { History.shared.add($0) }
    Clipboard.shared.start()

    Task {
      for await _ in Defaults.updates(.clipboardCheckInterval, initial: false) {
        Clipboard.shared.restart()
      }
    }

    statusItemVisibilityObserver = observe(\.statusItem.isVisible, options: .new) { _, change in
      if let newValue = change.newValue, Defaults[.showInStatusBar] != newValue {
        Defaults[.showInStatusBar] = newValue
      }
    }

    Task {
      for await value in Defaults.updates(.showInStatusBar) {
        statusItem.isVisible = value
      }
    }

    Task {
      for await value in Defaults.updates(.menuIcon, initial: false) {
        statusItem.button?.image = value.image
      }
    }

    synchronizeMenuIconText()
    Task {
      for await value in Defaults.updates(.showRecentCopyInMenuBar) {
        if value {
          statusItem.button?.title = AppState.shared.menuIconText
        } else {
          statusItem.button?.title = ""
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.ignoreEvents) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }

    Task {
      for await _ in Defaults.updates(.enabledPasteboardTypes) {
        statusItem.button?.appearsDisabled = isStatusItemDisabled
      }
    }
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    PinyinFocusRecovery.shared.start()
    migrateUserDefaults()
    disableUnusedGlobalHotkeys()

    panel = FloatingPanel(
      contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
      identifier: Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy",
      statusBarButton: statusItem.button,
      onClose: {
        AppState.shared.popup.reset()
        AppState.shared.history.releaseImageCaches()
      }
    ) {
      ContentView()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    panel.toggle(height: AppState.shared.popup.height)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    PinyinFocusRecovery.shared.stop()
    if Defaults[.clearOnQuit] {
      AppState.shared.history.clear()
    }
  }

  private func ensureMigration(key: String, _ action: () -> Void) {
    if Defaults[.migrations][key] != true {
      action()
      Defaults[.migrations][key] = true
    }
  }

  private func migrateUserDefaults() {
    ensureMigration(key: "2024-07-01-version-2") {
      // Start 2.x from scratch.
      Defaults.reset(.migrations)

      // Inverse hide* configuration keys.
      Defaults[.showFooter] = !UserDefaults.standard.bool(forKey: "hideFooter")
      Defaults[.showSearch] = !UserDefaults.standard.bool(forKey: "hideSearch")
      Defaults[.showTitle] = !UserDefaults.standard.bool(forKey: "hideTitle")
      UserDefaults.standard.removeObject(forKey: "hideFooter")
      UserDefaults.standard.removeObject(forKey: "hideSearch")
      UserDefaults.standard.removeObject(forKey: "hideTitle")

      Defaults[.migrations]["2024-07-01-version-2"] = true
    }

    ensureMigration(key: "2025-07-04-add-jpeg-heic") {
      var types = Defaults[.enabledPasteboardTypes]
      if !types.intersection(StorageType.images.types).isEmpty {
        types.formUnion(StorageType.images.types)
      }
      Defaults[.enabledPasteboardTypes] = types
    }

    // The following defaults are not used in Maccy 2.x
    // and should be removed in 3.x.
    // - LaunchAtLogin__hasMigrated
    // - avoidTakingFocus
    // - saratovSeparator
    // - maxMenuItemLength
    // - maxMenuItems
  }

  @objc
  private func performStatusItemClick() {
    if let event = NSApp.currentEvent {
      let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

      if modifierFlags.contains(.option) {
        Defaults[.ignoreEvents].toggle()

        if modifierFlags.contains(.shift) {
          Defaults[.ignoreOnlyNextEvent] = Defaults[.ignoreEvents]
        }

        return
      }
    }

    panel.toggle(height: AppState.shared.popup.height, at: .statusItem)
  }

  private func synchronizeMenuIconText() {
    _ = withObservationTracking {
      AppState.shared.menuIconText
    } onChange: {
      DispatchQueue.main.async {
        if Defaults[.showRecentCopyInMenuBar] {
          self.statusItem.button?.title = AppState.shared.menuIconText
        }
        self.synchronizeMenuIconText()
      }
    }
  }

  private func disableUnusedGlobalHotkeys() {
    let names: [KeyboardShortcuts.Name] = [.delete, .pin, .togglePreview]
    KeyboardShortcuts.disable(names)

    NotificationCenter.default.addObserver(
      forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil,
      queue: nil
    ) { notification in
      if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name, names.contains(name) {
        KeyboardShortcuts.disable(name)
      }
    }
  }
}

// Automatic remote Pinyin focus recovery; runs inside the existing Cliplet process.
final class PinyinRecoveryWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

final class PinyinFocusRecovery: NSObject, ObservableObject {
  static let shared = PinyinFocusRecovery()
  @Published var enabled = UserDefaults.standard.object(forKey: "remotePinyinRecovery") as? Bool ?? true {
    didSet {
      UserDefaults.standard.set(enabled, forKey: "remotePinyinRecovery")
      if enabled { start() } else { stop(); statusText = "已关闭" }
    }
  }
  @Published private(set) var statusText = "等待辅助功能权限"
  private var started = false
  var observer: AXObserver?
  var observedApp: AXUIElement?
  var workspaceToken: NSObjectProtocol?
  var sourceToken: NSObjectProtocol?
  var lastField: AXUIElement?
  var preparedField: AXUIElement?
  var preparedPID: pid_t = 0
  var typingGeneration = 0
  var pending: DispatchWorkItem?
  var restoring = false
  var disabledForSession = false
  var ignoreUntil = Date.distantPast
  var tap: CFMachPort?
  var tapSource: CFRunLoopSource?
  var buffered: [CGEvent] = []
  var originalPID: pid_t = 0
  let replayTag: Int64 = 0x50494E59494E
  var recoveries = 0
  let window = PinyinRecoveryWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false)

  func start() {
    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") { return }
    #endif
    guard enabled else { return }
    guard AXIsProcessTrusted() else { statusText = "请在系统设置中允许 Cliplet 的辅助功能权限"; return }
    guard installTap() else { statusText = "键盘事件监听暂不可用，请重新检查权限"; return }
    statusText = "自动修复已启用"
    if started { attach(); return }
    started = true
    window.alphaValue = 0.01
    window.isReleasedWhenClosed = false
    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    window.contentView?.addSubview(field)
    workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
      guard let self, !self.restoring, Date() >= self.ignoreUntil else { return }
      self.attach()
    }
    sourceToken = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main) { [weak self] _ in
      guard let self, !self.restoring else { return }
      self.lastField = nil
      self.schedule()
    }
    attach()
  }

  var clipboardPanelIsOpen: Bool { AppState.shared.appDelegate?.panel?.isPresented == true }

  func suspendForClipboardPanel() {
    pending?.cancel()
    preparedField = nil
  }

  func isPinyin() -> Bool {
    let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
    let id = Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() as? String
    return id == "com.apple.inputmethod.SCIM.ITABC" || id == "com.apple.inputmethod.TCIM.Pinyin"
  }

  func attr(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
  }

  func focusedTextField() -> (NSRunningApplication, AXUIElement)? {
    guard let app = NSWorkspace.shared.frontmostApplication,
          app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(ax, 0.05)
    guard let value = attr(ax, kAXFocusedUIElementAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    let field = value as! AXUIElement
    let role = attr(field, kAXRoleAttribute) as? String
    let subrole = attr(field, kAXSubroleAttribute) as? String
    guard subrole != kAXSecureTextFieldSubrole as String else { return nil }
    guard role == kAXTextFieldRole as String || role == kAXTextAreaRole as String || attr(field, kAXSelectedTextRangeAttribute) != nil else { return nil }
    return (app, field)
  }

  func attach() {
    pending?.cancel()
    if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
    observer = nil
    observedApp = nil
    lastField = nil
    preparedField = nil
    guard enabled, !disabledForSession, AXIsProcessTrusted(), tap != nil,
          let app = NSWorkspace.shared.frontmostApplication,
          app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
    var created: AXObserver?
    let callback: AXObserverCallback = { _, _, _, context in
      guard let context else { return }
      let owner = Unmanaged<PinyinFocusRecovery>.fromOpaque(context).takeUnretainedValue()
      owner.schedule()
    }
    guard AXObserverCreate(app.processIdentifier, callback, &created) == .success, let created else { return }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.05)
    let context = Unmanaged.passUnretained(self).toOpaque()
    AXObserverAddNotification(created, element, kAXFocusedUIElementChangedNotification as CFString, context)
    AXObserverAddNotification(created, element, kAXFocusedWindowChangedNotification as CFString, context)
    observer = created
    observedApp = element
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
    schedule()
  }

  // Focus changes prepare a candidate only. They never activate a window.
  func schedule() {
    guard enabled, !disabledForSession, !restoring, !clipboardPanelIsOpen, Date() >= ignoreUntil, tap != nil, isPinyin() else { return }
    pending?.cancel()
    preparedField = nil
    let generation = typingGeneration
    let job = DispatchWorkItem { [weak self] in
      guard let self, generation == self.typingGeneration,
            let (app, field) = self.focusedTextField(), !self.menuIsOpen(for: app) else { return }
      if let lastField = self.lastField, CFEqual(lastField, field) { return }
      self.preparedField = field
      self.preparedPID = app.processIdentifier
    }
    pending = job
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: job)
  }

  func menuIsOpen(for app: NSRunningApplication) -> Bool {
    let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
    guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else { return true }
    return windows.contains {
      $0[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier &&
      $0[kCGWindowLayer as String] as? Int == menuLevel
    }
  }

  func finishBufferedInput() {
    let targetStillFocused = !clipboardPanelIsOpen && NSWorkspace.shared.frontmostApplication?.processIdentifier == originalPID
    restoring = false
    ignoreUntil = Date().addingTimeInterval(0.35)
    for event in buffered {
      event.setIntegerValueField(.eventSourceUserData, value: replayTag)
      if targetStillFocused { event.post(tap: .cghidEventTap) }
      else { event.postToPid(originalPID) }
    }
    buffered.removeAll(keepingCapacity: false)
  }

  func repairBeforeFirstKey(field expected: AXUIElement, pid: pid_t) {
    guard enabled, !disabledForSession, !clipboardPanelIsOpen, !IsSecureEventInputEnabled(), isPinyin(),
          let (app, field) = focusedTextField(), app.processIdentifier == pid,
          CFEqual(expected, field), !menuIsOpen(for: app) else {
      finishBufferedInput()
      return
    }
    lastField = field
    let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard TISSelectInputSource(source) == noErr else { finishBufferedInput(); return }
    window.makeKeyAndOrderFront(nil)
    if let text = window.contentView?.subviews.first { window.makeFirstResponder(text) }
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
      guard let self else { return }
      self.window.orderOut(nil)
      if self.clipboardPanelIsOpen { self.finishBufferedInput(); return }
      // Respect a deliberate switch to a different application during recovery.
      let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
      if frontPID == ProcessInfo.processInfo.processIdentifier || frontPID == app.processIdentifier {
        app.activate(options: [])
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.finishBufferedInput()
        self.recoveries += 1

      }
    }
  }

  func installTap() -> Bool {
    if tap != nil { return true }
    let eventTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
    let mask = eventTypes.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
    let callback: CGEventTapCallBack = { _, type, event, context in
      guard let context else { return Unmanaged.passUnretained(event) }
      let owner = Unmanaged<PinyinFocusRecovery>.fromOpaque(context).takeUnretainedValue()
      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
      }
      if event.getIntegerValueField(.eventSourceUserData) == owner.replayTag { return Unmanaged.passUnretained(event) }
      if type == .rightMouseDown || type == .otherMouseDown {
        owner.pending?.cancel()
        owner.preparedField = nil
        return Unmanaged.passUnretained(event)
      }
      if type == .leftMouseDown {
        owner.pending?.cancel()
        owner.preparedField = nil
        // Selection, double-clicks and context-menu actions never move focus.
        // A later ordinary click may prepare a candidate but still cannot repair it.
        if event.getIntegerValueField(.mouseEventClickState) == 1 { owner.schedule() }
        return Unmanaged.passUnretained(event)
      }
      if owner.clipboardPanelIsOpen && !owner.restoring {
        owner.suspendForClipboardPanel()
        return Unmanaged.passUnretained(event)
      }
      // Store keyboard events only during the bounded first-character hand-off.
      if owner.restoring, let copy = event.copy() {
        owner.buffered.append(copy)
        return nil
      }
      if type == .keyDown {
        owner.typingGeneration += 1
        owner.pending?.cancel()
        let forbidden: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let letters: Set<Int64> = [0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,31,32,34,35,37,38,40,45,46]
        if owner.enabled, !owner.disabledForSession, owner.isPinyin(),
           event.flags.intersection(forbidden).isEmpty, letters.contains(code),
           let field = owner.preparedField, let first = event.copy() {
          let pid = owner.preparedPID
          owner.preparedField = nil
          owner.originalPID = pid
          owner.buffered = [first]
          owner.restoring = true
          DispatchQueue.main.async { owner.repairBeforeFirstKey(field: field, pid: pid) }
          return nil
        }
        // Once text starts without a prepared candidate, don't repair mid-composition.
        if event.flags.intersection(forbidden).isEmpty { owner.preparedField = nil }
      }
      return Unmanaged.passUnretained(event)
    }
    guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
    tap = created
    tapSource = CFMachPortCreateRunLoopSource(nil, created, 0)
    if let tapSource { CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes) }
    CGEvent.tapEnable(tap: created, enable: true)
    return true
  }

  func stop() {
    pending?.cancel()
    if let workspaceToken { NSWorkspace.shared.notificationCenter.removeObserver(workspaceToken) }
    if let sourceToken { DistributedNotificationCenter.default().removeObserver(sourceToken) }
    workspaceToken = nil
    sourceToken = nil
    if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
    observer = nil
    observedApp = nil
    if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
    if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
    tap = nil
    tapSource = nil
    lastField = nil
    preparedField = nil
    started = false
  }
}

// Keep sandbox-era history and preferences when adding assistive input handling.
enum ClipletLegacyData {
  static var containerLibrary: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Containers/com.tc023456.Cliplet/Data/Library")
  }
  static func preparePreferences() {
    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") { return }
    #endif
    let defaults = UserDefaults.standard
    let marker = "pinyinIntegrationPreferencesMigrated"
    guard !defaults.bool(forKey: marker),
      let data = try? Data(contentsOf: containerLibrary.appending(path: "Preferences/com.tc023456.Cliplet.plist")),
      let values = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    else { return }
    let existing = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.tc023456.Cliplet") ?? [:]
    for (key, value) in values where existing[key] == nil {
      defaults.set(value, forKey: key)
    }
    defaults.set(true, forKey: marker)
  }
}
