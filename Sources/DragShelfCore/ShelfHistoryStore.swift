import Foundation

public final class ShelfHistoryStore {
    public static let supportedLimits = [5, 10, 25, 50, 100]
    public static let defaultLimit = 25

    private struct Reference: Codable {
        let path: String
        let bookmark: Data?
    }

    private let defaults: UserDefaults
    private let historyKey = "shelfHistoryReferences"
    private let limitKey = "shelfHistoryLimit"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var limit: Int {
        let saved = defaults.integer(forKey: limitKey)
        return Self.supportedLimits.contains(saved) ? saved : Self.defaultLimit
    }

    @discardableResult
    public func setLimit(_ value: Int, in urls: [URL]) -> [URL] {
        guard Self.supportedLimits.contains(value) else { return urls }
        defaults.set(value, forKey: limitKey)
        let retained = Self.retainingNewest(urls, limit: value)
        save(retained)
        return retained
    }

    public func load() -> [URL] {
        guard let data = defaults.data(forKey: historyKey),
              let references = try? JSONDecoder().decode([Reference].self, from: data) else {
            return []
        }
        let urls = references.map { reference -> URL in
            if let bookmark = reference.bookmark {
                var stale = false
                if let resolved = try? URL(resolvingBookmarkData: bookmark,
                                           options: [], relativeTo: nil,
                                           bookmarkDataIsStale: &stale), resolved.isFileURL {
                    return resolved
                }
            }
            return URL(fileURLWithPath: reference.path)
        }
        return Self.retainingNewest(urls, limit: limit)
    }

    public func save(_ urls: [URL]) {
        let previous = defaults.data(forKey: historyKey)
            .flatMap { try? JSONDecoder().decode([Reference].self, from: $0) } ?? []
        let existingBookmarks = Dictionary(previous.compactMap { reference -> (String, Data)? in
            guard let bookmark = reference.bookmark else { return nil }
            return (reference.path, bookmark)
        }, uniquingKeysWith: { first, _ in first })
        let references = Self.retainingNewest(urls, limit: limit).filter(\.isFileURL).map { url in
            Reference(path: url.path,
                      bookmark: existingBookmarks[url.path] ??
                          (try? url.bookmarkData(options: [],
                                                 includingResourceValuesForKeys: nil,
                                                 relativeTo: nil)))
        }
        guard let data = try? JSONEncoder().encode(references) else { return }
        defaults.set(data, forKey: historyKey)
    }

    public static func retainingNewest(_ urls: [URL], limit: Int) -> [URL] {
        Array(urls.suffix(max(0, limit)))
    }
}
