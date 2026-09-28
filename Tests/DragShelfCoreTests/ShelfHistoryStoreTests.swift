import Foundation
import XCTest
@testable import DragShelfCore

final class ShelfHistoryStoreTests: XCTestCase {
    func testReferencesSurviveStoreRecreation() throws {
        let suite = "DragShelfHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DragShelfHistoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("sample.txt")
        XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: Data("test".utf8)))

        ShelfHistoryStore(defaults: defaults).save([file])
        XCTAssertEqual(ShelfHistoryStore(defaults: defaults).load().map { $0.resolvingSymlinksInPath() },
                       [file.resolvingSymlinksInPath()])
    }

    func testOldestReferencesAreDiscardedWhenLimitIsReduced() throws {
        let suite = "DragShelfHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShelfHistoryStore(defaults: defaults)
        let files = (0..<8).map { URL(fileURLWithPath: "/tmp/dragshelf-test-\($0)") }
        store.save(files)

        XCTAssertEqual(store.setLimit(5, in: files), Array(files.suffix(5)))
        XCTAssertEqual(ShelfHistoryStore(defaults: defaults).limit, 5)
        XCTAssertEqual(ShelfHistoryStore(defaults: defaults).load(), Array(files.suffix(5)))
        XCTAssertEqual(ShelfHistoryStore.retainingNewest(files + files, limit: 5),
                       Array((files + files).suffix(5)))
    }

    func testUnsupportedLimitDoesNotAlterHistory() throws {
        let suite = "DragShelfHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShelfHistoryStore(defaults: defaults)
        let file = URL(fileURLWithPath: "/tmp/dragshelf-test")
        store.save([file])

        XCTAssertEqual(store.setLimit(0, in: [file]), [file])
        XCTAssertEqual(store.limit, ShelfHistoryStore.defaultLimit)
        XCTAssertEqual(store.load(), [file])
    }

    @MainActor
    func testModelRestoresItemsAndEvictsOldestWithoutDeletingFiles() throws {
        let suite = "DragShelfHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DragShelfHistoryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = (0..<8).map { folder.appendingPathComponent("\($0).txt") }
        for file in files {
            XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: Data()))
        }

        let model = ShelfModel(history: ShelfHistoryStore(defaults: defaults))
        model.setMaximumItems(5)
        model.add(files)
        XCTAssertEqual(model.files.map { $0.resolvingSymlinksInPath() },
                       files.suffix(5).map { $0.resolvingSymlinksInPath() })

        let relaunched = ShelfModel(history: ShelfHistoryStore(defaults: defaults))
        XCTAssertEqual(relaunched.files.map { $0.resolvingSymlinksInPath() },
                       files.suffix(5).map { $0.resolvingSymlinksInPath() })
        relaunched.remove(at: 0)
        XCTAssertEqual(ShelfModel(history: ShelfHistoryStore(defaults: defaults)).files.count, 4)
        for file in files { XCTAssertTrue(FileManager.default.fileExists(atPath: file.path)) }
    }
}
