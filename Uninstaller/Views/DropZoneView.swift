import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var viewModel: UninstallerViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 64))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .scaleEffect(isTargeted ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)

            Text("Drop an Application Here")
                .font(.title2)
                .fontWeight(.medium)

            Text("Drag a .app file to find all associated files")
                .foregroundStyle(.secondary)

            if viewModel.isScanning {
                ProgressView("Scanning...")
                    .padding(.top, 8)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3))
        )
        .padding(40)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }
}
