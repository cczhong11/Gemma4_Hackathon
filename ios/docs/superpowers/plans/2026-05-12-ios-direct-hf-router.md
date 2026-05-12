# iOS Direct HF Router Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the FastAPI gloss pipeline into the iOS app so `TextPlaceholderView` talks straight to the HuggingFace router; behavior-identical port with the existing `ASLTranslationResponse` contract intact.

**Architecture:** Five Swift units in `Gemma4App/Runtime/` mirror the backend modules one-to-one (`vocab.py` → `ASLVocab.swift`, `prompt.py` → `ASLGlossPrompt.swift`, `hf_client.py` → `HFRouterClient.swift`, `postprocess.py` → `ASLGlossPostprocess.swift`, `main.py` → rewritten `ASLTranslationService.swift`). `signs.txt` is bundled as a resource. The public `ASLTranslationService.translate(text:)` API is unchanged so `TextTranslationViewModel` and the chip/player UI keep working without edits.

**Tech Stack:** Swift 5, Foundation (`URLSession`, `NSRegularExpression`, `JSONSerialization`), XcodeGen, `xcodebuild`. No automated tests — the spec's nine-step manual validation is Task 7.

**Spec:** `ios/docs/superpowers/specs/2026-05-12-ios-direct-hf-router-design.md` (commit `360ecd7`).

---

## Working directory

All commands run from `/Users/iltc/Downloads/Gemma4_Hackathon/ios` unless noted otherwise.

## Build command (used by every code task)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Gemma4App.xcodeproj \
  -scheme Gemma4App -sdk iphonesimulator \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

When invoking via the Bash tool, pass `dangerouslyDisableSandbox: true` — `xcodebuild` and `xcodegen` write outside the default sandbox.

## File structure (final state)

```
ios/Gemma4App/
  Runtime/
    ASLVocab.swift              NEW       vocab loading + VocabIndex
    ASLGlossPrompt.swift        NEW       chat messages builder
    HFRouterClient.swift        NEW       HF router POST + error mapping
    ASLGlossPostprocess.swift   NEW       model output → tokens + gloss
    ASLTranslationService.swift REWRITE   orchestrator (same public API)
  Resources/
    signs.txt                   NEW       copy of /Users/iltc/Downloads/Gemma4_ASL/signs.txt
ios/project.yml                 MODIFY    add Resources entry; remove ASL_API_BASE_URL and NSAppTransportSecurity
ios/Gemma4App/Info.plist        REGEN     via xcodegen
ios/Gemma4App.xcodeproj/project.pbxproj  REGEN  via xcodegen
```

---

## Task 1: Bundle signs.txt and clean project.yml

**Files:**
- Create: `ios/Gemma4App/Resources/signs.txt`
- Modify: `ios/project.yml`
- Regenerate: `ios/Gemma4App/Info.plist`, `ios/Gemma4App.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create the Resources directory**

```bash
mkdir -p Gemma4App/Resources
```

- [ ] **Step 2: Copy `signs.txt` from the backend repo**

```bash
cp /Users/iltc/Downloads/Gemma4_ASL/signs.txt Gemma4App/Resources/signs.txt
```

Expected: the file is ~12 KB and begins with `book,drink,computer,before,chair,go,...`.

- [ ] **Step 3: Add `Gemma4App/Resources` to `sources:` in `project.yml`**

In `ios/project.yml`, locate the `sources:` block (currently lines 28–36) and append the Resources entry so the final block reads:

```yaml
    sources:
      - path: Gemma4App/App
      - path: Gemma4App/UI
      - path: Gemma4App/Runtime
      - path: Gemma4App/Resources
      - path: Vendor/Gemma4Runtime/LLM
      - path: Vendor/Gemma4Runtime/Shared/L10n.swift
      - path: Vendor/Gemma4Runtime/Shared/LanguageService.swift
      - path: Vendor/Gemma4Runtime/Shared/PCLog.swift
      - path: Vendor/Gemma4Runtime/Shared/Audio/ASRBackend.swift
```

XcodeGen will auto-classify `signs.txt` as a bundled resource (non-`.swift` files under a sources path become resources by default).

- [ ] **Step 4: Remove `ASL_API_BASE_URL` and `NSAppTransportSecurity` from the Info.plist properties**

In `ios/project.yml`, the target's `info.properties:` block (currently lines 56–67) becomes:

```yaml
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
        HF_TOKEN: ""
