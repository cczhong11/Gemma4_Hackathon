import SwiftUI

private enum TextModePalette {
    static let background = Color(red: 245 / 255, green: 240 / 255, blue: 232 / 255)
    static let card = Color.white
    static let ink = Color(red: 19 / 255, green: 50 / 255, blue: 72 / 255)
    static let muted = Color(red: 105 / 255, green: 124 / 255, blue: 139 / 255)
    static let border = Color(red: 226 / 255, green: 216 / 255, blue: 202 / 255)
}

struct TextPlaceholderView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var navigateToPhotoMode = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TextModePalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("💬 Text to ASL")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(TextModePalette.ink)

                    Text("Text mode is still a placeholder for now.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(TextModePalette.muted)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Coming Soon")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(TextModePalette.ink)

                        Text("We are focusing on the photo flow first.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(TextModePalette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(TextModePalette.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(TextModePalette.border, lineWidth: 1.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                bottomTabBar
            }

            NavigationLink(isActive: $navigateToPhotoMode) {
                CameraRecognitionView(viewModel: viewModel)
            } label: {
                EmptyView()
            }
            .hidden()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var bottomTabBar: some View {
        HStack {
            Spacer()
            tabItem(icon: "text.bubble", title: "Type", isActive: true) { }
            Spacer()
            tabItem(icon: "camera", title: "Photo", isActive: false) {
                navigateToPhotoMode = true
            }
            Spacer()
        }
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(TextModePalette.background)
                .overlay(alignment: .top) {
                    Divider()
                        .overlay(TextModePalette.border)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(
        icon: String,
        title: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: isActive ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 16, weight: isActive ? .bold : .semibold, design: .rounded))
            }
            .foregroundStyle(isActive ? TextModePalette.ink : TextModePalette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        TextPlaceholderView(viewModel: AppViewModel())
    }
}
