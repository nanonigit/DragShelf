import Foundation

@MainActor
final class ShelfModel {
    private(set) var files: [URL] = []
    var didChange: (() -> Void)?

    func add(_ urls: [URL]) {
        let incoming = urls.filter { $0.isFileURL }
        guard !incoming.isEmpty else { return }
        files.append(contentsOf: incoming)
        didChange?()
    }

    func remove(at index: Int) {
        guard files.indices.contains(index) else { return }
        files.remove(at: index)
        didChange?()
    }
}
