import Foundation

class FileScanner {
    private let fileManager = FileManager.default

    func scan(appInfo: AppInfo) async -> [FoundFile] {
        var results: [FoundFile] = []
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let userLib = homeDir.appendingPathComponent("Library")
        let sysLib = URL(fileURLWithPath: "/Library")

        // --- EXACT MATCH SCANS ---

        // ~/Library/Containers/{bundleID}
        checkExact(
            userLib.appendingPathComponent("Containers")
                .appendingPathComponent(appInfo.bundleIdentifier),
            category: .containers, into: &results
        )

        // ~/Library/Saved Application State/{bundleID}.savedState
        checkExact(
            userLib.appendingPathComponent("Saved Application State")
                .appendingPathComponent("\(appInfo.bundleIdentifier).savedState"),
            category: .savedState, into: &results
        )

        // ~/Library/HTTPStorages/{bundleID}
        checkExact(
            userLib.appendingPathComponent("HTTPStorages")
                .appendingPathComponent(appInfo.bundleIdentifier),
            category: .httpStorages, into: &results
        )

        // ~/Library/WebKit/{bundleID}
        checkExact(
            userLib.appendingPathComponent("WebKit")
                .appendingPathComponent(appInfo.bundleIdentifier),
            category: .webKit, into: &results
        )

        // ~/Library/Cookies/{bundleID}.binarycookies
        checkExact(
            userLib.appendingPathComponent("Cookies")
                .appendingPathComponent("\(appInfo.bundleIdentifier).binarycookies"),
            category: .cookies, into: &results
        )

        // ~/Library/Preferences/{bundleID}.plist
        checkExact(
            userLib.appendingPathComponent("Preferences")
                .appendingPathComponent("\(appInfo.bundleIdentifier).plist"),
            category: .preferences, into: &results
        )

        // ~/Library/Preferences/{bundleID}.helper.plist
        checkExact(
            userLib.appendingPathComponent("Preferences")
                .appendingPathComponent("\(appInfo.bundleIdentifier).helper.plist"),
            category: .preferences, into: &results
        )

        // --- PATTERN MATCH SCANS ---

        let patterns = appInfo.searchPatterns

        // ~/Library/Application Support/
        scanDirectory(
            userLib.appendingPathComponent("Application Support"),
            patterns: patterns, category: .applicationSupport, into: &results
        )

        // ~/Library/Caches/
        scanDirectory(
            userLib.appendingPathComponent("Caches"),
            patterns: patterns, category: .caches, into: &results
        )

        // ~/Library/Logs/
        scanDirectory(
            userLib.appendingPathComponent("Logs"),
            patterns: patterns, category: .logs, into: &results
        )

        // ~/Library/LaunchAgents/
        scanDirectory(
            userLib.appendingPathComponent("LaunchAgents"),
            patterns: patterns, category: .launchAgents, into: &results
        )

        // ~/Library/Group Containers/
        scanDirectory(
            userLib.appendingPathComponent("Group Containers"),
            patterns: patterns, category: .groupContainers, into: &results
        )

        // ~/Library/Logs/DiagnosticReports/ (crash reports)
        scanDirectory(
            userLib.appendingPathComponent("Logs").appendingPathComponent("DiagnosticReports"),
            patterns: patterns, category: .crashReports, into: &results
        )

        // /Library paths (system-wide)
        scanDirectory(
            sysLib.appendingPathComponent("Application Support"),
            patterns: patterns, category: .applicationSupport, into: &results
        )
        scanDirectory(
            sysLib.appendingPathComponent("LaunchAgents"),
            patterns: patterns, category: .launchAgents, into: &results
        )
        scanDirectory(
            sysLib.appendingPathComponent("LaunchDaemons"),
            patterns: patterns, category: .launchDaemons, into: &results
        )
        scanDirectory(
            sysLib.appendingPathComponent("Preferences"),
            patterns: patterns, category: .preferences, into: &results
        )

        // /var/db/receipts/ (only match bundle ID for precision)
        scanDirectory(
            URL(fileURLWithPath: "/var/db/receipts"),
            patterns: [appInfo.bundleIdentifier],
            category: .receipts, into: &results
        )

        return results
    }

    private func checkExact(_ url: URL, category: FoundFile.FileCategory,
                            into results: inout [FoundFile]) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let size = calculateSize(at: url)
        results.append(FoundFile(
            url: url,
            size: size,
            isDirectory: isDirectory(url),
            category: category
        ))
    }

    private func scanDirectory(_ directory: URL, patterns: [String],
                               category: FoundFile.FileCategory,
                               into results: inout [FoundFile]) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            let name = item.lastPathComponent
            if patterns.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
                let size = calculateSize(at: item)
                results.append(FoundFile(
                    url: item,
                    size: size,
                    isDirectory: isDirectory(item),
                    category: category
                ))
            }
        }
    }

    private func calculateSize(at url: URL) -> Int64 {
        if !isDirectory(url) {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            ),
            resourceValues.isRegularFile == true else { continue }
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }
        return totalSize
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
