---
name: gemma4-text-rewriter
description: Rewrite, polish, shorten, expand, or restyle text with Gemma 4. Use when the user wants wording changes while preserving meaning. This skill uses `load_gemma4_text_to_text`.
---

# Gemma 4 Text Rewriter

Use this skill when the user wants better wording, a different tone, or a different length.

## Model

Load the model with `load_gemma4_text_to_text`.

## Workflow

1. Identify the transformation:
   - rewrite
   - shorten
   - expand
   - simplify
   - formalize
   - make more direct
2. Keep the original meaning unless the user explicitly asks to change content.
3. Preserve factual details, names, dates, URLs, code, and quoted text unless the user asks otherwise.
4. If the user gives no target tone, keep the tone close to the original but cleaner.

## Output rules

- Return only the rewritten text unless the user asks for alternatives.
- If multiple variants help, cap it at 3.
- For "fix grammar" requests, do not over-edit style.
- For "make it concise", cut repetition before cutting substance.

## Prompt pattern

Use a prompt shaped like:

```text
Rewrite the text below.
Target transformation: <requested transformation>
Constraints:
- Preserve meaning.
- Preserve concrete facts and entities.
- Match the requested tone and length.

Text:
<source text>
```
