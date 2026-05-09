import UIKit

struct Gemma4ImageToTextRequest {
    let prompt: String
    let image: UIImage
}

struct Gemma4ImageToTextResponse {
    let text: String
}

protocol Gemma4ImageToTextAdapter {
    func generate(request: Gemma4ImageToTextRequest) async throws -> Gemma4ImageToTextResponse
}

protocol Gemma4TextToTextAdapter {
    func generate(prompt: String) async throws -> String
}

enum Gemma4AdapterError: LocalizedError {
    case modelNotInstalled
    case imageConversionFailed
    case imageAnalysisFailed
    case noVisualContent
    case runtimeUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled:
            return "模型当前不可用。请先确认内置模型存在，或等待下载完成。"
        case .imageConversionFailed:
            return "图片预处理失败。"
        case .imageAnalysisFailed:
            return "图片分析失败。"
        case .noVisualContent:
            return "没有识别到足够清晰的图片内容。请换个角度或更近一点再拍。"
        case .runtimeUnavailable(let message):
            return message
        }
    }
}
