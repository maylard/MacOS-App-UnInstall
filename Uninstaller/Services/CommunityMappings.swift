import Foundation

/// Loads community-maintained mappings of bundle IDs to non-standard file paths.
/// Uses a bundled fallback and attempts to fetch the latest version from GitHub.
class CommunityMappings {

    struct MappingsFile: Codable {
        let version: Int
        let mappings: [String: AppMapping]
    }

    struct AppMapping: Codable {
        let name: String
        let paths: [String]
    }

    private static let remoteURL = URL(string: "https://raw.githubusercontent.com/maylard/MacOS-App-UnInstall/main/Uninstaller/Resources/community_mappings.json")!

    private var mappings: [String: AppMapping] = [:]

    /// Load mappings: try remote first, fall back to bundled
    func load() async {
        // Try fetching latest from GitHub
        if let remote = await fetchRemote() {
            mappings = remote.mappings
            return
        }

        // Fall back to bundled file
        if let bundled = loadBundled() {
            mappings = bundled.mappings
        }
    }

    /// Get extra paths for a given bundle identifier
    func paths(for bundleIdentifier: String) -> [String] {
        return mappings[bundleIdentifier]?.paths ?? []
    }

    private func fetchRemote() async -> MappingsFile? {
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(MappingsFile.self, from: data)
        } catch {
            return nil
        }
    }

    private func loadBundled() -> MappingsFile? {
        guard let url = Bundle.main.url(forResource: "community_mappings", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MappingsFile.self, from: data)
    }
}
