import AppKit
import DragShelfCore

@MainActor
final class DragPasteboardProbe {
    private let pasteboard = NSPasteboard(name: .drag)

    func snapshot() -> DragDetectionEngine.PasteboardSnapshot {
        DragDetectionEngine.PasteboardSnapshot(
            changeCount: pasteboard.changeCount,
            hasSupportedType: pasteboard.types?.contains(.fileURL) == true
        )
    }
}
