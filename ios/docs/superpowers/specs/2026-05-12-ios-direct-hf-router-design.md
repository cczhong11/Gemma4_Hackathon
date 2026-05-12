# iOS Direct HF Router — Design

Date: 2026-05-12
Status: Approved for implementation planning
Scope: iOS app only (`ios/Gemma4App`). The companion FastAPI repo at
`/Users/iltc/Downloads/Gemma4_ASL` stays in place, untouched.

## Goal

Move the gloss-generation pipeline currently served by the FastAPI proxy
into the iOS app, and have the app POST directly to the HuggingFace router
at `https://router.huggingface.co/v1/chat/completions`. After this change
the proxy is no longer in the iOS request path.

Behavior must be **identical** to the proxy — same prompt, same vocab
filter, same multi-word merging, same FS-classification. The public type
returned by `ASLTranslationService.translate(text:)` is byte-for-byte the
same `ASLTranslationResponse`, so `TextTranslationViewModel`, the chip UI,
and the player flow do not change.

## Non-goals

- Touching the `Gemma4_ASL` FastAPI repo. It stays where it is. No
  deletion, no archive move, no README edits.
- Changing the photo flow (`AppViewModel`, `CameraRecognitionView`,
  `ImageRecognitionService`, the Gemma4 runtime).
- Changes to `TextTranslationViewModel`, `GlossUnit`, `TextPlaceholderView`,
  or the Handspeak `ASLVideoLookupService` — the orchestrator preserves the
  existing `ASLTranslationResponse` contract.
- Settings UI for the HF token. The token continues to live in
  `ios/project.yml` under `HF_TOKEN`, regenerated into `Info.plist` by
  `xcodegen generate`.
- Automated tests. Matches the project's current stance and the backend
  spec's decision.
- Streaming responses, retry, response caching, batch translation — same
  scope cuts the backend made.

## Architecture overview

Four new Swift files, one rewritten Swift file, one bundled resource, and
a `project.yml` cleanup:

```
ios/Gemma4App/
  Runtime/
    ASLVocab.swift               NEW  — load signs.txt, build VocabIndex
    ASLGlossPrompt.swift         NEW  — system + user chat messages
    HFRouterClient.swift         NEW  — POST to HF router, error mapping
    ASLGlossPostprocess.swift    NEW  — model output → tokens + gloss
    ASLTranslationService.swift  REWRITTEN — orchestrator, same public API
  Resources/
    signs.txt                    NEW  — copy of Gemma4_ASL/signs.txt
ios/
  project.yml                    MODIFIED — Info.plist + sources updates
  Gemma4App/Info.plist           REGENERATED via xcodegen
  Gemma4App.xcodeproj/project.pbxproj  REGENERATED via xcodegen
```

The five-module split mirrors the backend layout one-to-one: `vocab.py`,
`prompt.py`, `hf_client.py`, `postprocess.py`, `main.py` →
`ASLVocab.swift`, `ASLGlossPrompt.swift`, `HFRouterClient.swift`,
`ASLGlossPostprocess.swift`, `ASLTranslationService.swift`. Each unit has
one job and can be reasoned about on its own.

## `project.yml` and resource packaging

Three edits to `ios/project.yml`:

1. Add a `Gemma4App/Resources` entry to `sources:` so XcodeGen wires the
   resource folder into the bundle.
2. Remove `ASL_API_BASE_URL` from the target's Info.plist `properties:`
   block. The iOS code no longer reads it.
3. Remove the `NSAppTransportSecurity` dictionary. It existed only to
   permit `http://127.0.0.1:8000`; the HF router is HTTPS so default ATS
   accepts it without exception.

After editing `project.yml`, run `xcodegen generate` to regenerate
`Info.plist` and `project.pbxproj`. The auto-memory note on
`ios-xcodegen-pbxproj-workflow.md` applies: any new `.swift` file under
`Runtime/` requires re-running `xcodegen` before `xcodebuild` will see it.

### `signs.txt` source of truth

