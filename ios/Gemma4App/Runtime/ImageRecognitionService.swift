import UIKit

struct ImageRecognitionAnalysis {
    let description: String
    let keywords: [String]
    let rawResponse: String
}

struct ImageRecognitionService {
    private let imageAdapterProvider: () -> any Gemma4ImageToTextAdapter
    private let textAdapterProvider: () -> any Gemma4TextToTextAdapter

    init(
        imageAdapterProvider: @escaping () -> any Gemma4ImageToTextAdapter = {
            Gemma4Loader.load_gemma4_image_to_text()
        },
        textAdapterProvider: @escaping () -> any Gemma4TextToTextAdapter = {
            Gemma4Loader.load_gemma4_text_to_text()
        }
    ) {
        self.imageAdapterProvider = imageAdapterProvider
        self.textAdapterProvider = textAdapterProvider
    }

    func analyze(image: UIImage) async throws -> ImageRecognitionAnalysis {
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
            rawResponse: response.text
        )
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
            rawResponse: raw
        )
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
