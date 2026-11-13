import SwiftUI

extension View {
  func onMouseMove(_ mouseMoved: @escaping () -> Void) -> some View {
    modifier(MouseMovedViewModifier(mouseMoved))
  }
}

struct MouseMovedViewModifier: ViewModifier {
  let mouseMoved: () -> Void

  init(_ mouseMoved: @escaping () -> Void) {
    self.mouseMoved = mouseMoved
  }

  func body(content: Content) -> some View {
    content.background(
      GeometryReader { geo in
        Representable(
          mouseMoved: mouseMoved,
          frame: geo.frame(in: .global)
        )
      }
    )
  }

  // The panel deliberately stays non-key to preserve the source app's selection.
  // Remote tools can also warp the pointer without delivering mouseMoved events.
  private class TrackingView: NSView {
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
        self?.checkPointer()
      }
      self.timer = timer
      RunLoop.main.add(timer, forMode: .common)
    }

    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      trackingAreas.forEach { removeTrackingArea($0) }
      addTrackingArea(NSTrackingArea(
        rect: .zero,
        options: [.activeAlways, .inVisibleRect, .mouseMoved],
        owner: self,
        userInfo: nil
      ))
    }

    override func mouseMoved(with event: NSEvent) {
      checkPointer()
    }

    private func checkPointer() {
      let location = NSEvent.mouseLocation
      defer { previousLocation = location }
      guard let window, window.isVisible,
            let previousLocation, location != previousLocation else { return }
      let local = convert(window.convertPoint(fromScreen: location), from: nil)
      guard visibleRect.contains(local) else { return }
      mouseMoved?()
    }

    func stopTracking() {
      timer?.invalidate()
      timer = nil
      mouseMoved = nil
    }

    deinit { timer?.invalidate() }
  }

  private struct Representable: NSViewRepresentable {
    let mouseMoved: () -> Void
    let frame: NSRect

    func makeNSView(context: Context) -> TrackingView {
      let view = TrackingView(frame: frame)
      view.mouseMoved = mouseMoved
      return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
      nsView.mouseMoved = mouseMoved
    }

    static func dismantleNSView(_ nsView: TrackingView, coordinator: ()) {
      nsView.stopTracking()
    }
  }
}
