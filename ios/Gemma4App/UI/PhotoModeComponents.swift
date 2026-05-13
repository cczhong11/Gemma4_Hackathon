import AVKit
import SwiftUI
import UIKit

enum PhotoModePalette {
    static let background = Color(red: 245 / 255, green: 240 / 255, blue: 232 / 255)
    static let card = Color.white
    static let ink = Color(red: 19 / 255, green: 50 / 255, blue: 72 / 255)
    static let muted = Color(red: 105 / 255, green: 124 / 255, blue: 139 / 255)
    static let border = Color(red: 226 / 255, green: 216 / 255, blue: 202 / 255)
    static let green = Color(red: 38 / 255, green: 166 / 255, blue: 122 / 255)
    static let gold = Color(red: 250 / 255, green: 199 / 255, blue: 117 / 255)
    static let goldSoft = Color(red: 1.0, green: 0.96, blue: 0.87)
    static let navyCard = Color(red: 22 / 255, green: 52 / 255, blue: 74 / 255)
    static let navyPanel = Color(red: 38 / 255, green: 70 / 255, blue: 96 / 255)
    static let chip = Color(red: 29 / 255, green: 112 / 255, blue: 84 / 255)
}

struct PhotoModeHeader: View {
    let onModeTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("📸 Photo to ASL")
                    .font(HearmeTypography.brand(34))
                    .foregroundStyle(PhotoModePalette.ink)

                Text("Take a picture of words. We will sign them!")
                    .font(HearmeTypography.bodyStrong(19))
                    .foregroundStyle(PhotoModePalette.muted)
            }

            Spacer()

            Button(action: onModeTap) {
                ZStack {
                    Circle()
                        .fill(PhotoModePalette.goldSoft)
                        .frame(width: 58, height: 58)

                    Circle()
                        .stroke(PhotoModePalette.gold, lineWidth: 2)
                        .frame(width: 58, height: 58)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Text("🤟")
                                .font(.system(size: 22))
                        }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose translation mode")
        }
    }
}

struct PhotoModeActionRow: View {
    let onCameraTap: () -> Void
    let onPhotosTap: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            actionButton(icon: "📷", title: "Camera", fill: PhotoModePalette.green, foreground: .white, border: nil, action: onCameraTap)
            actionButton(icon: "🖼️", title: "Photos", fill: PhotoModePalette.card, foreground: PhotoModePalette.ink, border: PhotoModePalette.ink, action: onPhotosTap)
        }
    }

    private func actionButton(
        icon: String,
        title: String,
        fill: Color,
        foreground: Color,
        border: Color?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(icon)
                    .font(.system(size: 26))
                Text(title)
                    .font(HearmeTypography.brand(26))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(fill)
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(border, lineWidth: 2.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PhotoSelectedImageCard: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .background(PhotoModePalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(PhotoModePalette.border, lineWidth: 1.5)
            }
    }
}

struct PhotoAnalyzeButton: View {
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("🤟")
                    .font(.system(size: 28))
                Text("Sign it!")
                    .font(HearmeTypography.brand(26))
            }
            .foregroundStyle(.white.opacity(isLoading ? 0.72 : 1))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(isLoading ? PhotoModePalette.green.opacity(0.55) : PhotoModePalette.green)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct PhotoStatusCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(PhotoModePalette.green)
            Text(title)
                .font(HearmeTypography.section(19))
                .foregroundStyle(PhotoModePalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(PhotoModePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(PhotoModePalette.border, lineWidth: 1.5)
        }
    }
}

struct PhotoMessageCard: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(HearmeTypography.bodyStrong(17))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(PhotoModePalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(PhotoModePalette.border, lineWidth: 1.5)
            }
    }
}

struct PhotoPlaybackSection: View {
    let player: AVPlayer
    let hasVideo: Bool
    let isLoadingSignVideos: Bool
    let activeIssue: (title: String, body: String)?
    let activeLabel: String?
    let activeIsFingerspelled: Bool
    let playbackProgress: CGFloat
    let playbackSpeeds: [String]
    let selectedPlaybackSpeed: String
    let videoHeight: CGFloat
    let onPlayTap: () -> Void
    let onSpeedTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(PhotoModePalette.navyCard)
                    .frame(height: videoHeight)

                if hasVideo {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .frame(height: videoHeight)
                } else {
                    VStack(spacing: 10) {
                        Text("Tap PLAY or any word above")
                            .font(HearmeTypography.section(18))
                            .foregroundStyle(Color.white.opacity(0.82))

                        if isLoadingSignVideos {
                            Text("Loading sign clips...")
                                .font(HearmeTypography.body(15))
                                .foregroundStyle(Color.white.opacity(0.68))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: videoHeight)
                }

                if isLoadingSignVideos {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .frame(height: videoHeight)
                        .overlay {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text("Preparing videos")
                                    .font(HearmeTypography.label(14))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .tracking(1)
                            }
                        }
                }

