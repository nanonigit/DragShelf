import AppKit
import DragShelfCore
import OSLog
import QuickLookUI

@MainActor
final class ShelfDropView: NSView, NSDraggingSource, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
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
    private var hoverTrackingArea: NSTrackingArea?
    private var hoveredURL: URL?
    private var hoverPoint: NSPoint?
    private var previewedURL: URL?
    private weak var controlledPreviewPanel: QLPreviewPanel?
    private var originalPreviewLevel: NSWindow.Level?
    private weak var previousKeyWindow: NSWindow?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { false }

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
        if let previewedURL, model?.files.contains(previewedURL) != true {
            closePreview()
        }
        updateHover(at: hoverPoint)
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                 options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                 owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
        toolTip = "ファイルをクリックし、スペースキーでプレビュー"
    }

    /// Resolve the current geometry, rather than retaining an index across mutations.
    func previewURL(at point: NSPoint) -> URL? {
        guard bounds.contains(point), let model,
              let index = layout.index(at: point, scrollOffset: scrollOffset),
              let frame = layout.itemFrame(at: index, scrollOffset: scrollOffset),
              frame.contains(point),
              !removeRect(for: frame).insetBy(dx: -6, dy: -6).contains(point) else { return nil }
        let url = model.files[index]
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseMoved(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        hoverPoint = nil
        hoveredURL = nil
        needsDisplay = true
        releaseHoverFocus()
    }

    private func updateHover(at point: NSPoint?) {
        hoverPoint = point
        let url = point.flatMap { previewURL(at: $0) }
        if hoveredURL != url { hoveredURL = url; needsDisplay = true }
        guard url != nil, window?.isVisible == true, NSEvent.pressedMouseButtons == 0 else {
            releaseHoverFocus()
            return
        }
    }

    private func acquireFileFocus() {
        guard let window else { return }
        window.makeFirstResponder(self)
        if !window.isKeyWindow {
            previousKeyWindow = NSApp.keyWindow
            window.makeKey()
        }
    }

    private func releaseHoverFocus() {
        guard window?.isKeyWindow == true else { return }
        window?.resignKey()
        if previousKeyWindow?.isVisible == true { previousKeyWindow?.makeKey() }
        previousKeyWindow = nil
    }

    static func isPreviewKey(_ event: NSEvent) -> Bool {
        event.type == .keyDown && event.keyCode == 49 && !event.isARepeat &&
            event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
    }

    override func keyDown(with event: NSEvent) {
        if Self.isPreviewKey(event), NSEvent.pressedMouseButtons == 0,
           let point = hoverPoint, let url = previewURL(at: point) {
            togglePreview(for: url)
        } else if event.keyCode == 53, controlledPreviewPanel?.isVisible == true {
            closePreview()
        } else if !event.isARepeat {
            super.keyDown(with: event)
        }
    }

    func togglePreview(for url: URL) {
        guard window?.isVisible == true, model?.files.contains(url) == true,
              FileManager.default.fileExists(atPath: url.path),
              NSEvent.pressedMouseButtons == 0 else { return }
        if controlledPreviewPanel?.isVisible == true, previewedURL == url {
            closePreview()
            return
        }
        previewedURL = url
        window?.makeFirstResponder(self)
        window?.makeKey()
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.makeKeyAndOrderFront(nil)
        panel.updateController()
        guard controlledPreviewPanel === panel else {
            panel.orderOut(nil)
            previewedURL = nil
            log.error("Quick Look could not acquire the shelf responder")
            NSSound.beep()
            return
        }
        // A populated shelf is status-bar-level; its preview must be above it.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        previewedURL != nil
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        controlledPreviewPanel = panel
        originalPreviewLevel = panel.level
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
        if let originalPreviewLevel { panel.level = originalPreviewLevel }
        originalPreviewLevel = nil
        controlledPreviewPanel = nil
        previewedURL = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewedURL == nil ? 0 : 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        index == 0 ? previewedURL.map { $0 as NSURL } : nil
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }
        if event.keyCode == 49, event.isARepeat { return true }
        if Self.isPreviewKey(event) {
            if NSEvent.pressedMouseButtons == 0, let point = hoverPoint,
               let url = previewURL(at: point), url != previewedURL {
                togglePreview(for: url)
            } else {
                closePreview()
            }
            return true
        }
        if event.keyCode == 53 { closePreview(); return true }
        return false
    }

    private func closePreview() {
        guard let panel = controlledPreviewPanel else { previewedURL = nil; return }
        panel.orderOut(nil)
        previewedURL = nil
        panel.updateController()
        updateHover(at: hoverPoint)
    }

    func endPreviewInteraction() {
        closePreview()
        hoverPoint = nil
        hoveredURL = nil
        releaseHoverFocus()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.97).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14).stroke()

        drawControlSymbol("gearshape.fill",
                          description: "管理画面を開く",
                          in: NSRect(x: 7, y: 6, width: 30, height: 30),
                          symbolInset: 6,
                          cornerRadius: 8)
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
        if hoveredURL == url {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            NSBezierPath(roundedRect: frame.insetBy(dx: 2, dy: 2), xRadius: 9, yRadius: 9).fill()
        }
        let image = previews?.image(for: url) ?? NSWorkspace.shared.icon(forFile: url.path)
        let exists = FileManager.default.fileExists(atPath: url.path)
        let title = exists ? url.lastPathComponent : "⚠︎ \(url.lastPathComponent)"
        switch displayMode {
        case .list:
            let imageFrame = NSRect(x: frame.minX + 5, y: frame.minY + 7, width: 34, height: 34)
            drawImage(image, fitting: imageFrame)
            drawText(title,
                     in: NSRect(x: frame.minX + 43, y: frame.minY + 14,
                                width: frame.width - 72, height: 22), size: 11,
                     color: exists ? .labelColor : .secondaryLabelColor)
            drawRemoveButton(in: removeRect(for: frame))
        case .icons:
            let background = frame.insetBy(dx: 4, dy: 4)
            NSColor.controlBackgroundColor.withAlphaComponent(0.65).setFill()
            NSBezierPath(roundedRect: background, xRadius: 9, yRadius: 9).fill()
            drawImage(image, fitting: NSRect(x: frame.minX + 15, y: frame.minY + 10,
                                             width: 118, height: 101))
            drawText(title,
                     in: NSRect(x: frame.minX + 8, y: frame.minY + 117,
                                width: frame.width - 16, height: 22), size: 11,
                     alignment: .center,
                     color: exists ? .labelColor : .secondaryLabelColor)
            drawRemoveButton(in: removeRect(for: frame))
        }
    }

    private func drawRemoveButton(in rect: NSRect) {
        drawControlSymbol("xmark", description: "棚から取り外す", in: rect,
                          symbolInset: 5, cornerRadius: rect.width / 2)
    }

    private func drawControlSymbol(_ name: String, description: String, in rect: NSRect,
                                   symbolInset: CGFloat, cornerRadius: CGFloat) {
        let background = NSBezierPath(roundedRect: rect, xRadius: cornerRadius,
                                      yRadius: cornerRadius)
        NSColor(calibratedWhite: 0.10, alpha: 0.96).setFill()
        background.fill()
        NSColor.white.withAlphaComponent(0.42).setStroke()
        background.lineWidth = 0.8
        background.stroke()

        let configuration = NSImage.SymbolConfiguration(paletteColors: [.white])
        NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)?
            .draw(in: rect.insetBy(dx: symbolInset, dy: symbolInset))
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
                          bold: Bool = false, alignment: NSTextAlignment = .left,
                          color: NSColor = .labelColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        paragraph.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    private func removeRect(for frame: NSRect) -> NSRect {
        switch displayMode {
        case .list: NSRect(x: frame.maxX - 28, y: frame.minY + 13, width: 23, height: 23)
        case .icons: NSRect(x: frame.maxX - 30, y: frame.minY + 8, width: 23, height: 23)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        releaseHoverFocus()
        return sender.draggingPasteboard.types?.contains(.fileURL) == true ? .copy : []
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
        hoverPoint = convert(event.locationInWindow, from: nil)
        scrollContent(by: event.scrollingDeltaY)
    }

    func scrollContent(by delta: CGFloat) {
        let maximum = layout.maximumScrollOffset(panelHeight: bounds.height)
        scrollOffset = min(max(0, scrollOffset - delta), maximum)
        updateHover(at: hoverPoint)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        closePreview()
        let point = convert(event.locationInWindow, from: nil)
        updateHover(at: point)
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
        guard FileManager.default.fileExists(atPath: model.files[index].path) else { return }
        acquireFileFocus()
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
        guard FileManager.default.fileExists(atPath: url.path) else {
            pendingIndex = nil
            self.mouseDownEvent = nil
            return
        }
        pendingIndex = nil
        self.mouseDownEvent = nil

        endPreviewInteraction()

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
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