The file is copied verbatim from `Gemma4_ASL/signs.txt` into
`ios/Gemma4App/Resources/signs.txt`. From this point on the iOS copy is the
source of truth for iOS builds. If the backend's vocab is ever edited,
the iOS copy must be re-copied manually. Hackathon scope: acceptable.

### Final `Info.plist` properties (post-edit)

```yaml
properties:
  NSCameraUsageDescription: 需要使用相机拍照并识别图片内容。
  UILaunchScreen: {}
  UIApplicationSceneManifest:
    UIApplicationSupportsMultipleScenes: false
  UISupportedInterfaceOrientations~iphone:
    - UIInterfaceOrientationPortrait
  UIStatusBarStyle: UIStatusBarStyleDefault
  HF_TOKEN: ""
```

## `ASLVocab.swift`

Direct Swift port of `app/vocab.py`. Loaded once at `ASLTranslationService`
init and reused for every translation in the lifetime of the service.

```swift
struct VocabIndex {
    let canonical: [String]          // post-filter order, lowercase
    let lookup: [String: String]     // normalized form → canonical
    let multiWord: [[String]]        // ["ice", "cream"], longest first
    var size: Int { canonical.count }
}

enum ASLVocabError: Error {
    case missingResource             // signs.txt not in bundle
    case emptyFile                   // present but no entries after filter
}

enum ASLVocab {
    static let excluded: Set<String> = [
        "a","b","d","e","f","g","h","i","j","k",
        "m","n","o","p","q","r","s","t","u","v","w",
        "don't want",
    ]

    static func load(bundle: Bundle = .main) throws -> VocabIndex
}
```

### Load steps (mirror Python)

1. `bundle.url(forResource: "signs", withExtension: "txt")` →
   `String(contentsOf:)`. Throw `.missingResource` if absent.
2. Trim, split by `,`, strip whitespace on each entry, drop empties.
3. Filter out anything in `excluded`. Throw `.emptyFile` if nothing
   remains.
4. For each canonical sign, register the five normalized forms (canonical;
   hyphens→spaces; spaces→hyphens; spaces+hyphens stripped; plus the
   uppercase variant of each) in `lookup`, all pointing at the canonical
   lowercase string.
5. For each sign containing a space, append
   `sign.split(separator: " ").map(String.init)` into `multiWord`.
6. Sort `multiWord` by descending count (longest first).

## `ASLGlossPrompt.swift`

Verbatim port of `app/prompt.py`. The rule text and the six few-shot
examples are character-for-character copies of the Python source — same
rules guarantee same gloss output.

```swift
enum ASLGlossPrompt {
    static func systemPrompt(vocab: VocabIndex) -> String
    static func messages(text: String, vocab: VocabIndex) -> [[String: String]]
}
```

`messages(text:vocab:)` returns:

```swift
[
    ["role": "system", "content": systemPrompt(vocab: vocab)],
    ["role": "user",   "content": "English: \"\(text)\"\nASL gloss:"],
]
```

The `[[String: String]]` shape is what `HFRouterClient` JSON-encodes
directly. No intermediate `Codable` model — that would add ceremony for a
fixed two-element array.

The system prompt sandwiches the vocab CSV between the framing line and
the rules:

```
You are converting English to ASL gloss for a teaching demo.

Available signs (use ONLY these, lowercase in this list, output as UPPERCASE):
<comma-joined vocab.canonical>

Rules:
- ASL drops articles (a, an, the) and "to be" verbs (am, is, are, was, were)
- Topic-comment order: time + subject + object + verb
- Questions go at the end with raised eyebrows (mark with ?)
- Negation goes after the verb: WANT NOT, LIKE NOT
- For multi-word signs, join with a hyphen: ICE-CREAM, THANK-YOU, HARD-OF-HEARING
- If a word isn't in the vocab, use FS-<WORD> for fingerspelling (e.g., FS-SARAH)
- Output ONLY the ASL gloss line. No explanation, no preamble.

Examples:
English: "I am going to the store tomorrow"
ASL gloss: TOMORROW STORE ME GO

English: "Where is the bathroom?"
ASL gloss: BATHROOM WHERE?

English: "I don't want coffee"
ASL gloss: COFFEE ME WANT NOT

English: "My friend Sarah is here"
ASL gloss: MY FRIEND FS-SARAH HERE

English: "Are you hungry?"
ASL gloss: YOU HUNGRY?

English: "Thank you for the ice cream"
ASL gloss: ICE-CREAM THANK-YOU
```

