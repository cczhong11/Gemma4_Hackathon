---
name: gemma4-image-describer
description: Describe photos, screenshots, scenes, diagrams, or UI states from an image with Gemma 4. Use when the user wants grounded visual understanding. This skill uses `load_gemma4_image_to_text`.
---

# Gemma 4 Image Describer

Use this skill for general image understanding.

## Model

Load the model with `load_gemma4_image_to_text`.

## Workflow

1. Inspect the user image.
2. Determine the task:
   - general description
   - screenshot explanation
   - scene understanding
   - object identification
   - UI state summary
3. Answer only from visible evidence.
4. If the request asks for something not visible, say it is not visible instead of inferring.

## Output rules

- Lead with the most relevant visible answer.
- Mention uncertainty when the image is blurry, cropped, or obstructed.
- For screenshots, prioritize text, layout, and state over aesthetic description.
- For UI debugging, mention visible controls, errors, disabled states, and missing content.

## Prompt pattern

Use a prompt shaped like:

```text
Analyze this image.
Task: <user request>
Rules:
- Base the answer only on visible evidence.
- Call out uncertainty when details are unclear.
- Be concise and direct.
```
