import UIKit
import Vision

struct ImageRecognitionAnalysis {
    let description: String
    let keywords: [String]
    let rawResponse: String
    let categories: [ImageRecognitionCategory]
}

struct ImageRecognitionCategory {
    let label: String
    let text: String
    let gloss: String
    let keywords: [String]
}

struct ImageRecognitionService {
    private let imageAdapterProvider: () -> any Gemma4ImageToTextAdapter
    private let textAdapterProvider: () -> any Gemma4TextToTextAdapter
    private let bundle: Bundle

    init(
        imageAdapterProvider: @escaping () -> any Gemma4ImageToTextAdapter = {
            Gemma4Loader.load_gemma4_image_to_text()
        },
        textAdapterProvider: @escaping () -> any Gemma4TextToTextAdapter = {
            Gemma4Loader.load_gemma4_text_to_text()
        },
        bundle: Bundle = .main
    ) {
        self.imageAdapterProvider = imageAdapterProvider
        self.textAdapterProvider = textAdapterProvider
        self.bundle = bundle
    }

    func analyze(image: UIImage) async throws -> ImageRecognitionAnalysis {
        let recognizedBlocks = try recognizeVisibleTextBlocks(in: image)
        if !recognizedBlocks.isEmpty {
            let normalizedText = recognizedBlocks.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let categories = try await buildCategories(from: recognizedBlocks)
            let keywords = categories.flatMap(\.keywords).uniquePrefix(5)
            return ImageRecognitionAnalysis(
                description: normalizedText,
                keywords: keywords,
                rawResponse: normalizedText,
                categories: categories
            )
        }

        let request = Gemma4ImageToTextRequest(
            prompt: """
            You are helping a beginner learn sign language from a photo.
            Return exactly two lines:
            Description: <one concise English sentence about what is visible>
            Keywords: <1 to 5 simple lowercase English words separated by comma and space>

            Rules:
            - Keywords must be visually concrete things or actions clearly visible in the photo.
            - Prefer single everyday dictionary words such as dog, book, drink, phone, run.
            - Do not use names, long phrases, numbering, or extra lines.
            - If text is visible in the image, you may mention it in the description.
            """,
            image: image
        )

        let adapter = imageAdapterProvider()
        let response = try await adapter.generate(request: request)
        let parsed = parse(response.text)
        if !parsed.keywords.isEmpty {
            return parsed
        }

        let fallbackKeywords = try await extractKeywordsFallback(from: parsed.description.isEmpty ? response.text : parsed.description)
        return ImageRecognitionAnalysis(
            description: parsed.description.isEmpty ? response.text.trimmingCharacters(in: .whitespacesAndNewlines) : parsed.description,
            keywords: fallbackKeywords,
            rawResponse: response.text,
            categories: [
                ImageRecognitionCategory(
                    label: "Result",
                    text: parsed.description.isEmpty ? response.text.trimmingCharacters(in: .whitespacesAndNewlines) : parsed.description,
                    gloss: fallbackKeywords.joined(separator: " ").uppercased(),
                    keywords: fallbackKeywords
                )
            ]
        )
    }

    private func recognizeVisibleTextBlocks(in image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgImageOrientation(for: image.imageOrientation))
        try handler.perform([request])

        let recognizedLines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniquePrefix(6)

