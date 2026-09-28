import AppKit

@MainActor
final class ShelfManagementWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let model: ShelfModel
    private let previews: FilePreviewStore
    private let window: NSWindow
    private let table = NSTableView()
    private let countLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "ファイルを棚へドラッグすると、ここに表示されます")
    private let transparencyLabel = NSTextField(labelWithString: "棚の透明度")
    private let transparencySlider = NSSlider(value: 0, minValue: 0, maxValue: 60,
                                              target: nil, action: nil)
    var onTransparencyChange: ((Double) -> Void)?

    init(model: ShelfModel, previews: FilePreviewStore, transparencyPercent: Double) {
        self.model = model
        self.previews = previews
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "DragShelf の管理"
        window.minSize = NSSize(width: 360, height: 240)
        window.center()
        window.isReleasedWhenClosed = false

        let content = NSView()
        window.contentView = content
        countLabel.font = .systemFont(ofSize: 13)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(countLabel)
        transparencyLabel.font = .systemFont(ofSize: 13)
        transparencyLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(transparencyLabel)
        transparencySlider.doubleValue = transparencyPercent
        transparencySlider.target = self
        transparencySlider.action = #selector(changeTransparency(_:))
        transparencySlider.translatesAutoresizingMaskIntoConstraints = false
        transparencySlider.toolTip = "棚の透明度（0〜60%）"
        content.addSubview(transparencySlider)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.title = "一時置きしたファイル"
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 50
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
            countLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            countLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            countLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            transparencyLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            transparencyLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 14),
            transparencySlider.leadingAnchor.constraint(equalTo: transparencyLabel.trailingAnchor, constant: 12),
            transparencySlider.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            transparencySlider.centerYAnchor.constraint(equalTo: transparencyLabel.centerYAnchor),
            scroll.topAnchor.constraint(equalTo: transparencySlider.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
        ])
        refresh()
    }

    func show() {
        refresh()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh() {
        countLabel.stringValue = model.files.isEmpty
            ? "棚は空です。ファイルをドラッグして一時置きできます。"
            : "一時置き: \(model.files.count) 件　　× で棚から取り外せます。"
        emptyLabel.isHidden = !model.files.isEmpty
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        model.files.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        guard model.files.indices.contains(row) else { return nil }
        let url = model.files[row]
        let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: table.bounds.width, height: 50))

        let image = NSImageView(frame: NSRect(x: 8, y: 6, width: 38, height: 38))
        image.image = previews.image(for: url)
        image.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(image)

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.frame = NSRect(x: 56, y: 14, width: max(100, table.bounds.width - 105), height: 23)
        name.lineBreakMode = .byTruncatingMiddle
        name.autoresizingMask = [.width]
        name.toolTip = url.path
        cell.addSubview(name)

        let remove = NSButton(image: NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "棚から取り外す")!,
                              target: self, action: #selector(removeFile(_:)))
        remove.frame = NSRect(x: max(115, table.bounds.width - 42), y: 10, width: 28, height: 28)
        remove.autoresizingMask = [.minXMargin]
        remove.isBordered = false
        remove.tag = row
        remove.toolTip = "棚から取り外す（元のファイルは消しません）"
        cell.addSubview(remove)
        return cell
    }

    @objc private func removeFile(_ sender: NSButton) {
        model.remove(at: sender.tag)
    }

    @objc private func changeTransparency(_ sender: NSSlider) {
        onTransparencyChange?(sender.doubleValue)
    }
}
