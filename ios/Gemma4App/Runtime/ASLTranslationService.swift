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
            return "HF_TOKEN is not configured."
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

    private enum Backend {
        case remote(HFRouterClient)
        case local(any Gemma4TextToTextAdapter, model: String)
    }

    private let vocab: VocabIndex
    private let backend: Backend

    init(session: URLSession? = nil, bundle: Bundle = .main) throws {
        // Prefer runtime environment injection for local/dev security, then fallback to Info.plist.
        let envToken = (ProcessInfo.processInfo.environment[Self.tokenKey] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let plistToken = (bundle.object(forInfoDictionaryKey: Self.tokenKey) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawToken = envToken.isEmpty ? plistToken : envToken
        guard !rawToken.isEmpty else { throw ASLTranslationError.missingToken }

        do {
            self.vocab = try ASLVocab.load(bundle: bundle)
        } catch let e as ASLVocabError {
            throw ASLTranslationError.vocabUnavailable(e)
        }

        self.backend = .remote(HFRouterClient(session: session, token: rawToken))
    }

    init(
        localAdapter: any Gemma4TextToTextAdapter,
        model: String = "gemma-4-e2b-it-4bit",
        bundle: Bundle = .main
    ) throws {
        do {
            self.vocab = try ASLVocab.load(bundle: bundle)
        } catch let e as ASLVocabError {
            throw ASLTranslationError.vocabUnavailable(e)
        }

        self.backend = .local(localAdapter, model: model)
    }

    func translate(text: String) async throws -> ASLTranslationResponse {
        let raw: String
        switch backend {
        case .remote(let client):
            let messages = ASLGlossPrompt.messages(text: text, vocab: vocab)
            do {
                raw = try await client.call(messages: messages)
            } catch let e as HFRouterError {
                throw ASLTranslationError.router(e)
            }
        case .local(let adapter, _):
            let prompt = ASLGlossPrompt.plainPrompt(text: text, vocab: vocab)
            raw = try await adapter.generate(prompt: prompt)
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
            model: modelName
        )
    }

    private var modelName: String {
        switch backend {
        case .remote:
            return HFRouterClient.model
        case .local(_, let model):
            return model
        }
    }
}
