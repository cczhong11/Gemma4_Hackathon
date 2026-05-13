import AVKit
import SwiftUI

private enum TextModePalette {
    static let background = Color(red: 245 / 255, green: 240 / 255, blue: 232 / 255)
    static let card = Color.white
    static let ink = Color(red: 15 / 255, green: 43 / 255, blue: 61 / 255)
    static let muted = Color(red: 107 / 255, green: 124 / 255, blue: 134 / 255)
    static let border = Color(red: 228 / 255, green: 220 / 255, blue: 207 / 255)
    static let accent = Color(red: 29 / 255, green: 158 / 255, blue: 117 / 255)
    static let accentSoft = Color(red: 23 / 255, green: 107 / 255, blue: 83 / 255)
    static let mutedFill = Color(red: 236 / 255, green: 227 / 255, blue: 210 / 255)
    static let destructive = Color(red: 196 / 255, green: 72 / 255, blue: 72 / 255)
    static let badgeFill = Color(red: 255 / 255, green: 231 / 255, blue: 176 / 255)
    static let badgeBorder = Color(red: 250 / 255, green: 199 / 255, blue: 117 / 255)
    static let chipInactive = Color(red: 232 / 255, green: 224 / 255, blue: 210 / 255)
    static let highlight = Color(red: 250 / 255, green: 199 / 255, blue: 117 / 255)
    static let primarySoft = Color(red: 27 / 255, green: 58 / 255, blue: 80 / 255)
    static let primaryForegroundMuted = Color(red: 200 / 255, green: 214 / 255, blue: 223 / 255)
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

private let recommendedInputCharacters = 500
private let maxInputCharacters = 2000

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

