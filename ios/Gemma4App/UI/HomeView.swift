import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: AppViewModel
    @State private var selectedTab: HomeTab = .photo

    private enum HomeTab {
        case type
        case photo
    }

    init(viewModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .type:
                    TextPlaceholderView(
                        viewModel: viewModel,
                        showsBottomBar: true,
                        onSwitchToPhoto: { selectedTab = .photo }
                    )
                case .photo:
                    CameraRecognitionView(
                        viewModel: viewModel,
                        showsBottomBar: true,
                        onSwitchToType: { selectedTab = .type }
                    )
                }
            }
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
