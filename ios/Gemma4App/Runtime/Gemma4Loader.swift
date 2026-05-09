enum Gemma4Loader {
    private static let runtime = EmbeddedGemma4Runtime()

    static func load_gemma4_image_to_text() -> any Gemma4ImageToTextAdapter {
        EmbeddedGemma4ImageToTextAdapter(runtime: runtime)
    }

    static func load_gemma4_text_to_text() -> any Gemma4TextToTextAdapter {
        EmbeddedGemma4TextToTextAdapter(runtime: runtime)
    }

    static func sharedRuntime() -> EmbeddedGemma4Runtime {
        runtime
    }
}
