import SwiftUI
import UniformTypeIdentifiers

@MainActor
class UninstallerViewModel: ObservableObject {
    @Published var scanResult: ScanResult?
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var hasFullDiskAccess = false
    @Published var showDeleteConfirmation = false
    @Published var appIcon: NSImage?

    private let scanner = FileScanner()

    func checkFullDiskAccess() {
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/Bookmarks.plist")
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: testPath.path)
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    await self.processApp(at: url)
                }
            }
            return true
        }
        return false
    }

    func processApp(at url: URL) async {
        errorMessage = nil
        isScanning = true
        scanResult = nil
        appIcon = nil

        do {
            let appInfo = try AppBundleParser.parse(appURL: url)
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
            appIcon?.size = NSSize(width: 64, height: 64)

            let files = await scanner.scan(appInfo: appInfo)
            scanResult = ScanResult(appInfo: appInfo, files: files)
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }

    func toggleSelection(for fileID: UUID) {
        guard let index = scanResult?.files.firstIndex(where: { $0.id == fileID }) else { return }
        scanResult?.files[index].isSelected.toggle()
    }

    func selectAll() {
        guard scanResult != nil else { return }
        for i in scanResult!.files.indices {
            scanResult!.files[i].isSelected = true
        }
    }

    func deselectAll() {
        guard scanResult != nil else { return }
        for i in scanResult!.files.indices {
            scanResult!.files[i].isSelected = false
        }
    }

    func deleteSelected() {
        guard let result = scanResult else { return }
        let selectedURLs = result.files.filter(\.isSelected).map(\.url)
        guard !selectedURLs.isEmpty else { return }

        let outcome = TrashService.moveToTrash(urls: selectedURLs)

        // Remove successfully trashed files from results
        let succeededSet = Set(outcome.succeeded)
        scanResult?.files.removeAll { $0.isSelected && succeededSet.contains($0.url) }

        if !outcome.failed.isEmpty {
            let failedPaths = outcome.failed.map { $0.0.lastPathComponent }.joined(separator: ", ")
            if !hasFullDiskAccess {
                errorMessage = "Could not move \(outcome.failed.count) file(s) to Trash (\(failedPaths)). Enable Full Disk Access in System Settings to allow deletion of protected files."
            } else {
                errorMessage = "Could not move \(outcome.failed.count) file(s) to Trash (\(failedPaths)). These may require admin privileges — try deleting them manually via Finder or Terminal."
            }
        } else {
            errorMessage = nil
        }
    }

    func deleteSingle(_ file: FoundFile) {
        let outcome = TrashService.moveToTrash(urls: [file.url])
        if !outcome.succeeded.isEmpty {
            scanResult?.files.removeAll { $0.id == file.id }
            errorMessage = nil
        } else if let error = outcome.failed.first?.1 {
            if !hasFullDiskAccess {
                errorMessage = "Cannot delete \"\(file.url.lastPathComponent)\": Enable Full Disk Access in System Settings, then try again."
            } else {
                errorMessage = "Cannot delete \"\(file.url.lastPathComponent)\": \(error.localizedDescription). Try deleting manually via Finder or Terminal."
            }
        }
    }

    func revealInFinder(_ url: URL) {
        TrashService.revealInFinder(url)
    }

    func reset() {
        scanResult = nil
        appIcon = nil
        errorMessage = nil
        isScanning = false
    }
}
