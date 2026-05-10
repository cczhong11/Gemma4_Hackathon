# Gemma4 Repo Agent Notes

This file is the working map for future development in this repository.

It focuses on the iOS app under `ios/`, because that is where the current
runtime, memory, packaging, and UI debugging happened.

## Repo Layout

- `ios/`
  - Main iOS app and vendored runtime.
- `skills/`
  - Project-local skills, including iOS/MLX/Jetsam notes.
- `asl-sequence/`
  - Separate app/project. Not part of the current iOS Gemma runtime work.

## Main iOS Entry Points

- App entry:
  - `ios/Gemma4App/App/Gemma4App.swift`
- Home screen:
  - `ios/Gemma4App/UI/HomeView.swift`
- Camera/image recognition screen:
  - `ios/Gemma4App/UI/CameraRecognitionView.swift`
- Camera/photo picker bridge:
  - `ios/Gemma4App/UI/CameraImagePicker.swift`
- View model:
  - `ios/Gemma4App/UI/AppViewModel.swift`
- Runtime adapter:
  - `ios/Gemma4App/Runtime/EmbeddedGemma4Runtime.swift`
- Feature service:
  - `ios/Gemma4App/Runtime/ImageRecognitionService.swift`
- ASL video lookup service:
  - `ios/Gemma4App/Runtime/ASLVideoLookupService.swift`

## Runtime / Model Code Map

- Main MLX runtime service:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/MLXLocalLLMService.swift`
- Install-state bookkeeping:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Installation/ModelInstaller.swift`
- Model path resolution:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Installation/ModelPaths.swift`
- Model download flow:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Installation/ModelDownloader.swift`
- Runtime memory budgets:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Core/RuntimeBudgets.swift`
- Per-model runtime profiles:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Core/BundledModel.swift`
- Memory stats / jetsam helpers:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Core/MemoryStats.swift`
- Gemma 4 processor / multimodal path:
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Gemma4/Gemma4Processor.swift`
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Gemma4/Gemma4VisionModel.swift`
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Gemma4/Gemma4LanguageModel.swift`
  - `ios/Vendor/Gemma4Runtime/LLM/MLX/Gemma4/Gemma4Model.swift`

## Vendored MLX / InferenceKit Code We Changed

- Eager model materialization:
  - `ios/Vendor/InferenceKit/Libraries/MLXLMCommon/Load.swift`
- Underlying package manifest:
  - `ios/Vendor/InferenceKit/Package.swift`
- Vendored MLX docs on iOS memory:
  - `ios/Vendor/mlx-swift/Source/MLX/Documentation.docc/Articles/running-on-ios.md`

## Project Config Files

- Xcode project:
  - `ios/Gemma4App.xcodeproj/project.pbxproj`
- XcodeGen source:
  - `ios/project.yml`
- iOS entitlements:
  - `ios/Gemma4App/Gemma4App.entitlements`
- Models README:
  - `ios/Models/README.md`

## Local Skills Relevant To This Repo

- iOS MLX / jetsam debugging skill:
  - `skills/ios-mlx-jetsam-debug/SKILL.md`
- Skill references:
  - `skills/ios-mlx-jetsam-debug/references/log-patterns.md`
  - `skills/ios-mlx-jetsam-debug/references/entitlements.md`
- Existing PhoneClaw builder skill:
  - `skills/phoneclaw-ios-swift-app-builder/SKILL.md`

## Architecture Summary

The app uses:

- SwiftUI UI
- `AppViewModel` as the main UI state holder
- `EmbeddedGemma4Runtime` as the app-facing runtime wrapper
- `MLXLocalLLMService` as the real MLX runtime
- Vendored `InferenceKit` / `mlx-swift` for model loading and inference

The default model ID is:

- `gemma-4-e2b-it-4bit`

The app currently supports:

