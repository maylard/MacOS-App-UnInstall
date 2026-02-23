import Foundation

struct ScanResult {
    let appInfo: AppInfo
    var files: [FoundFile]

    var totalSize: Int64 {
        files.reduce(0) { $0 + max($1.size, 0) }
    }

    var selectedSize: Int64 {
        files.filter(\.isSelected).reduce(0) { $0 + max($1.size, 0) }
    }

    var selectedCount: Int {
        files.filter(\.isSelected).count
    }

    var groupedByCategory: [(FoundFile.FileCategory, [FoundFile])] {
        let grouped = Dictionary(grouping: files, by: \.category)
        return FoundFile.FileCategory.allCases.compactMap { category in
            guard let files = grouped[category], !files.isEmpty else { return nil }
            return (category, files)
        }
    }
}
