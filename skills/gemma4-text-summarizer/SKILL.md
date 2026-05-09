---
name: gemma4-text-summarizer
description: Summarize long text, notes, transcripts, or articles with Gemma 4. Use when the user wants a concise summary, bullets, takeaways, or action items from text input. This skill uses `load_gemma4_text_to_text`.
---

# Gemma 4 Text Summarizer

Use this skill when the task is compressing text without losing key meaning.

## Model

Load the model with `load_gemma4_text_to_text`.

## Workflow

1. Read the user text or the referenced file content.
2. Preserve the original language unless the user asks for another one.
3. Pick the shortest output shape that satisfies the request:
   - paragraph summary
   - bullet summary
   - key takeaways
   - action items
4. Instruct Gemma 4 to stay grounded in the source text and not add facts.
5. If the source is very long, chunk it, summarize chunks, then merge into a final summary.

## Output rules

- Do not mention the model unless the user asks.
- Do not add filler like "Here is the summary".
- If the source is ambiguous or incomplete, say so briefly instead of guessing.
- If action items are requested, only include actions supported by the text.

## Prompt pattern

Use a prompt shaped like:

```text
Summarize the following text.
Goal: <requested format>
Constraints:
- Stay faithful to the source.
- Preserve important names, numbers, dates, and decisions.
- Do not invent missing details.

Text:
<source text>
```
