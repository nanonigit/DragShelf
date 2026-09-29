import Foundation

public struct AppPresence: Equatable {
    public static let dockKey = "showDockIcon"
    public static let menuBarKey = "showMenuBarIcon"

    public let dockVisible: Bool
    public let menuBarVisible: Bool

    public init(dockVisible: Bool, menuBarVisible: Bool) {
        self.dockVisible = dockVisible
        self.menuBarVisible = menuBarVisible
    }

    public static func restored(from defaults: UserDefaults) -> AppPresence {
        let dock = defaults.object(forKey: dockKey) as? Bool ?? true
        let menuBar = defaults.object(forKey: menuBarKey) as? Bool ?? true
        return AppPresence(dockVisible: dock, menuBarVisible: menuBar)
    }

    public func changingDockVisibility(to visible: Bool) -> AppPresence? {
        return AppPresence(dockVisible: visible, menuBarVisible: menuBarVisible)
    }

    public func changingMenuBarVisibility(to visible: Bool) -> AppPresence? {
        return AppPresence(dockVisible: dockVisible, menuBarVisible: visible)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(dockVisible, forKey: Self.dockKey)
        defaults.set(menuBarVisible, forKey: Self.menuBarKey)
    }
}
