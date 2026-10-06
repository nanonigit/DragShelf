import AppKit
import DragShelfCore
import OSLog

@MainActor
final class ShelfController {
    private let log = Logger(subsystem: "dev.local.DragShelf", category: "Shelf")
    let model = ShelfModel()
    private let previews = FilePreviewStore()
    private let panel: NSPanel
    private let dropView: ShelfDropView
    private var management: ShelfManagementWindow?
    private var lastScreen: NSScreen?
    private var lastPointer = NSPoint.zero
    var onLoginToggle: (() -> Void)?
    var onLanguageChange: (() -> Void)?
    var onMenuBarVisibilityChange: ((Bool) -> Void)?
    var onDockVisibilityChange: ((Bool) -> Void)?
    var onOpenInputSettings: (() -> Void)?
    var managementStatusProvider: (() -> ShelfManagementWindow.SystemStatus)?

    private(set) var displayMode: ShelfDisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "shelfDisplayMode") }
    }
    private(set) var placement: ShelfPlacement {
        didSet { UserDefaults.standard.set(placement.rawValue, forKey: "shelfPlacement") }
    }
    private(set) var transparencyPercent: Double {
        didSet { UserDefaults.standard.set(transparencyPercent, forKey: "shelfTransparencyPercent") }
    }

    var isVisible: Bool { panel.isVisible }

    init() {
        displayMode = ShelfDisplayMode(rawValue: UserDefaults.standard.string(forKey: "shelfDisplayMode") ?? "") ?? .icons
        placement = ShelfPlacement(rawValue: UserDefaults.standard.string(forKey: "shelfPlacement") ?? "") ?? .nearDrag
        transparencyPercent = min(60, max(0, UserDefaults.standard.double(forKey: "shelfTransparencyPercent")))
        panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: ShelfLayout.width, height: 112),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        dropView = ShelfDropView(frame: panel.contentView!.bounds)
        dropView.model = model
        dropView.previews = previews
        dropView.displayMode = displayMode
        dropView.onDisplayModeChange = { [weak self] mode in self?.setDisplayMode(mode) }
        dropView.onOpenManagement = { [weak self] in self?.openManagement() }
        panel.contentView = dropView
        panel.delegate = dropView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.alphaValue = 1 - transparencyPercent / 100
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        model.didChange = { [weak self] in self?.refresh() }
        previews.didUpdate = { [weak self] in
            self?.dropView.needsDisplay = true
            self?.management?.refreshFiles()
        }
    }

    func show(near point: NSPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        lastScreen = screen
        lastPointer = point
        updatePanelSize(for: screen)
        position(on: screen)
        panel.level = model.files.isEmpty ? .floating : .statusBar
        panel.orderFrontRegardless()
        log.info("Shelf shown at x=\(self.panel.frame.minX) y=\(self.panel.frame.minY) width=\(self.panel.frame.width) height=\(self.panel.frame.height)")
    }

    func hide() {
        dropView.endPreviewInteraction()
        panel.orderOut(nil)
    }

    func hideIfEmpty() {
        if model.files.isEmpty { hide() }
    }

    func showRestoredItemsIfNeeded() {
        if !model.files.isEmpty { show(near: NSEvent.mouseLocation) }
    }

    func setDisplayMode(_ mode: ShelfDisplayMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        dropView.displayMode = mode
        refresh()
    }

    func setPlacement(_ value: ShelfPlacement) {
        guard placement != value else { return }
        placement = value
        position(on: lastScreen ?? NSScreen.main)
        management?.refresh(displayMode: displayMode, placement: placement,
                            transparencyPercent: transparencyPercent)
    }

    func openManagement() {
        if management == nil {
            let newManagement = ShelfManagementWindow(model: model, previews: previews,
                                                      displayMode: displayMode, placement: placement,
                                                      transparencyPercent: transparencyPercent)
            newManagement.onDisplayModeChange = { [weak self] in self?.setDisplayMode($0) }
            newManagement.onLanguageChange = { [weak self] in self?.setLanguage($0) }
            newManagement.onPlacementChange = { [weak self] in self?.setPlacement($0) }
            newManagement.onTransparencyChange = { [weak self] in self?.setTransparency($0) }
            newManagement.onHistoryLimitChange = { [weak self] in self?.model.setMaximumItems($0) }
            newManagement.onLoginToggle = { [weak self] in self?.onLoginToggle?() }
            newManagement.onMenuBarVisibilityChange = { [weak self] in self?.onMenuBarVisibilityChange?($0) }
            newManagement.onDockVisibilityChange = { [weak self] in self?.onDockVisibilityChange?($0) }
            newManagement.onOpenInputSettings = { [weak self] in self?.onOpenInputSettings?() }
            newManagement.systemStatusProvider = managementStatusProvider
            management = newManagement
        }
        management?.show()
    }

    func setTransparency(_ percent: Double) {
        transparencyPercent = min(60, max(0, percent))
        panel.alphaValue = 1 - transparencyPercent / 100
        management?.refresh(displayMode: displayMode, placement: placement,
                            transparencyPercent: transparencyPercent)
    }

    func setLanguage(_ language: AppLanguage) {
        language.save(to: .standard)
        management?.refreshLanguage()
        dropView.toolTip = L(.previewHelp)
        dropView.needsDisplay = true
        onLanguageChange?()
    }

    func refreshManagementSystemStatus() {
        management?.refreshSystemStatus()
    }

    private func refresh() {
        previews.retainOnly(model.files)
        updatePanelSize(for: lastScreen ?? NSScreen.main)
        panel.level = model.files.isEmpty ? .floating : .statusBar
        management?.refresh(displayMode: displayMode, placement: placement,
                            transparencyPercent: transparencyPercent)
        position(on: lastScreen ?? NSScreen.main)
        if model.files.isEmpty {
            hide()
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func updatePanelSize(for screen: NSScreen?) {
        let desired = ShelfLayout(mode: displayMode, count: model.files.count).panelHeight
        let available = max(112, (screen?.visibleFrame.height ?? desired) - 24)
        panel.setContentSize(NSSize(width: ShelfLayout.width, height: min(desired, available)))
        dropView.refreshContent()
    }

    private func position(on screen: NSScreen?) {
        guard let screen else { return }
        let origin = ShelfLayout.origin(in: screen.visibleFrame,
                                        panelSize: panel.frame.size,
                                        pointer: lastPointer,
                                        placement: placement)
        if panel.frame.origin != origin { dropView.endPreviewInteraction() }
        panel.setFrameOrigin(origin)
    }
}
