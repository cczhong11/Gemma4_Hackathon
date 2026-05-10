import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 20) {
                            NavigationLink {
                                CameraRecognitionView(viewModel: viewModel)
                            } label: {
                                Text("拍照识别")
                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink {
                                TextPlaceholderView()
                            } label: {
                                Text("文字功能")
                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            }
                            .buttonStyle(.bordered)

                            modelCard
                        }
                        .padding(24)
                    }
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .top
                    )
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .top
                )
            }
            .navigationTitle("Gemma 4")
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                viewModel.refreshModelStatus()
                viewModel.ensureModelStatusPolling()
            }
        }
    }

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模型下载")
                .font(.headline)

            Text(viewModel.modelStatus.displayName)
                .font(.subheadline.weight(.semibold))

            Text("状态：\(installStateText(viewModel.modelStatus.installState))")
                .font(.subheadline)

            if let metrics = viewModel.modelStatus.downloadMetrics {
                Text(downloadText(metrics))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let fractionCompleted = downloadFraction(metrics) {
                    ProgressView(value: fractionCompleted)
                }
                
                if let etaText = remainingTimeText(metrics) {
                    Text("预计剩余时间：\(etaText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text("模型目录：\(viewModel.modelStatus.downloadedPath)")
                .font(.footnote)
                .textSelection(.enabled)

            Text("临时目录：\(viewModel.modelStatus.partialPath)")
                .font(.footnote)
                .textSelection(.enabled)

            if let resolvedPath = viewModel.modelStatus.resolvedPath {
                Text("当前使用：\(resolvedPath)")
                    .font(.footnote)
                    .textSelection(.enabled)
            } else {
                Text("当前使用：模型还没有下载完整")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.modelStatus.missingFiles.isEmpty {
                Text("缺少文件：\(viewModel.modelStatus.missingFiles.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(viewModel.isDownloadingModel ? "下载中..." : "下载模型") {
                    Task {
                        await viewModel.downloadModel()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isDownloadingModel || viewModel.modelStatus.isAvailable)

                Button("刷新状态") {
                    viewModel.refreshModelStatus()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func installStateText(_ state: ModelInstallState) -> String {
        switch state {
        case .notInstalled:
            return "未下载"
        case .checkingSource:
            return "检查下载源中"
        case .downloading(let completedFiles, let totalFiles, let currentFile):
            return "下载中 \(completedFiles)/\(totalFiles) - \(currentFile)"
        case .downloaded:
            return "已下载"
        case .bundled:
            return "已内置"
        case .failed(let message):
            return "下载失败: \(message)"
        }
    }

    private func downloadText(_ metrics: ModelDownloadMetrics) -> String {
        let receivedMB = Double(metrics.bytesReceived) / 1_048_576
        let totalText: String
        if let totalBytes = metrics.totalBytes {
            totalText = String(format: "%.1f MB / %.1f MB", receivedMB, Double(totalBytes) / 1_048_576)
        } else {
            totalText = String(format: "%.1f MB", receivedMB)
        }

        let speedText: String
        if let bytesPerSecond = metrics.bytesPerSecond {
            speedText = String(format: "，%.2f MB/s", bytesPerSecond / 1_048_576)
        } else {
            speedText = ""
        }

        let sourceText = metrics.sourceLabel.map { "，来源 \($0)" } ?? ""
        return "进度：\(totalText)\(speedText)\(sourceText)"
    }

    private func downloadFraction(_ metrics: ModelDownloadMetrics) -> Double? {
        guard let totalBytes = metrics.totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(metrics.bytesReceived) / Double(totalBytes), 0), 1)
    }

    private func remainingTimeText(_ metrics: ModelDownloadMetrics) -> String? {
        guard let totalBytes = metrics.totalBytes,
              totalBytes > metrics.bytesReceived,
              let bytesPerSecond = metrics.bytesPerSecond,
              bytesPerSecond > 0 else {
            return nil
        }

        let remainingSeconds = Double(totalBytes - metrics.bytesReceived) / bytesPerSecond
        let seconds = max(Int(remainingSeconds.rounded()), 0)

        if seconds < 60 {
            return "\(seconds) 秒"
        }

        let minutes = seconds / 60
        let leftoverSeconds = seconds % 60
        if minutes < 60 {
            return leftoverSeconds == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(leftoverSeconds) 秒"
        }

        let hours = minutes / 60
        let leftoverMinutes = minutes % 60
        return leftoverMinutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(leftoverMinutes) 分"
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
}
