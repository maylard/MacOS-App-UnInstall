import Foundation

enum AppBundleParserError: LocalizedError {
    case notAnAppBundle
    case infoPlistNotFound
    case missingBundleIdentifier

    var errorDescription: String? {
        switch self {
        case .notAnAppBundle:
            return "The dropped item is not an application bundle (.app)."
        case .infoPlistNotFound:
            return "Could not read the application's Info.plist."
        case .missingBundleIdentifier:
            return "The application does not have a bundle identifier."
        }
    }
}

struct AppBundleParser {

    static func parse(appURL: URL) throws -> AppInfo {
        guard appURL.pathExtension == "app" else {
            throw AppBundleParserError.notAnAppBundle
        }

        let infoPlistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(
                  from: plistData, format: nil
              ) as? [String: Any] else {
            throw AppBundleParserError.infoPlistNotFound
        }

        guard let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw AppBundleParserError.missingBundleIdentifier
        }

        let bundleName = plist["CFBundleName"] as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        let displayName = plist["CFBundleDisplayName"] as? String
        let executable = plist["CFBundleExecutable"] as? String

        let components = bundleID.split(separator: ".")
        let developerName: String? = components.count >= 2
            ? components.prefix(2).joined(separator: ".")
            : nil

        return AppInfo(
            bundleIdentifier: bundleID,
            bundleName: bundleName,
            displayName: displayName,
            executableName: executable,
            developerName: developerName,
            appURL: appURL
        )
    }
}
