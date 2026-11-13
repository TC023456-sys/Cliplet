import SwiftUI

private struct HoverSelectionModifier: ViewModifier {
  @Environment(AppState.self) private var appState
  var id: UUID

  func body(content: Content) -> some View {
    content.onPointerMoveInside {
      guard !appState.navigator.isMultiSelectInProgress else { return }
      appState.navigator.hoverSelectionWhileKeyboardNavigating = nil
      appState.navigator.isKeyboardNavigating = false
      appState.navigator.selectWithoutScrolling(id: id)
    }
  }
}

extension View {
  func hoverSelectionId(_ id: UUID) -> some View {
    modifier(HoverSelectionModifier(id: id))
  }
}
