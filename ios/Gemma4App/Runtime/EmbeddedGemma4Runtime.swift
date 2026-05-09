import CoreImage
import Foundation
import UIKit

struct Gemma4ModelStatus: Sendable {
    let modelID: String
    let displayName: String
    let installState: ModelInstallState
    let downloadMetrics: ModelDownloadMetrics?
    let isAvailable: Bool
    let downloadedPath: String
    let partialPath: String
    let resolvedPath: String?
    let missingFiles: [String]
}

final class EmbeddedGemma4Runtime {
    struct Configuration {
        var modelID = "gemma-4-e2b-it-4bit"
        var systemPrompt = "You are a helpful multimodal assistant. Describe the image contents accurately and answer in Chinese."
        var maxImageDimension: CGFloat = 1280
    }

    private let configuration: Configuration
    private let service: MLXLocalLLMService

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.service = MLXLocalLLMService(selectedModelID: configuration.modelID)
    }

    @discardableResult
    private func ensureSafeImageInference(for model: BundledModelOption) async throws -> MultimodalBudget? {
        #if canImport(UIKit)
        let isActive = await MainActor.run {
            UIApplication.shared.applicationState == .active
        }
        guard isActive else {
            log("preflight failed: app not active")
            throw MLXError.gpuExecutionRequiresForeground
        }
        #endif

        let (footprint, jetsamLimit) = MemoryStats.footprintMB()
        let headroom = MemoryStats.headroomMB
        let budget = try RuntimeBudgets.multimodal(
            profile: model.runtimeProfile,
            headroom: headroom,
            hasImages: true,
            hasAudio: false,
            modelDisplayName: model.displayName,
            fallbackRecommendation: "请关闭后台应用、改用更小的图片，或稍后重试。"
        )
        log(
            "preflight headroomMB=\(headroom), "
                + "footprintMB=\(Int(footprint)), "
                + "jetsamLimitMB=\(Int(jetsamLimit)), "
                + "imageSoftTokenCap=\(budget?.imageSoftTokenCap.map(String.init) ?? "n/a"), "
                + "model=\(model.displayName)"
        )

        return budget
    }

    private func log(_ message: String) {
        let line = "[Gemma4Runtime] \(message)"
        print(line)

        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let logURL = documents.appendingPathComponent("gemma4runtime.log")
        let data = (line + "\n").data(using: .utf8) ?? Data()
        if fm.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }

    func modelStatus() -> Gemma4ModelStatus {
        guard let model = MLXLocalLLMService.availableModels.first(where: { $0.id == configuration.modelID }) else {
            return Gemma4ModelStatus(
                modelID: configuration.modelID,
                displayName: configuration.modelID,
                installState: .failed("找不到模型配置"),
                downloadMetrics: nil,
                isAvailable: false,
                downloadedPath: "",
                partialPath: "",
                resolvedPath: nil,
                missingFiles: []
            )
        }

        service.refreshModelInstallStates()
        let installState = service.installState(for: model)
        let available = service.isModelAvailable(model)
        let downloadedURL = ModelPaths.downloaded(for: model)
        let downloadedPath = downloadedURL.path
        let partialPath = ModelPaths.partial(for: model).path
        let resolvedPath = available ? ModelPaths.resolve(for: model).path : nil
        let missingFiles = model.requiredFiles.filter {
            !FileManager.default.fileExists(atPath: downloadedURL.appendingPathComponent($0).path)
        }

        return Gemma4ModelStatus(
            modelID: model.id,
            displayName: model.displayName,
            installState: installState,
            downloadMetrics: service.downloadMetrics(for: model.id),
            isAvailable: available,
            downloadedPath: downloadedPath,
            partialPath: partialPath,
            resolvedPath: resolvedPath,
            missingFiles: missingFiles
        )
    }

    func downloadSelectedModel() async {
        await service.downloadModel(id: configuration.modelID)
    }

    func generateImageToText(request: Gemma4ImageToTextRequest) async throws -> Gemma4ImageToTextResponse {
        let modelID = configuration.modelID
        log("image-to-text requested, model=\(modelID)")
        guard let model = MLXLocalLLMService.availableModels.first(where: { $0.id == modelID }) else {
            throw Gemma4AdapterError.modelNotInstalled
        }

        try await ensureSafeImageInference(for: model)

        if !service.isModelAvailable(model) {
            log("model not available locally, starting download")
            await downloadSelectedModel()
            guard service.isModelAvailable(model) else {
                log("model still unavailable after download")
                throw Gemma4AdapterError.modelNotInstalled
            }
        }

        if !service.isLoaded || service.loadedModelID != modelID {
            log("loading model")
            try await service.load(modelID: modelID)
            log("model loaded")
        }

        try await ensureSafeImageInference(for: model)

        let preparedImage = request.image.normalizedForModel().resizedForModel(maxDimension: configuration.maxImageDimension)
        log("prepared image size=\(Int(preparedImage.size.width))x\(Int(preparedImage.size.height))")

        guard let ciImage = CIImage(image: preparedImage) else {
            log("failed to create CIImage")
            throw Gemma4AdapterError.imageConversionFailed
        }

        log("starting multimodal generation")
        let stream = service.generateMultimodal(
            images: [ciImage],
            audios: [],
            prompt: request.prompt,
            systemPrompt: configuration.systemPrompt
        )

        var response = ""
        for try await chunk in stream {
            response += chunk
        }
        log("generation finished, responseChars=\(response.count)")

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            log("generation produced empty output")
            throw Gemma4AdapterError.noVisualContent
        }

        return Gemma4ImageToTextResponse(text: trimmed)
    }

    func generateTextToText(prompt: String) async throws -> String {
        let modelID = configuration.modelID
        if !service.isLoaded || service.loadedModelID != modelID {
            log("loading model for text-to-text")
            try await service.load(modelID: modelID)
        }

        let stream = service.generate(prompt: prompt)
        var response = ""
        for try await chunk in stream {
            response += chunk
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension UIImage {
    func normalizedForModel() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedForModel(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else {
            return self
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct EmbeddedGemma4ImageToTextAdapter: Gemma4ImageToTextAdapter {
    private let runtime: EmbeddedGemma4Runtime

    init(runtime: EmbeddedGemma4Runtime) {
        self.runtime = runtime
    }

    func generate(request: Gemma4ImageToTextRequest) async throws -> Gemma4ImageToTextResponse {
        try await runtime.generateImageToText(request: request)
    }
}

struct EmbeddedGemma4TextToTextAdapter: Gemma4TextToTextAdapter {
    private let runtime: EmbeddedGemma4Runtime

    init(runtime: EmbeddedGemma4Runtime) {
        self.runtime = runtime
    }

    func generate(prompt: String) async throws -> String {
        try await runtime.generateTextToText(prompt: prompt)
    }
}