## `HFRouterClient.swift`

Direct port of `app/hf_client.py`. One function: send the chat messages,
return the raw model text.

```swift
enum HFRouterError: LocalizedError {
    case invalidToken                // HF returned 401
    case rateLimited                 // HF returned 429
    case upstream(status: Int)       // 5xx or other non-2xx
    case timeout                     // > 30s
    case transport(Error)            // URLError (offline, DNS, etc.)
    case unparseable                 // 200 but no choices[0].message.content
}

struct HFRouterClient {
    static let routerURL = URL(string: "https://router.huggingface.co/v1/chat/completions")!
    static let model = "google/gemma-4-31B-it:deepinfra"
    static let timeout: TimeInterval = 30

    init(session: URLSession? = nil, token: String)
    func call(messages: [[String: String]]) async throws -> String
}
```

### `call(messages:)` steps

1. Build the JSON body and encode via `JSONSerialization`:
   ```json
   { "model": "google/gemma-4-31B-it:deepinfra",
     "messages": [...],
     "temperature": 0.2,
     "max_tokens": 80 }
   ```
2. `URLRequest(url: routerURL)`, `httpMethod = "POST"`, headers
   `Authorization: Bearer <token>`, `Content-Type: application/json`,
   `Accept: application/json`.
3. `try await session.data(for:)`. Map errors:
   - `URLError(.timedOut)` → `.timeout`.
   - Other `URLError` → `.transport(error)`.
4. Inspect `HTTPURLResponse.statusCode`:
   - 200–299 → continue.
   - 401 → `.invalidToken`.
   - 429 → `.rateLimited`.
   - Anything else → `.upstream(status:)` (collapses the backend's
     400/500 distinction; iOS only needs to render one upstream-error
     string).
5. `JSONSerialization.jsonObject(with: data)` → cast to `[String: Any]`,
   walk `choices[0].message.content` as `String`. Any miss →
   `.unparseable`.

No retry, no caching — matches the backend.

The injected `URLSession?` initializer parameter is kept so the orchestrator
can pass its own configured session (which it does today for a 30s
`timeoutIntervalForRequest`). If `nil`, the client builds its own session
with `timeoutIntervalForRequest = HFRouterClient.timeout` and
`requestCachePolicy = .reloadIgnoringLocalCacheData`.

## `ASLGlossPostprocess.swift`

Port of `app/postprocess.py`. One entry point plus internal helpers
mirroring the Python ones.

```swift
struct ProcessedGloss {
    let gloss: String
    let tokens: [String]
    let unknownTokens: [String]
    let isQuestion: Bool
}

enum ASLGlossPostprocessError: Error {
    case emptyGloss
}

enum ASLGlossPostprocess {
    static func process(rawModelOutput: String, vocab: VocabIndex) throws -> ProcessedGloss
}
```

### Step 1 — Extract gloss line + detect question

Two compiled `NSRegularExpression`s held as static `let`s:

```swift
private static let glossHeader = try! NSRegularExpression(
    pattern: #"asl\s*gloss\s*:"#, options: .caseInsensitive)
private static let trailingQuestion = try! NSRegularExpression(
    pattern: #"\s*\?\s*$"#)
```

1. If `glossHeader` matches, drop everything up to and including the
   **last** match's range.
