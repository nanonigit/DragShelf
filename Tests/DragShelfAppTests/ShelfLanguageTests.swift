import AppKit
import XCTest
import DragShelfCore
@testable import DragShelf

final class ShelfLanguageTests: XCTestCase {
    @MainActor
    func testSwitchingLanguageUpdatesExistingUIAndPreservesItemsAndSettings() async throws {
        _ = NSApplication.shared
        let priorLanguage = UserDefaults.standard.object(forKey: AppLanguage.preferenceKey)
        defer {
            if let priorLanguage { UserDefaults.standard.set(priorLanguage, forKey: AppLanguage.preferenceKey) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.preferenceKey) }
        }
        UserDefaults.standard.removeObject(forKey: AppLanguage.preferenceKey)
        let suite = "DragShelf.LanguageUITests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ShelfModel(history: ShelfHistoryStore(defaults: defaults))
        let file = URL(fileURLWithPath: #filePath)
        model.add([file])
        model.setMaximumItems(10)
        let management = ShelfManagementWindow(model: model, previews: FilePreviewStore(),
                                               displayMode: .list, placement: .leftBottom,
                                               transparencyPercent: 35)
        defer { management.window.close() }
        management.systemStatusProvider = {
            ShelfManagementWindow.SystemStatus(inputGranted: true,
                detectionText: L(.monitorWithPermission), loginText: L(.loginEnabled),
                loginEnabled: true, loginAvailable: true, menuBarVisible: false, dockVisible: true)
        }
        management.onLanguageChange = { [weak management] language in
            language.save(to: .standard)
            management?.refreshLanguage()
        }
        management.refreshLanguage()
        let views = descendants(of: management.window.contentView!)
        let tabs = try XCTUnwrap(views.compactMap { $0 as? NSTabView }.first)
        let popups = views.compactMap { $0 as? NSPopUpButton }
        let language = try XCTUnwrap(popups.first { $0.itemTitles == ["English", "日本語"] })
        let otherPopups = popups.filter { $0 !== language }
        let selections = otherPopups.map(\.indexOfSelectedItem)
        let slider = try XCTUnwrap(views.compactMap { $0 as? NSSlider }.first)
        let historyControl = try XCTUnwrap(views.compactMap { $0 as? NSSegmentedControl }.first)
        XCTAssertEqual(historyControl.selectedSegment, 1)
        XCTAssertEqual(management.window.title, "DragShelf Settings")
        XCTAssertEqual(tabs.tabViewItems.map(\.label), ["Settings", "Parked Items"])
        XCTAssertEqual(tabs.indexOfTabViewItem(tabs.selectedTabViewItem!), 0)
        XCTAssertEqual(language.indexOfSelectedItem, 0)
        tabs.selectTabViewItem(at: 1)

        for (index, expectedTitle, expectedTabs) in [
            (1, "DragShelf の管理", ["設定", "一時置き"]),
            (0, "DragShelf Settings", ["Settings", "Parked Items"]),
            (1, "DragShelf の管理", ["設定", "一時置き"])
        ] {
            language.selectItem(at: index)
            XCTAssertTrue(language.sendAction(language.action, to: language.target))
            try await Task.sleep(for: .milliseconds(20))
            XCTAssertEqual(management.window.title, expectedTitle)
            XCTAssertEqual(tabs.tabViewItems.map(\.label), expectedTabs)
            XCTAssertEqual(tabs.indexOfTabViewItem(tabs.selectedTabViewItem!), 1)
            let refreshedPopups = descendants(of: tabs.tabViewItems[0].view!)
                .compactMap { $0 as? NSPopUpButton }.filter { $0 !== language }
            XCTAssertEqual(refreshedPopups.map(\.indexOfSelectedItem), selections)
            for popup in refreshedPopups {
                XCTAssertEqual((popup.cell as? NSPopUpButtonCell)?.title, popup.titleOfSelectedItem)
            }
            XCTAssertEqual(slider.doubleValue, 35)
            XCTAssertEqual(historyControl.selectedSegment, 1)
            XCTAssertEqual(model.files, [file])
            XCTAssertEqual(model.maximumItems, 10)
            XCTAssertEqual(AppLanguage.restored(from: .standard), AppLanguage.allCases[index])
            // NSTabView detaches the inactive tab from the window hierarchy.
            let labels = descendants(of: tabs.tabViewItems[0].view!).compactMap { $0 as? NSTextField }
            XCTAssertTrue(labels.contains { $0.stringValue == L(.permissionGranted) })
            XCTAssertTrue(labels.contains { $0.stringValue == L(.monitorWithPermission) })
        }
        XCTAssertEqual(ShelfModel(history: ShelfHistoryStore(defaults: defaults)).files, [file])
        let headings = descendants(of: tabs.tabViewItems[0].view!).compactMap { $0 as? NSTextField }
        for key in [AppText.general, .shelfAppearance, .history, .dragDetection] {
            XCTAssertTrue(headings.contains { $0.stringValue == L(key) })
        }
        tabs.selectTabViewItem(at: 0)
        management.window.setContentSize(NSSize(width: 600, height: 560))
        management.window.contentView?.layoutSubtreeIfNeeded()
        let scroll = try XCTUnwrap(tabs.tabViewItems[0].view as? NSScrollView)
        XCTAssertGreaterThan(scroll.documentView!.bounds.height, scroll.contentView.bounds.height)
    }

    @MainActor
    private func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }
}
