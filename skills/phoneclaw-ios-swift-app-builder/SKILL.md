---
name: phoneclaw-ios-swift-app-builder
description: Build or scaffold an iOS Swift app by reusing the real Gemma 4 and inference architecture from PhoneClaw. Use when the user wants SwiftUI app structure, Gemma 4 text or image inference, or a PhoneClaw-derived on-device AI app. Prefer wrapping PhoneClaw interfaces behind `load_gemma4_text_to_text` and `load_gemma4_image_to_text` rather than inventing a new runtime.
---

# PhoneClaw iOS Swift App Builder

Use this skill when the target is an iOS Swift app and `PhoneClaw` is the architectural reference.

## Source of truth

Read these files first:

- `/Users/tczhong/Documents/code/github/PhoneClaw/LLM/Core/InferenceService.swift`
- `/Users/tczhong/Documents/code/github/PhoneClaw/LLM/LLMEngine.swift`
- `/Users/tczhong/Documents/code/github/PhoneClaw/LLM/MLX/MLXLocalLLMService.swift`
- `/Users/tczhong/Documents/code/github/PhoneClaw/LLM/PromptBuilder.swift`

Then read [references/phoneclaw-runtime-map.md](references/phoneclaw-runtime-map.md).

## Architecture rule

Do not invent a parallel abstraction if `PhoneClaw` already has one.

Default mapping:

- text-only generation: wrap `InferenceService.generate(prompt:)`
- image + text generation: wrap `InferenceService.generateMultimodal(prompt:images:audios:)`
- raw text + optional image path: wrap `InferenceService.generateRaw(text:images:)`

If the user explicitly wants helpers named `load_gemma4_text_to_text` and `load_gemma4_image_to_text`, implement them as thin wrappers that return adapters over the real `PhoneClaw` backend.

## Wrapper rule

If a project wants these entrypoints:

- `load_gemma4_text_to_text`
- `load_gemma4_image_to_text`

implement them as loader or factory methods that internally construct or reuse a `PhoneClaw`-style inference backend. Do not duplicate model-loading logic from scratch unless the target app cannot depend on the original runtime.

## Preferred app shape

1. SwiftUI app shell
2. View model on `@MainActor`
3. Thin inference adapter over `InferenceService`
4. Prompt routing layer
5. Optional skill loader that reads local `SKILL.md` files

## Prompting rule

Reuse `PhoneClaw` prompt-building ideas:

- keep system prompts short in multimodal paths
- separate text-only and multimodal routes
- avoid inventing image details
- keep routing deterministic when the task is obvious

## When to use which backend path

- plain chat, rewrite, summarize, extract: text-only path
- OCR, screenshot analysis, chart reading, scene description: multimodal path
- exact prompt control without chat templating: raw path

## Output requirements

When generating app code:

- prefer SwiftUI
- keep the inference boundary small
- isolate `PhoneClaw`-derived code from UI code
- expose one clear async API per task
- do not claim cloud inference if the design is on-device

## Failure mode rules

- If `PhoneClaw` has no exact API for the requested shape, adapt the nearest real interface and say so in code comments.
- If the target app has no access to MLX or LiteRT yet, first scaffold protocols and adapters, then leave one explicit integration seam.
- Do not write fake model code that pretends to run inference.
