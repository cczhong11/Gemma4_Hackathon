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

    private var translationService: ASLTranslationService?
    private let lookupService: ASLVideoLookupService
    private var translateTask: Task<Void, Never>?

    init(
        translationService: ASLTranslationService? = nil,
        lookupService: ASLVideoLookupService = ASLVideoLookupService()
    ) {
        self.translationService = translationService
        self.lookupService = lookupService
    }

    var activeUnitID: GlossUnit.ID? {
        units.first(where: { $0.videoRange.contains(currentVideoIndex) })?.id
    }

    var currentVideoURL: URL? {
        guard videos.indices.contains(currentVideoIndex) else { return nil }
        return videos[currentVideoIndex].localVideoURL
    }

    func translate() {
        translateTask?.cancel()
        translateTask = Task { [weak self] in
            await self?.performTranslate()
        }
    }

    func onVideoEnded() {
        guard !videos.isEmpty else { return }
        currentVideoIndex = (currentVideoIndex + 1) % videos.count
    }

    func jumpTo(unit: GlossUnit) {
        guard !unit.videoRange.isEmpty else { return }
        currentVideoIndex = unit.videoRange.lowerBound
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

        let service: ASLTranslationService
        if let translationService {
            service = translationService
        } else {
            do {
                let created = try ASLTranslationService()
                translationService = created
                service = created
            } catch {
                errorMessage = error.localizedDescription
                isTranslating = false
                return
            }
        }

        let response: ASLTranslationResponse
        do {
            response = try await service.translate(text: trimmed)
        } catch {
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

        if playQueue.isEmpty {
            errorMessage = "No playable signs for this sentence."
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
