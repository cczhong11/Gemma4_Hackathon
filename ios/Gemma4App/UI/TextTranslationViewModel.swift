import Foundation
import SwiftUI

@MainActor
final class TextTranslationViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isTranslating: Bool = false
    @Published var errorMessage: String?
    @Published var units: [GlossUnit] = []
    @Published var videos: [ASLSignVideo] = []
    @Published var currentVideoIndex: Int = 0
    @Published var translatedText: String = ""
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0

    private var selectedMode: AppViewModel.TranslationMode = .betterSigns
    private var remoteTranslationService: ASLTranslationService?
    private var localTranslationService: ASLTranslationService?
    private let lookupService: ASLVideoLookupService
    private var translateTask: Task<Void, Never>?

    init(
        translationService: ASLTranslationService? = nil,
        lookupService: ASLVideoLookupService = ASLVideoLookupService()
    ) {
        self.remoteTranslationService = translationService
        self.lookupService = lookupService
    }

    var activeUnitID: GlossUnit.ID? {
        units.first(where: { $0.videoRange.contains(currentVideoIndex) })?.id
    }

    var currentVideoURL: URL? {
        guard videos.indices.contains(currentVideoIndex) else { return nil }
        return videos[currentVideoIndex].localVideoURL
    }

    var glossText: String {
        units.map(\.displayLabel).joined(separator: " ")
    }

    var playbackProgress: Double {
        guard !videos.isEmpty else { return 0 }
        return Double(currentVideoIndex + 1) / Double(videos.count)
    }

    var activeUnit: GlossUnit? {
        units.first(where: { $0.videoRange.contains(currentVideoIndex) })
    }

    func translate() {
        translateTask?.cancel()
        translateTask = Task { [weak self] in
            await self?.performTranslate()
        }
    }

    func clear() {
        translateTask?.cancel()
        translateTask = nil
        inputText = ""
        units = []
        videos = []
        currentVideoIndex = 0
        errorMessage = nil
        isTranslating = false
        translatedText = ""
        isPlaying = false
        playbackSpeed = 1.0
    }

    func onVideoEnded() {
        guard !videos.isEmpty else { return }
        let nextIndex = currentVideoIndex + 1
        if nextIndex >= videos.count {
            currentVideoIndex = 0
            isPlaying = false
        } else {
            currentVideoIndex = nextIndex
        }
    }

    func jumpTo(unit: GlossUnit) {
        guard !unit.videoRange.isEmpty else { return }
        currentVideoIndex = unit.videoRange.lowerBound
        isPlaying = true
    }

    func play() {
        guard !videos.isEmpty else { return }
        isPlaying = true
    }

    func stop() {
        isPlaying = false
    }

    func togglePlayback() {
        if isPlaying { stop() } else { play() }
    }

    func setSpeed(_ speed: Double) {
        playbackSpeed = speed
    }

    func setTranslationMode(_ mode: AppViewModel.TranslationMode) {
        selectedMode = mode
    }

    private func performTranslate() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Type something first."
            return
        }

        isTranslating = true
        errorMessage = nil
        units = []
        videos = []
        currentVideoIndex = 0
        isPlaying = false
        translatedText = trimmed

        let service: ASLTranslationService
        do {
            service = try translationService(for: selectedMode)
        } catch {
            errorMessage = error.localizedDescription
            isTranslating = false
            return
        }

        let response: ASLTranslationResponse
        do {
            response = try await service.translate(text: trimmed)
        } catch {
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
            isTranslating = false
            return
        }

        if Task.isCancelled { return }

        let pendingUnits = Self.buildPendingUnits(from: response.tokens)
        let flatLetters = pendingUnits.flatMap { $0.letters }

        let allResults: [ASLSignVideo]
        if flatLetters.isEmpty {
            allResults = []
        } else {
            allResults = await lookupService.lookup(words: flatLetters)
        }

        if Task.isCancelled { return }

        var assembledUnits: [GlossUnit] = []
        var playQueue: [ASLSignVideo] = []
        var resultCursor = 0

        for pending in pendingUnits {
            let letterCount = pending.letters.count
            let endCursor = min(resultCursor + letterCount, allResults.count)
            let slice = Array(allResults[resultCursor..<endCursor])
            resultCursor = endCursor

            let playable = slice.filter { $0.localVideoURL != nil }
            let rangeStart = playQueue.count
            playQueue.append(contentsOf: playable)
            let rangeEnd = playQueue.count

            assembledUnits.append(
                GlossUnit(
                    kind: pending.kind,
                    videoRange: rangeStart..<rangeEnd,
                    displayLabel: pending.displayLabel,
                    isPlayable: !playable.isEmpty
                )
            )
        }

        units = assembledUnits
        videos = playQueue
        currentVideoIndex = 0
        isTranslating = false
        isPlaying = !playQueue.isEmpty

        if playQueue.isEmpty {
            errorMessage = "No playable signs for this sentence."
        }
    }

    private func translationService(for mode: AppViewModel.TranslationMode) throws -> ASLTranslationService {
        switch mode {
        case .betterSigns:
            if let remoteTranslationService {
                return remoteTranslationService
            }
            let created = try ASLTranslationService()
            remoteTranslationService = created
            return created
        case .offline:
            if let localTranslationService {
                return localTranslationService
            }
            let created = try ASLTranslationService(localAdapter: Gemma4Loader.load_gemma4_text_to_text())
            localTranslationService = created
            return created
        }
    }

    private struct PendingUnit {
        let kind: GlossUnit.Kind
        let displayLabel: String
        let letters: [String]
    }

    private static func buildPendingUnits(from tokens: [String]) -> [PendingUnit] {
        tokens.compactMap { token in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if trimmed.uppercased().hasPrefix("FS-") {
                let word = String(trimmed.dropFirst(3)).uppercased()
                let letters = word.map { String($0).lowercased() }
                return PendingUnit(
                    kind: .fingerspell(word),
                    displayLabel: "\(word) (FS)",
                    letters: letters
                )
            }

            let canonical = trimmed.lowercased()
            return PendingUnit(
                kind: .sign(canonical),
                displayLabel: canonical.uppercased(),
                letters: [canonical]
            )
        }
    }
}
