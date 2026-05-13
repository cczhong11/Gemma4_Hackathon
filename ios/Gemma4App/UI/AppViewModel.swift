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
        let installedURL = ModelPaths.installed(for: model)
        let isAvailable = installedURL != nil
        let resolvedPath = installedURL?.path
        let missingFiles: [String]
        let installState: ModelInstallState

        if isDownloaded {
            installState = .downloaded
            missingFiles = []
        } else if bundledURL != nil {
            installState = .bundled
            missingFiles = []
        } else {
            installState = .notInstalled
            missingFiles = model.requiredFiles.filter {
                !FileManager.default.fileExists(atPath: downloadedURL.appendingPathComponent($0).path)
            }
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

    enum TranslationMode {
        case betterSigns
        case offline
    }

    @Published var capturedImage: UIImage?
    @Published var recognitionResult = ""
    @Published var suggestedKeywords: [String] = []
    @Published var signVideos: [ASLSignVideo] = []
    @Published var photoCategories: [PhotoRecognitionCategory] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isLoadingSignVideos = false
    @Published var modelStatus: Gemma4ModelStatus
    @Published var isDownloadingModel = false
    @Published var selectedTranslationMode: TranslationMode = .betterSigns

    private var modelStatusPollingTask: Task<Void, Never>?
    private lazy var offlineRecognitionService = ImageRecognitionService()
    private let aslVideoLookupService = ASLVideoLookupService()
    private lazy var runtime = Gemma4Loader.sharedRuntime()

    init() {
        self.modelStatus = LocalModelStatus.snapshot(modelID: Self.defaultModelID)
    }

    func setCapturedImage(_ image: UIImage) {
        capturedImage = image
        recognitionResult = ""
        suggestedKeywords = []
        signVideos = []
        photoCategories = []
        isLoadingSignVideos = false
        errorMessage = nil
    }

    func recognizeCapturedImage() async {
        guard let image = capturedImage else {
            errorMessage = "Please take or choose a photo first."
            return
        }

        isLoading = true
        isLoadingSignVideos = false
        suggestedKeywords = []
        signVideos = []
        photoCategories = []
        errorMessage = nil

        do {
            let recognitionService = try makeRecognitionService(for: selectedTranslationMode)
            let analysis = try await recognitionService.analyze(image: image)
            recognitionResult = analysis.description
            suggestedKeywords = analysis.keywords
            var builtCategories: [PhotoRecognitionCategory] = []

            if !analysis.categories.isEmpty {
                isLoadingSignVideos = true
                for category in analysis.categories {
                    let videos = category.keywords.isEmpty ? [] : await aslVideoLookupService.lookup(words: category.keywords)
                    builtCategories.append(
                        PhotoRecognitionCategory(
                            label: category.label,
                            text: category.text,
                            gloss: category.gloss,
                            keywords: category.keywords,
                            signVideos: videos
                        )
                    )
                }
                isLoadingSignVideos = false
            }

            photoCategories = builtCategories
            signVideos = builtCategories.first?.signVideos ?? []
        } catch {
            recognitionResult = ""
            suggestedKeywords = []
            signVideos = []
            photoCategories = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
        isLoadingSignVideos = false
        refreshModelStatus()
    }

    private func makeRecognitionService(for mode: TranslationMode) throws -> ImageRecognitionService {
        switch mode {
        case .offline:
            return offlineRecognitionService
        case .betterSigns:
            let imageAdapter = try HFImageToTextAdapter()
            let textAdapter = try HFTextToTextAdapter()
            return ImageRecognitionService(
                imageAdapterProvider: { imageAdapter },
                textAdapterProvider: { textAdapter }
            )
        }
    }

    func refreshModelStatus() {
        if isDownloadingModel {
            modelStatus = runtime.modelStatus()
        } else {
            modelStatus = LocalModelStatus.snapshot(modelID: Self.defaultModelID)
        }
    }

    func isOfflineModelAvailable() -> Bool {
        refreshModelStatus()
        return modelStatus.isAvailable
    }

    func selectBetterSignsMode() {
        selectedTranslationMode = .betterSigns
    }

    func enableOfflineModeIfAvailable() -> Bool {
        let isAvailable = isOfflineModelAvailable()
        if isAvailable {
            selectedTranslationMode = .offline
        }
        return isAvailable
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

    func deleteDownloadedModel() {
        guard let model = MLXLocalLLMService.availableModels.first(where: { $0.id == modelStatus.modelID }) else {
            errorMessage = "Could not find the selected model."
            return
        }

        let fileManager = FileManager.default
        let downloadedURL = ModelPaths.downloaded(for: model)
        let partialURL = ModelPaths.partial(for: model)
        var deletedAnything = false

        do {
            if fileManager.fileExists(atPath: downloadedURL.path) {
                try fileManager.removeItem(at: downloadedURL)
                deletedAnything = true
            }

            if fileManager.fileExists(atPath: partialURL.path) {
                try fileManager.removeItem(at: partialURL)
                deletedAnything = true
            }
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
            refreshModelStatus()
            return
        }

        if selectedTranslationMode == .offline {
            selectedTranslationMode = .betterSigns
        }

        if !deletedAnything {
            errorMessage = "No downloaded model was found to delete."
        } else {
            errorMessage = nil
        }

        refreshModelStatus()
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
