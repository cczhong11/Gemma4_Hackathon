# Text-to-ASL Translation Mode — Design

Date: 2026-05-11
Status: Approved for implementation planning
Scope: iOS app only (`ios/Gemma4App`)

## Goal

Replace the static placeholder body of `TextPlaceholderView` with a working
text-to-ASL flow that:

1. Lets the user type an English sentence and tap **Translate**.
2. Sends the sentence to our FastAPI proxy at `POST /translate`, which returns
   a list of canonical ASL gloss tokens (lowercase signs, hyphenated
   multi-word signs, and `FS-<WORD>` fingerspelling directives).
3. Verifies each token against Handspeak via the existing
   `ASLVideoLookupService`, expanding `FS-<WORD>` into a sequence of
   per-letter lookups.
4. Plays the verified videos in sequence, auto-advancing to the next clip
   when one ends and looping back to the first after the last.
5. Lets the user jump to any token by tapping its chip.

This mirrors what the Next.js prototype in `asl-sequence/src/app` does, but
goes through our new FastAPI gloss generator rather than tokenising the raw
input client-side.

## Non-goals

- Speed control (0.5x / 1x / 1.5x) — out of scope; Photo flow has it but the
  text flow stays minimal per user preference.
- A dedicated PLAY button — playback starts as soon as videos finish caching.
- Showing the formatted gloss string, original sentence, or unknown-token
  warnings on screen. The on-screen surface is intentionally minimal:
  textbox, button, video, chips.
- Fingerspelling fallback for tokens Handspeak can't resolve — those chips
  render dimmed and are skipped at playback time.
- Speech, recording, or any other input modality besides typing.
- Changes to the Photo flow. `AppViewModel`, `CameraRecognitionView`,
  `ImageRecognitionService`, and the runtime stay untouched.

## Architecture overview

Two new Swift files, one rewritten Swift file, and a XcodeGen-managed
Info.plist. No changes to any existing photo-flow code:

```
ios/Gemma4App/
  Runtime/
    ASLTranslationService.swift          NEW — wraps POST /translate.
    ASLVideoLookupService.swift          EXISTING — reused as-is for token
                                         and per-letter Handspeak lookup.
  UI/
    TextPlaceholderView.swift            REPLACED — text-mode UI.
    TextTranslationViewModel.swift       NEW — @StateObject owned by
                                         TextPlaceholderView.
ios/
  project.yml                            MODIFIED — Info.plist migration
                                         (see below).
  Gemma4App/Info.plist                   NEW (XcodeGen-generated, committed).
  Gemma4App.xcodeproj/project.pbxproj    REGENERATED via xcodegen.
```

`AppViewModel` is **not** modified. Text-mode state stays local to
`TextPlaceholderView`'s `@StateObject`. `AppViewModel` is still passed in
because the existing bottom tab bar uses it for the
`navigateToPhotoMode → CameraRecognitionView` link.

The struct `TextPlaceholderView` keeps its current name so the diff is small
and external references (`CameraRecognitionView` links to it) keep working.

## Data model

One new type, kept private to the text-mode files (no new globally visible
types). The other state pieces (`units`, `videos`, `currentVideoIndex`,
`gloss`, `errorMessage`, `inputText`, `isTranslating`) are held directly as
`@Published` properties on the view model — see the next section.

```swift
struct GlossUnit: Identifiable {
    let id = UUID()
    enum Kind {
        case sign(String)           // canonical lowercase token, e.g. "one", "ice-cream"
        case fingerspell(String)    // the FS word in UPPER, e.g. "SARAH"
    }
    let kind: Kind
    let videoRange: Range<Int>      // indices into the flat play queue
    var displayLabel: String        // "ONE" or "SARAH (FS)"
    var isPlayable: Bool            // false if every video in the range failed
}
```

Single source of truth for "what plays next" is the flat `videos` array on
the VM.
Each chip maps to a `Range<Int>` into that array — single-letter clip for
plain signs (length 1), multi-clip span for `FS-<WORD>`.

The active chip is computed:

```swift
units.first { $0.videoRange.contains(currentVideoIndex) }
```

