---
name: gemma4-text-extractor
description: Extract structured fields, entities, dates, tasks, decisions, or JSON-ready records from text with Gemma 4. Use when the user wants information pulled out in a stable schema. This skill uses `load_gemma4_text_to_text`.
---

# Gemma 4 Text Extractor

Use this skill when the output should be structured rather than free-form.

## Model

Load the model with `load_gemma4_text_to_text`.

## Workflow

1. Define the target schema before prompting the model.
2. Ask for only fields the user requested.
3. If a field is missing in the source, emit `null`, empty string, or empty array consistently.
4. Prefer deterministic output:
   - JSON
   - table
   - flat bullets
5. If the source is noisy, normalize formatting after extraction.

## Output rules

- Never fabricate missing values.
- Preserve exact strings for names, dates, amounts, emails, phone numbers, and IDs when present.
- If confidence is low, include a brief uncertainty note only if the user asked for reliability or review.
- When JSON is requested, return valid JSON and nothing else.

## Prompt pattern

Use a prompt shaped like:

```text
Extract structured information from the text below.
Schema:
<explicit field list or JSON schema>

Rules:
- Use only information present in the source.
- Leave missing fields as null.
- Preserve exact values when possible.

Text:
<source text>
```
