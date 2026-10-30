import AppKit

@main
struct SelectionTests {
  static func main() {
    var raw = CFRange(location: 2, length: 4)
    let encoded = AXValueCreate(.cfRange, &raw)!
    precondition(PasteSelection.decodeRange(encoded)?.length == 4)
    precondition(PasteSelection.decodeRange(nil) == nil)
    precondition(PasteSelection.decodeRange("unsupported" as CFString) == nil)
    let selected = CFRange(location: 5, length: 8)
    for location in [5, 9, 13] {
      precondition(PasteSelection.canRestore(original: selected, current: CFRange(location: location, length: 0)))
    }
    precondition(PasteSelection.canRestore(original: selected, current: selected))
    for current in [CFRange(location: 4, length: 0), CFRange(location: 14, length: 0),
                    CFRange(location: 5, length: 3), CFRange(location: 6, length: 8)] {
      precondition(!PasteSelection.canRestore(original: selected, current: current))
    }
    for original in [CFRange(location: -1, length: 8), CFRange(location: 5, length: 0),
                     CFRange(location: Int.max, length: 1)] {
      precondition(!PasteSelection.canRestore(original: original, current: selected))
    }
    print("PASS: retain selection; restore collapsed caret; reject changed selection, empty range and overflow")
  }
}
