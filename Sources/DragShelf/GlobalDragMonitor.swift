import AppKit
import CoreGraphics

/// Observes pointer events without modifying the event stream.
final class GlobalDragMonitor {
    enum Mode: String {
        case eventTap = "Passive event tap"
        case appKitMonitor = "AppKit global monitor"
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var appKitToken: Any?
    private let onEvent: (PointerEvent, NSPoint) -> Void
    private(set) var mode: Mode = .appKitMonitor
    var isRunning: Bool { eventTap != nil || appKitToken != nil }

    enum PointerEvent {
        case down
        case dragged
        case up
    }

    init(onEvent: @escaping (PointerEvent, NSPoint) -> Void) {
        self.onEvent = onEvent
    }

    func start(forceAppKit: Bool = false) {
        stop()
        let mask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseDragged.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        if !forceAppKit, CGPreflightListenEventAccess(), let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                if let userInfo {
                    let monitor = Unmanaged<GlobalDragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                    let kind: PointerEvent?
                    switch type {
                    case .leftMouseDown: kind = .down
                    case .leftMouseDragged: kind = .dragged
                    case .leftMouseUp: kind = .up
                    default: kind = nil
                    }
                    if let kind {
                        DispatchQueue.main.async { monitor.onEvent(kind, NSEvent.mouseLocation) }
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        ) {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            eventTap = tap
            runLoopSource = source
            mode = .eventTap
            return
        }

        appKitToken = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            let kind: PointerEvent
            switch event.type {
            case .leftMouseDown: kind = .down
            case .leftMouseDragged: kind = .dragged
            case .leftMouseUp: kind = .up
            default: return
            }
            self?.onEvent(kind, NSEvent.mouseLocation)
        }
        mode = .appKitMonitor
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        if let appKitToken {
            NSEvent.removeMonitor(appKitToken)
        }
        appKitToken = nil
    }

    deinit { stop() }
}
