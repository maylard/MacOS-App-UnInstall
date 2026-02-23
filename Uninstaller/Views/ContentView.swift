import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = UninstallerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.hasFullDiskAccess {
                FullDiskAccessPromptView()
            }

            if viewModel.scanResult != nil {
                FileListView(viewModel: viewModel)
            } else {
                DropZoneView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            viewModel.checkFullDiskAccess()
        }
    }
}
