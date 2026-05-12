import Foundation

enum HFRouterError: LocalizedError {
    case invalidToken
    case rateLimited
    case upstream(status: Int)
    case timeout
    case transport(Error)
    case unparseable

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid HuggingFace token."
        case .rateLimited:
            return "HuggingFace rate-limited. Try again shortly."
        case .upstream(let status):
            return "HuggingFace error (HTTP \(status))."
        case .timeout:
            return "HuggingFace request timed out."
        case .transport:
            return "Network error. Check your connection."
        case .unparseable:
            return "Model returned no usable content."
        }
    }
}

struct HFRouterClient {
    static let routerURL = URL(string: "https://router.huggingface.co/v1/chat/completions")!
    static let model = "google/gemma-4-31B-it:deepinfra"
    static let timeout: TimeInterval = 10

    private let session: URLSession
    private let token: String

    init(session: URLSession? = nil, token: String) {
        self.token = token
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = Self.timeout
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: cfg)
        }
    }

    func call(messages: [[String: String]]) async throws -> String {
        var request = URLRequest(url: Self.routerURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "model": Self.model,
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 80,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw HFRouterError.timeout
        } catch {
            throw HFRouterError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HFRouterError.upstream(status: -1)
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw HFRouterError.invalidToken
        case 429:
            throw HFRouterError.rateLimited
        default:
            throw HFRouterError.upstream(status: http.statusCode)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw HFRouterError.unparseable
        }

        return content
    }
}
