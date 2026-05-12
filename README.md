# Gemma4 Hackathon Project

This repository is a monorepo containing multiple experiments and applications built around the Gemma 4 multimodal capabilities. It explores various form factors (iOS, Web) and use cases (Image understanding, ASL translation, Text extraction).

## Project Structure

The project is divided into three main components:

### 1. `ios/` - Gemma4 iOS Scaffold App
A lightweight iOS SwiftUI scaffold demonstrating how to integrate the `Gemma4Runtime` into a native iOS application.
- **Goal:** Provide a camera-first experience to run on-device or edge-based multimodal inference (like `Gemma 4 E2B/E4B`).
- **Features:** 
  - A camera capture flow for taking photos.
  - Image-to-text recognition integration to describe the content of the captured photo.
  - A clean abstraction layer (`Gemma4Adapter`, `Gemma4Loader`) for swapping in different model inference engines.
- **Documentation:** See `ios/plan.md` for architectural decisions and the scaffold plan.

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

The iOS ASL translation flow uses `HF_TOKEN` (Hugging Face token).  
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