```

The three deletions: `ASL_API_BASE_URL: http://127.0.0.1:8000` and the two lines for `NSAppTransportSecurity:` and `NSAllowsLocalNetworking: true`.

- [ ] **Step 5: Regenerate the Xcode project**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
```

Expected: prints `Created project at /Users/iltc/Downloads/Gemma4_Hackathon/ios/Gemma4App.xcodeproj`.

- [ ] **Step 6: Build to confirm the project compiles**

Run the build command from the top of this plan.
Expected: `** BUILD SUCCEEDED **`. (The new `signs.txt` is just sitting in the bundle; no code uses it yet.)

- [ ] **Step 7: Verify the rebuilt `Info.plist`**

```bash
plutil -p ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphonesimulator/Gemma4App.app/Info.plist \
  | grep -E 'HF_TOKEN|ASL_API_BASE_URL|NSAppTransportSecurity'
```

Expected: exactly one line, `"HF_TOKEN" => ""`. The other two patterns must not appear.

- [ ] **Step 8: Verify `signs.txt` ships in the bundle**

```bash
ls ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphonesimulator/Gemma4App.app/signs.txt
```

Expected: prints the path. Non-zero exit means the resource didn't ship.

- [ ] **Step 9: Commit**

```bash
git add Gemma4App/Resources/signs.txt project.yml Gemma4App/Info.plist Gemma4App.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Bundle signs.txt and drop FastAPI proxy config from project.yml

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `ASLVocab.swift`

**Files:**
- Create: `ios/Gemma4App/Runtime/ASLVocab.swift`

- [ ] **Step 1: Write the file**

Create `ios/Gemma4App/Runtime/ASLVocab.swift` with the following content:

```swift
import Foundation

struct VocabIndex {
    let canonical: [String]
    let lookup: [String: String]
    let multiWord: [[String]]
    var size: Int { canonical.count }
}

enum ASLVocabError: Error {
    case missingResource
    case emptyFile
}

enum ASLVocab {
    static let excluded: Set<String> = [
        "a", "b", "d", "e", "f", "g", "h", "i", "j", "k",
        "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w",
        "don't want",
    ]

    static func load(bundle: Bundle = .main) throws -> VocabIndex {
        guard let url = bundle.url(forResource: "signs", withExtension: "txt") else {
            throw ASLVocabError.missingResource
        }
        let raw = (try String(contentsOf: url, encoding: .utf8))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { throw ASLVocabError.emptyFile }

        let entries = raw
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let canonical = entries.filter { !excluded.contains($0) }
        if canonical.isEmpty { throw ASLVocabError.emptyFile }

        var lookup: [String: String] = [:]
        var multiWord: [[String]] = []
        for sign in canonical {
            for form in normalizedForms(sign) {
                lookup[form] = sign
            }
            if sign.contains(" ") {
                multiWord.append(sign.split(separator: " ").map(String.init))
            }
        }
        multiWord.sort { $0.count > $1.count }

        return VocabIndex(
            canonical: canonical,
            lookup: lookup,
            multiWord: multiWord
        )
    }

    private static func normalizedForms(_ canonical: String) -> Set<String> {
        let spaceForm = canonical.replacingOccurrences(of: "-", with: " ")
        let hyphenForm = canonical.replacingOccurrences(of: " ", with: "-")
        let stripped = canonical
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let raw = Set([canonical, spaceForm, hyphenForm, stripped]
            .filter { !$0.isEmpty })
        var out = raw
        for form in raw {
            out.insert(form.uppercased())
        }
        return out
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
```

Required because XcodeGen picks up `.swift` files at generate time — `xcodebuild` won't compile the new file otherwise.

- [ ] **Step 3: Build to confirm `ASLVocab.swift` compiles**

Run the build command from the top of this plan.
Expected: `** BUILD SUCCEEDED **`. Nothing references the new types yet.

- [ ] **Step 4: Commit**

