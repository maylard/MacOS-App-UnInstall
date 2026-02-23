import SwiftUI

struct FileRowView: View {
    let file: FoundFile
    @ObservedObject var viewModel: UninstallerViewModel

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { file.isSelected },
                set: { _ in viewModel.toggleSelection(for: file.id) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(file.url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .font(.callout)

            Button {
                viewModel.revealInFinder(file.url)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")

            Button {
                viewModel.deleteSingle(file)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Move to Trash")
        }
        .padding(.vertical, 2)
    }
}
