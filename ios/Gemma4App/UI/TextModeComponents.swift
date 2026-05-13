import AVKit
import SwiftUI

enum TextModePalette {
    static let background = Color(red: 245 / 255, green: 240 / 255, blue: 232 / 255)
    static let card = Color.white
    static let ink = Color(red: 19 / 255, green: 50 / 255, blue: 72 / 255)
    static let muted = Color(red: 105 / 255, green: 124 / 255, blue: 139 / 255)
    static let border = Color(red: 226 / 255, green: 216 / 255, blue: 202 / 255)
    static let green = Color(red: 38 / 255, green: 166 / 255, blue: 122 / 255)
    static let navy = Color(red: 22 / 255, green: 52 / 255, blue: 74 / 255)
    static let chipInactive = Color(red: 232 / 255, green: 224 / 255, blue: 210 / 255)
}

struct TextModeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("💬 Text to ASL")
                .font(HearmeTypography.brand(34))
                .foregroundStyle(TextModePalette.ink)

            Text("Type something. We'll sign it.")
                .font(HearmeTypography.bodyStrong(19))
                .foregroundStyle(TextModePalette.muted)
        }
    }
}

struct TextModeInputCard: View {
    @Binding var text: String
    let recommendedLimit: Int
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(TextModePalette.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(TextModePalette.border, lineWidth: 1.5)
                    }

                if text.isEmpty {
                    Text("Type a word or sentence...")
                        .font(HearmeTypography.bodyStrong(18))
                        .foregroundStyle(TextModePalette.muted)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 22)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(UIFont(name: "DMSans-Regular", size: 18) != nil ? .custom("DMSans-Regular", size: 18) : .system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(TextModePalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(minHeight: 150, maxHeight: 230)
            }

            HStack {
                Text("\(text.count)/\(recommendedLimit)")
                    .font(HearmeTypography.label(12))
                    .foregroundStyle(text.count > recommendedLimit ? .red : TextModePalette.muted)

                Spacer()

                if !text.isEmpty {
                    Button(action: onClear) {
                        Text("✕ Clear")
                            .font(HearmeTypography.gloss(14))
                            .foregroundStyle(TextModePalette.green)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

struct TextModeSampleSection: View {
    let samplePhrases: [String]
    let emojiForPhrase: (String) -> String
    let onSampleTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✨ Try these")
                .font(HearmeTypography.section(18))
                .foregroundStyle(TextModePalette.ink)

            VStack(spacing: 10) {
                ForEach(samplePhrases, id: \.self) { phrase in
                    Button {
                        onSampleTap(phrase)
                    } label: {
                        HStack(spacing: 12) {
                            Text(emojiForPhrase(phrase))
                                .font(.system(size: 24))

                            Text(phrase)
                                .font(HearmeTypography.bodyStrong(16))
                                .foregroundStyle(TextModePalette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(TextModePalette.card)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(TextModePalette.border, lineWidth: 1.2)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TextModeTranslateButton: View {
    let isTranslating: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isTranslating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("🤟")
                        .font(.system(size: 26))
                }

                Text(isTranslating ? "Translating..." : "Sign it!")
                    .font(HearmeTypography.brand(24))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(isEnabled ? TextModePalette.green : TextModePalette.green.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct TextModeErrorCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Oops")
                .font(HearmeTypography.label(12))
                .foregroundStyle(.red.opacity(0.9))
            Text(text)
                .font(HearmeTypography.bodyStrong(16))
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(TextModePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1.5)
        }
    }
}

struct TextModePlayerCard: View {
    @ObservedObject var viewModel: TextTranslationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Playback")
                .font(HearmeTypography.label(15))
                .foregroundStyle(TextModePalette.ink)

            TextASLPlayer(viewModel: viewModel)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(TextModePalette.border, lineWidth: 1.5)
                }
        }
    }
}

struct TextModeGlossChipGrid: View {
    let units: [GlossUnit]
    let activeUnitID: GlossUnit.ID?
    let chipBackground: (GlossUnit) -> Color
    let chipForeground: (GlossUnit) -> Color
    let onTap: (GlossUnit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gloss words")
                .font(HearmeTypography.label(15))
                .foregroundStyle(TextModePalette.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(units) { unit in
                    Button {
                        onTap(unit)
                    } label: {
                        Text(unit.displayLabel)
                            .font(HearmeTypography.gloss(16))
                            .foregroundStyle(chipForeground(unit))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(chipBackground(unit))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(unit.isPlayable ? Color.clear : Color.yellow.opacity(0.9), style: StrokeStyle(lineWidth: unit.isPlayable ? 0 : 2, dash: [8, 6]))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .opacity(unit.isPlayable ? 1.0 : 0.55)
                    }
                    .buttonStyle(.plain)
                    .disabled(!unit.isPlayable)
                }
            }
        }
    }
}

struct TextModeBottomTabBar: View {
    let isTypeActive: Bool
    let isPhotoActive: Bool
    let onTypeTap: () -> Void
    let onPhotoTap: () -> Void

    var body: some View {
        HStack {
            Spacer()
            tabItem(icon: "text.bubble", title: "Type", isActive: isTypeActive, action: onTypeTap)
            Spacer()
            tabItem(icon: "camera", title: "Photo", isActive: isPhotoActive, action: onPhotoTap)
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

    private func tabItem(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: isActive ? .semibold : .regular))
                Text(title)
                    .font(HearmeTypography.gloss(16))
            }
            .foregroundStyle(isActive ? TextModePalette.ink : TextModePalette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct TextASLPlayer: UIViewControllerRepresentable {
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
            _ = controller
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