```bash
git add Gemma4App/Runtime/ASLVocab.swift Gemma4App.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Add ASLVocab loading vocab index from bundled signs.txt

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `ASLGlossPrompt.swift`

**Files:**
- Create: `ios/Gemma4App/Runtime/ASLGlossPrompt.swift`

- [ ] **Step 1: Write the file**

Create `ios/Gemma4App/Runtime/ASLGlossPrompt.swift` with the following content. The rule text and the six few-shot examples are character-for-character copies of the Python `app/prompt.py` source.

```swift
import Foundation

enum ASLGlossPrompt {
    static func systemPrompt(vocab: VocabIndex) -> String {
        let vocabCSV = vocab.canonical.joined(separator: ",")
        return """
            You are converting English to ASL gloss for a teaching demo.

            Available signs (use ONLY these, lowercase in this list, output as UPPERCASE):
            \(vocabCSV)

            \(rules)

            \(fewShots)
            """
    }

    static func messages(text: String, vocab: VocabIndex) -> [[String: String]] {
        [
            ["role": "system", "content": systemPrompt(vocab: vocab)],
            ["role": "user", "content": "English: \"\(text)\"\nASL gloss:"],
        ]
    }

    private static let rules = """
        Rules:
        - ASL drops articles (a, an, the) and "to be" verbs (am, is, are, was, were)
        - Topic-comment order: time + subject + object + verb
        - Questions go at the end with raised eyebrows (mark with ?)
        - Negation goes after the verb: WANT NOT, LIKE NOT
        - For multi-word signs, join with a hyphen: ICE-CREAM, THANK-YOU, HARD-OF-HEARING
        - If a word isn't in the vocab, use FS-<WORD> for fingerspelling (e.g., FS-SARAH)
        - Output ONLY the ASL gloss line. No explanation, no preamble.
        """

