import Foundation

struct AudioCaptureSnapshot: Sendable {
    let pcm: [Float]
    let sampleRate: Double
    let channelCount: Int
    let duration: TimeInterval
    let rawFileData: Data?

    init(
        pcm: [Float],
        sampleRate: Double,
        channelCount: Int,
        duration: TimeInterval,
        rawFileData: Data? = nil
    ) {
        self.pcm = pcm
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.duration = duration
        self.rawFileData = rawFileData
    }
}
