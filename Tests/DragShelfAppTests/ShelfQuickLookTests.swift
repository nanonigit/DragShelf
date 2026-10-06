import AppKit
import QuickLookUI
import XCTest
import DragShelfCore
@testable import DragShelf

final class ShelfQuickLookTests: XCTestCase {
    @MainActor
    private func makeView(mode: ShelfDisplayMode = .icons) -> ShelfDropView {
        let suite = "DragShelf.QuickLookTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let model = ShelfModel(history: ShelfHistoryStore(defaults: defaults))
        let file = URL(fileURLWithPath: #filePath)
        model.add([file, file.deletingLastPathComponent()])
        let view = ShelfDropView(frame: NSRect(x: 0, y: 0, width: 160, height: 220))
        view.model = model
        view.displayMode = mode
        return view
    }

    @MainActor
    func testHoverTargetsInBothModesExcludeControlsAndOutside() async {
        for mode in ShelfDisplayMode.allCases {
            let view = makeView(mode: mode)
            XCTAssertEqual(view.previewURL(at: NSPoint(x: 30, y: 75)), view.model?.files[0])
            XCTAssertNil(view.previewURL(at: NSPoint(x: 20, y: 20)))
            XCTAssertNil(view.previewURL(at: NSPoint(x: 2, y: 75)))
            XCTAssertNil(view.previewURL(at: NSPoint(x: 30, y: 230)))
            XCTAssertNil(view.previewURL(at: NSPoint(x: 140, y: 65)))
        }
    }

    @MainActor
    func testScrollAndMutationResolveCurrentFileInsteadOfStaleIndex() async {
        let view = makeView()
        // Use the same production scroll-offset setter as scrollWheel.
        view.scrollContent(by: -148)
        XCTAssertEqual(view.previewURL(at: NSPoint(x: 30, y: 75)), view.model?.files[1])
        view.model?.remove(at: 0)
        view.refreshContent()
        XCTAssertEqual(view.previewURL(at: NSPoint(x: 30, y: 75)), view.model?.files[0])
    }

    @MainActor
    func testMissingAndEmptyItemsCannotPreview() async {
        let view = makeView()
        view.model?.remove(at: 1)
        view.model?.remove(at: 0)
        XCTAssertNil(view.previewURL(at: NSPoint(x: 30, y: 75)))
        view.model?.add([URL(fileURLWithPath: "/nonexistent/DragShelf-test-\(UUID()).txt")])
        XCTAssertNil(view.previewURL(at: NSPoint(x: 30, y: 75)))
    }

    @MainActor
    func testOnlyPlainNonRepeatingSpaceTriggersPreview() async {
        func key(_ code: UInt16, flags: NSEvent.ModifierFlags = [], repeatKey: Bool = false) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                             timestamp: 0, windowNumber: 0, context: nil,
                             characters: " ", charactersIgnoringModifiers: " ",
                             isARepeat: repeatKey, keyCode: code)!
        }
        XCTAssertTrue(ShelfDropView.isPreviewKey(key(49)))
        XCTAssertTrue(ShelfDropView.isPreviewKey(key(49, flags: .capsLock)))
        for flags: NSEvent.ModifierFlags in [.command, .control, .option, .shift] {
            XCTAssertFalse(ShelfDropView.isPreviewKey(key(49, flags: flags)))
        }
        XCTAssertFalse(ShelfDropView.isPreviewKey(key(49, repeatKey: true)))
        XCTAssertFalse(ShelfDropView.isPreviewKey(key(53)))
    }

    @MainActor
    func testNativePreviewLifecycleAndRemoval() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.finishLaunching()
        NSApp.activate(ignoringOtherApps: true)
        let view = makeView()
        let window = ShelfPanel(contentRect: view.bounds,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.delegate = view
        window.orderFrontRegardless()
        window.makeFirstResponder(view)
        window.makeKey()
        try? await Task.sleep(for: .milliseconds(200))
        defer { view.endPreviewInteraction(); window.close() }
        guard window.isKeyWindow else {
            throw XCTSkip("Unhosted XCTest cannot acquire AppKit key focus. Verify preview lifecycle in the installed app; see verification.md.")
        }

        let url = view.model!.files[0]
        view.togglePreview(for: url)
        let panel = QLPreviewPanel.shared()!
        XCTAssertTrue(panel.currentController as AnyObject === view)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(view.numberOfPreviewItems(in: panel), 1)
        XCTAssertEqual(view.previewPanel(panel, previewItemAt: 0)?.previewItemURL, url)
        view.togglePreview(for: url)
        XCTAssertFalse(panel.isVisible)

        view.togglePreview(for: view.model!.files[1])
        XCTAssertTrue(panel.isVisible)
        view.model?.remove(at: 1)
        view.refreshContent()
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(panel.dataSource)
    }
}
