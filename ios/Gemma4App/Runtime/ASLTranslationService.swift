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
    case missingToken
    case vocabUnavailable(ASLVocabError)
    case router(HFRouterError)
    case unparseableGloss

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "HF_TOKEN is not configured in Info.plist."
        case .vocabUnavailable(.missingResource):
            return "signs.txt is missing from the app bundle."
        case .vocabUnavailable(.emptyFile):
            return "signs.txt is empty after filtering."
        case .router(let inner):
            return inner.errorDescription
        case .unparseableGloss:
            return "Model returned no usable gloss."
        }
    }
}

struct ASLTranslationService {
    private static let tokenKey = "HF_TOKEN"

    private let vocab: VocabIndex
    private let client: HFRouterClient

    init(session: URLSession? = nil, bundle: Bundle = .main) throws {
        let rawToken = (bundle.object(forInfoDictionaryKey: Self.tokenKey) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawToken.isEmpty else { throw ASLTranslationError.missingToken }

        do {
            self.vocab = try ASLVocab.load(bundle: bundle)
        } catch let e as ASLVocabError {
            throw ASLTranslationError.vocabUnavailable(e)
        }

        self.client = HFRouterClient(session: session, token: rawToken)
    }

    func translate(text: String) async throws -> ASLTranslationResponse {
        let messages = ASLGlossPrompt.messages(text: text, vocab: vocab)

        let raw: String
        do {
            raw = try await client.call(messages: messages)
        } catch let e as HFRouterError {
            throw ASLTranslationError.router(e)
        }

        let processed: ProcessedGloss
        do {
            processed = try ASLGlossPostprocess.process(rawModelOutput: raw, vocab: vocab)
        } catch {
            throw ASLTranslationError.unparseableGloss
        }

        return ASLTranslationResponse(
            gloss: processed.gloss,
            tokens: processed.tokens,
            unknownTokens: processed.unknownTokens,
            isQuestion: processed.isQuestion,
            model: HFRouterClient.model
        )
    }
}
