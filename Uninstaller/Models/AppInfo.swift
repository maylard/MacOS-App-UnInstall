import Foundation

struct AppInfo {
    let bundleIdentifier: String
    let bundleName: String
    let displayName: String?
    let executableName: String?
    let developerName: String?
    let appURL: URL

    /// Paths discovered by scanning the app's binary for embedded path references
    var discoveredPaths: [String] = []

    /// Generic runtime/framework names that should never be used as search patterns.
    /// These would cause massive false positives (e.g., every Electron app matching each other).
    private static let genericExecutableNames: Set<String> = [
        "electron", "node", "python", "python3", "ruby", "java", "php",
        "perl", "bash", "sh", "zsh", "nwjs", "cefclient", "helper",
        "chromium", "webkit", "qt", "gtk"
    ]

    /// Primary search patterns for Library directory scanning
    var searchPatterns: [String] {
        var patterns: [String] = [bundleIdentifier]
        patterns.append(bundleName)
        if let display = displayName, display != bundleName {
            patterns.append(display)
        }
        // Only include executable name if it's unique (not a generic runtime)
        if let exec = executableName,
           exec != bundleName,
           !Self.genericExecutableNames.contains(exec.lowercased()) {
            patterns.append(exec)
        }
        if let dev = developerName, !dev.hasPrefix("com.apple") {
            patterns.append(dev)
        }
        // Also add the last component of the bundle ID as a pattern
        // e.g., "antigravity" from "com.google.antigravity"
        let lastComponent = bundleIdentifier.split(separator: ".").last.map(String.init)
        if let last = lastComponent,
           !patterns.contains(where: { $0.localizedCaseInsensitiveCompare(last) == .orderedSame }) {
            patterns.append(last)
        }
        return patterns
    }

    /// Patterns specifically for home directory dot-folder scanning (more conservative)
    var homeDirPatterns: [String] {
        var patterns: [String] = []
        patterns.append(bundleName.lowercased())
        if let display = displayName {
            patterns.append(display.lowercased())
        }
        // Only include executable name if it's unique
        if let exec = executableName,
           !Self.genericExecutableNames.contains(exec.lowercased()) {
            patterns.append(exec.lowercased())
        }
        // Add last component of bundle ID
        if let last = bundleIdentifier.split(separator: ".").last {
            patterns.append(String(last).lowercased())
        }
        return Array(Set(patterns))
    }

    var effectiveName: String {
        displayName ?? bundleName
    }
}
