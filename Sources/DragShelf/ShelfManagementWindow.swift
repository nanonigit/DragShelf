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
    private let window: NSWindow
    private let table = NSTableView()
    private let countLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "ファイルを棚へドラッグすると、ここに表示されます")
    private let displayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let placementPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let transparencySlider = NSSlider(value: 0, minValue: 0, maxValue: 60,
                                              target: nil, action: nil)
    private let historyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let loginCheckbox = NSButton(checkboxWithTitle: "有効にする", target: nil, action: nil)
    private let menuBarCheckbox = NSButton(checkboxWithTitle: "表示する", target: nil, action: nil)
    private let dockCheckbox = NSButton(checkboxWithTitle: "表示する", target: nil, action: nil)
    private let presenceNote = NSTextField(wrappingLabelWithString: "")
    private let loginStatusLabel = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "入力監視の設定を開く", target: nil, action: nil)
    private let permissionNote = NSTextField(wrappingLabelWithString:
        "設定が ON でも未許可なら、アプリ更新で署名が変わった可能性があります。設定を OFF→ON にし、アプリを再起動してください。")
    private let detectionLabel = NSTextField(labelWithString: "")

    var onDisplayModeChange: ((ShelfDisplayMode) -> Void)?
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 590),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "DragShelf の管理"
        window.minSize = NSSize(width: 520, height: 560)
        window.center()
        window.isReleasedWhenClosed = false

        let tabs = NSTabView()
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
        settingsTab.label = "設定"
        settingsTab.view = makeSettingsView()
        tabs.addTabViewItem(settingsTab)

        let filesTab = NSTabViewItem(identifier: "files")
        filesTab.label = "一時置き"
        filesTab.view = makeFilesView()
        tabs.addTabViewItem(filesTab)
        tabs.selectTabViewItem(settingsTab)

        refresh(displayMode: displayMode, placement: placement,
                transparencyPercent: transparencyPercent)
    }

    private func makeFilesView() -> NSView {
        let content = NSView()
        countLabel.font = .systemFont(ofSize: 13)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(countLabel)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.title = "一時置きしたファイル"
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 54
        table.selectionHighlightStyle = .none
        table.delegate = self
        table.dataSource = self

        let scroll = NSScrollView()
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
        let content = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -12),
        ])

        displayPopup.addItems(withTitles: ["リスト", "アイコン"])
        displayPopup.target = self
        displayPopup.action = #selector(changeDisplayMode(_:))
        placementPopup.addItems(withTitles: ["左下", "右下", "ドラッグ位置の近く"])
        placementPopup.target = self
        placementPopup.action = #selector(changePlacement(_:))
        transparencySlider.target = self
        transparencySlider.action = #selector(changeTransparency(_:))
        transparencySlider.toolTip = "0%（不透明）〜60%（透明）"
        historyPopup.addItems(withTitles: ShelfHistoryStore.supportedLimits.map { "\($0) 件" })
        historyPopup.target = self
        historyPopup.action = #selector(changeHistoryLimit(_:))
        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLogin(_:))
        menuBarCheckbox.target = self
        menuBarCheckbox.action = #selector(changeMenuBarVisibility(_:))
        dockCheckbox.target = self
        dockCheckbox.action = #selector(changeDockVisibility(_:))
        permissionButton.target = self
        permissionButton.action = #selector(openInputSettings(_:))

        addHeading("表示", to: stack)
        addRow("表示形式", control: displayPopup, to: stack)
        addRow("棚の位置", control: placementPopup, to: stack)
        addRow("棚の透明度", control: transparencySlider, to: stack)
        addRow("メニューバーアイコン", control: menuBarCheckbox, to: stack)
        addRow("Dock アイコン", control: dockCheckbox, to: stack)
        presenceNote.textColor = .secondaryLabelColor
        stack.addArrangedSubview(presenceNote)
        presenceNote.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        addHeading("履歴", to: stack)
        addRow("最大保存件数", control: historyPopup, to: stack)
        let note = NSTextField(wrappingLabelWithString: "上限を超えると古い項目から棚を外します。元のファイルは消しません。")
        note.textColor = .secondaryLabelColor
        stack.addArrangedSubview(note)
        note.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        addHeading("起動", to: stack)
        addRow("ログイン時に起動", control: loginCheckbox, to: stack)
        loginStatusLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(loginStatusLabel)
        addHeading("ドラッグ検知", to: stack)
        addRow("入力監視", control: permissionLabel, to: stack)
        addRow("", control: permissionButton, to: stack)
        permissionNote.textColor = .secondaryLabelColor
        permissionNote.font = .systemFont(ofSize: 11)
        stack.addArrangedSubview(permissionNote)
        permissionNote.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        addRow("現在の動作", control: detectionLabel, to: stack)
        return content
    }

    private func addHeading(_ title: String, to stack: NSStackView) {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 14)
        stack.addArrangedSubview(label)
    }

    private func addRow(_ title: String, control: NSView, to stack: NSStackView) {
        let label = NSTextField(labelWithString: title)
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

    func refresh(displayMode: ShelfDisplayMode, placement: ShelfPlacement,
                 transparencyPercent: Double) {
        displayPopup.selectItem(at: displayMode == .list ? 0 : 1)
        placementPopup.selectItem(at: [.leftBottom, .rightBottom, .nearDrag].firstIndex(of: placement) ?? 2)
        transparencySlider.doubleValue = transparencyPercent
        historyPopup.selectItem(at: ShelfHistoryStore.supportedLimits.firstIndex(of: model.maximumItems) ?? 2)
        refreshFiles()
    }

    func refreshFiles() {
        countLabel.stringValue = model.files.isEmpty
            ? "棚は空です。ファイルをドラッグして一時置きできます。"
            : "一時置き: \(model.files.count) / \(model.maximumItems) 件　　× で棚から取り外せます。"
        emptyLabel.isHidden = !model.files.isEmpty
        table.reloadData()
    }

    func refreshSystemStatus() {
        guard let status = systemStatusProvider?() else { return }
        loginCheckbox.state = status.loginEnabled ? .on : .off
        menuBarCheckbox.state = status.menuBarVisible ? .on : .off
        dockCheckbox.state = status.dockVisible ? .on : .off
        menuBarCheckbox.isEnabled = status.dockVisible || !status.menuBarVisible
        dockCheckbox.isEnabled = status.menuBarVisible || !status.dockVisible
        if !status.menuBarVisible {
            presenceNote.stringValue = "Dock を隠すには、先にメニューバーアイコンを表示してください。"
        } else if !status.dockVisible {
            presenceNote.stringValue = "メニューバーを隠すには、先に Dock アイコンを表示してください。"
        } else {
            presenceNote.stringValue = "少なくとも一方のアイコンを表示します。アプリケーションからも管理画面を開けます。"
        }
        loginCheckbox.isEnabled = status.loginAvailable
        loginStatusLabel.stringValue = status.loginText
        permissionLabel.stringValue = status.inputGranted ? "アプリ側で許可済み" : "アプリ側では未許可"
        permissionButton.isEnabled = !status.inputGranted
        permissionNote.isHidden = status.inputGranted
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
            let missing = NSTextField(labelWithString: "元ファイルが見つかりません")
            missing.textColor = .systemOrange
            missing.font = .systemFont(ofSize: 11)
            missing.frame = NSRect(x: 56, y: 8, width: 230, height: 16)
            cell.addSubview(missing)
        }

        let remove = NSButton(image: NSImage(systemSymbolName: "xmark.circle",
                                             accessibilityDescription: "棚から取り外す")!,
                              target: self, action: #selector(removeFile(_:)))
        remove.frame = NSRect(x: max(115, table.bounds.width - 42), y: 12, width: 28, height: 28)
        remove.autoresizingMask = [.minXMargin]
        remove.isBordered = false
        remove.tag = row
        remove.toolTip = "棚から取り外す（元のファイルは消しません）"
        cell.addSubview(remove)
        return cell
    }

    @objc private func removeFile(_ sender: NSButton) { model.remove(at: sender.tag) }
    @objc private func changeDisplayMode(_ sender: NSPopUpButton) {
        onDisplayModeChange?(sender.indexOfSelectedItem == 0 ? .list : .icons)
    }
    @objc private func changePlacement(_ sender: NSPopUpButton) {
        let values: [ShelfPlacement] = [.leftBottom, .rightBottom, .nearDrag]
        guard values.indices.contains(sender.indexOfSelectedItem) else { return }
        onPlacementChange?(values[sender.indexOfSelectedItem])
    }
    @objc private func changeTransparency(_ sender: NSSlider) { onTransparencyChange?(sender.doubleValue) }
    @objc private func changeHistoryLimit(_ sender: NSPopUpButton) {
        let limits = ShelfHistoryStore.supportedLimits
        guard limits.indices.contains(sender.indexOfSelectedItem) else { return }
        onHistoryLimitChange?(limits[sender.indexOfSelectedItem])
    }
    @objc private func toggleLogin(_ sender: NSButton) { onLoginToggle?() }
    @objc private func changeMenuBarVisibility(_ sender: NSButton) {
        onMenuBarVisibilityChange?(sender.state == .on)
    }
    @objc private func changeDockVisibility(_ sender: NSButton) {
        onDockVisibilityChange?(sender.state == .on)
    }
    @objc private func openInputSettings(_ sender: NSButton) { onOpenInputSettings?() }
}
