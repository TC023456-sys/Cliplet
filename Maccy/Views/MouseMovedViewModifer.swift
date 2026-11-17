import SwiftUI

// Each row only registers its visible hit region. One panel-level tracker owns
// selection; native hover and remote pointer polling must never race each other.
private final class PointerRowView: NSView {
  static let rows = NSHashTable<PointerRowView>.weakObjects()
  var movedInside: (() -> Void)?

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    Self.rows.remove(self)
    if window != nil { Self.rows.add(self) }
  }

  func contains(screenPoint: NSPoint, in panel: NSWindow) -> Bool {
    guard window === panel, !isHiddenOrHasHiddenAncestor, !visibleRect.isEmpty else { return false }
    let screenRect = panel.convertToScreen(convert(bounds.intersection(visibleRect), to: nil))
    return screenRect.contains(screenPoint)
  }
}

private struct PointerRow: NSViewRepresentable {
  let action: () -> Void

  func makeNSView(context: Context) -> PointerRowView {
    let view = PointerRowView()
    view.movedInside = action
    return view
  }

  func updateNSView(_ nsView: PointerRowView, context: Context) { nsView.movedInside = action }

  static func dismantleNSView(_ nsView: PointerRowView, coordinator: ()) {
    PointerRowView.rows.remove(nsView)
    nsView.movedInside = nil
  }
}

extension View {
  func onMouseMove(_ mouseMoved: @escaping () -> Void) -> some View {
    background(PanelPointerTracker(mouseMoved: mouseMoved))
  }

  func onPointerMoveInside(_ action: @escaping () -> Void) -> some View {
    background(PointerRow(action: action))
  }
}

private struct PanelPointerTracker: NSViewRepresentable {
  let mouseMoved: () -> Void

  class TrackingView: NSView {
    var mouseMoved: (() -> Void)?
    private var timer: Timer?
    private var previousLocation: NSPoint?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      timer?.invalidate()
      timer = nil
      previousLocation = NSEvent.mouseLocation
      guard window != nil else { return }
      let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
        self?.samplePointer()
      }
      self.timer = timer
      RunLoop.main.add(timer, forMode: .common)
    }

    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      trackingAreas.forEach { removeTrackingArea($0) }
      addTrackingArea(NSTrackingArea(rect: .zero,
        options: [.activeAlways, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) { samplePointer() }

    private func samplePointer() { samplePointer(at: NSEvent.mouseLocation) }

    func samplePointer(at point: NSPoint) {
      defer { previousLocation = point }
      guard let previousLocation, point != previousLocation,
            let window, window.isVisible, !isHiddenOrHasHiddenAncestor,
            window.convertToScreen(convert(bounds.intersection(visibleRect), to: nil)).contains(point) else { return }
      // Freeze one screen position and resolve exactly one row before changing
      // any state. During overlapping layout animations keep the selection.
      let matches = PointerRowView.rows.allObjects.filter { $0.contains(screenPoint: point, in: window) }
      guard matches.count == 1 else { return }
      mouseMoved?()
      matches[0].movedInside?()
    }

    #if CLIPLET_HOVER_TESTS
    func pauseTimerForTesting() {
      timer?.invalidate()
      timer = nil
    }
    #endif

    func stop() {
      timer?.invalidate()
      timer = nil
      mouseMoved = nil
    }

    deinit { timer?.invalidate() }
  }

  func makeNSView(context: Context) -> TrackingView {
    let view = TrackingView()
    view.mouseMoved = mouseMoved
    return view
  }

  func updateNSView(_ nsView: TrackingView, context: Context) { nsView.mouseMoved = mouseMoved }

  static func dismantleNSView(_ nsView: TrackingView, coordinator: ()) { nsView.stop() }
}

#if CLIPLET_HOVER_TESTS
// Inject coordinates into the real tracker without moving the user's cursor.
func sampleClipletPointer(in view: NSView, at point: NSPoint) {
  if let tracker = view as? PanelPointerTracker.TrackingView {
    tracker.pauseTimerForTesting()
    tracker.samplePointer(at: point)
  }
  view.subviews.forEach { sampleClipletPointer(in: $0, at: point) }
}

func clipletPointerRowRects(in window: NSWindow) -> [NSRect] {
  PointerRowView.rows.allObjects.filter { $0.window === window }.map {
    window.convertToScreen($0.convert($0.bounds.intersection($0.visibleRect), to: nil))
  }.filter { !$0.isEmpty }.sorted { $0.maxY > $1.maxY }
}
#endif
