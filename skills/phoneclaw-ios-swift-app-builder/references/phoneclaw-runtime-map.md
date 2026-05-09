# PhoneClaw Runtime Map

This reference is intentionally short. Load it when building an iOS Swift app from `PhoneClaw`.

## Core interfaces

`LLM/Core/InferenceService.swift`

- Main backend-facing protocol.
- Text path: `generate(prompt:)`
- Multimodal path: `generateMultimodal(prompt:images:audios:)`
- Raw path: `generateRaw(text:images:)`
- Returns `AsyncThrowingStream<String, Error>`.

`LLM/LLMEngine.swift`

- Thin inference engine abstraction.
- Confirms the codebase expects streaming token output rather than only one-shot strings.

## MLX backend

`LLM/MLX/MLXLocalLLMService.swift`

- Real local Gemma 4 service in PhoneClaw.
- Registers Gemma 4 with `Gemma4Registration.register()`.
- Uses `generate(prompt:)` for text.
- Uses `generateMultimodal(prompt:images:audios:)` for image-aware requests.
- Uses `generateRaw(text:images:)` when exact raw prompt control is needed.

## Prompting

`LLM/PromptBuilder.swift`

- Multimodal prompts are deliberately lighter than text prompts.
- Image follow-up behavior is handled explicitly.
- Prompt structure is treated as a performance and correctness concern, not just copywriting.

## Practical adapter pattern

If a new app wants names like:

- `load_gemma4_text_to_text`
- `load_gemma4_image_to_text`

map them like this:

- `load_gemma4_text_to_text` -> create or return an adapter backed by `InferenceService.generate(prompt:)`
- `load_gemma4_image_to_text` -> create or return an adapter backed by `InferenceService.generateMultimodal(prompt:images:audios:)`

The wrapper should translate from app-friendly request structs into the real `PhoneClaw` call shape. The wrapper should not reimplement tokenizer, processor, or model registration logic unless the app is intentionally forking the runtime.
