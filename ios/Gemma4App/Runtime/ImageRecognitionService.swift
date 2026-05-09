import UIKit

struct ImageRecognitionService {
    private let adapter: any Gemma4ImageToTextAdapter

    init(adapter: (any Gemma4ImageToTextAdapter)? = nil) {
        self.adapter = adapter ?? Gemma4Loader.load_gemma4_image_to_text()
    }

    func describe(image: UIImage) async throws -> String {
        let request = Gemma4ImageToTextRequest(
            prompt: """
            Describe what is visible in this photo.
            Be concrete and concise.
            If text is visible, include it.
            If something is unclear, say it is unclear.
            """,
            image: image
        )

        let response = try await adapter.generate(request: request)
        return response.text
    }
}
