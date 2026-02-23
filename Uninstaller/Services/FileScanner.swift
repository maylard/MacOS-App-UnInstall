import Foundation

class FileScanner {
    private let fileManager = FileManager.default

    func scan(appInfo: AppInfo) async -> [FoundFile] {
        var appInfo = appInfo
        var results: [FoundFile] = []
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let userLib = homeDir.appendingPathComponent("Library")
        let sysLib = URL(fileURLWithPath: "/Library")

        // --- PHASE 1: Scan the app binary for embedded path references ---
        // This catches things like ~/.gemini/ that don't match standard patterns
        let discoveredPaths = scanAppBinary(appInfo: appInfo)
        appInfo.discoveredPaths = discoveredPaths

        // --- PHASE 2: EXACT MATCH SCANS ---

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

        // ~/Library/Application Scripts/{bundleID}
        checkExact(
            userLib.appendingPathComponent("Application Scripts")
                .appendingPathComponent(appInfo.bundleIdentifier),
            category: .applicationScripts, into: &results
        )

        // --- PHASE 3: PATTERN MATCH SCANS ---

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

        // ~/Library/Preferences/ (pattern match for helper plists, etc.)
        scanDirectory(
            userLib.appendingPathComponent("Preferences"),
            patterns: [appInfo.bundleIdentifier],
            category: .preferences, into: &results,
            skipExact: [
                "\(appInfo.bundleIdentifier).plist",
                "\(appInfo.bundleIdentifier).helper.plist"
            ]
        )

        // ~/Library/Application Scripts/ (pattern match for related scripts)
        scanDirectory(
            userLib.appendingPathComponent("Application Scripts"),
            patterns: patterns, category: .applicationScripts, into: &results,
            skipExact: [appInfo.bundleIdentifier]
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
        scanDirectory(
            sysLib.appendingPathComponent("Caches"),
            patterns: patterns, category: .caches, into: &results
        )

        // /var/db/receipts/ (only match bundle ID for precision)
        scanDirectory(
            URL(fileURLWithPath: "/var/db/receipts"),
            patterns: [appInfo.bundleIdentifier],
            category: .receipts, into: &results
        )

        // --- PHASE 4: HOME DIRECTORY DOT-FOLDER SCANNING ---
        scanHomeDirDotFolders(appInfo: appInfo, into: &results)

        // --- PHASE 5: BINARY-DISCOVERED PATHS ---
        checkDiscoveredPaths(discoveredPaths, existingResults: results, into: &results)

        // Deduplicate results by URL
        var seen = Set<String>()
        results = results.filter { file in
            let path = file.url.path
            if seen.contains(path) { return false }
            seen.insert(path)
            return true
        }

        return results
    }

    // MARK: - App Binary String Scanning

    /// Scans the app's main executable binary for embedded path-like strings.
    /// This is how we discover paths like ~/.gemini/ that don't follow standard patterns.
    private func scanAppBinary(appInfo: AppInfo) -> [String] {
        guard let execName = appInfo.executableName ?? Optional(appInfo.bundleName) else {
            return []
        }

        let execURL = appInfo.appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(execName)

        guard fileManager.fileExists(atPath: execURL.path) else { return [] }

        // Read the binary and look for path-like strings
        guard let data = try? Data(contentsOf: execURL) else { return [] }

        var paths: [String] = []
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        // Extract ASCII strings from the binary (similar to the `strings` command)
        let extractedStrings = extractStrings(from: data, minLength: 5)

        for str in extractedStrings {
            // Look for home directory references
            if str.hasPrefix("~/") || str.hasPrefix("$HOME/") || str.contains("/.") {
                let normalized = str
                    .replacingOccurrences(of: "$HOME", with: "~")
                    .trimmingCharacters(in: .whitespaces)

                // Only keep paths that look like config/data directories
                if normalized.hasPrefix("~/.")
                    && !normalized.contains("*")
                    && !normalized.contains("{")
                    && normalized.count < 100 {

                    // Extract just the first path component after ~/
                    let afterHome = String(normalized.dropFirst(2)) // drop ~/
                    if let firstSlash = afterHome.firstIndex(of: "/") {
                        let dirName = String(afterHome[afterHome.startIndex..<firstSlash])
                        let fullPath = homeDir + "/." + dirName.replacingOccurrences(of: ".", with: "", options: .anchored)
                        // Normalize: ensure it starts with .
                        let dotPath = "~/." + dirName.replacingOccurrences(of: ".", with: "", options: .anchored)
                        if !paths.contains(dotPath) {
                            paths.append(dotPath)
                        }
                    } else {
                        if !paths.contains(normalized) {
                            paths.append(normalized)
                        }
                    }
                }
            }

            // Also look for absolute paths to common config locations
            if str.hasPrefix("/Users/") && str.contains("/.") {
                // Extract the dot-folder portion
                if let dotRange = str.range(of: "/.", options: .backwards) {
                    let afterDot = str[dotRange.upperBound...]
                    if let slashIdx = afterDot.firstIndex(of: "/") {
                        let dirName = String(afterDot[afterDot.startIndex..<slashIdx])
                        let dotPath = "~/.\(dirName)"
                        if !paths.contains(dotPath) {
                            paths.append(dotPath)
                        }
                    }
                }
            }
        }

        return paths
    }

    /// Extract printable ASCII strings from binary data (like the `strings` command)
    private func extractStrings(from data: Data, minLength: Int) -> [String] {
        var strings: [String] = []
        var current = ""

        for byte in data {
            // Printable ASCII range (space through tilde)
            if byte >= 0x20 && byte <= 0x7E {
                current.append(Character(UnicodeScalar(byte)))
            } else {
                if current.count >= minLength {
                    strings.append(current)
                }
                current = ""
            }
        }
        if current.count >= minLength {
            strings.append(current)
        }

        // Filter to only path-like strings to reduce noise
        return strings.filter { str in
            str.contains("/") || str.contains("~")
        }
    }

    // MARK: - Home Directory Dot-Folder Scanning

    /// Scans ~/ for hidden dot-folders that match the app name or related identifiers
    private func scanHomeDirDotFolders(appInfo: AppInfo, into results: inout [FoundFile]) {
        let homeDir = fileManager.homeDirectoryForCurrentUser

        guard let contents = try? fileManager.contentsOfDirectory(
            at: homeDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        let patterns = appInfo.homeDirPatterns

        for item in contents {
            let name = item.lastPathComponent
            // Only check dot-folders
            guard name.hasPrefix(".") else { continue }

            // Strip the leading dot for matching
            let cleanName = String(name.dropFirst()).lowercased()

            // Check if the folder name matches any of our patterns
            if patterns.contains(where: { cleanName == $0 || cleanName.contains($0) }) {
                // Skip common system dot-folders that are too generic
                let systemFolders: Set<String> = [
                    ".Trash", ".cache", ".config", ".local", ".ssh",
                    ".zshrc", ".bash_profile", ".gitconfig", ".npm",
                    ".cargo", ".rustup"
                ]
                guard !systemFolders.contains(name) else { continue }

                let size = calculateSize(at: item)
                results.append(FoundFile(
                    url: item,
                    size: size,
                    isDirectory: isDirectory(item),
                    category: .homeDirectory
                ))
            }
        }
    }

    // MARK: - Binary-Discovered Path Checking

    /// Check paths discovered from binary scanning to see if they actually exist
    private func checkDiscoveredPaths(_ paths: [String],
                                      existingResults: [FoundFile],
                                      into results: inout [FoundFile]) {
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        let existingPaths = Set(existingResults.map(\.url.path))

        for path in paths {
            let resolvedPath: String
            if path.hasPrefix("~/") {
                resolvedPath = homeDir + String(path.dropFirst(1))
            } else {
                resolvedPath = path
            }

            let url = URL(fileURLWithPath: resolvedPath)

            // Skip if we already found this path
            guard !existingPaths.contains(url.path) else { continue }

            if fileManager.fileExists(atPath: resolvedPath) {
                let size = calculateSize(at: url)
                results.append(FoundFile(
                    url: url,
                    size: size,
                    isDirectory: isDirectory(url),
                    category: .binaryDiscovered
                ))
            }
        }
    }

    // MARK: - Core Scanning Methods

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
                               into results: inout [FoundFile],
                               skipExact: [String] = []) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            let name = item.lastPathComponent

            // Skip items already found via exact match
            if skipExact.contains(name) { continue }

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

    // MARK: - Helpers

    private func calculateSize(at url: URL) -> Int64 {
        if !isDirectory(url) {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
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
