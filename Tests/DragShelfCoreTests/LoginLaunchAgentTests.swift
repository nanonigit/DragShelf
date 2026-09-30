import Foundation
import XCTest
@testable import DragShelfCore

final class LoginLaunchAgentTests: XCTestCase {
    func testEnablesLaunchAtLoginWithInstalledAppPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let agent = LoginLaunchAgent(directory: directory)
        let app = URL(fileURLWithPath: "/Applications/DragShelf.app")

        XCTAssertFalse(agent.isEnabled(for: app))
        XCTAssertFalse(agent.isConfigured)
        try agent.enable(for: app)
        XCTAssertTrue(agent.isEnabled(for: app))
        XCTAssertTrue(agent.isConfigured)

        let data = try Data(contentsOf: agent.plistURL)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["Label"] as? String, LoginLaunchAgent.label)
        XCTAssertEqual(plist["ProgramArguments"] as? [String], [
            "/usr/bin/open", "-a", app.path, "--args", "--login-start",
        ])
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["KeepAlive"] as? Bool, false)
    }

    func testMovedAppNeedsAgentRefreshAndDisableRemovesOnlyOwnPlist() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let agent = LoginLaunchAgent(directory: directory)
        let oldApp = URL(fileURLWithPath: "/Applications/DragShelf.app")
        let movedApp = URL(fileURLWithPath: "/Users/example/Applications/DragShelf.app")
        try agent.enable(for: oldApp)

        XCTAssertFalse(agent.isEnabled(for: movedApp))
        XCTAssertTrue(agent.isConfigured)
        try agent.enable(for: movedApp)
        XCTAssertTrue(agent.isEnabled(for: movedApp))
        try agent.disable()
        XCTAssertFalse(agent.isConfigured)
        XCTAssertFalse(FileManager.default.fileExists(atPath: agent.plistURL.path))
    }
}