No separate "active unit index" state — eliminates a class of drift bugs.

## Translation flow

`TextTranslationViewModel.translate()`:

1. Trim `inputText`. If empty: set `errorMessage = "Type something first."`,
   return.
2. Cancel any in-flight `translateTask`. Reset published state:
   `isTranslating = true`, clear `errorMessage`, `units`, `videos`,
   `currentVideoIndex = 0`.
3. `response = try await translationService.translate(text: trimmed)`.
4. Expand the token list into a flat lookup list. For each server token,
   build a pending unit:
   - `FS-<WORD>`: letters = `Array(word).map { String($0).lowercased() }`.
     Display label `"<WORD> (FS)"`, kind `.fingerspell(word)`.
   - Anything else: letters = `[token]`. Display label `token.uppercased()`,
     kind `.sign(token)`. The canonical token stays lowercase
     (`"ice-cream"`) in the lookup; only the display is upper-cased.
5. One batched call: `await lookupService.lookup(words: flatLetters)`.
6. Stitch results back into units and the play queue:
   - Walk the flat results in order. For each pending unit take the next
     `letters.count` results.
   - Filter out results without a `localVideoURL` when building the flat
     `videos` queue.
   - Each unit's `videoRange` is `[playQueueIndex, playQueueIndex + playable)`.
     Empty range when nothing in the unit succeeded; `isPlayable = false`.
7. Publish `units`, `videos`, `currentVideoIndex = 0`,
   `isTranslating = false`.
8. If `videos.isEmpty`: `errorMessage = "No playable signs for this sentence."`
   Keep the (all-unplayable) chips visible so the user can see what we tried.

Cancellation: the VM stores `private var translateTask: Task<Void, Never>?`.
Every call to `translate()` cancels the previous one. Stale Handspeak
results from a previous request won't clobber a fresh batch.

## Networking — `ASLTranslationService`

Single-purpose struct that mirrors the shape of `ASLVideoLookupService`:
struct, injectable `URLSession`, no singletons, no global mutable state.

```swift
struct ASLTranslationResponse: Decodable {
    let gloss: String
    let tokens: [String]
    let unknownTokens: [String]
    let isQuestion: Bool
    let model: String

    enum CodingKeys: String, CodingKey {
        case gloss, tokens, model
        case unknownTokens = "unknown_tokens"
        case isQuestion = "is_question"
    }
}

enum ASLTranslationError: LocalizedError {
    case missingBaseURL
    case missingToken
    case invalidResponse(status: Int)
    case decodingFailed
    case transport(Error)
}

struct ASLTranslationService {
    private let session: URLSession
    private let baseURL: URL
    private let token: String

    init(session: URLSession? = nil) throws {
        // Read ASL_API_BASE_URL and HF_TOKEN from Bundle.main.infoDictionary.
        // Trim whitespace, strip trailing slash on baseURL.
        // Throw missingBaseURL / missingToken if either is empty.
    }

    func translate(text: String) async throws -> ASLTranslationResponse {
        // POST {baseURL}/translate
        // Authorization: Bearer <token>
        // Content-Type: application/json, Accept: application/json
        // Body: {"text": "<text>"}
        // 30s request timeout (matches ASLVideoLookupService).
        // Non-2xx -> .invalidResponse(status:)
        // URLError -> .transport
        // JSONDecodingError -> .decodingFailed
    }
}
```

Decisions:

- **Throwing init** so misconfiguration surfaces at the first call site
  rather than silently at request time. The VM catches and renders a clear
  error like `"ASL_API_BASE_URL is not configured."` — makes the
  local-vs-prod URL switch obvious to debug.
- **No retry, no response caching.** Translate requests are cheap and
  cacheable client-side adds complexity; on failure the user retaps.
- **`URLSessionConfiguration.default` with
  `timeoutIntervalForRequest = 30`** — consistent with the pattern already
  established in `ASLVideoLookupService`.
- **Token never logged.** Only `model`, token count, and unknown-token
  count get logged on success; errors log status codes and a sanitised
  error description.

## Playback unit (`TextTranslationViewModel` API)

