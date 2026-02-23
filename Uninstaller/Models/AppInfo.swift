import Foundation

struct AppInfo {
    let bundleIdentifier: String
    let bundleName: String
    let displayName: String?
    let executableName: String?
    let developerName: String?
    let appURL: URL

    var searchPatterns: [String] {
        var patterns: [String] = [bundleIdentifier]
        patterns.append(bundleName)
        if let display = displayName, display != bundleName {
            patterns.append(display)
        }
        if let dev = developerName, !dev.hasPrefix("com.apple") {
            patterns.append(dev)
        }
        return patterns
    }

    var effectiveName: String {
        displayName ?? bundleName
    }
}
