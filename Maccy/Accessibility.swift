import AppKit

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
