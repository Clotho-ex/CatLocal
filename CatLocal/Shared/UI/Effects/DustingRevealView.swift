import SwiftUI
import UIKit

struct CutoutSpotlightRevealView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sourceImage: UIImage?
    let cutoutImage: UIImage
    var onCompleted: () -> Void

    @State private var hasStarted = false
    @State private var hasCompleted = false
    @State private var stickerScale: CGFloat
    @State private var stickerOpacity = 0.0
    @State private var sourceOpacity = 0.0
    @State private var sourceBlur: CGFloat = 14
    @State private var spotlightProgress = 0.0
    @State private var moteProgress = 0.0
    @State private var haloOpacity = 0.0
    @State private var haloScale: CGFloat = 0.96
    @State private var stickerYOffset: CGFloat = 28
    @State private var stickerPeelTilt = -18.0
    @State private var stickerRotation = -5.0
    @State private var peelSheenProgress = 0.0
    @State private var anchorBounds: CGRect?
    @State private var liftFeedbackTrigger = 0
    @State private var edgeFeedbackTrigger = 0
    @State private var landingFeedbackTrigger = 0

    init(
        sourceImage: UIImage?,
        cutoutImage: UIImage,
        onCompleted: @escaping () -> Void
    ) {
        self.sourceImage = sourceImage
        self.cutoutImage = cutoutImage
        self.onCompleted = onCompleted
        _stickerScale = State(initialValue: 1.16)
    }

    var body: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 18) {
                Spacer(minLength: 72)

                revealStage
                    .padding(.horizontal, 30)

                Text("Lifting the subject")
                    .font(CatTypography.pageTitle)
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text("A private sticker is taking shape.")
                    .font(CatTypography.supporting)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 120)
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        }
        .task { await startRevealIfNeeded() }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.42), trigger: liftFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: edgeFeedbackTrigger)
        .sensoryFeedback(.success, trigger: landingFeedbackTrigger)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lifting the cat subject")
        .accessibilityIdentifier("cutout-reveal")
    }

    private var revealStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(CatLocalTheme.cardSurface.opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(CatLocalTheme.imageOutline.opacity(0.42), lineWidth: 1)
                )

            sourceBackdrop

            if !reduceMotion {
                CutoutSpotlightBeam(progress: spotlightProgress)
                    .allowsHitTesting(false)
            }

            Image(uiImage: cutoutImage)
                .resizable()
                .scaledToFit()
                .padding(20)
                .opacity(haloOpacity)
                .scaleEffect(haloScale)
                .blur(radius: reduceMotion ? 0 : 15)
                .blendMode(.screen)
                .accessibilityHidden(true)

            if !reduceMotion {
                StickerPeelSheen(
                    image: cutoutImage,
                    progress: peelSheenProgress
                )
                .opacity(stickerOpacity)
                .scaleEffect(stickerScale)
                .rotationEffect(.degrees(stickerRotation))
                .rotation3DEffect(
                    .degrees(stickerPeelTilt),
                    axis: (x: 1, y: -0.18, z: 0),
                    perspective: 0.62
                )
                .offset(y: stickerYOffset)
                .accessibilityHidden(true)
            }

            StickerCutoutView(
                image: cutoutImage,
                appliesMotion: false
            )
            .opacity(stickerOpacity)
            .scaleEffect(stickerScale)
            .rotationEffect(.degrees(stickerRotation))
            .rotation3DEffect(
                .degrees(stickerPeelTilt),
                axis: (x: 1, y: -0.18, z: 0),
                perspective: 0.62
            )
            .offset(y: stickerYOffset)
            .accessibilityHidden(true)

            if !reduceMotion {
                CutoutMoteField(
                    progress: moteProgress,
                    anchorBounds: anchorBounds
                )
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: 290, maxHeight: 340)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: CatLocalTheme.shadow.opacity(0.12), radius: 18, x: 0, y: 9)
    }

    @ViewBuilder
    private var sourceBackdrop: some View {
        if let sourceImage {
            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFill()
                .blur(radius: sourceBlur)
                .saturation(0.82)
                .opacity(sourceOpacity)
                .overlay(CatLocalTheme.primaryText.opacity(sourceOpacity * 0.16))
                .clipped()
                .accessibilityHidden(true)
        }
    }

    private func startRevealIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.22)) {
                sourceOpacity = sourceImage == nil ? 0 : 0.18
                stickerScale = 1
                stickerOpacity = 1
                stickerYOffset = 0
                stickerPeelTilt = 0
                stickerRotation = 0
                haloOpacity = 0.18
            }
            try? await Task.sleep(for: .milliseconds(360))
            complete()
            return
        }

        Task { @MainActor in
            anchorBounds = await Self.visibleBounds(for: SendableImage(value: cutoutImage))
        }

        liftFeedbackTrigger += 1
        withAnimation(.smooth(duration: 0.5, extraBounce: 0)) {
            sourceOpacity = sourceImage == nil ? 0 : 0.34
            sourceBlur = 9
            spotlightProgress = 0.34
            haloOpacity = 0.16
            haloScale = 1.04
            stickerYOffset = 18
            stickerPeelTilt = -12
        }

        try? await Task.sleep(for: .milliseconds(700))
        edgeFeedbackTrigger += 1
        withAnimation(.smooth(duration: 1.0, extraBounce: 0)) {
            moteProgress = 0.5
            stickerScale = 1.04
            stickerOpacity = 0.78
            stickerYOffset = 7
            stickerPeelTilt = -4
            stickerRotation = -1.5
            peelSheenProgress = 0.78
            haloOpacity = 0.34
            spotlightProgress = 0.74
        }

        try? await Task.sleep(for: .milliseconds(1_050))
        withAnimation(.smooth(duration: 0.75, extraBounce: 0)) {
            sourceOpacity = sourceImage == nil ? 0 : 0.18
            sourceBlur = 12
            spotlightProgress = 1
            moteProgress = 1
            stickerScale = 1
            stickerOpacity = 1
            stickerYOffset = 0
            stickerPeelTilt = 0
            stickerRotation = 0
            peelSheenProgress = 1
            haloOpacity = 0.42
            haloScale = 1
        }

        try? await Task.sleep(for: .milliseconds(850))
        landingFeedbackTrigger += 1
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            stickerScale = 0.985
        }

        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
            stickerScale = 1
            haloOpacity = 0.24
        }

        try? await Task.sleep(for: .milliseconds(350))
        complete()
    }

    private static func visibleBounds(for image: SendableImage) async -> CGRect? {
        await Task.detached(priority: .utility) {
            image.value.cgImage.flatMap { DustingAnchorSampler.visibleBounds(in: $0) }
        }.value
    }

    @MainActor
    private func complete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        onCompleted()
    }
}

