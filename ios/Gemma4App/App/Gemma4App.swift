import SwiftUI

@main
struct Gemma4App: App {
    var body: some Scene {
        WindowGroup {
            RootLaunchView()
        }
    }
}

private struct RootLaunchView: View {
    @State private var hasFinishedSplash = false

    var body: some View {
        Group {
            if hasFinishedSplash {
                HomeView(viewModel: AppViewModel())
            } else {
                SplashScreenView()
            }
        }
        .task {
            guard !hasFinishedSplash else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            hasFinishedSplash = true
        }
    }
}

private struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Image("Splash")
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
        }
    }
}
