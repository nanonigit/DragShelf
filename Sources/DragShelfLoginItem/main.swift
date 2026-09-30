import AppKit
import OSLog

let mainIdentifier = "com.github.nanonigit.DragShelf"
let log = Logger(subsystem: mainIdentifier, category: "LoginItem")
guard NSRunningApplication.runningApplications(withBundleIdentifier: mainIdentifier).isEmpty else {
    log.info("Main app is already running")
    exit(EXIT_SUCCESS)
}

let mainApp = Bundle.main.bundleURL
    .deletingLastPathComponent() // LoginItems
    .deletingLastPathComponent() // Library
    .deletingLastPathComponent() // Contents
    .deletingLastPathComponent() // DragShelf.app

guard FileManager.default.fileExists(atPath: mainApp.path) else {
    log.error("Main app bundle was not found at \(mainApp.path, privacy: .public)")
    exit(EXIT_FAILURE)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.arguments = ["--login-start"]
configuration.activates = false
NSWorkspace.shared.openApplication(at: mainApp, configuration: configuration) { _, error in
    if let error {
        log.error("Could not start main app: \(error.localizedDescription, privacy: .public)")
    }
    exit(error == nil ? EXIT_SUCCESS : EXIT_FAILURE)
}
RunLoop.current.run()
