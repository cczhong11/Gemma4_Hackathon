import Foundation

struct ASLTranslationResponse: Decodable, Equatable {
    let gloss: String
    let tokens: [String]
    let unknownTokens: [String]
    let isQuestion: Bool
    let model: String

    enum CodingKeys: String, CodingKey {
        case gloss
        case tokens
        case model
        case unknownTokens = "unknown_tokens"
        case isQuestion = "is_question"
    }
}

enum ASLTranslationError: LocalizedError {
    case missingBaseURL
    case missingToken
    case invalidResponse(status: Int)
    case decodingFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "ASL_API_BASE_URL is not configured in Info.plist."
        case .missingToken:
            return "HF_TOKEN is not configured in Info.plist."
        case .invalidResponse(let status):
            return "Translate API returned HTTP \(status)."
        case .decodingFailed:
            return "Could not decode the translate API response."
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct ASLTranslationService {
    private static let baseURLKey = "ASL_API_BASE_URL"
    private static let tokenKey = "HF_TOKEN"

    private let session: URLSession
    private let baseURL: URL
    private let token: String

    init(session: URLSession? = nil, bundle: Bundle = .main) throws {
        let rawBaseURL = (bundle.object(forInfoDictionaryKey: Self.baseURLKey) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawToken = (bundle.object(forInfoDictionaryKey: Self.tokenKey) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawBaseURL.isEmpty,
              let parsed = URL(string: rawBaseURL.hasSuffix("/") ? String(rawBaseURL.dropLast()) : rawBaseURL) else {
            throw ASLTranslationError.missingBaseURL
        }
        guard !rawToken.isEmpty else {
            throw ASLTranslationError.missingToken
        }

        self.baseURL = parsed
        self.token = rawToken

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func translate(text: String) async throws -> ASLTranslationResponse {
        let endpoint = baseURL.appendingPathComponent("translate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["text": text])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ASLTranslationError.transport(error)
        }

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ASLTranslationError.invalidResponse(status: status)
        }

        do {
            return try JSONDecoder().decode(ASLTranslationResponse.self, from: data)
        } catch {
            throw ASLTranslationError.decodingFailed
        }
    }
}
