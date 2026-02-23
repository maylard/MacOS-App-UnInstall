import SwiftUI

struct FullDiskAccessPromptView: View {
    @Binding var hasFullDiskAccess: Bool
    let onRecheck: () -> Void
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: hasFullDiskAccess
                      ? "checkmark.shield.fill"
                      : "exclamationmark.triangle.fill")
                    .foregroundStyle(hasFullDiskAccess ? .green : .yellow)

                if hasFullDiskAccess {
                    Text("Full Disk Access is enabled.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Full Disk Access is recommended to find all associated files.")
                        .font(.callout)
                }

                Spacer()

                if !hasFullDiskAccess {
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Button("Re-check") {
                    onRecheck()
                }
                .buttonStyle(.bordered)

                Button {
                    withAnimation {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            .background(hasFullDiskAccess ? .green.opacity(0.1) : .yellow.opacity(0.1))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
