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
