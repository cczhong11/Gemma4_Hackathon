---
name: gemma4-image-chart-reader
description: Read charts, graphs, dashboards, and plotted figures from images with Gemma 4. Use when the user wants trends, comparisons, labels, or chart takeaways grounded in the visual. This skill uses `load_gemma4_image_to_text`.
---

# Gemma 4 Chart Reader

Use this skill for visualized data in screenshots or images.

## Model

Load the model with `load_gemma4_image_to_text`.

## Workflow

1. Identify the chart type if possible.
2. Read visible labels, legends, axes, units, and time ranges first.
3. Describe trends and comparisons only if they are visually supported.
4. Separate observed facts from interpretation.
5. If exact values are unreadable, provide approximate language instead of fake precision.

## Output rules

- Prefer this order:
  1. what chart it is
  2. main trend
  3. important comparisons or outliers
  4. caveats
- Do not invent hidden data points.
- If the chart is too blurry, say what can still be read.
- When the user asks for business insight, ground every conclusion in visible evidence.

## Prompt pattern

Use a prompt shaped like:

```text
Analyze this chart image.
Task: <user request>
Rules:
- Read labels and axes before interpreting.
- Distinguish visible facts from inference.
- Avoid fake precision when values are unclear.
```
