import SwiftUI

@main
struct Gemma4App: App {
    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: AppViewModel())
        }
    }
}
