import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            CameraRecognitionView(viewModel: viewModel)
            .task {
                viewModel.refreshModelStatus()
                viewModel.ensureModelStatusPolling()
            }
        }
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
}
