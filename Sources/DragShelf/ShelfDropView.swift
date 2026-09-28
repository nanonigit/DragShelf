import AppKit
import DragShelfCore
import OSLog

@MainActor
final class ShelfDropView: NSView, NSDraggingSource {
    private let log = Logger(subsystem: "dev.local.DragShelf", category: "Drop")
    var model: ShelfModel?
    var previews: FilePreviewStore?
    var displayMode: ShelfDisplayMode = .icons
    var onDisplayModeChange: ((ShelfDisplayMode) -> Void)?
    var onOpenManagement: (() -> Void)?

    private var scrollOffset: CGFloat = 0
    private var pendingIndex: Int?
    private var mouseDownEvent: NSEvent?
    private var mouseDownPoint = NSPoint.zero

    override var isFlipped: Bool { true }

    private var layout: ShelfLayout {
        ShelfLayout(mode: displayMode, count: model?.files.count ?? 0)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    func refreshContent() {
        scrollOffset = min(scrollOffset, layout.maximumScrollOffset(panelHeight: bounds.height))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.97).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14).stroke()

        NSImage(systemSymbolName: "gearshape", accessibilityDescription: "管理画面を開く")?
            .draw(in: NSRect(x: 11, y: 10, width: 21, height: 21))
        drawModeButton("リスト", mode: .list, rect: NSRect(x: 40, y: 7, width: 51, height: 28))
        drawModeButton("アイコン", mode: .icons, rect: NSRect(x: 95, y: 7, width: 57, height: 28))
        NSColor.separatorColor.setFill()
        NSRect(x: 8, y: 41, width: bounds.width - 16, height: 1).fill()

        let files = model?.files ?? []
        guard !files.isEmpty else {
            drawText("ここにドロップ", in: NSRect(x: 12, y: 65, width: 136, height: 28),
                     size: 12, alignment: .center)
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 0, y: ShelfLayout.headerHeight,
                                  width: bounds.width,
                                  height: bounds.height - ShelfLayout.headerHeight)).addClip()
        for (index, url) in files.enumerated() {
            guard let frame = layout.itemFrame(at: index, scrollOffset: scrollOffset),
                  frame.maxY >= ShelfLayout.headerHeight, frame.minY <= bounds.height else { continue }
            drawItem(url, in: frame)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawModeButton(_ title: String, mode: ShelfDisplayMode, rect: NSRect) {
        let selected = displayMode == mode
        (selected ? NSColor.controlAccentColor.withAlphaComponent(0.24)
                  : NSColor.controlBackgroundColor).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
        drawText(title, in: rect.insetBy(dx: 2, dy: 5), size: 11, bold: selected,
                 alignment: .center)
    }

    private func drawItem(_ url: URL, in frame: NSRect) {
        let image = previews?.image(for: url) ?? NSWorkspace.shared.icon(forFile: url.path)
        switch displayMode {
        case .list:
            let imageFrame = NSRect(x: frame.minX + 5, y: frame.minY + 7, width: 34, height: 34)
            drawImage(image, fitting: imageFrame)
            drawText(url.lastPathComponent,
                     in: NSRect(x: frame.minX + 43, y: frame.minY + 14,
                                width: frame.width - 72, height: 22), size: 11)
            drawRemoveButton(in: removeRect(for: frame))
        case .icons:
            let background = frame.insetBy(dx: 4, dy: 4)
            NSColor.controlBackgroundColor.withAlphaComponent(0.65).setFill()
            NSBezierPath(roundedRect: background, xRadius: 9, yRadius: 9).fill()
            drawImage(image, fitting: NSRect(x: frame.minX + 15, y: frame.minY + 10,
                                             width: 118, height: 101))
            drawText(url.lastPathComponent,
                     in: NSRect(x: frame.minX + 8, y: frame.minY + 117,
                                width: frame.width - 16, height: 22), size: 11,
                     alignment: .center)
            drawRemoveButton(in: removeRect(for: frame))
        }
    }

    private func drawRemoveButton(in rect: NSRect) {
        NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "削除")?
            .draw(in: rect)
    }

    private func drawImage(_ image: NSImage, fitting rect: NSRect) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = NSRect(x: rect.midX - size.width * scale / 2,
                            y: rect.midY - size.height * scale / 2,
                            width: size.width * scale, height: size.height * scale)
        image.draw(in: fitted, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }

    private func drawText(_ text: String, in rect: NSRect, size: CGFloat,
                          bold: Bool = false, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        paragraph.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    private func removeRect(for frame: NSRect) -> NSRect {
        switch displayMode {
        case .list: NSRect(x: frame.maxX - 25, y: frame.minY + 15, width: 19, height: 19)
        case .icons: NSRect(x: frame.maxX - 28, y: frame.minY + 10, width: 19, height: 19)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.types?.contains(.fileURL) == true ? .copy : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.types?.contains(.fileURL) == true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: options
        ) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        model?.add(urls)
        log.info("Parked \(urls.count) file URLs")
        return true
    }

    override func scrollWheel(with event: NSEvent) {
        let maximum = layout.maximumScrollOffset(panelHeight: bounds.height)
        scrollOffset = min(max(0, scrollOffset - event.scrollingDeltaY), maximum)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if NSRect(x: 6, y: 5, width: 31, height: 32).contains(point) {
            onOpenManagement?()
            return
        }
        if NSRect(x: 40, y: 7, width: 51, height: 28).contains(point) {
            onDisplayModeChange?(.list)
            return
        }
        if NSRect(x: 95, y: 7, width: 57, height: 28).contains(point) {
            onDisplayModeChange?(.icons)
            return
        }
        guard point.y < bounds.height, let model,
              let index = layout.index(at: point, scrollOffset: scrollOffset),
              let frame = layout.itemFrame(at: index, scrollOffset: scrollOffset),
              frame.contains(point) else { return }
        if removeRect(for: frame).insetBy(dx: -6, dy: -6).contains(point) {
            model.remove(at: index)
            return
        }
        pendingIndex = index
        mouseDownEvent = event
        mouseDownPoint = point
    }

    override func mouseDragged(with event: NSEvent) {
        guard let model, let index = pendingIndex,
              model.files.indices.contains(index), let mouseDownEvent else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) >= 4 else { return }
        let url = model.files[index]
        pendingIndex = nil
        self.mouseDownEvent = nil

        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let frame = layout.itemFrame(at: index, scrollOffset: scrollOffset)
            ?? NSRect(x: 14, y: 52, width: 40, height: 40)
        let draggingFrame = displayMode == .list
            ? NSRect(x: frame.minX + 5, y: frame.minY + 7, width: 34, height: 34)
            : NSRect(x: frame.minX + 15, y: frame.minY + 10, width: 118, height: 101)
        item.setDraggingFrame(draggingFrame,
                              contents: previews?.image(for: url) ?? NSWorkspace.shared.icon(forFile: url.path))
        beginDraggingSession(with: [item], event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        pendingIndex = nil
        mouseDownEvent = nil
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
