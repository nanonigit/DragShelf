import AppKit
import QuickLookThumbnailing

@MainActor
final class FilePreviewStore {
    private var thumbnails: [URL: NSImage] = [:]
    private var requested: Set<URL> = []
    var didUpdate: (() -> Void)?

    func image(for url: URL) -> NSImage {
        if let thumbnail = thumbnails[url] { return thumbnail }
        requestThumbnail(for: url)
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func requestThumbnail(for url: URL) {
        guard requested.insert(url).inserted else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 132, height: 100),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: [.thumbnail]
        )
        request.iconMode = true
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let representation else { return }
            DispatchQueue.main.async {
                self?.thumbnails[url] = representation.nsImage
                self?.didUpdate?()
            }
        }
    }

    func retainOnly(_ urls: [URL]) {
        let keep = Set(urls)
        thumbnails = thumbnails.filter { keep.contains($0.key) }
        requested = requested.intersection(keep)
    }
}
