# Entitlements

Use this note when the debugging path reaches process memory limits instead of algorithmic spikes.

## What It Helps With

`com.apple.developer.kernel.increased-memory-limit` can allow a higher process memory ceiling on supported devices and signing configurations.

This is useful when:
- physical RAM is much larger than the measured jetsam limit
- the model load itself is close to the process ceiling
- the app is already running in `Release` without debugger overhead

## What It Does Not Guarantee

- It does not guarantee access to all physical RAM.
- It does not make the app immune to jetsam.
- It may depend on app ID capability support and signing context.

## Practical Validation

After adding the entitlement:

1. Rebuild and reinstall on a real device.
2. Re-run the same inference scenario.
3. Compare:
   - `jetsamLimitMB`
   - `footprintMB` after load
   - remaining headroom before multimodal inference

If the limit does not move, the entitlement may not be active in the current signing configuration.

## Related Apple Terms

- Increased Memory Limit
- Extended Virtual Addressing
- Increased Debugging Memory Limit

Treat these as ways to improve odds, not a substitute for runtime budgeting.