- image recognition from camera / photo library
- extracting 1-5 English learning keywords from a recognized image
- looking up ASL sign videos on Handspeak and caching MP4s locally
- model status and model downloading
- local MLX multimodal inference

## ASL Learning Flow

Current photo-to-ASL flow:

1. User captures or selects a photo in `CameraRecognitionView`.
2. `AppViewModel.recognizeCapturedImage()` calls `ImageRecognitionService.analyze(image:)`.
3. Gemma returns:
   - `Description: ...`
   - `Keywords: word1, word2, ...`
4. `ImageRecognitionService` parses the response and falls back to text-only keyword extraction if the image response format is loose.
5. `AppViewModel` sends those keywords to `ASLVideoLookupService`.
6. `ASLVideoLookupService`:
   - queries Handspeak search JSON
   - chooses the best dictionary entry
   - fetches the word page HTML
   - extracts all MP4 candidates from `<video ... src="...mp4">`
   - downloads the first valid MP4 to local cache
7. `CameraRecognitionView` renders the suggested keywords plus one video card per result.

Main files:

- UI:
  - `ios/Gemma4App/UI/CameraRecognitionView.swift`
- View model:
  - `ios/Gemma4App/UI/AppViewModel.swift`
- Image analysis / keyword extraction:
  - `ios/Gemma4App/Runtime/ImageRecognitionService.swift`
- Handspeak search / MP4 caching:
  - `ios/Gemma4App/Runtime/ASLVideoLookupService.swift`

## Important Lessons Learned

### 1. Startup slowness was not model weights loading

The big startup freeze came from eager runtime/service initialization and model
status filesystem checks, not from loading the full model into memory at launch.

Key fixes:

- `AppViewModel` now uses lazy runtime/service creation.
- Home screen uses lightweight local file checks first.
- Full runtime initialization happens only when needed.

Relevant files:

- `ios/Gemma4App/UI/AppViewModel.swift`
- `ios/Gemma4App/Runtime/ImageRecognitionService.swift`

### 2. Jetsam limit, not physical RAM, is the real memory ceiling

On device, physical RAM was around 11.7 GB, but process jetsam limit was about
3.3 GB. That process limit is what matters.

Meaning:

- You cannot reason from device RAM alone.
- A 3.0 GB loaded model can still be unsafe on a 12 GB phone.

### 3. First inference spikes can be worse than steady-state load

Originally, the model was lazily materialized on first inference. That stacked:

- weight materialization
- Metal / shader warmup
- vision encode
- text prefill / decode

This caused the worst spikes.

We changed `Load.swift` to eagerly evaluate the model during `load()`.

Relevant file:

- `ios/Vendor/InferenceKit/Libraries/MLXLMCommon/Load.swift`

### 4. Multimodal needs separate safety limits

We tightened E2B multimodal memory budgets in:

- `ios/Vendor/Gemma4Runtime/LLM/MLX/Core/BundledModel.swift`

We also added multimodal safety controls in:

- `ios/Vendor/Gemma4Runtime/LLM/MLX/MLXLocalLLMService.swift`

Those changes include:

- smaller image soft-token caps
- critical headroom checks
- runtime headroom floors
- lower multimodal output caps
- fixed `maxKVSize` for multimodal generation

### 5. Installation speed can be misleading if DerivedData is dirty

We saw a case where the source `ios/Models/` folder looked empty, but the built
`.app` still contained:

- `Models/gemma-4-e2b-it-4bit/model.safetensors` at about 3.3 GB

The cause was stale build output in `DerivedData`, not current source state.

If installation suddenly becomes extremely slow again:

1. inspect the built `.app` size
2. inspect whether `.app/Models/` exists
3. clean build products / DerivedData if needed

### 6. Bundle-vs-Documents model source matters

There are two model locations:

- bundled:
  - `Bundle.main.resourceURL/.../Models/<model>`
- downloaded:
  - `Documents/models/<model>`

