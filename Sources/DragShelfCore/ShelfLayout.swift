import CoreGraphics

public enum ShelfDisplayMode: String, CaseIterable {
    case list
    case icons
}

public enum ShelfPlacement: String, CaseIterable {
    case leftBottom
    case rightBottom
    case nearDrag
}

public struct ShelfLayout {
    public static let width: CGFloat = 160
    public static let headerHeight: CGFloat = 42
    public static let maximumHeight: CGFloat = 430

    public let mode: ShelfDisplayMode
    public let count: Int

    public init(mode: ShelfDisplayMode, count: Int) {
        self.mode = mode
        self.count = max(0, count)
    }

    public var contentHeight: CGFloat {
        switch mode {
        case .list: CGFloat(count) * 48
        case .icons: CGFloat(count) * 148
        }
    }

    public var panelHeight: CGFloat {
        min(Self.maximumHeight, max(112, Self.headerHeight + contentHeight + 8))
    }

    public func maximumScrollOffset(panelHeight: CGFloat) -> CGFloat {
        max(0, contentHeight - (panelHeight - Self.headerHeight - 8))
    }

    public func itemFrame(at index: Int, scrollOffset: CGFloat = 0) -> CGRect? {
        guard (0..<count).contains(index) else { return nil }
        switch mode {
        case .list:
            return CGRect(x: 6, y: Self.headerHeight + CGFloat(index) * 48 - scrollOffset,
                          width: Self.width - 12, height: 48)
        case .icons:
            return CGRect(x: 6,
                          y: Self.headerHeight + CGFloat(index) * 148 - scrollOffset,
                          width: 148, height: 148)
        }
    }

    public func index(at point: CGPoint, scrollOffset: CGFloat = 0) -> Int? {
        guard point.y >= Self.headerHeight else { return nil }
        let contentY = point.y - Self.headerHeight + scrollOffset
        guard contentY >= 0 else { return nil }
        let index: Int
        switch mode {
        case .list:
            index = Int(contentY / 48)
        case .icons:
            guard point.x >= 6 && point.x < Self.width - 6 else { return nil }
            index = Int(contentY / 148)
        }
        return (0..<count).contains(index) ? index : nil
    }

    public static func origin(
        in visibleFrame: CGRect,
        panelSize: CGSize,
        pointer: CGPoint,
        placement: ShelfPlacement
    ) -> CGPoint {
        let inset: CGFloat = 12
        let x: CGFloat
        let y: CGFloat
        switch placement {
        case .leftBottom:
            x = visibleFrame.minX + inset
            y = visibleFrame.minY + inset
        case .rightBottom:
            x = visibleFrame.maxX - panelSize.width - inset
            y = visibleFrame.minY + inset
        case .nearDrag:
            let preferredX = pointer.x + 24
            x = preferredX + panelSize.width + inset <= visibleFrame.maxX
                ? preferredX : pointer.x - panelSize.width - 24
            let preferredY = pointer.y - panelSize.height / 2
            y = preferredY
        }
        return CGPoint(
            x: min(max(x, visibleFrame.minX + inset), visibleFrame.maxX - panelSize.width - inset),
            y: min(max(y, visibleFrame.minY + inset), visibleFrame.maxY - panelSize.height - inset)
        )
    }
}
