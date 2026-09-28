import XCTest
@testable import DragShelfCore

final class DragDetectionEngineTests: XCTestCase {
    private let stale = DragDetectionEngine.PasteboardSnapshot(changeCount: 4, hasSupportedType: true)
    private let fileDrag = DragDetectionEngine.PasteboardSnapshot(changeCount: 5, hasSupportedType: true)

    func testRevealsOnlyAfterFreshSupportedDragAndOnlyOnce() {
        var engine = DragDetectionEngine()
        XCTAssertEqual(engine.handle(.mouseDown, pasteboard: stale), .none)
        XCTAssertEqual(engine.handle(.mouseDragged, pasteboard: stale), .none)
        XCTAssertEqual(engine.handle(.sample, pasteboard: fileDrag), .reveal)
        XCTAssertEqual(engine.handle(.mouseDragged, pasteboard: fileDrag), .none)
    }

    func testWindowMovementDoesNotRevealWithOldPasteboard() {
        var engine = DragDetectionEngine()
        XCTAssertEqual(engine.handle(.mouseDown, pasteboard: stale), .none)
        XCTAssertEqual(engine.handle(.mouseDragged, pasteboard: stale), .none)
        XCTAssertEqual(engine.handle(.sample, pasteboard: stale), .none)
    }

    func testNewUnsupportedPayloadDoesNotReveal() {
        var engine = DragDetectionEngine()
        XCTAssertEqual(engine.handle(.mouseDown, pasteboard: stale), .none)
        let unsupported = DragDetectionEngine.PasteboardSnapshot(changeCount: 5, hasSupportedType: false)
        XCTAssertEqual(engine.handle(.mouseDragged, pasteboard: unsupported), .none)
    }

    func testNewPasteboardWithoutPointerDragDoesNotReveal() {
        var engine = DragDetectionEngine()
        XCTAssertEqual(engine.handle(.mouseDown, pasteboard: stale), .none)
        XCTAssertEqual(engine.handle(.sample, pasteboard: fileDrag), .none)
    }

    func testMouseUpEndsSessionAndNextDragCanReveal() {
        var engine = DragDetectionEngine()
        XCTAssertEqual(engine.handle(.mouseDown, pasteboard: stale), .none)
        XCTAssertEqual(engine.handle(.mouseDragged, pasteboard: fileDrag), .reveal)
        XCTAssertEqual(engine.handle(.mouseUp, pasteboard: fileDrag), .end)
        XCTAssertEqual(engine.handle(.sample, pasteboard: fileDrag), .none)
        XCTAssertEqual(engine.handle(.mouseDown, pasteboard: fileDrag), .none)
        let another = DragDetectionEngine.PasteboardSnapshot(changeCount: 6, hasSupportedType: true)
        XCTAssertEqual(engine.handle(.mouseDragged, pasteboard: another), .reveal)
    }
}