    private static let fewShots = """
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
        """
}
```

Notes on the multiline literals:
- The closing `"""` on each literal sits at the same indentation as the content lines, so Swift strips that common prefix and the rendered strings have no leading whitespace per line.
- The outer `systemPrompt` literal stitches `rules` and `fewShots` directly via interpolation, matching the Python concatenation in `build_system_prompt` byte for byte.

- [ ] **Step 2: Regenerate the Xcode project**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
```

- [ ] **Step 3: Build**

Run the build command from the top of this plan.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Gemma4App/Runtime/ASLGlossPrompt.swift Gemma4App.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Add ASLGlossPrompt building HF chat messages from vocab

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add `HFRouterClient.swift`

**Files:**
- Create: `ios/Gemma4App/Runtime/HFRouterClient.swift`

- [ ] **Step 1: Write the file**

Create `ios/Gemma4App/Runtime/HFRouterClient.swift` with the following content:

```swift
import Foundation

enum HFRouterError: LocalizedError {
    case invalidToken
    case rateLimited
    case upstream(status: Int)
    case timeout
    case transport(Error)
    case unparseable

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid HuggingFace token."
        case .rateLimited:
            return "HuggingFace rate-limited. Try again shortly."
        case .upstream(let status):
            return "HuggingFace error (HTTP \(status))."
        case .timeout:
            return "HuggingFace request timed out."
        case .transport:
            return "Network error. Check your connection."
        case .unparseable:
            return "Model returned no usable content."
        }
    }
}

struct HFRouterClient {
    static let routerURL = URL(string: "https://router.huggingface.co/v1/chat/completions")!
    static let model = "google/gemma-4-31B-it:deepinfra"
    static let timeout: TimeInterval = 30

    private let session: URLSession
    private let token: String

    init(session: URLSession? = nil, token: String) {
        self.token = token
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = Self.timeout
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: cfg)
        }
    }

    func call(messages: [[String: String]]) async throws -> String {
        var request = URLRequest(url: Self.routerURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "model": Self.model,
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 80,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw HFRouterError.timeout
        } catch {
            throw HFRouterError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HFRouterError.upstream(status: -1)
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw HFRouterError.invalidToken
        case 429:
            throw HFRouterError.rateLimited
        default:
            throw HFRouterError.upstream(status: http.statusCode)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw HFRouterError.unparseable
        }

        return content
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
```

- [ ] **Step 3: Build**

Run the build command from the top of this plan.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Gemma4App/Runtime/HFRouterClient.swift Gemma4App.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Add HFRouterClient POSTing to HuggingFace router

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add `ASLGlossPostprocess.swift`

**Files:**
- Create: `ios/Gemma4App/Runtime/ASLGlossPostprocess.swift`

- [ ] **Step 1: Write the file**

Create `ios/Gemma4App/Runtime/ASLGlossPostprocess.swift` with the following content. The four helpers (`extractGlossLine`, `mergeMultiWord`, `classify`, `reconstructGloss`) mirror the Python `app/postprocess.py` ones.

```swift
import Foundation

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
    private static let glossHeader = try! NSRegularExpression(
        pattern: "asl\\s*gloss\\s*:",
        options: .caseInsensitive
    )
    private static let trailingQuestion = try! NSRegularExpression(
        pattern: "\\s*\\?\\s*$"
    )

    static func process(rawModelOutput: String, vocab: VocabIndex) throws -> ProcessedGloss {
        let (line, isQuestion) = extractGlossLine(rawModelOutput)
        if line.isEmpty {
            throw ASLGlossPostprocessError.emptyGloss
        }

        let rawTokens = line
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        let merged = mergeMultiWord(rawTokens, vocab)

        var outTokens: [String] = []
        var unknown: [String] = []
        for tok in merged {
            let (emit, unk) = classify(tok, vocab: vocab)
            outTokens.append(emit)
            if let u = unk { unknown.append(u) }
        }

        let gloss = reconstructGloss(outTokens, isQuestion: isQuestion)
        return ProcessedGloss(
            gloss: gloss,
            tokens: outTokens,
            unknownTokens: unknown,
            isQuestion: isQuestion
        )
    }

    private static func extractGlossLine(_ raw: String) -> (line: String, isQuestion: Bool) {
        var text = raw
        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = glossHeader.matches(in: text, range: fullRange)
        if let last = matches.last,
           let swiftRange = Range(last.range, in: text) {
            text = String(text[swiftRange.upperBound...])
        }

        var line = ""
        for candidate in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let stripped = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty {
                line = stripped
                break
            }
        }

        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripChars: Set<Character> = ["\"", "'", "`"]
        while let first = line.first, stripChars.contains(first) {
            line.removeFirst()
        }
        while let last = line.last, stripChars.contains(last) {
            line.removeLast()
        }

        let lineRange = NSRange(line.startIndex..., in: line)
        let isQuestion = trailingQuestion.firstMatch(in: line, range: lineRange) != nil
        if isQuestion {
            let replaced = trailingQuestion.stringByReplacingMatches(
                in: line, range: lineRange, withTemplate: "")
            line = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (line, isQuestion)
    }

    private static func mergeMultiWord(_ raw: [String], _ vocab: VocabIndex) -> [String] {
        var out: [String] = []
        var i = 0
        while i < raw.count {
            var merged = false
            for words in vocab.multiWord {
                let n = words.count
                if i + n > raw.count { continue }
                let window = raw[i..<(i + n)].joined(separator: " ").lowercased()
                if let canonical = vocab.lookup[window] {
                    out.append(canonical)
                    i += n
                    merged = true
                    break
                }
            }
            if !merged {
                out.append(raw[i])
                i += 1
            }
        }
        return out
    }

    private static func classify(_ token: String, vocab: VocabIndex) -> (emit: String, unknown: String?) {
        if token.uppercased().hasPrefix("FS-") {
            let rest = String(token.dropFirst(3))
            return ("FS-" + rest.uppercased(), nil)
        }
        if let canonical = vocab.lookup[token] {
            return (canonical, nil)
        }
        let upper = token.uppercased()
        if let canonical = vocab.lookup[upper] {
            return (canonical, nil)
        }
        return ("FS-" + upper, upper)
    }

    private static func reconstructGloss(_ tokens: [String], isQuestion: Bool) -> String {
        let parts = tokens.map { token -> String in
            token.uppercased().hasPrefix("FS-") ? token : token.uppercased()
        }
        var s = parts.joined(separator: " ")
        if isQuestion { s += "?" }
        return s
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
```

- [ ] **Step 3: Build**

Run the build command from the top of this plan.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Gemma4App/Runtime/ASLGlossPostprocess.swift Gemma4App.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
Add ASLGlossPostprocess parsing model output into gloss tokens

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Rewrite `ASLTranslationService.swift` as the orchestrator

**Files:**
- Modify: `ios/Gemma4App/Runtime/ASLTranslationService.swift` (full replacement)

- [ ] **Step 1: Replace the file contents**

Overwrite `ios/Gemma4App/Runtime/ASLTranslationService.swift` with:

```swift
import Foundation

struct ASLTranslationResponse: Decodable, Equatable {
    let gloss: String
    let tokens: [String]
    let unknownTokens: [String]
    let isQuestion: Bool
    let model: String

    enum CodingKeys: String, CodingKey {
        case gloss
        case tokens
        case model
        case unknownTokens = "unknown_tokens"
        case isQuestion = "is_question"
    }
}

enum ASLTranslationError: LocalizedError {
    case missingToken
    case vocabUnavailable(ASLVocabError)
    case router(HFRouterError)
    case unparseableGloss

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "HF_TOKEN is not configured in Info.plist."
        case .vocabUnavailable(.missingResource):
            return "signs.txt is missing from the app bundle."
        case .vocabUnavailable(.emptyFile):
            return "signs.txt is empty after filtering."
        case .router(let inner):
            return inner.errorDescription
        case .unparseableGloss:
            return "Model returned no usable gloss."
        }
    }
}

struct ASLTranslationService {
    private static let tokenKey = "HF_TOKEN"

    private let vocab: VocabIndex
    private let client: HFRouterClient

    init(session: URLSession? = nil, bundle: Bundle = .main) throws {
        let rawToken = (bundle.object(forInfoDictionaryKey: Self.tokenKey) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawToken.isEmpty else { throw ASLTranslationError.missingToken }

        do {
            self.vocab = try ASLVocab.load(bundle: bundle)
        } catch let e as ASLVocabError {
            throw ASLTranslationError.vocabUnavailable(e)
        }

        self.client = HFRouterClient(session: session, token: rawToken)
    }

    func translate(text: String) async throws -> ASLTranslationResponse {
        let messages = ASLGlossPrompt.messages(text: text, vocab: vocab)

        let raw: String
        do {
            raw = try await client.call(messages: messages)
        } catch let e as HFRouterError {
            throw ASLTranslationError.router(e)
        }

        let processed: ProcessedGloss
        do {
            processed = try ASLGlossPostprocess.process(rawModelOutput: raw, vocab: vocab)
        } catch {
            throw ASLTranslationError.unparseableGloss
        }

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

The replacement removes the proxy-specific error cases (`missingBaseURL`, `invalidResponse(status:)`, `decodingFailed`, `transport(Error)`) and the manual `URLSession` POST. The public surface — `ASLTranslationResponse` shape and `ASLTranslationService.init(session:bundle:)` / `translate(text:)` signatures — stays identical so `TextTranslationViewModel` compiles without edits.

- [ ] **Step 2: Build**

No new files were added, so xcodegen is not required. Run the build command from the top of this plan.
Expected: `** BUILD SUCCEEDED **`. If `TextTranslationViewModel.swift` fails to compile, the orchestrator's public API diverged from what the VM expects — recheck `ASLTranslationResponse` field names and `ASLTranslationService.init` / `translate(text:)` signatures.

- [ ] **Step 3: Commit**

```bash
git add Gemma4App/Runtime/ASLTranslationService.swift
git commit -m "$(cat <<'EOF'
Rewrite ASLTranslationService to call HF router directly

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Manual simulator validation

This task runs the spec's nine-step validation plan against the simulator. No code is written here unless a defect is found, in which case loop back to the relevant task above.

**Prerequisites:**
- A valid HuggingFace token with access to `google/gemma-4-31B-it:deepinfra`.
- Xcode 16.x with an iOS 17 simulator runtime installed.
- The FastAPI server at `Gemma4_ASL/` is **not** running (so we prove the iOS app isn't hitting it).

- [ ] **Step 1: Paste a real HF token into `project.yml`**

Edit `ios/project.yml`, find the `HF_TOKEN: ""` line, replace `""` with the actual token (quoted), e.g. `HF_TOKEN: "hf_abc123..."`.

- [ ] **Step 2: Regenerate and rebuild**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Gemma4App.xcodeproj \
  -scheme Gemma4App -sdk iphonesimulator \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Confirm bundle hygiene (spec validation steps 2–3)**

```bash
plutil -p ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphonesimulator/Gemma4App.app/Info.plist \
  | grep -E 'HF_TOKEN|ASL_API_BASE_URL|NSAppTransportSecurity'
ls ~/Library/Developer/Xcode/DerivedData/Gemma4App-*/Build/Products/Debug-iphonesimulator/Gemma4App.app/signs.txt
```

Expected: only `HF_TOKEN` appears in `plutil` output (with the real token value); `signs.txt` is listed.

- [ ] **Step 4: Launch the app in the simulator**

Open `Gemma4App.xcodeproj` in Xcode and run the app on an iOS 17 simulator. Confirm `TextPlaceholderView` (the text-to-ASL screen) is reachable from the home screen.

- [ ] **Step 5: Happy path — statement (spec validation step 4)**

In `TextPlaceholderView`, type `I am going to the store tomorrow` and tap Translate.
Expected: chips render `TOMORROW`, `STORE`, `ME`, `GO`; the player auto-plays each clip in sequence, advances on end, loops after the last.

- [ ] **Step 6: Question path (spec validation step 5)**

Type `Where is the bathroom?` and tap Translate.
Expected: chips render `BATHROOM`, `WHERE` (no separate `?` chip). The translation completes without error. The current UI doesn't surface `isQuestion`, but the response payload internally carries `isQuestion = true` — verify by setting a breakpoint in `TextTranslationViewModel.performTranslate` (or print) and checking `response.isQuestion`.

- [ ] **Step 7: Fingerspelling path (spec validation step 6)**

Type `My friend Sarah is here` and tap Translate.
Expected: among the chips is one labelled `SARAH (FS)`; tapping it plays five letter clips (`s`, `a`, `r`, `a`, `h`) in sequence before continuing.

- [ ] **Step 8: Multi-word merging (spec validation step 7)**

Type `Thank you for the ice cream` and tap Translate.
Expected: chips include single canonical signs `THANK YOU` and `ICE CREAM`, not four separate `FS-` letters. Both clips play through their Handspeak videos.

- [ ] **Step 9: Error path — empty token (spec validation step 8a)**

Edit `project.yml`, set `HF_TOKEN: ""`, run `xcodegen generate`, rebuild, relaunch.
Type any sentence and tap Translate.
Expected: red error card reads `HF_TOKEN is not configured in Info.plist.`

- [ ] **Step 10: Error path — invalid token (spec validation step 8b)**

Edit `project.yml`, set `HF_TOKEN: "hf_obviously_wrong"`, run `xcodegen generate`, rebuild, relaunch.
Type any sentence and tap Translate.
Expected: red error card reads `Invalid HuggingFace token.`

- [ ] **Step 11: Error path — offline (spec validation step 8c)**

Restore the real `HF_TOKEN`, rebuild, relaunch. Then in the simulator menu choose **Features → Network Link Conditioner → 100% Loss** (or toggle the host Mac's Wi‑Fi off).
Type any sentence and tap Translate.
Expected: red error card reads `Network error. Check your connection.`. Re-enable networking before continuing.

- [ ] **Step 12: Photo-flow smoke test (spec validation step 9)**

From the home screen, switch to the camera/photo flow (`CameraRecognitionView`). Take or pick an image and confirm the existing translation flow still runs and shows a result.
Expected: no regression; the photo flow behaves as it did before this branch.

- [ ] **Step 13: Reset `HF_TOKEN` to empty before pushing**

Restore `HF_TOKEN: ""` in `project.yml` and run `xcodegen generate` so the committed config doesn't ship a real token. The token regeneration in Step 2 produced a transient `Info.plist` / `project.pbxproj`; reverting `project.yml` and regenerating restores them.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
git diff project.yml Gemma4App/Info.plist Gemma4App.xcodeproj/project.pbxproj
```

Expected: the diff against the previous committed state is either empty or only re-canonicalises `project.pbxproj`. Commit any canonicalisation:

```bash
git add project.yml Gemma4App/Info.plist Gemma4App.xcodeproj/project.pbxproj
git diff --cached --quiet || git commit -m "$(cat <<'EOF'
Reset HF_TOKEN to empty after manual validation

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

(The `git diff --cached --quiet` guard skips the commit when there's nothing staged.)

If any of steps 5–12 fail, do not mark the task complete. Diagnose, return to the relevant earlier task, fix, build, commit, then resume from the failed validation step.

---

## End of plan
