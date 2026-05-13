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
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .type:
                        TextPlaceholderView(
                            viewModel: viewModel,
                            showsBottomBar: false,
                            onSwitchToPhoto: { selectedTab = .photo }
                        )
                    case .photo:
                        CameraRecognitionView(
                            viewModel: viewModel,
                            showsBottomBar: false,
                            onSwitchToType: { selectedTab = .type }
                        )
                    }
                }

                PhotoModeBottomTabBar(
                    isTypeActive: selectedTab == .type,
                    isPhotoActive: selectedTab == .photo,
                    onTypeTap: { selectedTab = .type },
                    onPhotoTap: { selectedTab = .photo }
                )
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
