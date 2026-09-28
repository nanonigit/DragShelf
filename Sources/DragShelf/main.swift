import AppKit
import CoreGraphics
import DragShelfCore
import OSLog
import ServiceManagement

@MainActor
@main
enum DragShelfMain {
    private static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
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
    private var modeItem: NSMenuItem?
    private var permissionItem: NSMenuItem?
    private var loginItem: NSMenuItem?
    private var displayItems: [ShelfDisplayMode: NSMenuItem] = [:]
    private var placementItems: [ShelfPlacement: NSMenuItem] = [:]
    private var loggedFirstMove = false
    private let loginService = SMAppService.loginItem(identifier: "com.github.nanonigit.DragShelf.LoginItem")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "DragShelf")
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "管理画面を開く", action: #selector(openManagement), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "棚を表示", action: #selector(showShelf), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "棚を隠す", action: #selector(hideShelf), keyEquivalent: ""))

        let displayMenu = NSMenu()
        for (title, mode) in [("リスト", ShelfDisplayMode.list), ("アイコン", .icons)] {
            let choice = NSMenuItem(title: title, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            choice.representedObject = mode.rawValue
            choice.target = self
            displayMenu.addItem(choice)
            displayItems[mode] = choice
        }
        let displayItem = NSMenuItem(title: "表示形式", action: nil, keyEquivalent: "")
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        let placementMenu = NSMenu()
        for (title, placement) in [("左下", ShelfPlacement.leftBottom),
                                   ("右下", .rightBottom),
                                   ("ドラッグ位置の近く", .nearDrag)] {
            let choice = NSMenuItem(title: title, action: #selector(selectPlacement(_:)), keyEquivalent: "")
            choice.representedObject = placement.rawValue
            choice.target = self
            placementMenu.addItem(choice)
            placementItems[placement] = choice
        }
        let placementItem = NSMenuItem(title: "棚の位置", action: nil, keyEquivalent: "")
        placementItem.submenu = placementMenu
        menu.addItem(placementItem)

        menu.addItem(.separator())
        let permissionItem = NSMenuItem(title: "入力監視の権限: 確認中", action: #selector(requestInputAccess), keyEquivalent: "")
        menu.addItem(permissionItem)
        self.permissionItem = permissionItem
        let modeItem = NSMenuItem(title: "ドラッグ検知: 確認中", action: nil, keyEquivalent: "")
        modeItem.isEnabled = false
        menu.addItem(modeItem)
        let loginItem = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLoginItem), keyEquivalent: "")
        menu.addItem(loginItem)
        self.loginItem = loginItem
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        for entry in menu.items where entry.action != nil { entry.target = self }
        item.menu = menu
        statusItem = item
        self.modeItem = modeItem

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
        }
        DispatchQueue.main.async { [weak self] in
            self?.requestInputAccessIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        permissionTimer?.invalidate()
        monitor?.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shelf.openManagement()
        return false
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

    @objc private func openManagement() {
        shelf.openManagement()
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ShelfDisplayMode(rawValue: raw) else { return }
        shelf.setDisplayMode(mode)
        updateMenuState()
    }

    @objc private func selectPlacement(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let placement = ShelfPlacement(rawValue: raw) else { return }
        shelf.setPlacement(placement)
        updateMenuState()
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
        let permissionGranted = CGPreflightListenEventAccess()
        permissionItem?.title = permissionGranted
            ? "入力監視の権限: 許可済み"
            : "入力監視の権限: 未許可（設定を開く）"
        permissionItem?.isEnabled = !permissionGranted
        if monitor?.isRunning != true {
            modeItem?.title = "ドラッグ検知: 停止中"
        } else if monitor?.mode == .eventTap {
            modeItem?.title = "ドラッグ検知: 動作中（入力監視を使用）"
        } else {
            modeItem?.title = "ドラッグ検知: 動作中（入力監視なし）"
        }
    }

    private func updateMenuState() {
        updateMonitorStatus()
        for (mode, item) in displayItems { item.state = mode == shelf.displayMode ? .on : .off }
        for (placement, item) in placementItems { item.state = placement == shelf.placement ? .on : .off }
        let status = loginService.status
        loginItem?.state = status == .enabled ? .on : .off
        switch status {
        case .enabled:
            loginItem?.title = "ログイン時に起動"
        case .requiresApproval:
            loginItem?.title = "ログイン時に起動（システム設定で承認待ち）"
        case .notFound:
            loginItem?.title = "ログイン時に起動（利用不可）"
        case .notRegistered:
            loginItem?.title = "ログイン時に起動"
        @unknown default:
            loginItem?.title = "ログイン時に起動（状態不明）"
        }
    }

    @objc private func toggleLoginItem() {
        do {
            if loginService.status == .enabled || loginService.status == .requiresApproval {
                try loginService.unregister()
            } else {
                try loginService.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "ログイン時起動を変更できませんでした"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            log.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
        }
        updateMenuState()
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
