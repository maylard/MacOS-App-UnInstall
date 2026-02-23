import Foundation

struct FoundFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let isDirectory: Bool
    let category: FileCategory
    var isSelected: Bool = true

    enum FileCategory: String, CaseIterable {
        case applicationSupport = "Application Support"
        case caches = "Caches"
        case preferences = "Preferences"
        case savedState = "Saved Application State"
        case logs = "Logs"
        case launchAgents = "Launch Agents"
        case launchDaemons = "Launch Daemons"
        case httpStorages = "HTTP Storages"
        case webKit = "WebKit"
        case cookies = "Cookies"
        case containers = "Containers"
        case groupContainers = "Group Containers"
        case receipts = "Receipts"
        case crashReports = "Crash Reports"
        case other = "Other"
    }
}
