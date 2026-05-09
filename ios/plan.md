# iOS Scaffold Plan

## Goal

Create a very small iOS SwiftUI scaffold in `../ios/` with only the first-screen flow defined clearly:

- home page with 2 buttons
- button 1: photo recognition
- button 2: text features placeholder

For now, only implement the photo recognition path.

## Product shape

### Home page

Show exactly 2 primary actions:

1. `拍照识别`
2. `文字功能`

Current scope:

- `拍照识别`: implemented
- `文字功能`: placeholder only

### Photo recognition flow

1. User taps `拍照识别`
2. App enters a camera page
3. User takes a photo
4. App sends the image to the image-to-text model path
5. App shows the result as "the model looked at the image and described what is inside"

## Source of truth

Use `Gemma4Runtime` as the runtime reference:

- `/Users/tczhong/Documents/code/github/Gemma4Runtime/LLM/Core/InferenceService.swift`
- `/Users/tczhong/Documents/code/github/Gemma4Runtime/LLM/LLMEngine.swift`
- `/Users/tczhong/Documents/code/github/Gemma4Runtime/LLM/MLX/MLXLocalLLMService.swift`
- `/Users/tczhong/Documents/code/github/Gemma4Runtime/LLM/PromptBuilder.swift`

## Runtime mapping

Only one real model path is needed in this scaffold:

- `load_gemma4_image_to_text`
  - mapped to a `Gemma4Runtime`-style multimodal backend
  - conceptually aligned with `InferenceService.generateMultimodal(prompt:images:audios:)`

Text path is deferred:

- `load_gemma4_text_to_text`
  - not used yet by the UI

## Proposed scaffold

```text
ios/
├── plan.md
└── Gemma4App/
    ├── App/
    │   └── Gemma4App.swift
    ├── UI/
    │   ├── HomeView.swift
    │   ├── CameraRecognitionView.swift
    │   ├── TextPlaceholderView.swift
    │   ├── CameraImagePicker.swift
    │   └── AppViewModel.swift
    └── Runtime/
        ├── Gemma4Loader.swift
        ├── Gemma4Adapter.swift
        └── ImageRecognitionService.swift
```

## File responsibilities

### `Gemma4App.swift`

- app entry
- open the home page

### `HomeView.swift`

- show only 2 buttons
- route to:
  - camera recognition page
  - text placeholder page

### `CameraRecognitionView.swift`

- open camera
- preview selected photo
- trigger image recognition
- render output, loading state, and failure state

### `TextPlaceholderView.swift`

- simple placeholder
- no actual text flow yet

### `CameraImagePicker.swift`

- UIKit bridge for camera capture
- return captured image to SwiftUI

### `AppViewModel.swift`

- store:
  - captured image
  - recognition result
  - loading state
  - error message
- call the image recognition service

### `Gemma4Loader.swift`

- define app-facing model loaders
- expose:
  - `load_gemma4_image_to_text`
  - `load_gemma4_text_to_text`
- keep the boundary small and replaceable

### `Gemma4Adapter.swift`

- define the image-to-text protocol
- define request and response types
- provide a clear seam for later `Gemma4Runtime` integration

### `ImageRecognitionService.swift`

- build the image prompt
- call the image-to-text adapter
- return a plain text description of what is visible in the photo

## Prompt rule

Keep the image prompt compact and grounded:

- ask what is visible in the image
- avoid over-inference
- do not ask the model to guess hidden details

Example prompt shape:

```text
Describe what is visible in this photo.
Be concrete and concise.
If text is visible, include it.
If something is unclear, say it is unclear.
```

## Implementation rules

- Prefer SwiftUI.
- Keep the first version narrow.
- Do not add the text feature flow yet.
- Do not reimplement `Gemma4Runtime` internals in the scaffold.
- If backend integration is not wired yet, make that explicit in the adapter layer instead of pretending inference works.

## Order of work

1. Create the app folders.
2. Add runtime protocols and loader functions.
3. Add the photo recognition service.
4. Add the home page and camera page.
5. Add the text placeholder page.

## Done when

- home page has exactly 2 buttons
- photo recognition page can capture an image
- the view model sends the image through the image-to-text boundary
- the UI can show result, loading, and error states
- text feature remains a placeholder
