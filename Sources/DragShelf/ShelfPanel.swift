import AppKit

/// Allows a clicked file to take keyboard focus without activating DragShelf.
@MainActor
final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