```swift
@MainActor
final class TextTranslationViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isTranslating: Bool = false
    @Published var errorMessage: String?
    @Published var units: [GlossUnit] = []
    @Published var videos: [ASLSignVideo] = []
    @Published var currentVideoIndex: Int = 0

    init(
        translationService: ASLTranslationService? = nil,
        lookupService: ASLVideoLookupService = ASLVideoLookupService()
    )

    func translate() async
    func onVideoEnded()                      // advance index with wrap
    func jumpTo(unit: GlossUnit)             // currentVideoIndex = lowerBound
    var activeUnitID: GlossUnit.ID? { get }  // computed
    var currentVideoURL: URL? { get }        // safe-indexed
}
```

If `translationService == nil`, the VM tries `try? ASLTranslationService()`
on first use and surfaces the config error in `errorMessage`. This lets
`#Preview` and earlier-stage screens construct the VM without crashing when
Info.plist isn't wired yet.

`onVideoEnded` advances using
`currentVideoIndex = (currentVideoIndex + 1) % videos.count`. Failed videos
never enter the flat queue, so wrap-around naturally loops the sequence.

## View — `TextPlaceholderView`

Outer shell stays as-is: `TextModePalette` background, the bottom tab bar
with the `navigateToPhotoMode` link to `CameraRecognitionView`, the
`.toolbar(.hidden)`. Only the middle section is rewritten.

Stack top → bottom:

1. **Header** — `Text("💬 Text to ASL")` in the rounded display font, plus
   a one-line subtitle ("Type something. We'll sign it.").
2. **Input card** — multi-line `TextEditor` bound to `vm.inputText`,
   ~140 pt tall, inside a rounded card matching `TextModePalette.card`,
   with a placeholder rendered behind it when the binding is empty
   ("Type a sentence in English").
3. **Translate button** — full-width pill, same green as the Photo screen's
   "Sign it!" button for visual consistency. Label flips to "Translating..."
   with a `ProgressView` while `vm.isTranslating == true`. Disabled when
   translating or when input is empty after trim.
4. **Error message card** (conditional) — copy of the red-tinted style
   `CameraRecognitionView` uses. A small private helper inside this file,
   not extracted to a shared helper (keeps diff narrow; can be refactored
   later).
5. **Player card** (`!vm.videos.isEmpty`) — navy rounded rectangle,
   `aspectRatio(16/9)` `VideoPlayer`. Single shared `AVPlayer`; on
   `onChange(of: vm.currentVideoIndex)` we call `replaceCurrentItem` with
   the new `AVPlayerItem` and `player.play()`. End-of-item observed via
   `NotificationCenter` on `AVPlayerItem.didPlayToEndTimeNotification`,
   which calls `vm.onVideoEnded()`. Smoother than rebuilding the
   `AVPlayer` per clip (which would flash between letters of `FS-SARAH`).
6. **Chip row** (`!vm.units.isEmpty`) — `LazyVGrid` of capsule buttons,
   one per unit. The active unit (its range contains `currentVideoIndex`)
   gets a filled background + white text; non-playable units render muted
   and are tap-disabled. Tap → `vm.jumpTo(unit:)`.
7. **Bottom tab bar** — unchanged.

The single-`AVPlayer` choice matters because every gloss token swap is a
`replaceCurrentItem` call rather than a fresh `VideoPlayer` view; the
existing `ASLSignVideoCard` in `CameraRecognitionView` uses one-AVPlayer-per-
clip, which is fine for that flow because the user manually re-engages with
each clip, but would visibly hiccup when fingerspelling.

## Info.plist migration

This is the slightly fiddly part. Today the project uses
`GENERATE_INFOPLIST_FILE: YES` with `INFOPLIST_KEY_*` build settings. That
auto-generation path only supports top-level scalars; nested dictionaries
like `NSAppTransportSecurity` cannot be set that way.

**Chosen approach: switch this target to a XcodeGen-managed
`info.properties`.** Set `GENERATE_INFOPLIST_FILE: NO`, add an `info:`
block to the target, migrate the existing `INFOPLIST_KEY_*` lines into the
same `properties:` dict. Same pattern PhoneClaw uses.

### `ios/project.yml` diff

