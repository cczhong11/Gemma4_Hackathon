# Log Patterns

Use these patterns to quickly identify which phase is actually failing.

## 1. Startup path problem

Symptoms:
- App is unresponsive right after launch.
- Little or no MLX memory growth yet.
- UI becomes usable only after long directory scans or model status checks.

Likely cause:
- Synchronous filesystem work or runtime initialization on the main thread.

Typical fixes:
- Lazy runtime/service creation.
- Move install-state refresh and cleanup off the startup path.

## 2. Lazy-load spike on first inference

Symptoms:
- `After load` footprint remains surprisingly small.
- Logs mention lazy load or skipped `eval(model)`.
- App dies only when first image or prompt is processed.

Likely cause:
- Weight materialization, Metal shader compilation, and inference activations happen in the same request.

Typical fixes:
- Eagerly materialize weights during `load()`.
- Lower multimodal input budgets for the first request.

## 3. Model residency too close to jetsam

Symptoms:
- `After load` is already within roughly 300-500 MB of the jetsam limit.
- App may show plenty of physical RAM, but little remaining process headroom.

Likely cause:
- The model itself is too large for safe steady-state residency on that device/configuration.

Typical fixes:
- Use `Release` without debugger.
- Add increased-memory entitlement.
- Unload after use.
- Move to a smaller or different backend/model if still too close.

## 4. Vision spike

Symptoms:
- Crash happens after image preparation or during/after vision encode.
- Logs show large patch counts, large resized image tensors, or high visual token caps.

Likely cause:
- Vision encoder activations or temporary buffers exceed remaining headroom.

Typical fixes:
- Lower image soft-token cap.
- Reduce image resolution.
- Refuse multimodal work when headroom is below a critical threshold.

## 5. Generation/KV growth

Symptoms:
- Vision stage succeeds.
- App dies later during decode or after many output tokens.

Likely cause:
- KV cache growth or long prefill/decoding budget.

Typical fixes:
- Lower `maxOutputTokens`.
- Use fixed `maxKVSize` / rotating KV cache when supported.
- Use smaller prefill steps or chunking.
