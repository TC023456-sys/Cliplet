import AppKit
import SwiftUI

@main
struct NativeHoverCheck {
  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    var changes = 0
    let panel = NSPanel(contentRect: NSRect(x: 20, y: 20, width: 300, height: 400),
                        styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.contentView = NSHostingView(rootView:
      ScrollView {
        VStack {
          ForEach(0..<40) { row in Text("Row \(row)").frame(height: 30) }
        }
      }.frame(width: 300, height: 400).onMouseMove { changes += 1 })
    panel.orderFrontRegardless()
    defer { panel.orderOut(nil) }
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    precondition(!panel.isKeyWindow, "Test requires a non-key history panel")
    func areas(_ view: NSView) -> [NSTrackingArea] {
      view.trackingAreas + view.subviews.flatMap { areas($0) }
    }
    let candidates = areas(panel.contentView!).filter {
      $0.options.contains(.activeAlways) && $0.options.contains(.mouseMoved)
        && $0.options.contains(.mouseEnteredAndExited)
    }
    precondition(candidates.count == 1, "Exactly one native pointer listener must own navigation")
    let listener = candidates[0]
    precondition(!listener.options.contains(.activeInKeyWindow), "Listener must work without taking focus")
    let owner = listener.owner as! NSResponder
    let event = NSEvent.mouseEvent(with: .mouseMoved, location: NSPoint(x: 50, y: 50),
      modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
      context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
    let initial = changes
    for _ in 0..<1000 { owner.mouseMoved(with: event) }
    precondition(changes == initial + 1000, "Movement must have exactly one callback per native event")
    let stationary = changes
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    precondition(changes == stationary, "No polling may change navigation while the pointer is stationary")
    precondition(!panel.isKeyWindow, "Pointer tracking must preserve source focus")
    print("PASS: one native listener, non-key tracking, 1000 movements, stationary stability, focus preserved")
  }
}
