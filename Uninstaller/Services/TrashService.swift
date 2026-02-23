import Foundation
import AppKit

struct TrashService {

    static func moveToTrash(urls: [URL]) -> (succeeded: [URL], failed: [(URL, Error)]) {
        var succeeded: [URL] = []
        var failed: [(URL, Error)] = []

        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                succeeded.append(url)
            } catch {
                failed.append((url, error))
            }
        }

        return (succeeded, failed)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
