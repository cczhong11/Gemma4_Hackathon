import AVKit
import SwiftUI
import UIKit

struct CameraRecognitionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea()

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
                                        Text("No photo selected yet")
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }

                        HStack(spacing: 12) {
                            Button("Take Photo") {
                                showingCamera = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Choose from Library") {
                                showingPhotoLibrary = true
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("Analyze Photo") {
                            Task {
                                await viewModel.recognizeCapturedImage()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.capturedImage == nil || viewModel.isLoading)

                        if viewModel.isLoading {
                            ProgressView("Analyzing...")
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }

                        if !viewModel.recognitionResult.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recognition Result")
                                    .font(.headline)
                                Text(viewModel.recognitionResult)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if !viewModel.suggestedKeywords.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Suggested Keywords")
                                    .font(.headline)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), alignment: .leading)], alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.suggestedKeywords, id: \.self) { keyword in
                                        Text(keyword)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if viewModel.isLoadingSignVideos {
                            ProgressView("Looking up sign videos...")
                        }

                        if !viewModel.signVideos.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sign Videos")
                                    .font(.headline)

                                ForEach(viewModel.signVideos) { sign in
                                    ASLSignVideoCard(sign: sign)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
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
        .navigationTitle("Photo Recognition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

private struct ASLSignVideoCard: View {
    let sign: ASLSignVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(sign.normalized)
                    .font(.headline)
                if let match = sign.match, match.lowercased() != sign.normalized {
                    Text("Matched \(match)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let localVideoURL = sign.localVideoURL {
                VideoPlayer(player: AVPlayer(url: localVideoURL))
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let reason = sign.reason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let error = sign.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        CameraRecognitionView(viewModel: AppViewModel())
    }
}
