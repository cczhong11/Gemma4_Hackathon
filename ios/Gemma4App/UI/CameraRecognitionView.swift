import AVKit
import SwiftUI
import UIKit

private enum PhotoModePalette {
    static let background = Color(red: 245 / 255, green: 240 / 255, blue: 232 / 255)
    static let card = Color.white
    static let ink = Color(red: 19 / 255, green: 50 / 255, blue: 72 / 255)
    static let muted = Color(red: 105 / 255, green: 124 / 255, blue: 139 / 255)
    static let border = Color(red: 226 / 255, green: 216 / 255, blue: 202 / 255)
    static let green = Color(red: 38 / 255, green: 166 / 255, blue: 122 / 255)
    static let gold = Color(red: 250 / 255, green: 199 / 255, blue: 117 / 255)
    static let goldSoft = Color(red: 1.0, green: 0.96, blue: 0.87)
    static let navyCard = Color(red: 22 / 255, green: 52 / 255, blue: 74 / 255)
    static let navyPanel = Color(red: 38 / 255, green: 70 / 255, blue: 96 / 255)
    static let chip = Color(red: 29 / 255, green: 112 / 255, blue: 84 / 255)
}

struct CameraRecognitionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var navigateToTypeMode = false
    @State private var isModeSheetPresented = false
    @State private var isDownloadPromptPresented = false
    @State private var selectedPlaybackSpeed = "1.5x"
    @State private var selectedSignID: String?
    @State private var player = AVPlayer()

    var body: some View {
        ZStack(alignment: .bottom) {
            PhotoModePalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        actionRow

                        if let image = viewModel.capturedImage, !hasTranslationUI {
                            selectedImageCard(image)

                            analyzeButton
                        }

                        if viewModel.isLoading {
                            statusCard(title: "Analyzing photo...")
                        }

                        if let errorMessage = viewModel.errorMessage {
                            messageCard(text: errorMessage, tint: .red)
                        }

                        if viewModel.isLoadingSignVideos {
                            statusCard(title: "Looking up sign videos...")
                        }

                        if hasTranslationUI {
                            playbackSection
                            translationCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 140)
                }

                bottomTabBar
            }

            if isModeSheetPresented {
                overlay
                modeSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isDownloadPromptPresented {
                overlay
                offlineDownloadPrompt
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            NavigationLink(isActive: $navigateToTypeMode) {
                TextPlaceholderView(viewModel: viewModel)
            } label: {
                EmptyView()
            }
            .hidden()
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.spring(response: 0.35, dampingFraction: 0.92), value: isModeSheetPresented)
        .animation(.spring(response: 0.35, dampingFraction: 0.92), value: isDownloadPromptPresented)
        .onChange(of: signVideoSelectionKey) { _ in
            selectDefaultPlayableSignIfNeeded()
        }
        .onChange(of: selectedPlaybackSpeed) { _ in
            updatePlayerRateIfNeeded()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker(sourceType: .camera) { image in
                viewModel.setCapturedImage(image)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            CameraImagePicker(sourceType: .photoLibrary) { image in
                viewModel.setCapturedImage(image)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("📸 Photo to ASL")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PhotoModePalette.ink)

                Text("Take a picture of words. We will sign them!")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(PhotoModePalette.muted)
            }

            Spacer()

            Button {
                isModeSheetPresented = true
            } label: {
                ZStack {
                    Circle()
                        .fill(PhotoModePalette.goldSoft)
                        .frame(width: 58, height: 58)

                    Circle()
                        .stroke(PhotoModePalette.gold, lineWidth: 2)
                        .frame(width: 58, height: 58)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Text("🤟")
                                .font(.system(size: 22))
                        }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose translation mode")
        }
    }

    private var actionRow: some View {
        HStack(spacing: 18) {
            Button {
                showingCamera = true
            } label: {
                HStack(spacing: 14) {
                    Text("📷")
                        .font(.system(size: 26))
                    Text("Camera")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(PhotoModePalette.green)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                showingPhotoLibrary = true
            } label: {
                HStack(spacing: 14) {
                    Text("🖼️")
                        .font(.system(size: 26))
                    Text("Photos")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .foregroundStyle(PhotoModePalette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(PhotoModePalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(PhotoModePalette.ink, lineWidth: 2.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func selectedImageCard(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .background(PhotoModePalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(PhotoModePalette.border, lineWidth: 1.5)
            }
    }

    private var analyzeButton: some View {
        Button {
            Task {
                await viewModel.recognizeCapturedImage()
            }
        } label: {
            HStack(spacing: 12) {
                Text("🤟")
                    .font(.system(size: 28))
                Text("Sign it!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(viewModel.isLoading ? 0.72 : 1))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(viewModel.isLoading ? PhotoModePalette.green.opacity(0.55) : PhotoModePalette.green)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }

    private func statusCard(title: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(PhotoModePalette.green)
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(PhotoModePalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(PhotoModePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PhotoModePalette.border, lineWidth: 1.5)
        }
    }

    private func messageCard(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(PhotoModePalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PhotoModePalette.border, lineWidth: 1.5)
            }
    }

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(PhotoModePalette.navyCard)
                .frame(height: 320)
                .overlay {
                    if let activeVideo = activeSignVideo, activeVideo.localVideoURL != nil {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    } else {
                        Text("Tap PLAY or any word above")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }

            Capsule()
                .fill(PhotoModePalette.border)
                .frame(height: 10)

            HStack(spacing: 12) {
                Button {
                    playSelectedVideo()
                } label: {
                    Text("PLAY")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(PhotoModePalette.green)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(playbackSpeeds, id: \.self) { speed in
                    Button {
                        selectedPlaybackSpeed = speed
                    } label: {
                        Text(speed)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedPlaybackSpeed == speed ? .white : PhotoModePalette.ink)
                            .frame(width: 86, height: 86)
                            .background(selectedPlaybackSpeed == speed ? PhotoModePalette.ink : PhotoModePalette.background)
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(selectedPlaybackSpeed == speed ? PhotoModePalette.ink : PhotoModePalette.border, lineWidth: 2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let pageURL = activeSignVideo?.pageURL {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SOURCE PAGE")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Color.white.opacity(0.7))

                    Link(destination: pageURL) {
                        Text(pageURL.absoluteString)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Translation Card")

            infoPanel(title: "ORIGINAL", body: originalText)
            infoPanel(title: "ASL GLOSS", body: glossText, fill: PhotoModePalette.green)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 18)], alignment: .leading, spacing: 18) {
                ForEach(glossWords, id: \.self) { word in
                    Button {
                        selectSign(for: word)
                    } label: {
                        Text(word)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 26)
                            .background(chipBackground(for: word))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(chipBorder(for: word), lineWidth: chipLineWidth(for: word))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Yellow dashed = no ASL clip in library, auto-fingerspelled")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background(PhotoModePalette.navyCard)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundStyle(Color.white.opacity(0.84))
    }

    private func infoPanel(title: String, body: String, fill: Color = PhotoModePalette.navyPanel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.82))

            Text(body)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var bottomTabBar: some View {
        HStack {
            Spacer()
            tabItem(icon: "text.bubble", title: "Type", isActive: false) {
                navigateToTypeMode = true
            }
            Spacer()
            tabItem(icon: "camera", title: "Photo", isActive: true) { }
            Spacer()
        }
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(PhotoModePalette.background)
                .overlay(alignment: .top) {
                    Divider()
                        .overlay(PhotoModePalette.border)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var overlay: some View {
        Color.black.opacity(0.18)
            .ignoresSafeArea()
            .onTapGesture {
                isModeSheetPresented = false
            }
    }

    private var modeSheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule()
                .fill(PhotoModePalette.border)
                .frame(width: 88, height: 8)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Translation mode")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(PhotoModePalette.ink)

            Text("Pick how Hearme makes the sign for each word.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(PhotoModePalette.muted)

            modeOption(
                icon: "🌟",
                title: "Better Signs",
                subtitle: "Enjoy high quality ASL with internet",
                badge: "RECOMMENDED",
                highlighted: viewModel.selectedTranslationMode == .betterSigns,
                action: {
                    viewModel.selectBetterSignsMode()
                    isDownloadPromptPresented = false
                    isModeSheetPresented = false
                }
            )

            modeOption(
                icon: "✈️",
                title: "Offline Mode",
                subtitle: "Use anywhere · needs download",
                badge: nil,
                highlighted: viewModel.selectedTranslationMode == .offline,
                action: handleOfflineModeTap
            )
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(PhotoModePalette.background)
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private func modeOption(
        icon: String,
        title: String,
        subtitle: String,
        badge: String?,
        highlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                Text(icon)
                    .font(.system(size: 38))

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(PhotoModePalette.ink)

                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(PhotoModePalette.muted)
                }

                Spacer(minLength: 12)

                if let badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PhotoModePalette.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .background(PhotoModePalette.card)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(highlighted ? PhotoModePalette.green : PhotoModePalette.border, lineWidth: highlighted ? 4 : 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
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
            .foregroundStyle(isActive ? PhotoModePalette.ink : PhotoModePalette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var offlineDownloadPrompt: some View {
        VStack(spacing: 18) {
            Text("📥")
                .font(.system(size: 54))

            Text("Ready to download?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(PhotoModePalette.ink)

            Text(downloadPromptBody)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(PhotoModePalette.muted)
                .multilineTextAlignment(.center)

            if viewModel.isDownloadingModel {
                ProgressView(value: downloadFraction)
                    .tint(PhotoModePalette.green)
                    .padding(.top, 4)

                Text(downloadStatusText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(PhotoModePalette.muted)
            }

            HStack(spacing: 16) {
                Button("Not now") {
                    if !viewModel.isDownloadingModel {
                        isDownloadPromptPresented = false
                    }
                }
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PhotoModePalette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(PhotoModePalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(PhotoModePalette.border, lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .disabled(viewModel.isDownloadingModel)

                Button {
                    Task {
                        await viewModel.downloadModel()
                        if viewModel.enableOfflineModeIfAvailable() {
                            isDownloadPromptPresented = false
                            isModeSheetPresented = false
                        }
                    }
                } label: {
                    Text(viewModel.isDownloadingModel ? "Downloading..." : "👉 Yes, download!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(PhotoModePalette.green)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isDownloadingModel)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(PhotoModePalette.background)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var downloadPromptBody: String {
        if viewModel.modelStatus.isAvailable {
            return "Offline ASL is already saved on this device."
        }
        return "We'll save the ASL signs to your phone so you can use them anywhere, even with no internet."
    }

    private var downloadFraction: Double? {
        guard let metrics = viewModel.modelStatus.downloadMetrics,
              let totalBytes = metrics.totalBytes,
              totalBytes > 0 else {
            return nil
        }
        return min(max(Double(metrics.bytesReceived) / Double(totalBytes), 0), 1)
    }

    private var downloadStatusText: String {
        switch viewModel.modelStatus.installState {
        case .downloading(let completedFiles, let totalFiles, let currentFile):
            return "Downloading \(completedFiles)/\(totalFiles): \(currentFile)"
        default:
            return "Preparing offline mode..."
        }
    }

    private func handleOfflineModeTap() {
        if viewModel.enableOfflineModeIfAvailable() {
            isDownloadPromptPresented = false
            isModeSheetPresented = false
        } else {
            isDownloadPromptPresented = true
        }
    }

    private var hasTranslationUI: Bool {
        !viewModel.recognitionResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.suggestedKeywords.isEmpty
    }

    private var playbackSpeeds: [String] {
        ["0.5x", "0.75x", "1x", "1.5x"]
    }

    private var originalText: String {
        if let descriptionRange = viewModel.recognitionResult.range(of: "Description:", options: .caseInsensitive) {
            let descriptionPortion = String(viewModel.recognitionResult[descriptionRange.upperBound...])
            if let keywordsRange = descriptionPortion.range(of: "Keywords:", options: .caseInsensitive) {
                let value = descriptionPortion[..<keywordsRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
            let trimmed = descriptionPortion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return viewModel.recognitionResult.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var glossWords: [String] {
        if !viewModel.suggestedKeywords.isEmpty {
            return viewModel.suggestedKeywords
        }
        return originalText
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .split(separator: " ")
            .map(String.init)
    }

    private var glossText: String {
        glossWords.joined(separator: " ").uppercased()
    }

    private var signVideoSelectionKey: String {
        viewModel.signVideos.map { "\($0.id)|\($0.localVideoURL?.absoluteString ?? "none")" }.joined(separator: ",")
    }

    private var activeSignVideo: ASLSignVideo? {
        if let selectedSignID {
            return viewModel.signVideos.first(where: { $0.id == selectedSignID })
        }
        return viewModel.signVideos.first(where: { $0.localVideoURL != nil })
    }

    private func selectDefaultPlayableSignIfNeeded() {
        guard let firstPlayable = viewModel.signVideos.first(where: { $0.localVideoURL != nil }) else {
            selectedSignID = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
            return
        }

        if selectedSignID != firstPlayable.id || player.currentItem == nil {
            selectedSignID = firstPlayable.id
            loadPlayer(for: firstPlayable, autoplay: false)
        }
    }

    private func selectSign(for word: String) {
        guard let sign = signForWord(word) else { return }
        selectedSignID = sign.id
        loadPlayer(for: sign, autoplay: true)
    }

    private func signForWord(_ word: String) -> ASLSignVideo? {
        let normalizedWord = word.lowercased()
        return viewModel.signVideos.first {
            $0.normalized == normalizedWord || $0.input.lowercased() == normalizedWord
        }
    }

    private func loadPlayer(for sign: ASLSignVideo, autoplay: Bool) {
        guard let localVideoURL = sign.localVideoURL else { return }
        let item = AVPlayerItem(url: localVideoURL)
        item.audioTimePitchAlgorithm = .varispeed
        player.replaceCurrentItem(with: item)
        player.pause()
        player.defaultRate = playbackRate

        if autoplay {
            player.seek(to: .zero) { _ in
                playSelectedVideo()
            }
        } else {
            player.seek(to: .zero)
        }
    }

    private func playSelectedVideo() {
        guard let sign = activeSignVideo else { return }

        if player.currentItem == nil, let url = sign.localVideoURL {
            let item = AVPlayerItem(url: url)
            item.audioTimePitchAlgorithm = .varispeed
            player.replaceCurrentItem(with: item)
        }

        player.defaultRate = playbackRate
        player.playImmediately(atRate: playbackRate)
        reinforcePlaybackRate()
    }

    private func updatePlayerRateIfNeeded() {
        guard player.timeControlStatus == .playing else { return }
        player.defaultRate = playbackRate
        player.rate = playbackRate
        reinforcePlaybackRate()
    }

    private func reinforcePlaybackRate() {
        let targetRate = playbackRate
        player.rate = targetRate

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            if player.timeControlStatus == .playing {
                player.defaultRate = targetRate
                player.rate = targetRate
            }
        }
    }

    private var playbackRate: Float {
        switch selectedPlaybackSpeed {
        case "0.5x":
            return 0.5
        case "0.75x":
            return 0.75
        case "1.5x":
            return 1.5
        default:
            return 1.0
        }
    }

    private func chipBackground(for word: String) -> Color {
        if signForWord(word)?.localVideoURL == nil {
            return PhotoModePalette.chip.opacity(0.55)
        }
        return isSelectedWord(word) ? PhotoModePalette.green : PhotoModePalette.chip
    }

    private func chipBorder(for word: String) -> Color {
        if signForWord(word)?.localVideoURL == nil {
            return Color.yellow.opacity(0.9)
        }
        return isSelectedWord(word) ? Color.white.opacity(0.95) : Color.clear
    }

    private func chipLineWidth(for word: String) -> CGFloat {
        signForWord(word)?.localVideoURL == nil || isSelectedWord(word) ? 2 : 0
    }

    private func isSelectedWord(_ word: String) -> Bool {
        guard let selectedSignID,
              let sign = signForWord(word) else { return false }
        return sign.id == selectedSignID
    }
}

private struct ASLSignVideoCard: View {
    let sign: ASLSignVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(sign.normalized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let match = sign.match, match.lowercased() != sign.normalized {
                    Text("Matched \(match)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }

            if let localVideoURL = sign.localVideoURL {
                VideoPlayer(player: AVPlayer(url: localVideoURL))
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if let reason = sign.reason {
                Text(reason)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
            }

            if let error = sign.error {
                Text(error)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.red.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(PhotoModePalette.navyPanel)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        CameraRecognitionView(viewModel: AppViewModel())
    }
}
