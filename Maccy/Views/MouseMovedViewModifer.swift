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
      NotificationCenter.default.post(name: pointerMovedNotification, object: window)
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

private let pointerMovedNotification = Notification.Name("ClipletPointerMoved")

// Hit-test visible rows after an actual pointer displacement, including warps
// that do not generate SwiftUI hover callbacks. All rows share the panel timer.
private struct PointerTarget: NSViewRepresentable {
  let movedInside: () -> Void

  class TargetView: NSView {
    var movedInside: (() -> Void)?
    private var observer: NSObjectProtocol?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      stop()
      guard window != nil else { return }
      observer = NotificationCenter.default.addObserver(
        forName: pointerMovedNotification, object: nil, queue: .main
      ) { [weak self] notification in
        guard let self, let window = self.window, window.isVisible,
              (notification.object as? NSWindow) === window else { return }
        let point = self.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        if self.visibleRect.contains(point) { self.movedInside?() }
      }
    }

    func stop() {
      if let observer { NotificationCenter.default.removeObserver(observer) }
      observer = nil
    }

    deinit { stop() }
  }

  func makeNSView(context: Context) -> TargetView {
    let view = TargetView()
    view.movedInside = movedInside
    return view
  }

  func updateNSView(_ nsView: TargetView, context: Context) {
    nsView.movedInside = movedInside
  }

  static func dismantleNSView(_ nsView: TargetView, coordinator: ()) {
    nsView.stop()
    nsView.movedInside = nil
  }
}

extension View {
  func onPointerMoveInside(_ action: @escaping () -> Void) -> some View {
    background(PointerTarget(movedInside: action))
  }
}
