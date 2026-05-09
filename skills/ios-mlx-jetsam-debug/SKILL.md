---
name: ios-mlx-jetsam-debug
description: Debug high memory use, jetsam kills, and slow first inference in iOS apps that run MLX or other on-device multimodal models. Use when an iPhone app is terminated for memory, shows code 9 / jetsam, stalls on startup, or needs guidance on runtime budgets, eager vs lazy model load, and increased memory limit entitlement.
---

# iOS MLX Jetsam Debug

Use this skill when an iOS app is being killed by the OS for memory pressure, especially with MLX, Metal, multimodal vision models, or first-inference spikes.

## Goals

1. Identify whether the failure is caused by startup work, model load, vision encode, or generation.
2. Reduce memory spikes before changing models.
3. Confirm whether process limits, not physical RAM, are the real bottleneck.
4. Apply entitlement-based headroom increases when supported.

## Fast Workflow

1. Confirm whether the user is seeing a real jetsam symptom:
   `Signal 9`, `Code 11` in `IDEDebugSessionErrorDomain`, or "terminated due to memory issue".
2. Collect app logs around these checkpoints:
   `[MEM] Before load`
   `[MEM] After load`
   `[MEM] generateStream start`
   `[VLM] image prompt prepared`
   `[VLM] vision encoded`
3. Classify the failure:
   - Startup freeze before inference: likely synchronous file scan, cleanup, or runtime init on main thread.
   - `After load` still small, then crash on first inference: likely lazy weight materialization + Metal/JIT + inference spike.
   - `After load` already close to jetsam: model residency itself is too large for the process limit.
   - Reaches generation, then dies after many tokens: KV cache / output budget problem.
4. Apply the narrowest mitigation that matches the class.
5. Re-run on real device, preferably `Release` and without attached debugger.

## What To Measure

- Physical RAM is not enough. Always compare:
  - process footprint
  - jetsam limit
  - remaining headroom
- If available, log:
  - `headroomMB`
  - `footprintMB`
  - `jetsamLimitMB`
  - visual token cap
  - multimodal output cap
  - KV cache limit

If the app shows about 12 GB physical RAM but only about 3.3 GB jetsam limit, treat 3.3 GB as the real ceiling.

## Mitigation Ladder

### 1. Remove startup work

- Make runtime creation lazy.
- Do not scan model directories or clean partial downloads on the critical startup path.
- Replace heavyweight startup status checks with lightweight file existence checks.

### 2. Split model load from first inference

- If logs show lazy load, consider eager materialization during `load()`.
- This trades a larger steady-state footprint for a smaller first-inference spike.
- Use when the first multimodal request combines:
  - weight materialization
  - Metal shader compilation
  - vision encode
  - text prefill

### 3. Reduce multimodal pressure

- Lower image soft-token caps or equivalent visual token budgets.
- Add a minimum headroom gate before starting image inference.
- Add a generation floor that stops if runtime headroom drops too low.
- Reduce image size or pooled visual tokens before changing text budgets.

### 4. Cap generation growth

- Clamp multimodal `maxOutputTokens`.
- If the stack supports it, set a fixed `maxKVSize` or rotating KV cache.
- Use smaller prefill chunks when long prompts or large multimodal prompts spike memory.

### 5. Improve runtime conditions

- Prefer real-device `Release`.
- Disable debugger attachment if the goal is memory validation.
- Turn off diagnostics such as View Debugging, Main Thread Checker, and queue/thread debugging unless needed.
- Prefer USB over wireless debugging.

### 6. Increase process headroom

- Add the `com.apple.developer.kernel.increased-memory-limit` entitlement when supported.
- This may raise the process limit on supported devices, but it does not guarantee survival under pressure.
- Expect entitlement setup to require both:
  - project entitlements
  - Apple Developer capability support for the app ID

## Decision Rules

- If `After load` is far below jetsam and first inference crashes, prioritize eager load and multimodal spike reduction.
- If `After load` is already within a few hundred MB of jetsam, treat the model as too large for safe residency on that device/configuration.
- If startup is slow but memory is fine, prioritize lazy initialization and background filesystem work.
- If only debug builds fail, first remove debugger/diagnostic overhead before changing model strategy.

## Entitlement Checklist

1. Add an `.entitlements` file to the iOS target.
2. Set `CODE_SIGN_ENTITLEMENTS`.
3. Include:

```plist
<key>com.apple.developer.kernel.increased-memory-limit</key>
<true/>
```

4. Re-sign and reinstall on device.
5. Compare runtime `jetsamLimitMB` before and after.

Read [references/entitlements.md](./references/entitlements.md) when you need the Apple-side caveats.

## Log Interpretation

Read [references/log-patterns.md](./references/log-patterns.md) when you need to map concrete log lines to likely failure stages.

## Constraints

- Do not assume physical RAM equals safe per-process memory.
- Do not assume `PhoneClaw`-style MLX apps automatically avoid first-inference spikes.
- Do not claim entitlement changes are guaranteed to bypass jetsam.
- Prefer concrete numbers and exact log lines over generic advice.
