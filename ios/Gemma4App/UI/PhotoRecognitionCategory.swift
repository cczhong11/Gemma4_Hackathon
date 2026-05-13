import Foundation

struct PhotoRecognitionCategory: Identifiable {
    let id: UUID
    let label: String
    let text: String
    let keywords: [String]
    let signVideos: [ASLSignVideo]

    init(
        id: UUID = UUID(),
        label: String,
        text: String,
        keywords: [String],
        signVideos: [ASLSignVideo]
    ) {
        self.id = id
        self.label = label
        self.text = text
        self.keywords = keywords
        self.signVideos = signVideos
    }

    var glossText: String {
        keywords.joined(separator: " ").uppercased()
    }
}