2. Split by newline, take the first non-empty line trimmed of whitespace.
3. Strip surrounding `"`, `'`, `` ` ``.
4. If `trailingQuestion` matches, set `isQuestion = true` and remove the
   match (along with any whitespace before the `?`).
5. If the remaining line is empty, throw `.emptyGloss`.

`NSRegularExpression` is chosen over Swift 5.7 `Regex` literals to keep
parity with Python's `re` semantics and avoid surprises on the two patterns.

### Step 2 — Tokenize with multi-word merging

```swift
private static func mergeMultiWord(_ raw: [String], _ vocab: VocabIndex) -> [String]
```

Walk `raw` with an index `i`. For each position, iterate
`vocab.multiWord` (already longest-first). For each candidate `words`:

- If `i + words.count > raw.count`, skip.
- Join `raw[i ..< i + words.count]` with a single space, lowercase, look
  up in `vocab.lookup`.
- On hit, append the canonical form, advance `i` by `words.count`, break.

If no multi-word matched, emit `raw[i]` as-is and `i += 1`.

### Step 3 — Classify each merged token

```swift
private static func classify(_ token: String, vocab: VocabIndex)
    -> (emit: String, unknown: String?)
```

- If `token.uppercased().hasPrefix("FS-")` → emit
  `"FS-" + token.dropFirst(3).uppercased()`, no unknown.
- Else if `vocab.lookup[token]` exists → emit canonical, no unknown.
- Else if `vocab.lookup[token.uppercased()]` exists → emit canonical, no
  unknown.
- Else → record `token.uppercased()` in `unknownTokens`, emit
  `"FS-" + token.uppercased()`.

### Step 4 — Reconstruct display gloss

Join classified tokens with single spaces; sign tokens get `.uppercased()`,
`FS-…` tokens stay as-is. Append `?` if `isQuestion`.

## `ASLTranslationService.swift` (rewritten)

Same public surface as today; internals now pull the four new modules
together.

```swift
struct ASLTranslationResponse: Decodable, Equatable {
    let gloss: String
    let tokens: [String]
    let unknownTokens: [String]
    let isQuestion: Bool
    let model: String
}

enum ASLTranslationError: LocalizedError {
    case missingToken
    case vocabUnavailable(ASLVocabError)
    case router(HFRouterError)
    case unparseableGloss
}

struct ASLTranslationService {
    private static let tokenKey = "HF_TOKEN"

    private let vocab: VocabIndex
    private let client: HFRouterClient