The app should prefer a complete downloaded model in `Documents` over a bundled
copy. Otherwise old bundled leftovers can shadow the downloaded model.

This priority logic is handled in:

- `ios/Vendor/Gemma4Runtime/LLM/MLX/Installation/ModelPaths.swift`

### 7. UI state could become self-contradictory

We saw a bad state where the UI showed:

- status: bundled
- missing files: all files missing

That came from mixing:

- install-state from bundled path
- missing-file checks against downloaded path

`AppViewModel` local snapshot logic was updated so missing files are only shown
for the actually relevant unresolved case.

Relevant file:

- `ios/Gemma4App/UI/AppViewModel.swift`

### 8. Root UI black borders were likely tied to app-level plist config

PhoneClaw has:

- `UILaunchScreen`
- `UISupportedInterfaceOrientations`

Our generated app initially did not. Build warnings matched this.

We aligned project settings in:

- `ios/project.yml`
- `ios/Gemma4App.xcodeproj/project.pbxproj`

Also added stronger root sizing/layout guards in:

- `ios/Gemma4App/UI/HomeView.swift`
- `ios/Gemma4App/UI/CameraRecognitionView.swift`

If the floating white-card / black-border issue returns, inspect generated
`Gemma4App.app/Info.plist` first before assuming a SwiftUI layout bug.

### 9. Handspeak playback is more reliable from cached local files than direct remote playback

Handspeak MP4s are discoverable from the dictionary page HTML, but the flow is
not just "guess a URL and stream it".

What proved reliable:

- query `https://www.handspeak.com/word/app/search-dict.php?q=<word>`
- open the returned word page
- parse actual MP4 candidates from the HTML
- send browser-like headers
- include the word page as `Referer`
- cache the MP4 into `Caches/HandspeakVideos/`
- play the local file in SwiftUI

This logic lives in:

- `ios/Gemma4App/Runtime/ASLVideoLookupService.swift`

Practical implication:

- if Handspeak starts failing, inspect search JSON, extracted candidate URLs,
  response status codes, and whether the local cache file was written before
  touching the UI.

### 10. Keyword extraction is intentionally constrained to simple English dictionary words

The ASL lookup works best when the model returns:

- 1-5 keywords
- lowercase English
- simple concrete nouns or actions
- no names or long phrases

This is enforced in the multimodal prompt and then normalized again in code.
If Gemma drifts, the service falls back to a text-only prompt that extracts
dictionary-friendly words from the description.

Relevant file:

- `ios/Gemma4App/Runtime/ImageRecognitionService.swift`

## Current Model Path Rules

Current intent:

1. Prefer `Documents/models/<model>` if complete.
2. Otherwise fall back to bundled `Models/<model>`.
3. Resolve symlinks before using the final path.

Code:

- `ios/Vendor/Gemma4Runtime/LLM/MLX/Installation/ModelPaths.swift`

## Current Entitlement Setup

The project now includes:

- `com.apple.developer.kernel.increased-memory-limit`

Files:

- `ios/Gemma4App/Gemma4App.entitlements`
- `ios/project.yml`
- `ios/Gemma4App.xcodeproj/project.pbxproj`

Important:

- Xcode/project config is only one half.
- Apple Developer capability support still determines whether it truly applies.

## PhoneClaw Reference Paths

Reference repo:

- `/Users/tczhong/Documents/code/github/PhoneClaw`

Most important files:

