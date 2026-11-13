import AppKit
import SwiftUI

@main struct Check {
  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    var selected = -1
    var selections: [Int] = []
    var movements = 0
    let rows = ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(0..<40, id: \.self) { row in
          Text("Row \(row)").frame(maxWidth: .infinity).frame(height: 40)
            .onPointerMoveInside { selected = row; selections.append(row) }
        }
      }
    }.frame(width: 300, height: 400).onMouseMove { movements += 1 }
    let panel = NSPanel(contentRect: NSRect(x: 100, y: 100, width: 300, height: 400),
      styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.contentView = NSHostingView(rootView: rows)
    panel.orderFrontRegardless()
    defer { panel.orderOut(nil) }
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    precondition(!panel.isKeyWindow)
    let rects = clipletPointerRowRects(in: panel)
    precondition(rects.count >= 8, "Need a real scrollable list with visible rows")
    for i in 0..<rects.count {
      for j in 0..<i {
        precondition(rects[i].intersection(rects[j]).isEmpty, "Row hit regions must never overlap")
      }
    }
    for index in 0..<1000 {
      let row = index % min(8, rects.count)
      let rect = rects[row]
      let before = selections.count
      sampleClipletPointer(in: panel.contentView!, at: NSPoint(x: rect.midX, y: rect.midY))
      precondition(selected == row, "Pointer must select the actual row, never a different row")
      precondition(selections.count == before + 1, "Each movement must select exactly one row")
    }
    let stationary = rects[7]
    let count = selections.count
    selected = 999 // Simulate a subsequent keyboard selection under a stationary pointer.
    for _ in 0..<100 {
      sampleClipletPointer(in: panel.contentView!, at: NSPoint(x: stationary.midX, y: stationary.midY))
    }
    precondition(selected == 999 && selections.count == count, "Stationary pointer must preserve keyboard selection")
    panel.orderOut(nil)
    let hiddenCount = selections.count
    sampleClipletPointer(in: panel.contentView!, at: NSPoint(x: rects[0].midX, y: rects[0].midY))
    precondition(selections.count == hiddenCount, "Hidden panel must not select rows")
    print("PASS: real list hit regions do not overlap; 1000 pointer jumps select exactly one correct row; stationary keyboard selection and hidden panel preserved")
  }
}
