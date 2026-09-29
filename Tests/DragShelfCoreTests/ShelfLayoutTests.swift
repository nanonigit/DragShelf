import XCTest
@testable import DragShelfCore

final class ShelfLayoutTests: XCTestCase {
    func testListAndIconRowsMapToTheCorrectItem() {
        let list = ShelfLayout(mode: .list, count: 3)
        XCTAssertEqual(list.index(at: CGPoint(x: 30, y: 43)), 0)
        XCTAssertEqual(list.index(at: CGPoint(x: 30, y: 91)), 1)
        XCTAssertNil(list.index(at: CGPoint(x: 30, y: 210)))

        let icons = ShelfLayout(mode: .icons, count: 3)
        XCTAssertEqual(icons.index(at: CGPoint(x: 30, y: 80)), 0)
        XCTAssertEqual(icons.index(at: CGPoint(x: 30, y: 220)), 1)
        XCTAssertEqual(icons.index(at: CGPoint(x: 30, y: 370)), 2)
        XCTAssertNil(icons.index(at: CGPoint(x: 200, y: 80)))
        XCTAssertEqual(ShelfLayout.width, 160)
    }

    func testLongListIsCappedAndScrollable() {
        let layout = ShelfLayout(mode: .list, count: 20)
        XCTAssertEqual(layout.panelHeight, ShelfLayout.maximumHeight)
        XCTAssertGreaterThan(layout.maximumScrollOffset(panelHeight: layout.panelHeight), 0)
        XCTAssertEqual(layout.index(at: CGPoint(x: 30, y: 60), scrollOffset: 96), 2)
    }

    func testPlacementStaysInsideVisibleDisplay() {
        let visible = CGRect(x: 100, y: 50, width: 1000, height: 700)
        let size = CGSize(width: 320, height: 300)
        let left = ShelfLayout.origin(in: visible, panelSize: size,
                                      pointer: CGPoint(x: 900, y: 600), placement: .leftBottom)
        let leftTop = ShelfLayout.origin(in: visible, panelSize: size,
                                         pointer: CGPoint(x: 900, y: 600), placement: .leftTop)
        let right = ShelfLayout.origin(in: visible, panelSize: size,
                                       pointer: CGPoint(x: 200, y: 600), placement: .rightBottom)
        let rightTop = ShelfLayout.origin(in: visible, panelSize: size,
                                          pointer: CGPoint(x: 200, y: 600), placement: .rightTop)
        XCTAssertEqual(left, CGPoint(x: 112, y: 62))
        XCTAssertEqual(leftTop, CGPoint(x: 112, y: 438))
        XCTAssertEqual(right, CGPoint(x: 768, y: 62))
        XCTAssertEqual(rightTop, CGPoint(x: 768, y: 438))
        XCTAssertEqual(ShelfPlacement.allCases.count, 5)

        for pointer in [CGPoint(x: 105, y: 55), CGPoint(x: 1095, y: 745)] {
            let origin = ShelfLayout.origin(in: visible, panelSize: size,
                                            pointer: pointer, placement: .nearDrag)
            XCTAssertGreaterThanOrEqual(origin.x, visible.minX + 12)
            XCTAssertGreaterThanOrEqual(origin.y, visible.minY + 12)
            XCTAssertLessThanOrEqual(origin.x + size.width, visible.maxX - 12)
            XCTAssertLessThanOrEqual(origin.y + size.height, visible.maxY - 12)
        }
    }

    func testAllPlacementChoicesRoundTripThroughStoredRawValue() {
        for choice in ShelfPlacement.allCases {
            XCTAssertEqual(ShelfPlacement(rawValue: choice.rawValue), choice)
        }
        XCTAssertEqual(ShelfPlacement(rawValue: "leftBottom"), .leftBottom)
        XCTAssertEqual(ShelfPlacement(rawValue: "rightBottom"), .rightBottom)
        XCTAssertEqual(ShelfPlacement(rawValue: "nearDrag"), .nearDrag)
    }
}
