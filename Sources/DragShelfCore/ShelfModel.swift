import Foundation

@MainActor
public final class ShelfModel {
    private let history: ShelfHistoryStore
    public private(set) var files: [URL]
    public var didChange: (() -> Void)?

    public init(history: ShelfHistoryStore = ShelfHistoryStore()) {
        self.history = history
        files = history.load()
    }

    public var maximumItems: Int { history.limit }

    public func add(_ urls: [URL]) {
        let incoming = urls.filter(\.isFileURL)
        guard !incoming.isEmpty else { return }
        files = ShelfHistoryStore.retainingNewest(files + incoming, limit: history.limit)
        history.save(files)
        didChange?()
    }

    public func remove(at index: Int) {
        guard files.indices.contains(index) else { return }
        files.remove(at: index)
        history.save(files)
        didChange?()
    }

    public func setMaximumItems(_ value: Int) {
        guard value != history.limit else { return }
        files = history.setLimit(value, in: files)
        didChange?()
    }
}
