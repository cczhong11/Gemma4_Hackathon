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
