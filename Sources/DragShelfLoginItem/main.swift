import AppKit

let mainIdentifier = "dev.local.DragShelf"
guard NSRunningApplication.runningApplications(withBundleIdentifier: mainIdentifier).isEmpty else {
    exit(EXIT_SUCCESS)
}

let mainApp = Bundle.main.bundleURL
    .deletingLastPathComponent() // LoginItems
    .deletingLastPathComponent() // Library
    .deletingLastPathComponent() // Contents
    .deletingLastPathComponent() // DragShelf.app

guard FileManager.default.fileExists(atPath: mainApp.path) else {
    exit(EXIT_FAILURE)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.arguments = ["--login-start"]
configuration.activates = false
NSWorkspace.shared.openApplication(at: mainApp, configuration: configuration) { _, error in
    exit(error == nil ? EXIT_SUCCESS : EXIT_FAILURE)
}
RunLoop.current.run()