private struct CutoutSpotlightBeam: View, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                CatLocalTheme.warning.opacity(0.30 * progress),
                                CatLocalTheme.backgroundGlow.opacity(0.30 * progress),
                                CatLocalTheme.backgroundGlow.opacity(0)
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: min(width, height) * 0.42
                        )
                    )
                    .frame(width: width * 0.82, height: height * 0.58)
                    .blur(radius: 24)
                    .offset(y: height * 0.07)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0),
                                .white.opacity(0.16 * progress),
                                .white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.34, height: height * 0.82)
                    .rotationEffect(.degrees(-7))
                    .blur(radius: 20)
                    .offset(y: -height * 0.05)
            }
            .frame(width: width, height: height)
        }
        .blendMode(.screen)
    }
}

private struct StickerPeelSheen: View, Animatable {
    let image: UIImage
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    let travel = proxy.size.width * 1.3

                    LinearGradient(
                        colors: [
                            .white.opacity(0),
                            .white.opacity(0.38),
                            .white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: proxy.size.width * 0.34, height: proxy.size.height * 1.18)
                    .rotationEffect(.degrees(-18))
                    .blur(radius: 10)
                    .offset(x: -travel * 0.55 + travel * progress)
                }
                .mask(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                )
                .blendMode(.screen)
                .opacity(sin(min(progress, 1) * .pi) * 0.7)
            }
            .padding(16)
            .allowsHitTesting(false)
    }
}

private struct CutoutMoteField: View, Animatable {
    var progress: Double
    let anchorBounds: CGRect?

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private let motes: [Mote] = [
        Mote(x: 0.24, y: 0.30, dx: -12, dy: -24, size: 3, delay: 0.00, color: .white),
        Mote(x: 0.74, y: 0.28, dx: 16, dy: -22, size: 4, delay: 0.08, color: Color(red: 1.0, green: 0.92, blue: 0.74)),
        Mote(x: 0.18, y: 0.62, dx: -18, dy: 12, size: 3, delay: 0.18, color: CatLocalTheme.warning),
        Mote(x: 0.78, y: 0.66, dx: 18, dy: 14, size: 3, delay: 0.26, color: .white),
        Mote(x: 0.50, y: 0.16, dx: 4, dy: -28, size: 3, delay: 0.34, color: Color(red: 1.0, green: 0.96, blue: 0.82))
    ]

