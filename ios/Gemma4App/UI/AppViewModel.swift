import SwiftUI
import UIKit

private enum LocalModelStatus {
    static func snapshot(modelID: String) -> Gemma4ModelStatus {
        guard let model = MLXLocalLLMService.availableModels.first(where: { $0.id == modelID }) else {
            return Gemma4ModelStatus(
                modelID: modelID,
                displayName: modelID,
                installState: .failed("找不到模型配置"),
                downloadMetrics: nil,
                isAvailable: false,
                downloadedPath: "",
                partialPath: "",
                resolvedPath: nil,
                missingFiles: []
            )
        }

        let downloadedURL = ModelPaths.downloaded(for: model)
        let downloadedPath = downloadedURL.path
        let partialPath = ModelPaths.partial(for: model).path
        let bundledURL = ModelPaths.bundled(for: model)
        let isDownloaded = ModelPaths.hasRequiredFiles(model, at: downloadedURL)
        let isAvailable = bundledURL != nil || isDownloaded
        let resolvedPath = isAvailable ? ModelPaths.resolve(for: model).path : nil
        let missingFiles = model.requiredFiles.filter {
            !FileManager.default.fileExists(atPath: downloadedURL.appendingPathComponent($0).path)
        }
        let installState: ModelInstallState

        if bundledURL != nil {
            installState = .bundled
        } else if isDownloaded {
            installState = .downloaded
        } else {
            installState = .notInstalled
        }

        return Gemma4ModelStatus(
            modelID: model.id,
            displayName: model.displayName,
            installState: installState,
            downloadMetrics: nil,
            isAvailable: isAvailable,
            downloadedPath: downloadedPath,
            partialPath: partialPath,
            resolvedPath: resolvedPath,
            missingFiles: missingFiles
        )
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    private static let defaultModelID = "gemma-4-e2b-it-4bit"

    @Published var capturedImage: UIImage?
    @Published var recognitionResult = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var modelStatus: Gemma4ModelStatus
    @Published var isDownloadingModel = false

    private var modelStatusPollingTask: Task<Void, Never>?
    private lazy var recognitionService = ImageRecognitionService()
    private lazy var runtime = Gemma4Loader.sharedRuntime()

    init() {
        self.modelStatus = LocalModelStatus.snapshot(modelID: Self.defaultModelID)
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
        if isDownloadingModel {
            modelStatus = runtime.modelStatus()
        } else {
            modelStatus = LocalModelStatus.snapshot(modelID: Self.defaultModelID)
        }
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
