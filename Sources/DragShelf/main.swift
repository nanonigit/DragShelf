import AppKit
import CoreGraphics
import DragShelfCore
import OSLog
import ServiceManagement

@MainActor
@main
enum DragShelfMain {
    private static var delegate: AppDelegate?
    fileprivate static let bundleID = "com.github.nanonigit.DragShelf"
    fileprivate static let reopenNotification = Notification.Name("com.github.nanonigit.DragShelf.reopenManagement")

    static func main() {
        let app = NSApplication.shared
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter({ !$0.isTerminated && $0.processIdentifier < ownPID })
            .min(by: { $0.processIdentifier < $1.processIdentifier }) {
            DistributedNotificationCenter.default().postNotificationName(
                reopenNotification, object: bundleID, userInfo: nil, deliverImmediately: true)
            _ = existing.activate(options: [.activateAllWindows])
            return
        }
        let presence = AppPresence.restored(from: .standard)
        let policy: NSApplication.ActivationPolicy = presence.dockVisible ? .regular : .accessory
        if !app.setActivationPolicy(policy) {
            _ = app.setActivationPolicy(.regular)
            UserDefaults.standard.set(true, forKey: AppPresence.dockKey)
        }
        let delegate = AppDelegate()
        self.delegate = delegate
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let log = Logger(subsystem: "dev.local.DragShelf", category: "Detection")
    private let shelf = ShelfController()
    private let probe = DragPasteboardProbe()
    private var detector = DragDetectionEngine()
    private var monitor: GlobalDragMonitor?
    private var timer: Timer?
    private var permissionTimer: Timer?
    private var lastPermissionGranted: Bool?
    private var pendingHide: DispatchWorkItem?
    private var statusItem: NSStatusItem?
    private var visibilityItem: NSMenuItem?
    private var countItem: NSMenuItem?
    private var loggedFirstMove = false
    private let legacyLoginService = SMAppService.loginItem(identifier: "com.github.nanonigit.DragShelf.LoginItem")
    private let loginAgent = LoginLaunchAgent()
    private var loginRepairError: String?

    private var isInstalledInApplications: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/DragShelf.app"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(reopenFromOtherInstance(_:)),
            name: DragShelfMain.reopenNotification, object: DragShelfMain.bundleID)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "DragShelf")
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "管理画面を開く", action: #selector(openManagement), keyEquivalent: ""))
        let visibilityItem = NSMenuItem(title: "棚を表示", action: #selector(toggleShelf), keyEquivalent: "")
        menu.addItem(visibilityItem)
        self.visibilityItem = visibilityItem
        menu.addItem(.separator())
        let countItem = NSMenuItem(title: "一時置き: 0 件", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)
        self.countItem = countItem
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        for entry in menu.items where entry.action != nil { entry.target = self }
        item.menu = menu
        statusItem = item
        item.isVisible = AppPresence.restored(from: .standard).menuBarVisible
        shelf.onLoginToggle = { [weak self] in self?.toggleLoginItem() }
        shelf.onMenuBarVisibilityChange = { [weak self] in self?.setMenuBarVisibility($0) }
        shelf.onDockVisibilityChange = { [weak self] in self?.setDockVisibility($0) }
        shelf.onOpenInputSettings = { [weak self] in self?.requestInputAccess() }
        shelf.managementStatusProvider = { [weak self] in self?.managementSystemStatus() ??
            ShelfManagementWindow.SystemStatus(inputGranted: false, detectionText: "確認中",
                                               loginText: "確認中", loginEnabled: false,
                                               loginAvailable: false, menuBarVisible: true,
                                               dockVisible: true)
        }
        migrateLoginItemIfNeeded()

        let monitor = GlobalDragMonitor { [weak self] kind, point in
            self?.receive(kind, at: point)
        }
        monitor.start(forceAppKit: CommandLine.arguments.contains("--force-appkit-monitor"))
        self.monitor = monitor
        lastPermissionGranted = CGPreflightListenEventAccess()
        updateMonitorStatus()
        log.info("Monitor started: \(monitor.mode.rawValue, privacy: .public)")
        log.info("Listen event access granted: \(CGPreflightListenEventAccess())")
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshMonitorForPermissionChange() }
        }
        if CommandLine.arguments.contains("--show-shelf") {
            shelf.show(near: NSEvent.mouseLocation)
        } else if !CommandLine.arguments.contains("--login-start") {
            shelf.openManagement()
            shelf.showRestoredItemsIfNeeded()
        }
        DispatchQueue.main.async { [weak self] in
            self?.requestInputAccessIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        timer?.invalidate()
        permissionTimer?.invalidate()
        monitor?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shelf.openManagement()
        return false
    }

    @objc private func reopenFromOtherInstance(_ notification: Notification) {
        shelf.openManagement()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
    }

    private func receive(_ event: GlobalDragMonitor.PointerEvent, at point: NSPoint) {
        let input: DragDetectionEngine.Input
        var firstDrag = false
        switch event {
        case .down:
            input = .mouseDown
            loggedFirstMove = false
            log.info("Mouse down observed")
            startSampling()
        case .dragged:
            input = .mouseDragged
            if !loggedFirstMove {
                loggedFirstMove = true
                firstDrag = true
            }
        case .up:
            input = .mouseUp
            log.info("Mouse up observed")
            timer?.invalidate()
            timer = nil
        }
        let snapshot = probe.snapshot()
        if firstDrag {
            log.info("First mouse drag observed; generation: \(snapshot.changeCount); supported: \(snapshot.hasSupportedType)")
        }
        apply(detector.handle(input, pasteboard: snapshot), at: point)
    }

    private func sampleWhileDragging() {
        guard detector.isTracking else { return }
        apply(detector.handle(.sample, pasteboard: probe.snapshot()), at: NSEvent.mouseLocation)
    }

    private func startSampling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleWhileDragging() }
        }
    }

    private func apply(_ action: DragDetectionEngine.Action, at point: NSPoint) {
        switch action {
        case .none: break
        case .reveal:
            pendingHide?.cancel()
            log.info("Supported external drag detected; showing shelf")
            shelf.show(near: point)
        case .end:
            let work = DispatchWorkItem { [weak self] in self?.shelf.hideIfEmpty() }
            pendingHide = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }
    }

    @objc private func showShelf() {
        pendingHide?.cancel()
        shelf.show(near: NSEvent.mouseLocation)
    }

    @objc private func hideShelf() {
        shelf.hide()
    }

    @objc private func toggleShelf() {
        if shelf.isVisible { hideShelf() } else { showShelf() }
        updateMenuState()
    }

    @objc private func openManagement() {
        shelf.openManagement()
    }

    @objc private func requestInputAccess() {
        guard !CGPreflightListenEventAccess() else { return }
        let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        if !NSWorkspace.shared.open(settingsURL) {
            let fallback = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            if !NSWorkspace.shared.open(fallback) {
                let alert = NSAlert()
                alert.messageText = "入力監視の設定を開けませんでした"
                alert.informativeText = "システム設定 → プライバシーとセキュリティ → 入力監視 から DragShelf を許可してください。"
                alert.runModal()
            }
        }
    }

    private func requestInputAccessIfNeeded() {
        guard !CGPreflightListenEventAccess() else { return }
        _ = CGRequestListenEventAccess()
        let granted = CGPreflightListenEventAccess()
        if granted != lastPermissionGranted {
            monitor?.start()
        }
        lastPermissionGranted = granted
        updateMonitorStatus()
        log.info("Input Monitoring request finished; granted: \(granted)")
    }

    private func updateMonitorStatus() {
        shelf.refreshManagementSystemStatus()
    }

    private func updateMenuState() {
        visibilityItem?.title = shelf.isVisible ? "棚を隠す" : "棚を表示"
        countItem?.title = "一時置き: \(shelf.model.files.count) 件"
        shelf.refreshManagementSystemStatus()
    }

    private func managementSystemStatus() -> ShelfManagementWindow.SystemStatus {
        let oldStatus = legacyLoginService.status
        let enabled = loginAgent.isEnabled(for: Bundle.main.bundleURL)
        let loginText: String
        if loginRepairError != nil {
            loginText = "設定エラー（もう一度切り替えてください）"
        } else if enabled {
            loginText = "有効（次回ログイン時に起動）"
        } else {
            loginText = oldStatus == .requiresApproval ? "旧項目の承認待ち" : "無効"
        }
        let detectionText: String
        if monitor?.isRunning != true {
            detectionText = "停止中"
        } else if monitor?.mode == .eventTap {
            detectionText = "動作中（入力監視を使用）"
        } else {
            detectionText = "動作中（入力監視なし）"
        }
        return ShelfManagementWindow.SystemStatus(
            inputGranted: CGPreflightListenEventAccess(), detectionText: detectionText,
            loginText: loginText,
            loginEnabled: enabled || oldStatus == .enabled || oldStatus == .requiresApproval,
            loginAvailable: isInstalledInApplications,
            menuBarVisible: statusItem?.isVisible ?? true,
            dockVisible: NSApp.activationPolicy() == .regular
        )
    }

    private func setMenuBarVisibility(_ visible: Bool) {
        guard let item = statusItem,
              let next = currentPresence.changingMenuBarVisibility(to: visible) else {
            shelf.refreshManagementSystemStatus()
            return
        }
        item.isVisible = visible
        next.save(to: .standard)
        shelf.refreshManagementSystemStatus()
    }

    private var currentPresence: AppPresence {
        AppPresence(dockVisible: NSApp.activationPolicy() == .regular,
                    menuBarVisible: statusItem?.isVisible ?? false)
    }

    private func setDockVisibility(_ visible: Bool) {
        guard let next = currentPresence.changingDockVisibility(to: visible) else {
            shelf.refreshManagementSystemStatus()
            return
        }
        let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
        guard NSApp.setActivationPolicy(policy), NSApp.activationPolicy() == policy else {
            let alert = NSAlert()
            alert.messageText = "Dock アイコンの表示を変更できませんでした"
            alert.informativeText = "アプリを再起動してから、もう一度お試しください。"
            alert.runModal()
            shelf.refreshManagementSystemStatus()
            return
        }
        next.save(to: .standard)
        shelf.openManagement()
        shelf.refreshManagementSystemStatus()
    }

    @objc private func toggleLoginItem() {
        do {
            if loginAgent.isConfigured || legacyLoginService.status == .enabled
                || legacyLoginService.status == .requiresApproval {
                try loginAgent.disable()
                if legacyLoginService.status == .enabled || legacyLoginService.status == .requiresApproval {
                    try legacyLoginService.unregister()
                }
            } else {
                try loginAgent.enable(for: Bundle.main.bundleURL)
            }
            loginRepairError = nil
        } catch {
            let alert = NSAlert()
            alert.messageText = "ログイン時起動を変更できませんでした"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            log.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
        }
        updateMenuState()
    }

    private func migrateLoginItemIfNeeded() {
        guard isInstalledInApplications else { return }
        let oldStatus = legacyLoginService.status
        guard oldStatus == .enabled || loginAgent.isConfigured else { return }
        do {
            if !loginAgent.isEnabled(for: Bundle.main.bundleURL) {
                try loginAgent.enable(for: Bundle.main.bundleURL)
            }
            if oldStatus == .enabled {
                try legacyLoginService.unregister()
            }
            loginRepairError = nil
            log.info("Migrated startup registration to the user LaunchAgent")
        } catch {
            loginRepairError = error.localizedDescription
            log.error("Could not migrate startup registration: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshMonitorForPermissionChange() {
        guard let monitor else { return }
        let granted = CGPreflightListenEventAccess()
        guard granted != lastPermissionGranted else { return }
        lastPermissionGranted = granted
        monitor.start()
        updateMonitorStatus()
        log.info("Monitor changed after permission update: \(monitor.mode.rawValue, privacy: .public)")
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