                        if !vm.videos.isEmpty || !vm.units.isEmpty {
                            playbackCard
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
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(TextModePalette.badgeBorder, lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                Text("🤟")
                    .font(.system(size: 22))
            }
            .padding(.top, 4)
        }
    }

    private var inputCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(TextModePalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(TextModePalette.border, lineWidth: 1)
                }

            if vm.inputText.isEmpty {
                Text("Type a word or sentence...")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(TextModePalette.muted)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $vm.inputText)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(TextModePalette.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 160, maxHeight: 220)
                .onChange(of: vm.inputText) { newValue in
                    if newValue.count > maxInputCharacters {
                        vm.inputText = String(newValue.prefix(maxInputCharacters))
                    }
                }

            VStack {
                Spacer()
                HStack {
                    Text("\(vm.inputText.count)/\(recommendedInputCharacters)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(vm.inputText.count > recommendedInputCharacters ? TextModePalette.destructive : TextModePalette.muted)
                    Spacer()
                    if !vm.inputText.isEmpty {
                        Button {
                            vm.clear()
                        } label: {
                            Text("✕ Clear")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(TextModePalette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
        .frame(minHeight: 200)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✨ Try these:")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(TextModePalette.ink)

            VStack(spacing: 10) {
                ForEach(suggestionSentences) { suggestion in
                    Button {
                        vm.inputText = suggestion.text
                    } label: {
                        HStack(spacing: 12) {
                            Text(suggestion.emoji)
                                .font(.system(size: 22))
                            Text(suggestion.text)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(TextModePalette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 56)
                        .background(TextModePalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(TextModePalette.border, lineWidth: 1)
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
            HStack(spacing: 10) {
                if vm.isTranslating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("🤟")
                        .font(.system(size: 22))
                }
                Text(vm.isTranslating ? "Translating..." : "Sign it!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundStyle(canTranslate ? Color.white : TextModePalette.muted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .background(canTranslate ? TextModePalette.accent : TextModePalette.mutedFill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canTranslate)
    }

    private var canTranslate: Bool {
        !vm.isTranslating
            && !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func errorCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("😕 Oops!")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(TextModePalette.destructive)
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(TextModePalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TextModePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TextModePalette.destructive, lineWidth: 1)
        }
    }

    private var playbackCard: some View {
        VStack(spacing: 16) {
            videoViewer
            progressTrack
            playbackControls

            if !vm.units.isEmpty {
                translationCard
            }
        }
    }

    private var videoViewer: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(TextModePalette.ink)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)

            if vm.currentVideoURL != nil {
                TextASLPlayer(viewModel: vm)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                Text("Tap PLAY or any word above")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(TextModePalette.primaryForegroundMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
            }

            if let active = vm.activeUnit {
                Text(activeWordBadgeText(for: active))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(activeBadgeForeground(for: active))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(activeBadgeBackground(for: active))
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
    }

    private func activeWordBadgeText(for unit: GlossUnit) -> String {
        switch unit.kind {
        case .fingerspell:
            return "\(unit.displayLabel) · spell"
        case .sign:
            return unit.displayLabel
        }
    }

    private func activeBadgeBackground(for unit: GlossUnit) -> Color {
        switch unit.kind {
        case .fingerspell: return TextModePalette.highlight
        case .sign: return TextModePalette.accent
        }
    }

    private func activeBadgeForeground(for unit: GlossUnit) -> Color {
        switch unit.kind {
        case .fingerspell: return TextModePalette.ink
        case .sign: return Color.white
        }
    }

    private var progressTrack: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(TextModePalette.border)
                Capsule()
                    .fill(TextModePalette.accent)
                    .frame(width: max(0, geo.size.width * CGFloat(vm.playbackProgress)))
            }
        }
        .frame(height: 6)
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                vm.togglePlayback()
            } label: {
                Text(vm.isPlaying ? "STOP" : "PLAY")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(vm.isPlaying ? TextModePalette.ink : TextModePalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(vm.videos.isEmpty)

            HStack(spacing: 6) {
                ForEach(Self.playbackSpeeds, id: \.self) { speed in
                    Button {
                        vm.setSpeed(speed)
                    } label: {
                        Text(Self.formatSpeed(speed))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(vm.playbackSpeed == speed ? .white : TextModePalette.ink)
                            .frame(width: 44, height: 44)
                            .background(vm.playbackSpeed == speed ? TextModePalette.ink : Color.clear)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(vm.playbackSpeed == speed ? TextModePalette.ink : TextModePalette.border, lineWidth: 1.5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private static let playbackSpeeds: [Double] = [0.5, 0.75, 1.0, 1.5]

    private static func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))x"
        }
        let trimmed = String(format: "%g", speed)
        return "\(trimmed)x"
    }

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRANSLATION CARD")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(TextModePalette.primaryForegroundMuted)

            translationSubCard(label: "ORIGINAL", body: vm.translatedText, fill: TextModePalette.primarySoft, bodyColor: .white)
            translationSubCard(label: "ASL GLOSS", body: vm.glossText, fill: TextModePalette.accent, bodyColor: .white, bodyTracking: 0.5, isBold: true)

            chipsWrap

            Text("Yellow dashed = no ASL clip in library, auto-fingerspelled")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(TextModePalette.primaryForegroundMuted)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TextModePalette.ink)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func translationSubCard(
        label: String,
        body: String,
        fill: Color,
        bodyColor: Color,
        bodyTracking: CGFloat = 0,
        isBold: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(TextModePalette.primaryForegroundMuted)

            Text(body)
                .font(.system(size: 16, weight: isBold ? .bold : .regular, design: .rounded))
                .tracking(bodyTracking)
                .foregroundStyle(bodyColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var chipsWrap: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(vm.units) { unit in
                Button {
                    vm.jumpTo(unit: unit)
                } label: {
                    Text(unit.displayLabel)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .textCase(.lowercase)
                        .tracking(0.5)
                        .foregroundStyle(chipForeground(for: unit))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 14)
                        .background(chipBackground(for: unit))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(chipBorder(for: unit), style: chipStrokeStyle(for: unit))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!unit.isPlayable)
            }
        }
    }

    private func chipIsActive(_ unit: GlossUnit) -> Bool {
        unit.id == vm.activeUnit?.id
    }

    private func chipBackground(for unit: GlossUnit) -> Color {
        if chipIsActive(unit) { return TextModePalette.highlight }
        switch unit.kind {
        case .fingerspell: return .clear
        case .sign: return TextModePalette.accentSoft
        }
    }

    private func chipForeground(for unit: GlossUnit) -> Color {
        if chipIsActive(unit) { return TextModePalette.ink }
        return .white
    }

    private func chipBorder(for unit: GlossUnit) -> Color {
        if chipIsActive(unit) { return TextModePalette.highlight }
        switch unit.kind {
        case .fingerspell: return TextModePalette.highlight
        case .sign: return TextModePalette.accentSoft
        }
    }

    private func chipStrokeStyle(for unit: GlossUnit) -> StrokeStyle {
        switch unit.kind {
        case .fingerspell where !chipIsActive(unit):
            return StrokeStyle(lineWidth: 1.5, dash: [4, 3])
        default:
            return StrokeStyle(lineWidth: 1.5)
        }
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
        context.coordinator.sync(
            url: viewModel.currentVideoURL,
            isPlaying: viewModel.isPlaying,
            rate: Float(viewModel.playbackSpeed)
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        context.coordinator.sync(
            url: viewModel.currentVideoURL,
            isPlaying: viewModel.isPlaying,
            rate: Float(viewModel.playbackSpeed)
        )
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

        func sync(url: URL?, isPlaying: Bool, rate: Float) {
            if url != lastURL {
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
            }

            guard player.currentItem != nil else { return }

            if isPlaying {
                if player.timeControlStatus != .playing {
                    player.play()
                }
                if player.rate != rate {
                    player.rate = rate
                }
            } else if player.timeControlStatus == .playing {
                player.pause()
            }
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
