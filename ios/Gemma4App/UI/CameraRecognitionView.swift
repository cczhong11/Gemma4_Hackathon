import SwiftUI
import UIKit

struct CameraRecognitionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    if let image = viewModel.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 260)
                            .overlay {
                                Text("还没有拍照")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }

                HStack(spacing: 12) {
                    Button("拍照") {
                        showingCamera = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("从相册选择") {
                        showingPhotoLibrary = true
                    }
                    .buttonStyle(.bordered)
                }

                Button("识别图片内容") {
                    Task {
                        await viewModel.recognizeCapturedImage()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.capturedImage == nil || viewModel.isLoading)

                if viewModel.isLoading {
                    ProgressView("识别中...")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if !viewModel.recognitionResult.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("识别结果")
                            .font(.headline)
                        Text(viewModel.recognitionResult)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("拍照识别")
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker(sourceType: .camera) { image in
                viewModel.setCapturedImage(image)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            CameraImagePicker(sourceType: .photoLibrary) { image in
                viewModel.setCapturedImage(image)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CameraRecognitionView(viewModel: AppViewModel())
    }
}
