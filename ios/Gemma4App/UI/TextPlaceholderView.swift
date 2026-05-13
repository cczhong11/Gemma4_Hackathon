import AVKit
import SwiftUI

private enum TextModePalette {
    static let background = Color(red: 245 / 255, green: 240 / 255, blue: 232 / 255)
    static let card = Color.white
    static let ink = Color(red: 19 / 255, green: 50 / 255, blue: 72 / 255)
    static let muted = Color(red: 105 / 255, green: 124 / 255, blue: 139 / 255)
    static let border = Color(red: 226 / 255, green: 216 / 255, blue: 202 / 255)
    static let signButton = Color(red: 232 / 255, green: 220 / 255, blue: 197 / 255)
    static let signButtonText = Color(red: 105 / 255, green: 92 / 255, blue: 75 / 255)
    static let badgeFill = Color(red: 255 / 255, green: 232 / 255, blue: 184 / 255)
    static let chipInactive = Color(red: 232 / 255, green: 224 / 255, blue: 210 / 255)
}

private struct SuggestionSentence: Identifiable {
    let id = UUID()
    let emoji: String
    let text: String
}

private let suggestionSentences: [SuggestionSentence] = [
    SuggestionSentence(emoji: "👋", text: "Hello! What is your name?"),
    SuggestionSentence(emoji: "📖", text: "I want to read a book with you."),
    SuggestionSentence(emoji: "🐶", text: "Today we will learn about animals."),
]

private let maxInputCharacters = 500

struct TextPlaceholderView: View {
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var vm = TextTranslationViewModel()
    @State private var navigateToPhotoMode = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TextModePalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        inputCard

                        if let errorMessage = vm.errorMessage {
                            errorCard(text: errorMessage)
                        }

                        if !vm.videos.isEmpty {
                            playerCard
                        }

                        if !vm.units.isEmpty {
                            chipRow
                        }

                        if vm.videos.isEmpty && vm.units.isEmpty {
                            suggestionsSection
                        }

                        signItButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }

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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("💬 Text to ASL")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(TextModePalette.ink)

                Text("Type some words. We will sign them!")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(TextModePalette.muted)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(TextModePalette.badgeFill)
                    .frame(width: 54, height: 54)
                Text("🤟")
                    .font(.system(size: 28))
            }
            .padding(.top, 4)
        }
    }

    private var inputCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(TextModePalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(TextModePalette.border, lineWidth: 1.5)
                }

            if vm.inputText.isEmpty {
                Text("Type a word or sentence...")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(TextModePalette.muted)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 22)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $vm.inputText)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(TextModePalette.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(minHeight: 200, maxHeight: 240)
                .onChange(of: vm.inputText) { newValue in
                    if newValue.count > maxInputCharacters {
                        vm.inputText = String(newValue.prefix(maxInputCharacters))
                    }
                }

            VStack {
                Spacer()
                HStack {
                    Text("\(vm.inputText.count)/\(maxInputCharacters)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(TextModePalette.muted)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
        }
        .frame(minHeight: 240)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("✨ Try these:")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(TextModePalette.ink)

            VStack(spacing: 12) {
                ForEach(suggestionSentences) { suggestion in
                    Button {
                        vm.inputText = suggestion.text
                    } label: {
                        HStack(spacing: 14) {
                            Text(suggestion.emoji)
                                .font(.system(size: 22))
                            Text(suggestion.text)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(TextModePalette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(TextModePalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(TextModePalette.border, lineWidth: 1.2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var signItButton: some View {
        Button {
            vm.translate()
        } label: {
            HStack(spacing: 12) {
                if vm.isTranslating {
                    ProgressView()
                        .tint(TextModePalette.signButtonText)
                } else {
                    Text("🤟")
                        .font(.system(size: 24))
                }
                Text(vm.isTranslating ? "Translating..." : "Sign it!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundStyle(TextModePalette.signButtonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(canTranslate ? TextModePalette.signButton : TextModePalette.signButton.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canTranslate)
    }

    private var canTranslate: Bool {
        !vm.isTranslating
            && !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func errorCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(Color.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(TextModePalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1.5)
            }
    }

    private var playerCard: some View {
        TextASLPlayer(viewModel: vm)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(TextModePalette.border, lineWidth: 1.5)
            }
    }

    private var chipRow: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(vm.units) { unit in
                Button {
                    vm.jumpTo(unit: unit)
                } label: {
                    Text(unit.displayLabel)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(chipForeground(for: unit))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(chipBackground(for: unit))
                        .clipShape(Capsule())
                        .opacity(unit.isPlayable ? 1.0 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(!unit.isPlayable)
            }
        }
    }

    private func chipBackground(for unit: GlossUnit) -> Color {
        if unit.id == vm.activeUnitID {
            return TextModePalette.ink
        }
        return TextModePalette.chipInactive
    }

    private func chipForeground(for unit: GlossUnit) -> Color {
        if unit.id == vm.activeUnitID {
            return Color.white
        }
        return TextModePalette.ink
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

private struct TextASLPlayer: UIViewControllerRepresentable {
    @ObservedObject var viewModel: TextTranslationViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = context.coordinator.player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = UIColor.black
        context.coordinator.bind(to: controller)
        context.coordinator.replaceItem(for: viewModel.currentVideoURL)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        context.coordinator.replaceItem(for: viewModel.currentVideoURL)
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator {
        let player = AVPlayer()
        private weak var viewModel: TextTranslationViewModel?
        private var endObserver: NSObjectProtocol?
        private var lastURL: URL?

        init(viewModel: TextTranslationViewModel) {
            self.viewModel = viewModel
            player.actionAtItemEnd = .none
        }

        func bind(to controller: AVPlayerViewController) {
            // No-op for now; observer is attached per-item in replaceItem.
        }

        func replaceItem(for url: URL?) {
            guard url != lastURL else {
                if url != nil, player.timeControlStatus != .playing {
                    player.play()
                }
                return
            }
            lastURL = url

            removeEndObserver()

            guard let url else {
                player.replaceCurrentItem(with: nil)
                return
            }

            let item = AVPlayerItem(url: url)
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.viewModel?.onVideoEnded()
                }
            }

            player.replaceCurrentItem(with: item)
            player.seek(to: .zero)
            player.play()
        }

        func teardown() {
            removeEndObserver()
            player.replaceCurrentItem(with: nil)
        }

        private func removeEndObserver() {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            endObserver = nil
        }
    }
}

#Preview {
    NavigationStack {
        TextPlaceholderView(viewModel: AppViewModel())
    }
}
