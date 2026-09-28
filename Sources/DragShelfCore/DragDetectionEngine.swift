/// Combines pointer movement with a fresh, supported drag pasteboard generation.
/// A pointer drag alone is not evidence that an item can be dropped on the shelf.
public struct DragDetectionEngine {
    public enum Input {
        case mouseDown
        case mouseDragged
        case sample
        case mouseUp
    }

    public enum Action: Equatable {
        case none
        case reveal
        case end
    }

    public struct PasteboardSnapshot {
        public let changeCount: Int
        public let hasSupportedType: Bool

        public init(changeCount: Int, hasSupportedType: Bool) {
            self.changeCount = changeCount
            self.hasSupportedType = hasSupportedType
        }
    }

    private var baseline: Int?
    private var hasMoved = false
    private var hasRevealed = false

    public var isTracking: Bool { baseline != nil }

    public init() {}

    public mutating func handle(_ input: Input, pasteboard: PasteboardSnapshot) -> Action {
        switch input {
        case .mouseDown:
            baseline = pasteboard.changeCount
            hasMoved = false
            hasRevealed = false
            return .none
        case .mouseDragged:
            hasMoved = true
            return revealIfEligible(pasteboard)
        case .sample:
            return revealIfEligible(pasteboard)
        case .mouseUp:
            let wasActive = baseline != nil
            baseline = nil
            hasMoved = false
            hasRevealed = false
            return wasActive ? .end : .none
        }
    }

    private mutating func revealIfEligible(_ snapshot: PasteboardSnapshot) -> Action {
        guard let baseline, hasMoved, !hasRevealed,
              snapshot.changeCount > baseline,
              snapshot.hasSupportedType else {
            return .none
        }
        hasRevealed = true
        return .reveal
    }
}
