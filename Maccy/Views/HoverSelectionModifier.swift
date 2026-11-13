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
    }.onHover { hovering in
      if hovering {
        if !appState.navigator.isKeyboardNavigating && !appState.navigator.isMultiSelectInProgress {
          appState.navigator.selectWithoutScrolling(id: id)
        } else {
          appState.navigator.hoverSelectionWhileKeyboardNavigating = id
        }
      } else if appState.navigator.hoverSelectionWhileKeyboardNavigating == id {
        appState.navigator.hoverSelectionWhileKeyboardNavigating = nil
      }
    }
  }
}

extension View {
  func hoverSelectionId(_ id: UUID) -> some View {
    modifier(HoverSelectionModifier(id: id))
  }
}
