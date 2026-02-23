import SwiftUI

struct FileListView: View {
    @ObservedObject var viewModel: UninstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            toolbarSection
            Divider()
            fileListSection
        }
        .alert("Delete Selected Files?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                viewModel.deleteSelected()
            }
        } message: {
            if let result = viewModel.scanResult {
                Text("Move \(result.selectedCount) item(s) (\(ByteCountFormatter.string(fromByteCount: result.selectedSize, countStyle: .file))) to Trash?")
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            if let icon = viewModel.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let result = viewModel.scanResult {
                    Text(result.appInfo.effectiveName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(result.appInfo.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let result = viewModel.scanResult {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(result.files.count) files found")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text(ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))
                        .font(.callout)
                        .fontWeight(.medium)
                }
            }

            Button("Scan Another") {
                viewModel.reset()
            }
        }
        .padding()
    }

    private var toolbarSection: some View {
        HStack {
            Button("Select All") { viewModel.selectAll() }
            Button("Deselect All") { viewModel.deselectAll() }

            Spacer()

            if let result = viewModel.scanResult {
                Text("\(result.selectedCount) selected (\(ByteCountFormatter.string(fromByteCount: result.selectedSize, countStyle: .file)))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Delete Selected") {
                viewModel.showDeleteConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.scanResult?.selectedCount == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var fileListSection: some View {
        Group {
            if let result = viewModel.scanResult {
                if result.files.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("No associated files found")
                            .font(.title3)
                        Text("This application appears to be self-contained.")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(result.groupedByCategory, id: \.0) { category, files in
                            Section(category.rawValue) {
                                ForEach(files) { file in
                                    FileRowView(file: file, viewModel: viewModel)
                                }
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }
}
