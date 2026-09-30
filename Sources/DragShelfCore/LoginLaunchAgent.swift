import Foundation

public struct LoginLaunchAgent {
    public static let label = "com.github.nanonigit.DragShelf.startAtLogin"

    public let plistURL: URL

    public init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents", isDirectory: true)) {
        plistURL = directory.appendingPathComponent("\(Self.label).plist")
    }

    public func isEnabled(for appURL: URL) -> Bool {
        guard let plist = existingPropertyList() else { return false }
        return plist["Label"] as? String == Self.label
            && plist["ProgramArguments"] as? [String] == Self.arguments(for: appURL)
            && plist["RunAtLoad"] as? Bool == true
    }

    public var isConfigured: Bool {
        guard let plist = existingPropertyList() else { return false }
        return plist["Label"] as? String == Self.label
            && plist["RunAtLoad"] as? Bool == true
    }

    public func enable(for appURL: URL) throws {
        try verifyExistingFileOwnership()
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": Self.arguments(for: appURL),
            "RunAtLoad": true,
            "KeepAlive": false,
            "AssociatedBundleIdentifiers": "com.github.nanonigit.DragShelf",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                       format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    public func disable() throws {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        try verifyExistingFileOwnership()
        try FileManager.default.removeItem(at: plistURL)
    }

    private func verifyExistingFileOwnership() throws {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        guard existingPropertyList()?["Label"] as? String == Self.label else {
            throw CocoaError(.fileWriteNoPermission, userInfo: [
                NSFilePathErrorKey: plistURL.path,
            ])
        }
    }

    private func existingPropertyList() -> [String: Any]? {
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    private static func arguments(for appURL: URL) -> [String] {
        ["/usr/bin/open", "-a", appURL.standardizedFileURL.path, "--args", "--login-start"]
    }
}
