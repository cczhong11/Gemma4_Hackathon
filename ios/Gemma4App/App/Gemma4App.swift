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
            Color(red: 244 / 255, green: 238 / 255, blue: 230 / 255)
                .ignoresSafeArea()

            Image("Splash")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
