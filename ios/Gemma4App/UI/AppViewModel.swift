import SwiftUI
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var recognitionResult = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var modelStatus: Gemma4ModelStatus
    @Published var isDownloadingModel = false

    private let recognitionService: ImageRecognitionService
    private let runtime: EmbeddedGemma4Runtime
    private var modelStatusPollingTask: Task<Void, Never>?

    init(recognitionService: ImageRecognitionService = ImageRecognitionService()) {
        self.recognitionService = recognitionService
        self.runtime = Gemma4Loader.sharedRuntime()
        self.modelStatus = runtime.modelStatus()
    }

    func setCapturedImage(_ image: UIImage) {
        capturedImage = image
        recognitionResult = ""
        errorMessage = nil
    }

    func recognizeCapturedImage() async {
        guard let image = capturedImage else {
            errorMessage = "请先拍一张照片。"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            recognitionResult = try await recognitionService.describe(image: image)
        } catch {
            recognitionResult = ""
            errorMessage = error.localizedDescription
        }

        isLoading = false
        refreshModelStatus()
    }

    func refreshModelStatus() {
        modelStatus = runtime.modelStatus()
    }

    func downloadModel() async {
        isDownloadingModel = true
        errorMessage = nil
        startModelStatusPolling()
        await runtime.downloadSelectedModel()
        refreshModelStatus()
        isDownloadingModel = false
        stopModelStatusPolling()
    }

    func ensureModelStatusPolling() {
        let isActivelyDownloading: Bool
        if case .downloading = modelStatus.installState {
            isActivelyDownloading = true
        } else {
            isActivelyDownloading = false
        }

        if isActivelyDownloading || isDownloadingModel {
            startModelStatusPolling()
        } else {
            stopModelStatusPolling()
        }
    }

    private func startModelStatusPolling() {
        guard modelStatusPollingTask == nil else { return }
        modelStatusPollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.refreshModelStatus()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func stopModelStatusPolling() {
        modelStatusPollingTask?.cancel()
        modelStatusPollingTask = nil
    }
}