                if let activeIssue {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activeIssue.title)
                            .font(HearmeTypography.label(12))
                            .foregroundStyle(PhotoModePalette.gold)
                            .tracking(1.2)
                        Text(activeIssue.body)
                            .font(HearmeTypography.bodyStrong(17))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.black.opacity(0.34))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }

                if let activeLabel {
                    Text(activeLabel)
                        .font(HearmeTypography.label(12))
                        .foregroundStyle(activeIsFingerspelled ? PhotoModePalette.ink : .white)
                        .tracking(1.1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(activeIsFingerspelled ? PhotoModePalette.gold : PhotoModePalette.green)
                        .clipShape(Capsule())
                        .padding(18)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PhotoModePalette.border)
                    Capsule()
                        .fill(PhotoModePalette.green)
                        .frame(width: max(10, geometry.size.width * playbackProgress))
                }
            }
            .frame(height: 10)

            HStack(spacing: 12) {
                Button(action: onPlayTap) {
                    Text("PLAY")
                        .font(HearmeTypography.section(20))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(PhotoModePalette.green)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(playbackSpeeds, id: \.self) { speed in
                    Button {
                        onSpeedTap(speed)
                    } label: {
                        Text(speed)
                            .font(HearmeTypography.gloss(16))
                            .foregroundStyle(selectedPlaybackSpeed == speed ? .white : PhotoModePalette.ink)
                            .frame(width: 84, height: 84)
                            .background(selectedPlaybackSpeed == speed ? PhotoModePalette.ink : PhotoModePalette.background)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(selectedPlaybackSpeed == speed ? PhotoModePalette.ink : PhotoModePalette.border, lineWidth: 2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PhotoTranslationCard: View {
    let originalText: String
    let glossText: String
    let glossWords: [String]
    let chipBackground: (String) -> Color
    let chipBorder: (String) -> Color
    let chipLineWidth: (String) -> CGFloat
    let chipDash: (String) -> [CGFloat]
    let cardHeight: CGFloat
    let sourcePageURL: URL?
    let onWordTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TRANSLATION CARD")
                .font(HearmeTypography.label(15))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.84))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    infoPanel(title: "ORIGINAL", body: originalText)
                    infoPanel(title: "ASL GLOSS", body: glossText, fill: PhotoModePalette.green)

                    Text("Words I found")
                        .font(HearmeTypography.section(15))
                        .foregroundStyle(.white.opacity(0.94))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 14)], alignment: .leading, spacing: 14) {
                        ForEach(glossWords, id: \.self) { word in
                            Button {
                                onWordTap(word)
                            } label: {
                                Text(word)
                                    .font(HearmeTypography.gloss(16))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 22)
                                    .background(chipBackground(word))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(
                                                chipBorder(word),
                                                style: StrokeStyle(
                                                    lineWidth: chipLineWidth(word),
                                                    dash: chipDash(word)
                                                )
                                            )
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Yellow dashed = no ASL clip in library, auto-fingerspelled")
                        .font(HearmeTypography.bodyStrong(13))
                        .foregroundStyle(Color.white.opacity(0.82))

                    if let sourcePageURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SOURCE PAGE")
                                .font(HearmeTypography.label(11))
                                .tracking(1.5)
                                .foregroundStyle(Color.white.opacity(0.7))

                            Link(destination: sourcePageURL) {
                                Text(sourcePageURL.absoluteString)
                                    .font(HearmeTypography.bodyStrong(13))
                                    .foregroundStyle(Color.white.opacity(0.92))
                                    .underline()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.trailing, 6)
            }
            .frame(height: cardHeight)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(PhotoModePalette.navyCard)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func infoPanel(title: String, body: String, fill: Color = PhotoModePalette.navyPanel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(HearmeTypography.label(14))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.82))

            Text(body)
                .font(HearmeTypography.bodyStrong(18))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct PhotoCategoryTabs: View {
    let categories: [PhotoRecognitionCategory]
    let activeIndex: Int
    let onTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📝 Text blocks")
                .font(HearmeTypography.section(18))
                .foregroundStyle(PhotoModePalette.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        Button {
                            onTap(index)
                        } label: {
                            Text(category.label)
                                .font(HearmeTypography.label(13))
                                .foregroundStyle(activeIndex == index ? .white : PhotoModePalette.ink)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(activeIndex == index ? PhotoModePalette.ink : PhotoModePalette.card)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(activeIndex == index ? PhotoModePalette.ink : PhotoModePalette.border, lineWidth: 1.5)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }
}

struct PhotoModeBottomTabBar: View {
    let isTypeActive: Bool
    let isPhotoActive: Bool
    let onTypeTap: () -> Void
    let onPhotoTap: () -> Void

    var body: some View {
        HStack {
            Spacer()
            tabItem(icon: "text.bubble", title: "Type", isActive: isTypeActive, action: onTypeTap)
            Spacer()
            tabItem(icon: "camera", title: "Photo", isActive: isPhotoActive, action: onPhotoTap)
            Spacer()
        }
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(PhotoModePalette.background)
                .overlay(alignment: .top) {
                    Divider()
                        .overlay(PhotoModePalette.border)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isActive ? .semibold : .regular))
                Text(title)
                    .font(HearmeTypography.gloss(13))
            }
            .foregroundStyle(isActive ? PhotoModePalette.ink : PhotoModePalette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct PhotoModeSheet: View {
    let selectedMode: AppViewModel.TranslationMode
    let offlineSubtitle: String
    let onBetterSignsTap: () -> Void
    let onOfflineTap: () -> Void
    let modelSettingsCard: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule()
                .fill(PhotoModePalette.border)
                .frame(width: 88, height: 8)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("Translation mode")
                .font(HearmeTypography.brand(30))
                .foregroundStyle(PhotoModePalette.ink)

            Text("Pick how Hearme makes the sign for each word.")
                .font(HearmeTypography.bodyStrong(18))
                .foregroundStyle(PhotoModePalette.muted)

            option(icon: "🌟", title: "Better Signs", subtitle: "Enjoy high quality ASL with internet", badge: "RECOMMENDED", highlighted: selectedMode == .betterSigns, action: onBetterSignsTap)
            option(icon: "✈️", title: "Offline Mode", subtitle: offlineSubtitle, badge: nil, highlighted: selectedMode == .offline, action: onOfflineTap)
            modelSettingsCard
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(PhotoModePalette.background)
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private func option(
        icon: String,
        title: String,
        subtitle: String,
        badge: String?,
        highlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                Text(icon)
                    .font(.system(size: 38))

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(HearmeTypography.brand(24))
                        .foregroundStyle(PhotoModePalette.ink)

                    Text(subtitle)
                        .font(HearmeTypography.bodyStrong(16))
                        .foregroundStyle(PhotoModePalette.muted)
                }

                Spacer(minLength: 12)

                if let badge {
                    Text(badge)
                        .font(HearmeTypography.label(12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PhotoModePalette.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .background(PhotoModePalette.card)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(highlighted ? PhotoModePalette.green : PhotoModePalette.border, lineWidth: highlighted ? 4 : 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PhotoOfflineDownloadPrompt: View {
    let isDownloading: Bool
    let downloadStageEmoji: String
    let downloadPromptBody: String
    let downloadFraction: Double?
    let downloadStageText: String
    let downloadStatusText: String
    let onCancel: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(isDownloading ? downloadStageEmoji : "📥")
                .font(.system(size: 54))

            Text("Ready to download?")
                .font(HearmeTypography.brand(28))
                .foregroundStyle(PhotoModePalette.ink)

            Text(downloadPromptBody)
                .font(HearmeTypography.bodyStrong(17))
                .foregroundStyle(PhotoModePalette.muted)
                .multilineTextAlignment(.center)

            if isDownloading {
                ProgressView(value: downloadFraction)
                    .tint(PhotoModePalette.green)
                    .padding(.top, 4)

                Text(downloadStageText)
                    .font(HearmeTypography.section(18))
                    .foregroundStyle(PhotoModePalette.ink)

                Text(downloadStatusText)
                    .font(HearmeTypography.bodyStrong(14))
                    .foregroundStyle(PhotoModePalette.muted)
            }

            HStack(spacing: 16) {
                Button("Not now", action: onCancel)
                    .font(HearmeTypography.gloss(18))
                    .foregroundStyle(PhotoModePalette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(PhotoModePalette.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(PhotoModePalette.border, lineWidth: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .disabled(isDownloading)

                Button(action: onDownload) {
                    Text(isDownloading ? "Downloading..." : "👉 Yes, download!")
                        .font(HearmeTypography.gloss(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(PhotoModePalette.green)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isDownloading)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(PhotoModePalette.background)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

struct PhotoCelebrationOverlay: View {
    let mode: AppViewModel.TranslationMode
    let opacity: Double
    let scale: CGFloat
    let rotation: Double
    let sparkleLift: CGFloat

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text(mode == .offline ? "✈️" : "🤟")
                    .font(.system(size: 92))
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)

                Text(mode == .offline ? "Offline mode is ready" : "Better signs selected")
                    .font(HearmeTypography.brand(24))
                    .foregroundStyle(.white)

                Text(mode == .offline ? "Your app is ready to sign without internet." : "We'll use the richer internet-backed ASL flow.")
                    .font(HearmeTypography.bodyStrong(16))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 34)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(PhotoModePalette.navyCard.opacity(0.96))
            )
            .overlay(alignment: .topLeading) {
                Text("✨")
                    .font(.system(size: 28))
                    .offset(x: 6, y: -sparkleLift)
            }
            .overlay(alignment: .topTrailing) {
                Text("✨")
                    .font(.system(size: 32))
                    .offset(x: -4, y: -sparkleLift / 2)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("⭐")
                    .font(.system(size: 28))
                    .offset(x: 10, y: sparkleLift)
            }
            .padding(.horizontal, 28)
            .opacity(opacity)
        }
    }
}
