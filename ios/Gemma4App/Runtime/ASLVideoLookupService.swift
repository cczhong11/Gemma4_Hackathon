import Foundation

struct ASLSignVideo: Identifiable, Sendable {
    let input: String
    let normalized: String
    let match: String?
    let pageURL: URL?
    let sourceVideoURL: URL?
    let localVideoURL: URL?
    let skipped: Bool
    let reason: String?
    let error: String?

    var id: String { normalized }
}

struct ASLVideoLookupService {
    private static let handspeakBaseURL = URL(string: "https://www.handspeak.com")!
    private static let omittedWords = Set(["a", "an", "the"])
    private static let browserHeaders = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7",
        "Accept-Language": "en-US,en;q=0.9"
    ]

    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession? = nil, fileManager: FileManager = .default) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
        self.fileManager = fileManager
    }

    func lookup(words: [String]) async -> [ASLSignVideo] {
        var results: [ASLSignVideo] = []
        for word in words {
            let normalized = normalize(word)
            guard !normalized.isEmpty else { continue }
            let result = await lookup(word: word, normalized: normalized)
            results.append(result)
        }
        return results
    }

    private func lookup(word: String, normalized: String) async -> ASLSignVideo {
        if Self.omittedWords.contains(normalized) {
            return ASLSignVideo(
                input: word,
                normalized: normalized,
                match: nil,
                pageURL: nil,
                sourceVideoURL: nil,
                localVideoURL: nil,
                skipped: true,
                reason: "Skipped common filler word.",
                error: nil
            )
        }

        do {
            var lastMiss: ASLSignVideo?

            for lookupTerm in fallbackLookupTerms(for: normalized) {
                let searchURL = Self.handspeakBaseURL
                    .appending(path: "/word/app/search-dict.php")
                    .appending(queryItems: [URLQueryItem(name: "q", value: lookupTerm)])
                let payload: SearchPayload = try await fetchJSON(from: searchURL)

                guard let bestMatch = bestMatch(for: lookupTerm, in: payload),
                      let pageURL = absoluteHandspeakURL(path: bestMatch.url) else {
                    lastMiss = ASLSignVideo(
                        input: word,
                        normalized: normalized,
                        match: nil,
                        pageURL: nil,
                        sourceVideoURL: nil,
                        localVideoURL: nil,
                        skipped: false,
                        reason: nil,
                        error: "No matching ASL dictionary entry found."
                    )
                    continue
                }

                let html = try await fetchText(from: pageURL)
                let candidates = extractVideoURLs(from: html)
                guard !candidates.isEmpty else {
                    lastMiss = ASLSignVideo(
                        input: word,
                        normalized: normalized,
                        match: bestMatch.signName,
                        pageURL: pageURL,
                        sourceVideoURL: nil,
                        localVideoURL: nil,
                        skipped: false,
                        reason: lookupTerm == normalized ? nil : "Used singular fallback: \(lookupTerm).",
                        error: "No MP4 found on the dictionary page."
                    )
                    continue
                }

                let cachedVideo = try await downloadFirstPlayableVideo(
                    from: candidates,
                    pageURL: pageURL,
                    normalized: normalized
                )

                return ASLSignVideo(
                    input: word,
                    normalized: normalized,
                    match: bestMatch.signName,
                    pageURL: pageURL,
                    sourceVideoURL: cachedVideo.sourceURL,
                    localVideoURL: cachedVideo.localURL,
                    skipped: false,
                    reason: lookupTerm == normalized
                        ? "Cached locally and ready to play."
                        : "Used singular fallback '\(lookupTerm)' and cached locally.",
                    error: nil
                )
            }

            return lastMiss ?? ASLSignVideo(
                input: word,
                normalized: normalized,
                match: nil,
                pageURL: nil,
                sourceVideoURL: nil,
                localVideoURL: nil,
                skipped: false,
                reason: nil,
                error: "No matching ASL dictionary entry found."
            )
        } catch {
            return ASLSignVideo(
                input: word,
                normalized: normalized,
                match: nil,
                pageURL: nil,
                sourceVideoURL: nil,
                localVideoURL: nil,
                skipped: false,
                reason: nil,
                error: error.localizedDescription
            )
        }
    }

    private func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        Self.browserHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw ASLVideoLookupError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func fetchText(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        Self.browserHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw ASLVideoLookupError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ASLVideoLookupError.unreadableHTML
        }
        return html
    }

    private func extractVideoURLs(from html: String) -> [URL] {
        let pattern = #"<video[^>]+src="([^"]+\.mp4)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var urls: [URL] = []
        var seen = Set<String>()

        for match in regex.matches(in: html, options: [], range: range) {
            guard let relativeRange = Range(match.range(at: 1), in: html) else { continue }
            let candidate = String(html[relativeRange])
            guard let url = absoluteHandspeakURL(path: candidate) else { continue }
            guard seen.insert(url.absoluteString).inserted else { continue }
            urls.append(url)
        }

        return urls
    }

    private func downloadFirstPlayableVideo(
        from candidates: [URL],
        pageURL: URL,
        normalized: String
    ) async throws -> (sourceURL: URL, localURL: URL) {
        var lastError: Error = ASLVideoLookupError.noPlayableVideo

        for candidate in candidates {
            do {
                let localURL = try await downloadVideo(candidate, referer: pageURL, normalized: normalized)
                return (candidate, localURL)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private func downloadVideo(_ sourceURL: URL, referer pageURL: URL, normalized: String) async throws -> URL {
        let destination = try cachedVideoURL(for: sourceURL, normalized: normalized)
        if fileManager.fileExists(atPath: destination.path) {
            return destination
        }

        var request = URLRequest(url: sourceURL)
        Self.browserHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue(pageURL.absoluteString, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw ASLVideoLookupError.invalidVideoResponse
        }

        let mimeType = (httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        guard mimeType.contains("video/mp4") || sourceURL.pathExtension.lowercased() == "mp4" else {
            throw ASLVideoLookupError.invalidVideoResponse
        }

        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func cachedVideoURL(for sourceURL: URL, normalized: String) throws -> URL {
        let cachesDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = cachesDirectory.appendingPathComponent("HandspeakVideos", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let filename = "\(normalized)-\(sourceURL.lastPathComponent)"
        return directory.appendingPathComponent(filename)
    }

    private func bestMatch(for normalized: String, in payload: SearchPayload) -> SearchResult? {
        payload.word
            ?? payload.wordlist?.first(where: { $0.signName.lowercased() == normalized })
            ?? payload.wordlist?.first
    }

    private func fallbackLookupTerms(for normalized: String) -> [String] {
        var terms = [normalized]

        if normalized.count > 3, normalized.hasSuffix("ies") {
            terms.append(String(normalized.dropLast(3)) + "y")
        }

        if normalized.count > 3, normalized.hasSuffix("es") {
            terms.append(String(normalized.dropLast(2)))
        }

        if normalized.count > 2, normalized.hasSuffix("s"), !normalized.hasSuffix("ss") {
            terms.append(String(normalized.dropLast()))
        }

        var seen = Set<String>()
        return terms.filter { term in
            !term.isEmpty && seen.insert(term).inserted
        }
    }

    private func absoluteHandspeakURL(path: String) -> URL? {
        URL(string: path, relativeTo: Self.handspeakBaseURL)?.absoluteURL
    }

    private func normalize(_ word: String) -> String {
        word
            .lowercased()
            .replacingOccurrences(of: #"[^\p{ASCII}]"#, with: "", options: .regularExpression)
            .components(separatedBy: CharacterSet.letters.inverted)
            .joined()
    }
}

private struct SearchPayload: Decodable {
    let word: SearchResult?
    let wordlist: [SearchResult]?
}

private struct SearchResult: Decodable {
    let signID: Int
    let signName: String
    let url: String
}

private enum ASLVideoLookupError: LocalizedError {
    case invalidResponse
    case unreadableHTML
    case invalidVideoResponse
    case noPlayableVideo

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Handspeak lookup failed."
        case .unreadableHTML:
            return "Could not parse the Handspeak page."
        case .invalidVideoResponse:
            return "Handspeak MP4 download failed."
        case .noPlayableVideo:
            return "No playable sign video found."
        }
    }
}
