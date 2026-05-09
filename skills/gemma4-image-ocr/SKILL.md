---
name: gemma4-image-ocr
description: Read and extract text from images, documents, whiteboards, slides, receipts, or screenshots with Gemma 4. Use when the user wants transcription or text-first extraction from an image. This skill uses `load_gemma4_image_to_text`.
---

# Gemma 4 Image OCR

Use this skill when text inside the image matters more than scene description.

## Model

Load the model with `load_gemma4_image_to_text`.

## Workflow

1. Treat the image as a text extraction task first.
2. Preserve line breaks and ordering when they matter.
3. If the user asks for cleanup, do extraction first, then normalize formatting.
4. If parts are unreadable, mark them with `[unclear]` instead of guessing.

## Output rules

- Return plain transcription unless the user asks for parsing or summary.
- Keep numbers, dates, totals, URLs, and codes exact.
- If the image mixes UI and text, ignore non-text details unless they affect interpretation.
- For tables, use markdown table format only when the layout is readable.

## Prompt pattern

Use a prompt shaped like:

```text
Extract the text from this image.
Rules:
- Preserve exact wording where legible.
- Mark unreadable spans as [unclear].
- Do not infer missing text.
```
