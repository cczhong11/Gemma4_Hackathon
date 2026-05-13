import AVKit
import SwiftUI
import UIKit

struct CameraRecognitionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var navigateToTypeMode = false
    @State private var isModeSheetPresented = false
    @State private var isDownloadPromptPresented = false
    @State private var selectedPlaybackSpeed = "1.5x"
    @State private var selectedSignID: String?
    @State private var activeCategoryIndex = 0
    @State private var player = AVPlayer()
    @State private var celebratedMode: AppViewModel.TranslationMode?
    @State private var celebrationOpacity = 0.0
    @State private var celebrationScale: CGFloat = 0.5
    @State private var celebrationRotation = -18.0
    @State private var sparkleLift: CGFloat = 18

    var body: some View {
        ZStack(alignment: .bottom) {
            PhotoModePalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        PhotoModeHeader {
                            viewModel.refreshModelStatus()
                            isModeSheetPresented = true
                        }

                        PhotoModeActionRow(
                            onCameraTap: { showingCamera = true },
                            onPhotosTap: { showingPhotoLibrary = true }
                        )

                        if let image = viewModel.capturedImage, !hasTranslationUI {
                            PhotoSelectedImageCard(image: image)
                            PhotoAnalyzeButton(isLoading: viewModel.isLoading) {
                                Task {
                                    await viewModel.recognizeCapturedImage()
                                }
                            }
                        }

                        if viewModel.isLoading {
                            PhotoStatusCard(title: "Analyzing photo...")
                        }

                        if let errorMessage = viewModel.errorMessage {
                            PhotoMessageCard(text: errorMessage, tint: .red)
                        }

                        if viewModel.isLoadingSignVideos {
                            PhotoStatusCard(title: "Looking up sign videos...")
                        }

                        if viewModel.photoCategories.count > 1 {
                            PhotoCategoryTabs(
                                categories: viewModel.photoCategories,
                                activeIndex: activeCategoryIndex,
                                onTap: { index in
                                    activeCategoryIndex = index
                                }
                            )
                        }

                        if hasTranslationUI {
                            PhotoPlaybackSection(
                                player: player,
                                hasVideo: activeSignVideo?.localVideoURL != nil,
                                isLoadingSignVideos: viewModel.isLoadingSignVideos,
                                activeIssue: activePlaybackIssue,
                                activeLabel: activePlaybackLabel,
                                activeIsFingerspelled: activePlaybackIsFingerspelled,
                                playbackProgress: playbackProgress,
                                playbackSpeeds: playbackSpeeds,
                                selectedPlaybackSpeed: selectedPlaybackSpeed,
                                sourcePageURL: activeSignVideo?.pageURL,
                                onPlayTap: playSelectedVideo,
                                onSpeedTap: { selectedPlaybackSpeed = $0 }
                            )

                            PhotoTranslationCard(
                                originalText: originalText,
                                glossText: glossText,
                                glossWords: glossWords,
                                chipBackground: chipBackground,
                                chipBorder: chipBorder,
                                chipLineWidth: chipLineWidth,
                                chipDash: chipDash,
                                onWordTap: selectSign
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 140)
                }

                PhotoModeBottomTabBar(
                    isTypeActive: false,
                    isPhotoActive: true,
                    onTypeTap: { navigateToTypeMode = true },
                    onPhotoTap: { }
                )
            }

            if isModeSheetPresented {
                overlay
                PhotoModeSheet(
                    selectedMode: viewModel.selectedTranslationMode,
                    offlineSubtitle: offlineModeSubtitle,
                    onBetterSignsTap: {
                        celebrateModeSelection(.betterSigns) {
                            viewModel.selectBetterSignsMode()
                        }
                    },
                    onOfflineTap: handleOfflineModeTap,
                    modelSettingsCard: AnyView(modelSettingsCard)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isDownloadPromptPresented {
                overlay
                PhotoOfflineDownloadPrompt(
                    isDownloading: viewModel.isDownloadingModel,
                    downloadStageEmoji: downloadStageEmoji,
                    downloadPromptBody: downloadPromptBody,
                    downloadFraction: downloadFraction,
                    downloadStageText: downloadStageText,
                    downloadStatusText: downloadStatusText,
                    onCancel: {
                        if !viewModel.isDownloadingModel {
                            isDownloadPromptPresented = false
                        }
                    },
                    onDownload: {
                        Task {
                            await viewModel.downloadModel()
                            if viewModel.enableOfflineModeIfAvailable() {
                                celebrateModeSelection(.offline) { }
                            }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let celebratedMode {
                PhotoCelebrationOverlay(
                    mode: celebratedMode,
                    opacity: celebrationOpacity,
                    scale: celebrationScale,
                    rotation: celebrationRotation,
                    sparkleLift: sparkleLift
                )
                .transition(.opacity.combined(with: .scale))
                .allowsHitTesting(false)
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
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: celebratedMode)
        .onChange(of: signVideoSelectionKey) { _ in
            selectDefaultPlayableSignIfNeeded()
        }
        .onChange(of: activeCategoryIndex) { _ in
            selectDefaultPlayableSignIfNeeded()
        }
        .onChange(of: photoCategorySelectionKey) { _ in
            activeCategoryIndex = 0
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

    private var overlay: some View {
        Color.black.opacity(0.18)
            .ignoresSafeArea()
            .onTapGesture {
                if !viewModel.isDownloadingModel {
                    isModeSheetPresented = false
                    isDownloadPromptPresented = false
                }
            }
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
        viewModel.refreshModelStatus()
        if viewModel.enableOfflineModeIfAvailable() {
            celebrateModeSelection(.offline) { }
        } else {
            isDownloadPromptPresented = true
        }
    }

    private var offlineModeSubtitle: String {
        viewModel.modelStatus.isAvailable
            ? "Use anywhere · model cached"
            : "Use anywhere · needs download"
    }

    private var modelSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Model Settings")
                .font(HearmeTypography.brand(23))
                .foregroundStyle(PhotoModePalette.ink)

            Text(modelStatusSummary)
                .font(HearmeTypography.bodyStrong(16))
                .foregroundStyle(PhotoModePalette.muted)

            if viewModel.isDownloadingModel || isModelDownloading {
                ProgressView(value: downloadFraction)
                    .tint(PhotoModePalette.green)

                Text(downloadStatusText)
                    .font(HearmeTypography.bodyStrong(15))
                    .foregroundStyle(PhotoModePalette.muted)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.refreshModelStatus()
                } label: {
                    Text("Refresh status")
                        .font(HearmeTypography.gloss(17))
                        .foregroundStyle(PhotoModePalette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(PhotoModePalette.card)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(PhotoModePalette.border, lineWidth: 1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    guard !viewModel.modelStatus.isAvailable else {
                        viewModel.refreshModelStatus()
                        return
                    }

                    Task {
                        await viewModel.downloadModel()
                    }
                } label: {
                    Text(modelActionTitle)
                        .font(HearmeTypography.gloss(17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(modelActionEnabled ? PhotoModePalette.green : PhotoModePalette.green.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!modelActionEnabled)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .background(PhotoModePalette.card)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(PhotoModePalette.border, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var isModelDownloading: Bool {
        if case .downloading = viewModel.modelStatus.installState {
            return true
        }
        return false
    }

    private var modelStatusSummary: String {
        if viewModel.modelStatus.isAvailable {
            return "Cached on this device. Offline mode is ready."
        }

        switch viewModel.modelStatus.installState {
        case .checkingSource:
            return "Checking whether an offline model is already cached."
        case .downloading:
            return "Downloading offline model now."
        case .bundled:
            return "Bundled model found and ready to use."
        case .downloaded:
            return "Downloaded model found and ready to use."
        case .notInstalled:
            return "No cached offline model found yet."
        case .failed(let message):
            return message
        }
    }

    private var modelActionTitle: String {
        if viewModel.modelStatus.isAvailable {
            return "Cached"
        }
        if viewModel.isDownloadingModel || isModelDownloading {
            return "Downloading..."
        }
        return "Download model"
    }

    private var modelActionEnabled: Bool {
        !viewModel.modelStatus.isAvailable && !(viewModel.isDownloadingModel || isModelDownloading)
    }

    private var hasTranslationUI: Bool {
        activeCategory != nil || !viewModel.recognitionResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.suggestedKeywords.isEmpty
    }

    private var playbackSpeeds: [String] {
        ["0.5x", "0.75x", "1x", "1.5x"]
    }

    private var originalText: String {
        if let activeCategory {
            return activeCategory.text
        }
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
        if let activeCategory, !activeCategory.keywords.isEmpty {
            return activeCategory.keywords
        }
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
        currentSignVideos.map { "\($0.id)|\($0.localVideoURL?.absoluteString ?? "none")" }.joined(separator: ",")
    }

    private var activeSignVideo: ASLSignVideo? {
        if let selectedSignID {
            return currentSignVideos.first(where: { $0.id == selectedSignID })
        }
        return currentSignVideos.first(where: { $0.localVideoURL != nil })
    }

    private var activeCategory: PhotoRecognitionCategory? {
        guard viewModel.photoCategories.indices.contains(activeCategoryIndex) else { return nil }
        return viewModel.photoCategories[activeCategoryIndex]
    }

    private var currentSignVideos: [ASLSignVideo] {
        activeCategory?.signVideos ?? viewModel.signVideos
    }

    private var photoCategorySelectionKey: String {
        viewModel.photoCategories.map { "\($0.id.uuidString)|\($0.label)" }.joined(separator: ",")
    }

    private func selectDefaultPlayableSignIfNeeded() {
        guard let firstPlayable = currentSignVideos.first(where: { $0.localVideoURL != nil }) else {
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
        return currentSignVideos.first {
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
        player.currentItem?.audioTimePitchAlgorithm = .varispeed
        player.defaultRate = playbackRate

        guard player.currentItem != nil else { return }

        if player.timeControlStatus == .playing {
            player.rate = playbackRate
            reinforcePlaybackRate()
        }
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

    private func chipDash(for word: String) -> [CGFloat] {
        signForWord(word)?.localVideoURL == nil ? [8, 6] : []
    }

    private func isSelectedWord(_ word: String) -> Bool {
        guard let selectedSignID,
              let sign = signForWord(word) else { return false }
        return sign.id == selectedSignID
    }

    private var activePlaybackLabel: String? {
        guard let sign = activeSignVideo else { return nil }
        return sign.localVideoURL == nil ? "\(sign.normalized.uppercased()) · SPELL" : sign.normalized.uppercased()
    }

    private var activePlaybackIsFingerspelled: Bool {
        activeSignVideo?.localVideoURL == nil
    }

    private var activePlaybackIssue: (title: String, body: String)? {
        guard let sign = activeSignVideo else { return nil }
        if let error = sign.error {
            return ("SIGN UNAVAILABLE", error)
        }
        if sign.localVideoURL == nil {
            return ("FINGERSPELLING", sign.reason ?? "No direct clip found, so this word is treated as fingerspelling.")
        }
        return nil
    }

    private var playbackProgress: CGFloat {
        guard let activeSignVideo,
              let index = currentSignVideos.firstIndex(where: { $0.id == activeSignVideo.id }),
              !currentSignVideos.isEmpty else {
            return 0
        }
        return CGFloat(index + 1) / CGFloat(max(currentSignVideos.count, 1))
    }

    private func celebrateModeSelection(
        _ mode: AppViewModel.TranslationMode,
        apply: @escaping () -> Void
    ) {
        apply()
        celebratedMode = mode
        celebrationOpacity = 0
        celebrationScale = 0.5
        celebrationRotation = -18
        sparkleLift = 18

        withAnimation(.easeOut(duration: 0.18)) {
            celebrationOpacity = 1
        }
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 11)) {
            celebrationScale = 1
            celebrationRotation = 0
            sparkleLift = 0
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_350_000_000)
            withAnimation(.easeOut(duration: 0.24)) {
                celebrationOpacity = 0
            }
            isModeSheetPresented = false
            isDownloadPromptPresented = false
            try? await Task.sleep(nanoseconds: 250_000_000)
            if celebratedMode == mode {
                celebratedMode = nil
            }
        }
    }

    private var downloadStageText: String {
        let progress = downloadFraction ?? 0
        switch progress {
        case ..<0.15:
            return "Getting ready..."
        case ..<0.35:
            return "Packing the signs..."
        case ..<0.55:
            return "Adding ASL words..."
        case ..<0.8:
            return "Loading videos..."
        case ..<0.98:
            return "Almost done!"
        default:
            return "All set!"
        }
    }

    private var downloadStageEmoji: String {
        let progress = downloadFraction ?? 0
        switch progress {
        case ..<0.15:
            return "✨"
        case ..<0.35:
            return "📦"
        case ..<0.55:
            return "🤟"
        case ..<0.8:
            return "🎬"
        case ..<0.98:
            return "🎉"
        default:
            return "✅"
        }
    }
}

#Preview {
    NavigationStack {
        CameraRecognitionView(viewModel: AppViewModel())
    }
}
