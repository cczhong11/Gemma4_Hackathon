import Foundation
import UIKit

private enum HFAdapterConfig {
    static let tokenKey = "HF_TOKEN"
}

enum HFAdapterError: LocalizedError {
    case missingToken
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "HF_TOKEN is not configured."
        case .imageEncodingFailed:
            return "Failed to encode image for Hugging Face request."
        }
    }
}

private func resolveHFToken(bundle: Bundle = .main) -> String? {
    let envToken = (ProcessInfo.processInfo.environment[HFAdapterConfig.tokenKey] ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if !envToken.isEmpty { return envToken }

    let plistToken = (bundle.object(forInfoDictionaryKey: HFAdapterConfig.tokenKey) as? String ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return plistToken.isEmpty ? nil : plistToken
}

struct HFImageToTextAdapter: Gemma4ImageToTextAdapter {
    private let client: HFRouterClient

    init(session: URLSession? = nil, bundle: Bundle = .main) throws {
        guard let token = resolveHFToken(bundle: bundle) else {
            throw HFAdapterError.missingToken
        }
        self.client = HFRouterClient(session: session, token: token)
    }

    func generate(request: Gemma4ImageToTextRequest) async throws -> Gemma4ImageToTextResponse {
        guard let jpeg = request.image.jpegData(compressionQuality: 0.8) else {
            throw HFAdapterError.imageEncodingFailed
        }
        let base64 = jpeg.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"

        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": request.prompt,
                    ],
                    [
                        "type": "image_url",
                        "image_url": ["url": dataURL],
                    ],
                ],
            ]
        ]

        let content = try await client.call(messages: messages)
        return Gemma4ImageToTextResponse(text: content.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct HFTextToTextAdapter: Gemma4TextToTextAdapter {
    private let client: HFRouterClient

    init(session: URLSession? = nil, bundle: Bundle = .main) throws {
        guard let token = resolveHFToken(bundle: bundle) else {
            throw HFAdapterError.missingToken
        }
        self.client = HFRouterClient(session: session, token: token)
    }

    func generate(prompt: String) async throws -> String {
        let messages = [["role": "user", "content": prompt]]
        let content = try await client.call(messages: messages)
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