    init(session: URLSession? = nil, bundle: Bundle = .main) throws {
        let rawToken = (bundle.object(forInfoDictionaryKey: Self.tokenKey)
            as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawToken.isEmpty else { throw ASLTranslationError.missingToken }

        do { self.vocab = try ASLVocab.load(bundle: bundle) }
        catch let e as ASLVocabError { throw ASLTranslationError.vocabUnavailable(e) }

        self.client = HFRouterClient(session: session, token: rawToken)
    }

    func translate(text: String) async throws -> ASLTranslationResponse {
        let messages = ASLGlossPrompt.messages(text: text, vocab: vocab)
        let raw: String
        do { raw = try await client.call(messages: messages) }
        catch let e as HFRouterError { throw ASLTranslationError.router(e) }

        let processed: ProcessedGloss
        do { processed = try ASLGlossPostprocess.process(rawModelOutput: raw, vocab: vocab) }
        catch { throw ASLTranslationError.unparseableGloss }

        return ASLTranslationResponse(
            gloss: processed.gloss,
            tokens: processed.tokens,
            unknownTokens: processed.unknownTokens,
            isQuestion: processed.isQuestion,
            model: HFRouterClient.model
        )
    }
}
```

The throwing `init` lets `TextTranslationViewModel` keep its existing
"construct lazily on first translate, surface init failure as
`errorMessage`" pattern (today's `TextTranslationViewModel.swift` lines
64–77) unchanged.

### Why `ASLTranslationError` widens

Today's enum is proxy-specific: `missingBaseURL`, `missingToken`,
`invalidResponse(status:)`, `decodingFailed`, `transport`. Without the
proxy, the error surface fans out — vocab loading, HF networking, and
model-output parsing can each fail. Wrapping `ASLVocabError` and
`HFRouterError` in `ASLTranslationError` cases keeps a single VM-facing
type while letting each unit own its own error vocabulary.

`missingBaseURL`, `invalidResponse(status:)`, `decodingFailed`, and
`transport` are removed — they were proxy-specific. The VM continues to
display `error.localizedDescription` and is unaware of the new types.

### `localizedDescription` mapping

| Case | Message |
|---|---|
| `.missingToken` | `HF_TOKEN is not configured in Info.plist.` |
| `.vocabUnavailable(.missingResource)` | `signs.txt is missing from the app bundle.` |
| `.vocabUnavailable(.emptyFile)` | `signs.txt is empty after filtering.` |
| `.router(.invalidToken)` | `Invalid HuggingFace token.` |
| `.router(.rateLimited)` | `HuggingFace rate-limited. Try again shortly.` |
| `.router(.timeout)` | `HuggingFace request timed out.` |
| `.router(.upstream(let s))` | `HuggingFace error (HTTP \(s)).` |
| `.router(.transport(_))` | `Network error. Check your connection.` |
| `.router(.unparseable)` | `Model returned no usable content.` |
| `.unparseableGloss` | `Model returned no usable gloss.` |

## Validation plan

1. **Build succeeds** with the known-good simulator command:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
   xcodebuild -project ios/Gemma4App.xcodeproj \
     -scheme Gemma4App -sdk iphonesimulator \
     -configuration Debug build CODE_SIGNING_ALLOWED=NO
   ```
   Run via Bash with `dangerouslyDisableSandbox: true` per the toolchain
   memory note.

2. **Info.plist no longer leaks `ASL_API_BASE_URL` or
   `NSAppTransportSecurity`**, but still carries `HF_TOKEN`:
   ```bash
   plutil -p ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphonesimulator/Gemma4App.app/Info.plist \
     | grep -E 'HF_TOKEN|ASL_API_BASE_URL|NSAppTransportSecurity'
   ```
   Only `HF_TOKEN` should appear.

3. **Bundle ships `signs.txt`** as a resource:
   ```bash
   ls ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphonesimulator/Gemma4App.app/signs.txt
   ```

4. **End-to-end on simulator, no FastAPI running**: paste a real HF token
   into `project.yml`, run `xcodegen`, build, launch simulator, type
   `"I am going to the store tomorrow"`, verify chips `TOMORROW STORE ME GO`
   appear, video plays + auto-advances + loops. The FastAPI server must be
   stopped to prove iOS isn't reaching it.

5. **Question path**: `"Where is the bathroom?"` → chips `BATHROOM WHERE`,
   no `?` chip. `ASLTranslationResponse.isQuestion == true` round-trips
   (current UI doesn't surface it yet but the response must still carry
   it for parity).

6. **Fingerspelling path**: `"My friend Sarah is here"` → a chip labelled
   `SARAH (FS)` and 5 letter clips play through it.

7. **Multi-word merging**: `"Thank you for the ice cream"` → tokens
   `ice cream` and `thank you` are emitted as single canonical signs, not
   as four separate `FS-` letters.

8. **Error paths**:
   - Empty `HF_TOKEN` in `project.yml` → `"HF_TOKEN is not configured…"`.
   - Garbage `HF_TOKEN` → `"Invalid HuggingFace token."`.
   - Simulator in airplane mode → `"Network error. Check your connection."`.

9. **No regression to photo flow** — `CameraRecognitionView` builds and
   still translates an image (smoke test).

## Open items / known caveats

- `signs.txt` is missing letter clips for `c, l, x, y, z` — orthogonal to
  this change but reaffirmed from the prior spec.
- No automated tests, matching the project's current stance.
- The bundled `signs.txt` is a copy of the backend's file; the two files
  can drift if the backend's vocab is edited. iOS copy is the source of
  truth for iOS builds.
- The HF router's exact non-401/429 error shapes haven't been tested from
  the device. If we see distinct 4xx codes worth surfacing differently,
  we can split `.upstream(status:)` later — out of scope for the first
  pass.
