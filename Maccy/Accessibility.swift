import AppKit
import OSLog

struct Accessibility {
  private static var allowed: Bool { AXIsProcessTrustedWithOptions(nil) }

  @discardableResult
  static func check() -> Bool {
    guard !allowed else { return true }

    let alert = NSAlert()
    alert.messageText = "自动粘贴需要辅助功能权限"
    alert.informativeText = "内容已复制到剪贴板，可以手动按 ⌘V 粘贴。若要选择历史记录后直接粘贴，请在系统设置 → 隐私与安全性 → 辅助功能中允许 Cliplet。"
    alert.addButton(withTitle: "打开系统设置")
    alert.addButton(withTitle: "稍后")
    if alert.runModal() == .alertFirstButtonReturn,
       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
    return false
  }
}

// A short-lived selection bookmark, never clipboard text or a synthetic click.
// Only restore in the same focused control; never move focus to another app.
final class PasteSelection {
  private static let logger = Logger(subsystem: "com.tc023456.Cliplet", category: "Selection")
  private let element: AXUIElement
  private let application: AXUIElement
  private let processID: pid_t
  private let range: CFRange
  private let capturedAt = ProcessInfo.processInfo.systemUptime

  private init(element: AXUIElement, application: AXUIElement, processID: pid_t, range: CFRange) {
    self.element = element
    self.application = application
    self.processID = processID
    self.range = range
  }

  static func capture() -> PasteSelection? {
    guard AXIsProcessTrusted() else {
      logger.notice("capture: accessibility-not-trusted")
      return nil
    }
    guard let app = NSWorkspace.shared.frontmostApplication,
          app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
      logger.notice("capture: no-external-app")
      return nil
    }
    let application = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.3)
    guard let focused = focusedElement(in: application) else {
      logger.notice("capture: focused-element-unavailable")
      return nil
    }
    guard let range = selectedRange(in: focused) else {
      logger.notice("capture: selection-range-unavailable")
      return nil
    }
    guard range.length > 0 else {
      logger.notice("capture: empty-selection")
      return nil
    }
    // Custom text controls may not implement AXIsAttributeSettable accurately.
    // Save the readable range and verify the actual write when pasting instead.
    logger.notice("capture: saved")
    return PasteSelection(element: focused, application: application,
                          processID: app.processIdentifier, range: range)
  }

  // A failed restore must not turn a replacement into an insertion elsewhere.
  func restore() -> Bool {
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID,
          ProcessInfo.processInfo.systemUptime - capturedAt < 120,
          let focused = Self.focusedElement(in: application), CFEqual(focused, element),
          let current = Self.selectedRange(in: element),
          Self.canRestore(original: range, current: current) else {
      Self.logger.notice("restore: target-or-selection-changed")
      return false
    }
    if current.location == range.location && current.length == range.length {
      Self.logger.notice("restore: selection-already-intact")
      return true
    }
    var restoredRange = range
    guard let value = AXValueCreate(.cfRange, &restoredRange),
          AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success,
          let result = Self.selectedRange(in: element) else {
      Self.logger.notice("restore: write-failed")
      return false
    }
    let restored = result.location == range.location && result.length == range.length
    Self.logger.notice("restore: verified=\(restored, privacy: .public)")
    return restored
  }

  static func canRestore(original: CFRange, current: CFRange) -> Bool {
    guard original.location >= 0, original.length > 0,
          original.location <= Int.max - original.length else { return false }
    if current.location == original.location && current.length == original.length { return true }
    // Accept only a collapsed caret within the original selection. A different
    // selection/caret belongs to a subsequent user action and must be left alone.
    return current.length == 0 && current.location >= original.location &&
      current.location <= original.location + original.length
  }

  private static func focusedElement(in application: AXUIElement) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
          let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
  }

  private static func selectedRange(in element: AXUIElement) -> CFRange? {
    var value: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
       let range = decodeRange(value) { return range }
    value = nil
    guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangesAttribute as CFString, &value) == .success,
          let ranges = value as? [AXValue], ranges.count == 1 else { return nil }
    return decodeRange(ranges[0])
  }

  static func decodeRange(_ value: CFTypeRef?) -> CFRange? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == .cfRange else { return nil }
    var range = CFRange()
    guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
    return range
  }
}
