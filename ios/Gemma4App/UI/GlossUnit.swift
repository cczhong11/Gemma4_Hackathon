import Foundation

struct GlossUnit: Identifiable, Equatable {
    enum Kind: Equatable {
        case sign(String)
        case fingerspell(String)
    }

    let id: UUID
    let kind: Kind
    let videoRange: Range<Int>
    let displayLabel: String
    let isPlayable: Bool

    init(
        id: UUID = UUID(),
        kind: Kind,
        videoRange: Range<Int>,
        displayLabel: String,
        isPlayable: Bool
    ) {
        self.id = id
        self.kind = kind
        self.videoRange = videoRange
        self.displayLabel = displayLabel
        self.isPlayable = isPlayable
    }
}
