# Gemma4 Hackathon Project

This repository is a monorepo containing multiple experiments and applications built around the Gemma 4 multimodal capabilities. It explores various form factors (iOS, Web) and use cases (Image understanding, ASL translation, Text extraction).

## Project Structure

The project is divided into three main components:

### 1. `ios/` - Gemma4 iOS ASL Learning App
A SwiftUI iPhone app for turning photos or typed English into beginner-friendly ASL learning outputs, with both internet-backed and offline Gemma-powered flows.
- **Goal:** Make ASL practice feel simple and visual by combining Gemma 4 multimodal understanding, ASL gloss generation, and playable sign-video results.
- **Current iOS capabilities:**
  - Photo-to-ASL flow from either the camera or photo library.
  - OCR-first recognition for visible text in an image, so signs/photos of words can be translated directly.
  - Multimodal image understanding fallback when the photo does not contain readable text.
  - Extraction of 1-5 simple ASL-friendly keywords from an image.
  - Text-to-ASL flow for typed words or full sentences.
  - ASL gloss generation for recognized or typed text.
  - Per-word sign lookup against Handspeak with automatic MP4 discovery from dictionary pages.
  - Local caching of downloaded ASL videos for smoother playback after lookup.
  - Sequential playback of sign clips with speed controls and word selection.
  - Fingerspelling fallback when an exact ASL clip is not available.
  - Category/tab UI when a photo contains multiple recognizable text regions.
  - Switchable translation modes:
    - `Better Signs`: internet-backed flow using hosted adapters plus Handspeak lookup.
    - `Offline`: on-device Gemma flow using the locally downloaded MLX model.
  - Offline model management in-app:
    - check install status
    - download the model
    - show progress while downloading
    - cancel downloads
    - delete the downloaded model from the device
  - Runtime safeguards for iOS memory pressure and multimodal inference limits.
  - Lazy runtime initialization so the app does not fully spin up the model at launch.
- **Main iOS areas:**
  - `ios/Gemma4App/UI/HomeView.swift` - top-level tabbed shell
  - `ios/Gemma4App/UI/CameraRecognitionView.swift` - photo-to-ASL experience
  - `ios/Gemma4App/UI/TextPlaceholderView.swift` - text-to-ASL experience
  - `ios/Gemma4App/UI/AppViewModel.swift` - shared app state and mode/model management
  - `ios/Gemma4App/Runtime/ImageRecognitionService.swift` - OCR, image analysis, keyword extraction, gloss prep
  - `ios/Gemma4App/Runtime/ASLVideoLookupService.swift` - Handspeak search, MP4 extraction, caching
  - `ios/Gemma4App/Runtime/EmbeddedGemma4Runtime.swift` - app-facing local runtime wrapper
- **Documentation:** See `ios/plan.md` for the broader architecture and `AGENTS.md` for the current repo-specific iOS debugging map.

### 2. `asl-sequence/` - ASL Translator Web App
A Next.js web application that translates written English sentences into American Sign Language (ASL) video sequences.
- **Goal:** Create a visual "Phrase Coach" for learning or practicing ASL sentences.
- **Features:**
  - Tokenizes input sentences and filters out non-essential filler words (like 'the', 'a').
  - Looks up each word dynamically against the Handspeak dictionary.
  - Scrapes the corresponding ASL demonstration MP4 video for each recognized word.
  - Provides a "Teaching loop" video player that stitches these videos together in sequence to perform the whole sentence.

### 3. `skills/` - Prompt Engineering & Capabilities
A collection of prompts, system instructions, and tool definitions specifically tuned for Gemma 4.
- `gemma4-image-chart-reader`: Extracting data and insights from charts.
- `gemma4-image-describer`: Generating rich descriptions of general images.
- `gemma4-image-ocr`: Specialized OCR extraction prompts.
- `gemma4-text-extractor`: Structured data extraction from raw text.
- `gemma4-text-rewriter`: Style and tone adjustment tools.
- `gemma4-text-summarizer`: Condensing large contexts.
- `phoneclaw-ios-swift-app-builder`: Agentic prompts for generating Swift UI code.

## Getting Started

- **For the iOS App:** Open `ios/Gemma4App/Gemma4App.xcodeproj` in Xcode (you may need to run `xcodegen` if it uses `project.yml`).
- **For the Web App:** Navigate to `asl-sequence/`, run `npm install`, and start the server with `npm run dev`.

### iOS HF Token Setup (`.xcconfig`, local only)

The iOS app's internet-backed `Better Signs` mode uses `HF_TOKEN` (Hugging Face token).
This repo is configured so your token stays local and is not committed.

1. Copy `ios/Configs/LocalSecrets.example.xcconfig` to `ios/Configs/LocalSecrets.xcconfig`.
2. Edit `ios/Configs/LocalSecrets.xcconfig`:
   - `HF_TOKEN = hf_your_token_here`
3. Regenerate the Xcode project after config changes:
   - `cd ios && xcodegen generate`
4. Build/run in Xcode.

Notes:
- `ios/Configs/LocalSecrets.xcconfig` is gitignored.
- `Info.plist` reads `HF_TOKEN` from build settings via `$(HF_TOKEN)`.