    var body: some View {
        Canvas { context, size in
            guard progress > 0 else { return }

            let rect = resolvedRect(in: size).insetBy(dx: -16, dy: -16)
            for mote in motes {
                let localProgress = min(max((progress - mote.delay) / 0.62, 0), 1)
                guard localProgress > 0 else { continue }

                let alpha = pow(1 - localProgress, 0.9) * 0.68
                let radius = mote.size * CGFloat(0.82 + localProgress * 0.6)
                let position = CGPoint(
                    x: rect.minX + rect.width * mote.x + mote.dx * CGFloat(localProgress),
                    y: rect.minY + rect.height * mote.y + mote.dy * CGFloat(localProgress)
                )
                let ellipse = CGRect(
                    x: position.x - radius / 2,
                    y: position.y - radius / 2,
                    width: radius,
                    height: radius
                )
                context.fill(
                    Path(ellipseIn: ellipse),
                    with: .color(mote.color.opacity(alpha))
                )
            }
        }
        .blendMode(.screen)
    }

    private func resolvedRect(in size: CGSize) -> CGRect {
        let normalized = anchorBounds ?? CGRect(x: 0.22, y: 0.16, width: 0.56, height: 0.68)
        return CGRect(
            x: normalized.minX * size.width,
            y: normalized.minY * size.height,
            width: normalized.width * size.width,
            height: normalized.height * size.height
        )
    }

    private struct Mote {
        let x: CGFloat
        let y: CGFloat
        let dx: CGFloat
        let dy: CGFloat
        let size: CGFloat
        let delay: Double
        let color: Color
    }
}

struct StickerCutoutView: View {
    let image: UIImage
    var appliesMotion: Bool

    var body: some View {
        stickerBody
            .compositingGroup()
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 8)
            .shadow(color: .white.opacity(0.32), radius: 2, x: 0, y: -1)
            .padding(16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cat sticker preview")
    }

    private var stickerBody: some View {
        ZStack {
            stickerImage
                .stickerOutline()

            stickerImage
        }
    }

    private var stickerImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
    }
}

private extension View {
    func stickerOutline() -> some View {
        self
            .shadow(color: .white.opacity(1), radius: 0, x: 0, y: 4)
            .shadow(color: .white.opacity(1), radius: 0, x: 0, y: -4)
            .shadow(color: .white.opacity(1), radius: 0, x: 4, y: 0)
            .shadow(color: .white.opacity(1), radius: 0, x: -4, y: 0)
            .shadow(color: .white.opacity(0.98), radius: 0, x: 3, y: 3)
            .shadow(color: .white.opacity(0.98), radius: 0, x: -3, y: 3)
            .shadow(color: .white.opacity(0.98), radius: 0, x: 3, y: -3)
            .shadow(color: .white.opacity(0.98), radius: 0, x: -3, y: -3)
            .shadow(color: .white.opacity(0.9), radius: 4, x: 0, y: 1)
    }
}

enum DustingAnchorSampler {
    static let defaultMaximumAnchors = 8

    static func visibleBounds(
        in image: CGImage,
        alphaThreshold: UInt8 = 18
    ) -> CGRect? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                guard pixels[offset + 3] > alphaThreshold else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(minY) / CGFloat(height),
            width: CGFloat(maxX - minX + 1) / CGFloat(width),
            height: CGFloat(maxY - minY + 1) / CGFloat(height)
        )
    }

    static func sampleVisibleAnchors(
        in image: CGImage,
        maximumAnchors: Int = defaultMaximumAnchors,
        alphaThreshold: UInt8 = 18
    ) -> [CGPoint] {
        guard maximumAnchors > 0 else { return [] }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return [] }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let targetSamples = max(maximumAnchors * 4, maximumAnchors)
        let step = max(1, Int(sqrt(Double(width * height) / Double(targetSamples))))
        var anchors: [CGPoint] = []
        anchors.reserveCapacity(maximumAnchors)

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                guard pixels[offset + 3] > alphaThreshold else { continue }
                anchors.append(
                    CGPoint(
                        x: CGFloat(x) / CGFloat(max(width - 1, 1)),
                        y: CGFloat(y) / CGFloat(max(height - 1, 1))
                    )
                )
            }
        }

        guard anchors.count > maximumAnchors else { return anchors }
        let stride = max(1, anchors.count / maximumAnchors)
        return anchors.enumerated()
            .compactMap { index, anchor in index.isMultiple(of: stride) ? anchor : nil }
            .prefix(maximumAnchors)
            .map(\.self)
    }
}