```yaml
settings:
  base:
    ...
    GENERATE_INFOPLIST_FILE: NO          # was YES
    # The five INFOPLIST_KEY_* lines below are removed from here:
    #   INFOPLIST_KEY_NSCameraUsageDescription
    #   INFOPLIST_KEY_UILaunchScreen_Generation
    #   INFOPLIST_KEY_UIApplicationSceneManifest_Generation
    #   INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone
    #   INFOPLIST_KEY_UIStatusBarStyle
targets:
  Gemma4App:
    ...
    info:
      path: Gemma4App/Info.plist
      properties:
        NSCameraUsageDescription: 需要使用相机拍照并识别图片内容。
        UILaunchScreen: {}
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
        UISupportedInterfaceOrientations~iphone:
          - UIInterfaceOrientationPortrait
        UIStatusBarStyle: UIStatusBarStyleDefault
        ASL_API_BASE_URL: http://127.0.0.1:8000
        HF_TOKEN: ""
        NSAppTransportSecurity:
          NSAllowsLocalNetworking: true
```

After this change, `xcodegen` regenerates the project file and produces a
checked-in `ios/Gemma4App/Info.plist`. The developer commits both
`project.yml`, the new `Info.plist`, and the regenerated
`Gemma4App.xcodeproj/project.pbxproj`.

`NSAllowsLocalNetworking: true` allows `127.0.0.1`, `localhost`, `.local`,
and private LAN IPs over HTTP. HTTPS prod URLs still work without any
exception. When the API ships to production, only `ASL_API_BASE_URL`
changes — the ATS dict can stay (it doesn't loosen anything for non-local
addresses).

### Token in git

Per user decision: `HF_TOKEN` value lives directly in `ios/project.yml`.
No `project.local.yml` overlay, no env-var indirection. Acceptable because
this is a private hackathon repo with a personal HF token.

## Validation plan

After implementation:

1. **Build succeeds** with the known-good simulator command from
   `AGENTS.md`:
   ```bash
   xcodebuild -project ios/Gemma4App.xcodeproj \
     -scheme Gemma4App -sdk iphonesimulator \
     -configuration Debug build CODE_SIGNING_ALLOWED=NO
   ```
2. **Info.plist contains the keys**:
   ```bash
   plutil -p ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphonesimulator/Gemma4App.app/Info.plist \
     | grep -E 'ASL_API_BASE_URL|HF_TOKEN|NSAllowsLocalNetworking'
   ```
3. **End-to-end on simulator**: start FastAPI locally with a real HF token,
   set `HF_TOKEN` in `project.yml`, run `xcodegen`, build, launch
   simulator, type "Which one do you like best?", verify chips appear,
   video plays + auto-advances + loops.
4. **`FS-` path**: type "My friend Sarah is here", verify a chip labelled
   `SARAH (FS)` appears, and tapping it plays five letter clips before
   advancing to the next unit.
5. **Error paths**: empty `HF_TOKEN` → error card with config message;
   offline backend → transport error card; nonsense input → backend may
   return tokens but all might be unknown to Handspeak — verify graceful
   "No playable signs for this sentence." state.
6. **No regression to photo flow** — `CameraRecognitionView` builds, opens,
   and still produces a translation when given an image (smoke test).

## Open questions / known caveats

- **Handspeak per-letter coverage.** The design assumes Handspeak's
  search-dict endpoint returns playable MP4s for single-letter queries.
  This needs to be confirmed empirically during implementation. If a
  letter doesn't have a video, that letter is omitted from the flat queue
  and the surrounding `FS-` chip becomes partially or fully unplayable;
  this falls out of the existing `isPlayable` logic, so no design change is
  needed if the assumption fails — only display affordance.
- **Multi-word hyphenated tokens.** The server emits things like
  `ice-cream` and `thank-you`. The design passes those through the search
  endpoint as-is. If Handspeak doesn't match `ice-cream`, a future
  enhancement could retry with `ice cream` or fall back to fingerspelling
  — out of scope for the first pass.
- **No accessibility pass.** Voice-over labels for the chip row and player
  are not in this design. To be added as a follow-up.