- app entry:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/App/PhoneClawApp.swift`
- main UI:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/UI/ContentView.swift`
- runtime:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/LLM/MLX/MLXLocalLLMService.swift`
- runtime profiles:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/LLM/MLX/Core/BundledModel.swift`
- memory stats:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/LLM/MLX/Core/MemoryStats.swift`
- iOS memory doc:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/Packages/mlx-swift/Source/MLX/Documentation.docc/Articles/running-on-ios.md`
- entitlements:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/PhoneClaw.entitlements`
- app plist:
  - `/Users/tczhong/Documents/code/github/PhoneClaw/Info.plist`

Important conclusion from comparing PhoneClaw:

- It does use increased-memory entitlement.
- It does not have a magical hidden runtime fix that makes first inference safe.
- It still needed careful budgeting and device-specific tuning.

## Debugging Checklist For Future Work

When debugging model issues, always collect:

- `[MEM] Before load`
- `[MEM] After load`
- `[MEM] generateStream start`
- `[VLM] image prompt prepared`
- `[VLM] vision encoded`
- current `resolvedPath`
- current install state

Then classify:

- startup freeze
- lazy-load spike
- model too large at steady state
- vision spike
- generation/KV spike

Use the local skill:

- `skills/ios-mlx-jetsam-debug/SKILL.md`

When debugging the ASL lookup flow, collect:

- the model's raw `Description:` / `Keywords:` output
- parsed keyword list after normalization
- Handspeak search URL
- chosen word page URL
- extracted MP4 candidate URLs
- first MP4 response status / content type
- cached local video path

Then classify:

- poor keyword choice from Gemma
- parse/normalization issue
- Handspeak search miss
- no MP4 on page
- MP4 download/header issue
- local playback/UI issue

## Known Good Commands

Build simulator:

```bash
xcodebuild -project /Users/tczhong/Documents/code/hackathon/Gemma4/ios/Gemma4App.xcodeproj -scheme Gemma4App -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Build generic iOS device artifact:

```bash
xcodebuild -project /Users/tczhong/Documents/code/hackathon/Gemma4/ios/Gemma4App.xcodeproj -scheme Gemma4App -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

Inspect built app size:

```bash
du -sh ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphoneos/Gemma4App.app
```

Inspect whether bundled `Models/` still exists:

```bash
find ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphoneos/Gemma4App.app -path '*/Models/*'
```

## Current In-Progress / Recently Changed Files

At the time this file was written, recent important edits include:

- `ios/Gemma4App/UI/HomeView.swift`
- `ios/Gemma4App/UI/CameraRecognitionView.swift`
- `ios/Gemma4App/UI/AppViewModel.swift`
- `ios/Gemma4App/Runtime/ImageRecognitionService.swift`
- `ios/Gemma4App/Runtime/ASLVideoLookupService.swift`
- `ios/Gemma4App/Runtime/EmbeddedGemma4Runtime.swift`
- `ios/Vendor/Gemma4Runtime/LLM/MLX/Installation/ModelPaths.swift`
- `ios/Vendor/Gemma4Runtime/LLM/MLX/Installation/ModelInstaller.swift`
- `ios/Vendor/Gemma4Runtime/LLM/MLX/Core/BundledModel.swift`
- `ios/Vendor/Gemma4Runtime/LLM/MLX/MLXLocalLLMService.swift`
- `ios/Vendor/InferenceKit/Libraries/MLXLMCommon/Load.swift`
- `ios/Gemma4App/Gemma4App.entitlements`
- `ios/project.yml`
- `ios/Gemma4App.xcodeproj/project.pbxproj`

## Practical Rules For The Next Agent

- Do not assume physical RAM means the model is safe on-device.
- Do not assume bundle models are desired just because they exist.
- Prefer `Documents` models when complete.
- Verify built `.app` contents whenever install speed changes unexpectedly.
- Treat `Info.plist` warnings as potentially user-visible runtime bugs, not just
  packaging noise.
- If UI looks like a floating card inside black borders, inspect app-level plist
  and display mode before over-editing SwiftUI layout.
- If multimodal crashes, inspect logs before shrinking the model blindly.
- If the app becomes slow on launch again, re-check for accidental eager runtime
  initialization in `AppViewModel` and related services.
- If sign lookup breaks, debug the Handspeak fetch/caching flow before assuming
  the video player is the root cause.
- If ASL keyword quality gets worse, inspect the raw model output before
  changing Handspeak matching logic.
