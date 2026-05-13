import Foundation

struct PhotoRecognitionCategory: Identifiable {
    let id: UUID
    let label: String
    let text: String
    let gloss: String
    let keywords: [String]
    let signVideos: [ASLSignVideo]

    init(
        id: UUID = UUID(),
        label: String,
        text: String,
        gloss: String,
        keywords: [String],
        signVideos: [ASLSignVideo]
    ) {
        self.id = id
        self.label = label
        self.text = text
        self.gloss = gloss
        self.keywords = keywords
        self.signVideos = signVideos
    }

    var glossText: String {
        gloss
    }
}
