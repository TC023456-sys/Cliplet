import Cocoa

class About {
  @objc func openAbout(_ sender: NSMenuItem?) {
    let credits = NSMutableAttributedString(string:
      "修改版维护：TC023456-sys\n基于 Maccy 2.7.1，非原作者官方版本\n\n",
      attributes: [.foregroundColor: NSColor.labelColor])
    let links = [
      ("Cliplet 项目与更新", "https://github.com/TC023456-sys/Cliplet"),
      ("反馈问题", "https://github.com/TC023456-sys/Cliplet/issues"),
      ("原作者 Alexey Rodionov / p0deje", "https://github.com/p0deje"),
      ("原项目 Maccy", "https://github.com/p0deje/Maccy"),
      ("原作者官网", "https://maccy.app"),
      ("MIT 许可证", "https://github.com/TC023456-sys/Cliplet/blob/main/LICENSE")
    ]
    for (label, url) in links {
      credits.append(NSAttributedString(string: label, attributes: [.link: url]))
      credits.append(NSAttributedString(string: "\n"))
    }
    credits.append(NSAttributedString(string: "\n保留 Maccy 原作者及贡献者的版权和 MIT 许可。\nCliplet 使用临时签名，未经 Apple 公证。"))
    credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Cliplet", .credits: credits])
  }
}
