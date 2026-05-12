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
