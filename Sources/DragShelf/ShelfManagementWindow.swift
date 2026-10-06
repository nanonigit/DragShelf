import AppKit
import DragShelfCore

@MainActor
final class ShelfManagementWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    struct SystemStatus {
        let inputGranted: Bool
        let detectionText: String
        let loginText: String
        let loginEnabled: Bool
        let loginAvailable: Bool
        let menuBarVisible: Bool
        let dockVisible: Bool
    }

    private let model: ShelfModel
    private let previews: FilePreviewStore
    let window: NSWindow
    private let table = NSTableView()
    private let tabs = NSTabView(frame: NSRect(x: 0, y: 0, width: 600, height: 700))
    private let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var localizedLabels: [(NSTextField, AppText)] = []
    private let countLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: L(.emptyFiles))
    private var displayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var placementPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let transparencySlider = NSSlider(value: 0, minValue: 0, maxValue: 60,
                                              target: nil, action: nil)
    private let historyControl = NSSegmentedControl(labels: ShelfHistoryStore.supportedLimits.map { String($0) },
                                                    trackingMode: .selectOne, target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: L(.enable), target: nil, action: nil)
    private let menuBarCheckbox = NSButton(checkboxWithTitle: L(.show), target: nil, action: nil)
    private let dockCheckbox = NSButton(checkboxWithTitle: L(.show), target: nil, action: nil)
    private let presenceNote = NSTextField(wrappingLabelWithString: "")
    private let loginStatusLabel = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: L(.openInputSettings), target: nil, action: nil)
    private let permissionHelpButton = NSButton(title: L(.permissionHelpTitle), target: nil, action: nil)
    private let detectionLabel = NSTextField(labelWithString: "")

    var onDisplayModeChange: ((ShelfDisplayMode) -> Void)?
    var onLanguageChange: ((AppLanguage) -> Void)?
    var onPlacementChange: ((ShelfPlacement) -> Void)?
    var onTransparencyChange: ((Double) -> Void)?
    var onHistoryLimitChange: ((Int) -> Void)?
    var onLoginToggle: (() -> Void)?
    var onMenuBarVisibilityChange: ((Bool) -> Void)?
    var onDockVisibilityChange: ((Bool) -> Void)?
    var onOpenInputSettings: (() -> Void)?
    var systemStatusProvider: (() -> SystemStatus)?

    init(model: ShelfModel, previews: FilePreviewStore, displayMode: ShelfDisplayMode,
         placement: ShelfPlacement, transparencyPercent: Double) {
        self.model = model
        self.previews = previews
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 740),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = L(.managementTitle)
        window.minSize = NSSize(width: 600, height: 560)
        window.center()
        window.isReleasedWhenClosed = false

        tabs.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        window.contentView = content
        content.addSubview(tabs)
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            tabs.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            tabs.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            tabs.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])

        let settingsTab = NSTabViewItem(identifier: "settings")
        settingsTab.label = L(.settings)
        settingsTab.view = makeSettingsView()
        tabs.addTabViewItem(settingsTab)

        let filesTab = NSTabViewItem(identifier: "files")
        filesTab.label = L(.parkedItems)
        filesTab.view = makeFilesView()
        tabs.addTabViewItem(filesTab)
        tabs.selectTabViewItem(settingsTab)

        refresh(displayMode: displayMode, placement: placement,
                transparencyPercent: transparencyPercent)
        refreshLanguage()
    }

    private func makeFilesView() -> NSView {
        let content = NSView()
        countLabel.font = .systemFont(ofSize: 13)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(countLabel)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.title = L(.parkedFiles)
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 54
        table.selectionHighlightStyle = .none
        table.delegate = self
        table.dataSource = self

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 580, height: 650))
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            countLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            countLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            countLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            scroll.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
        ])
        return content
    }

    private func makeSettingsView() -> NSView {
        let content = SettingsDocumentView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])

        languagePopup.addItems(withTitles: AppLanguage.allCases.map(\.nativeName))
        languagePopup.setAccessibilityIdentifier("appLanguage")
        languagePopup.target = self
        languagePopup.action = #selector(changeLanguage(_:))

        displayPopup.addItems(withTitles: [L(.list), L(.icons)])
        displayPopup.target = self
        displayPopup.action = #selector(changeDisplayMode(_:))
        placementPopup.addItems(withTitles: [L(.leftBottom), L(.leftTop), L(.rightBottom), L(.rightTop), L(.nearDrag)])
        placementPopup.target = self
        placementPopup.action = #selector(changePlacement(_:))
        transparencySlider.target = self
        transparencySlider.action = #selector(changeTransparency(_:))
        transparencySlider.toolTip = L(.transparencyHelp)
        historyControl.target = self
        historyControl.action = #selector(changeHistoryLimit(_:))
        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLogin(_:))
        menuBarCheckbox.target = self
        menuBarCheckbox.action = #selector(changeMenuBarVisibility(_:))
        dockCheckbox.target = self
        dockCheckbox.action = #selector(changeDockVisibility(_:))
        permissionButton.target = self
        permissionButton.action = #selector(openInputSettings(_:))
        permissionHelpButton.target = self
        permissionHelpButton.action = #selector(showPermissionHelp(_:))

        let general = addSection(.general, to: stack)
        addRow(.language, control: languagePopup, to: general)
        addRow(.menuBarIcon, control: menuBarCheckbox, to: general)
        addRow(.dockIcon, control: dockCheckbox, to: general)
        addRow(.launchAtLogin, control: loginCheckbox, to: general)
        addNote(loginStatusLabel, to: general)
        addNote(presenceNote, to: general)

        let appearance = addSection(.shelfAppearance, to: stack)
        addRow(.displayMode, control: displayPopup, to: appearance)
        addRow(.placement, control: placementPopup, to: appearance)
        addRow(.transparency, control: transparencySlider, to: appearance)

        let history = addSection(.history, to: stack)
        addRow(.maximumItems, control: historyControl, to: history)
        let note = NSTextField(wrappingLabelWithString: L(.historyHelp))
        localizedLabels.append((note, .historyHelp))
        addNote(note, to: history)

        let detection = addSection(.dragDetection, to: stack)
        addRow(.currentStatus, control: detectionLabel, to: detection)
        addRow(.inputMonitoring, control: permissionLabel, to: detection)
        let permissionActions = NSStackView(views: [permissionButton, permissionHelpButton])
        permissionActions.spacing = 8
        addRow(nil, control: permissionActions, to: detection)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 580, height: 650))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = content
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        return scroll
    }

    private func addHeading(_ key: AppText, to stack: NSStackView) {
        let label = NSTextField(labelWithString: L(key))
        localizedLabels.append((label, key))
        label.font = .boldSystemFont(ofSize: 14)
        stack.addArrangedSubview(label)
    }

    private func addSection(_ key: AppText, to parent: NSStackView) -> NSStackView {
        let box = NSBox(frame: NSRect(x: 0, y: 0, width: 540, height: 100))
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = 8
        box.borderWidth = 1
        box.borderColor = .separatorColor
        box.fillColor = .controlBackgroundColor
        box.setAccessibilityLabel(L(key))
        let section = NSStackView()
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        section.translatesAutoresizingMaskIntoConstraints = false
        box.contentView!.addSubview(section)
        parent.addArrangedSubview(box)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalTo: parent.widthAnchor),
            section.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            section.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            section.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            section.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
        ])
        addHeading(key, to: section)
        // The heading supplies the localized accessibility text without a stale box title.
        box.setAccessibilityElement(false)
        return section
    }

    private func addNote(_ label: NSTextField, to stack: NSStackView) {
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 11)
        stack.addArrangedSubview(label)
        label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addRow(_ key: AppText?, control: NSView, to stack: NSStackView) {
        let label = NSTextField(labelWithString: key.map { L($0) } ?? "")
        if let key { localizedLabels.append((label, key)) }
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 142).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.distribution = .fill
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    func show() {
        refreshFiles()
        refreshSystemStatus()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Change text in place: retain the active tab, controls, and parked-file model.
    func refreshLanguage() {
        window.title = L(.managementTitle)
        tabs.tabViewItems[0].label = L(.settings)
        tabs.tabViewItems[1].label = L(.parkedItems)
        languagePopup.selectItem(at: AppLanguage.allCases.firstIndex(of: AppLanguage.restored(from: .standard)) ?? 0)
        languagePopup.setAccessibilityLabel("Language / 言語")
        for (label, key) in localizedLabels { label.stringValue = L(key) }
        displayPopup = translatedPopup(displayPopup, titles: [AppText.list, .icons].map { L($0) })
        placementPopup = translatedPopup(placementPopup, titles: [AppText.leftBottom, .leftTop, .rightBottom, .rightTop, .nearDrag].map { L($0) })
        historyControl.setAccessibilityLabel(L(.maximumItems))
        loginCheckbox.title = L(.enable)
        menuBarCheckbox.title = L(.show)
        dockCheckbox.title = L(.show)
        emptyLabel.stringValue = L(.emptyFiles)
        permissionButton.title = L(.openInputSettings)
        permissionHelpButton.title = L(.permissionHelpTitle)
        transparencySlider.toolTip = L(.transparencyHelp)
        table.tableColumns.first?.title = L(.parkedFiles)
        refreshFiles()
        refreshSystemStatus()
    }

    private func translatedPopup(_ popup: NSPopUpButton, titles: [String]) -> NSPopUpButton {
        guard let row = popup.superview as? NSStackView else { return popup }
        // A live popup's modern renderer can keep the first item's title cached
        // even when its selection and cell title are correct. Replace only this
        // control, configuring its selection before attachment; never fire actions.
        let replacement = NSPopUpButton(frame: popup.frame, pullsDown: false)
        replacement.addItems(withTitles: titles)
        replacement.selectItem(at: popup.indexOfSelectedItem)
        replacement.target = popup.target
        replacement.action = popup.action
        row.removeArrangedSubview(popup)
        popup.removeFromSuperview()
        row.addArrangedSubview(replacement)
        return replacement
    }

    func refresh(displayMode: ShelfDisplayMode, placement: ShelfPlacement,
                 transparencyPercent: Double) {
        displayPopup.selectItem(at: displayMode == .list ? 0 : 1)
        placementPopup.selectItem(at: ShelfPlacement.allCases.firstIndex(of: placement) ?? 4)
        transparencySlider.doubleValue = transparencyPercent
        historyControl.selectedSegment = ShelfHistoryStore.supportedLimits.firstIndex(of: model.maximumItems) ?? 2
        refreshFiles()
    }

    func refreshFiles() {
        countLabel.stringValue = model.files.isEmpty
            ? L(.emptyCount)
            : L(.managementCount, model.files.count, model.maximumItems)
        emptyLabel.isHidden = !model.files.isEmpty
        table.reloadData()
    }

    func refreshSystemStatus() {
        guard let status = systemStatusProvider?() else { return }
        loginCheckbox.state = status.loginEnabled ? .on : .off
        menuBarCheckbox.state = status.menuBarVisible ? .on : .off
        dockCheckbox.state = status.dockVisible ? .on : .off
        menuBarCheckbox.isEnabled = true
        dockCheckbox.isEnabled = true
        presenceNote.stringValue = L(.presenceHelp)
        loginCheckbox.isEnabled = status.loginAvailable
        loginStatusLabel.stringValue = status.loginText
        permissionLabel.stringValue = status.inputGranted ? L(.permissionGranted) : L(.permissionDenied)
        permissionButton.isEnabled = !status.inputGranted
        detectionLabel.stringValue = status.detectionText
    }

    func numberOfRows(in tableView: NSTableView) -> Int { model.files.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard model.files.indices.contains(row) else { return nil }
        let url = model.files[row]
        let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: table.bounds.width, height: 54))
        let image = NSImageView(frame: NSRect(x: 8, y: 8, width: 38, height: 38))
        image.image = previews.image(for: url)
        image.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(image)

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.frame = NSRect(x: 56, y: 25, width: max(100, table.bounds.width - 108), height: 22)
        name.lineBreakMode = .byTruncatingMiddle
        name.autoresizingMask = [.width]
        name.toolTip = url.path
        cell.addSubview(name)
        if !FileManager.default.fileExists(atPath: url.path) {
            name.textColor = .secondaryLabelColor
            let missing = NSTextField(labelWithString: L(.missingFile))
            missing.textColor = .systemOrange
            missing.font = .systemFont(ofSize: 11)
            missing.frame = NSRect(x: 56, y: 8, width: 230, height: 16)
            cell.addSubview(missing)
        }

        let remove = NSButton(image: NSImage(systemSymbolName: "xmark.circle",
                                             accessibilityDescription: L(.remove))!,
                              target: self, action: #selector(removeFile(_:)))
        remove.frame = NSRect(x: max(115, table.bounds.width - 42), y: 12, width: 28, height: 28)
        remove.autoresizingMask = [.minXMargin]
        remove.isBordered = false
        remove.tag = row
        remove.toolTip = L(.removeHelp)
        cell.addSubview(remove)
        return cell
    }

    @objc private func removeFile(_ sender: NSButton) { model.remove(at: sender.tag) }
    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard AppLanguage.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        let language = AppLanguage.allCases[sender.indexOfSelectedItem]
        // Do not mutate other popup menus inside AppKit's menu-tracking action.
        DispatchQueue.main.async { [weak self] in self?.onLanguageChange?(language) }
    }
    @objc private func changeDisplayMode(_ sender: NSPopUpButton) {
        onDisplayModeChange?(sender.indexOfSelectedItem == 0 ? .list : .icons)
    }
    @objc private func changePlacement(_ sender: NSPopUpButton) {
        let values = ShelfPlacement.allCases
        guard values.indices.contains(sender.indexOfSelectedItem) else { return }
        onPlacementChange?(values[sender.indexOfSelectedItem])
    }
    @objc private func changeTransparency(_ sender: NSSlider) { onTransparencyChange?(sender.doubleValue) }
    @objc private func changeHistoryLimit(_ sender: NSSegmentedControl) {
        let limits = ShelfHistoryStore.supportedLimits
        guard limits.indices.contains(sender.selectedSegment) else { return }
        onHistoryLimitChange?(limits[sender.selectedSegment])
    }
    @objc private func toggleLogin(_ sender: NSButton) { onLoginToggle?() }
    @objc private func changeMenuBarVisibility(_ sender: NSButton) {
        onMenuBarVisibilityChange?(sender.state == .on)
    }
    @objc private func changeDockVisibility(_ sender: NSButton) {
        onDockVisibilityChange?(sender.state == .on)
    }
    @objc private func openInputSettings(_ sender: NSButton) { onOpenInputSettings?() }
    @objc private func showPermissionHelp(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = L(.inputMonitoring)
        alert.informativeText = L(.inputSettingsHelp) + "\n\n" + L(.permissionHelp)
        alert.beginSheetModal(for: window)
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}
