import SwiftUI

struct TextPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("文字功能")
                .font(.title2.weight(.semibold))
            Text("这个入口先保留，暂时不实现。")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .navigationTitle("文字功能")
    }
}

#Preview {
    NavigationStack {
        TextPlaceholderView()
    }
}
