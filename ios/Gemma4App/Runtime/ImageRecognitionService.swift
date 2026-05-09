import UIKit

struct ImageRecognitionService {
    private let adapterProvider: () -> any Gemma4ImageToTextAdapter

    init(
        adapterProvider: @escaping () -> any Gemma4ImageToTextAdapter = {
            Gemma4Loader.load_gemma4_image_to_text()
        }
    ) {
        self.adapterProvider = adapterProvider
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

        let adapter = adapterProvider()
        let response = try await adapter.generate(request: request)
        return response.text
    }
}
