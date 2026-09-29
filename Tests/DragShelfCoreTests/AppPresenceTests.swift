import XCTest
@testable import DragShelfCore

final class AppPresenceTests: XCTestCase {
    func testDefaultsShowBothIcons() {
        let defaults = makeDefaults()
        XCTAssertEqual(AppPresence.restored(from: defaults),
                       AppPresence(dockVisible: true, menuBarVisible: true))
    }

    func testCanHideBothIcons() {
        let dockOnly = AppPresence(dockVisible: true, menuBarVisible: false)
        XCTAssertEqual(dockOnly.changingDockVisibility(to: false),
                       AppPresence(dockVisible: false, menuBarVisible: false))
        XCTAssertNotNil(dockOnly.changingMenuBarVisibility(to: true))

        let menuOnly = AppPresence(dockVisible: false, menuBarVisible: true)
        XCTAssertEqual(menuOnly.changingMenuBarVisibility(to: false),
                       AppPresence(dockVisible: false, menuBarVisible: false))
        XCTAssertNotNil(menuOnly.changingDockVisibility(to: true))
    }

    func testChoicePersistsAcrossRestart() {
        let defaults = makeDefaults()
        let menuOnly = AppPresence(dockVisible: false, menuBarVisible: true)
        menuOnly.save(to: defaults)
        XCTAssertEqual(AppPresence.restored(from: defaults), menuOnly)
    }

    func testBothHiddenPersistsAcrossRestart() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: AppPresence.dockKey)
        defaults.set(false, forKey: AppPresence.menuBarKey)
        XCTAssertEqual(AppPresence.restored(from: defaults),
                       AppPresence(dockVisible: false, menuBarVisible: false))
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "DragShelfTests.AppPresence.\(UUID().uuidString)")!
    }
}