        return recognizedLines
    }

    private func cgImageOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }

    private func parse(_ raw: String) -> ImageRecognitionAnalysis {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let descriptionLine = lines.first(where: { hasPrefix($0, candidates: ["Description:", "Description：", "描述:", "描述："]) })
        let keywordsLine = lines.first(where: { hasPrefix($0, candidates: ["Keywords:", "Keywords：", "关键词:", "关键词："]) })

        let description = stripPrefix(
            from: descriptionLine ?? lines.first ?? trimmed,
            prefixes: ["Description:", "Description：", "描述:", "描述："]
        )
        let keywords = normalizeKeywords(from: stripPrefix(
            from: keywordsLine ?? "",
            prefixes: ["Keywords:", "Keywords：", "关键词:", "关键词："]
        ))

        return ImageRecognitionAnalysis(
            description: description.isEmpty ? trimmed : description,
            keywords: keywords,
            rawResponse: raw,
            categories: [
                ImageRecognitionCategory(
                    label: "Result",
                    text: description.isEmpty ? trimmed : description,
                    gloss: keywords.joined(separator: " ").uppercased(),
                    keywords: keywords
                )
            ]
        )
    }

    private func buildCategories(from blocks: [String]) async throws -> [ImageRecognitionCategory] {
        var categories: [ImageRecognitionCategory] = []

        for (index, block) in blocks.enumerated() {
            let normalized = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let translated = try await extractGlossAndTokens(from: normalized)
            categories.append(
                ImageRecognitionCategory(
                    label: categoryLabel(for: normalized, index: index),
                    text: normalized,
                    gloss: translated.gloss,
                    keywords: translated.tokens
                )
            )
        }

        if categories.isEmpty, let first = blocks.first {
            let normalized = first.trimmingCharacters(in: .whitespacesAndNewlines)
            let translated = try await extractGlossAndTokens(from: normalized)
            categories.append(
                ImageRecognitionCategory(
                    label: "Text 1",
                    text: normalized,
                    gloss: translated.gloss,
                    keywords: translated.tokens
                )
            )
        }

        return categories
    }

    private func extractGlossAndTokens(from text: String) async throws -> (gloss: String, tokens: [String]) {
        do {
            let vocab = try ASLVocab.load(bundle: bundle)
            let prompt = ASLGlossPrompt.plainPrompt(text: text, vocab: vocab)
            let adapter = textAdapterProvider()
            let response = try await adapter.generate(prompt: prompt)
            let processed = try ASLGlossPostprocess.process(rawModelOutput: response, vocab: vocab)
            return (processed.gloss, processed.tokens)
        } catch {
            let keywords = try await extractKeywordsFallback(from: text)
            return (keywords.joined(separator: " ").uppercased(), keywords)
        }
    }

    private func categoryLabel(for text: String, index: Int) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = cleaned.split(separator: " ").prefix(2).joined(separator: " ")
        if preview.isEmpty {
            return "Text \(index + 1)"
        }
        let capped = String(preview.prefix(18))
        return capped.count < cleaned.count ? "\(capped)..." : capped
    }

    private func extractKeywordsFallback(from description: String) async throws -> [String] {
        let prompt = """
        Pick 1 to 5 simple lowercase English words that a beginner could look up in an ASL dictionary.
        Return only the words, separated by commas.

        Description:
        \(description)
        """

        let adapter = textAdapterProvider()
        let response = try await adapter.generate(prompt: prompt)
        return normalizeKeywords(from: response)
    }

    private func normalizeKeywords(from text: String) -> [String] {
        let matches = text.matches(of: /[A-Za-z][A-Za-z'-]*/)
        var seen = Set<String>()
        var keywords: [String] = []

        for match in matches {
            let keyword = match.output.lowercased()
            guard !["a", "an", "the", "and", "or"].contains(keyword) else { continue }
            guard seen.insert(keyword).inserted else { continue }
            keywords.append(keyword)
            if keywords.count == 5 {
                break
            }
        }

        return keywords
    }

    private func hasPrefix(_ text: String, candidates: [String]) -> Bool {
        candidates.contains { text.hasPrefix($0) }
    }

    private func stripPrefix(from text: String, prefixes: [String]) -> String {
        for prefix in prefixes where text.hasPrefix(prefix) {
            return text.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == String {
    func uniquePrefix(_ count: Int) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for value in self {
            guard seen.insert(value).inserted else { continue }
            output.append(value)
            if output.count == count {
                break
            }
        }

        return output
    }
}
