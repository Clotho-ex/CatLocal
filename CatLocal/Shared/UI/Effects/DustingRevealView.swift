import SwiftUI
import UIKit

struct DustingRevealView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let image: UIImage
    var onCompleted: () -> Void

    @State private var hasStarted = false
    @State private var hasCompleted = false
    @State private var stickerScale: CGFloat
    @State private var stickerOpacity = 0.0
    @State private var dustIsActive = false
    @State private var sweepProgress = 0.0
    @State private var anchorBounds: CGRect?

    init(image: UIImage, onCompleted: @escaping () -> Void) {
        self.image = image
        self.onCompleted = onCompleted
        _stickerScale = State(initialValue: 1.48)
    }

    var body: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 18) {
                Spacer(minLength: 72)

                ZStack {
                    StickerCutoutView(
                        image: image,
                        appliesMotion: false
                    )
                    .opacity(stickerOpacity)
                    .scaleEffect(stickerScale)
                    .accessibilityHidden(true)

                    if !reduceMotion {
                        StickerDustEmitterView(
                            anchorBounds: anchorBounds,
                            isActive: dustIsActive
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)

                        DustingSweepView(progress: sweepProgress)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)

                        DustingParticleField(
                            progress: sweepProgress,
                            anchorBounds: anchorBounds
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: 270, maxHeight: 330)
                .padding(.horizontal, 32)

                Text("Lifting the subject")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text("A private sticker is taking shape.")
                    .font(.subheadline)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 120)
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        }
        .task { await startRevealIfNeeded() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Creating cat sticker")
        .accessibilityIdentifier("dusting-reveal")
    }

    private func startRevealIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        if reduceMotion {
            stickerScale = 1
            stickerOpacity = 1
            try? await Task.sleep(for: .milliseconds(260))
            complete()
            return
        }

        Task { @MainActor in
            anchorBounds = await Self.visibleBounds(for: SendableImage(value: image))
        }
        dustIsActive = true
        withAnimation(.spring(response: 0.72, dampingFraction: 0.76)) {
            stickerScale = 1
            stickerOpacity = 1
        }
        withAnimation(.easeOut(duration: 1.8)) {
            sweepProgress = 1
        }

        try? await Task.sleep(for: .milliseconds(1_850))
        dustIsActive = false
        try? await Task.sleep(for: .milliseconds(450))
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

private struct DustingSweepView: View, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                guard progress > 0 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * (0.24 + (0.2 * progress))
                let alpha = sin(progress * .pi)
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                var path = Path()
                path.addEllipse(in: rect)
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(0.55 * alpha)),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [22, 18])
                )

                var warmPath = Path()
                warmPath.addEllipse(in: rect.insetBy(dx: -8, dy: -8))
                context.stroke(
                    warmPath,
                    with: .color(CatLocalTheme.warning.opacity(0.32 * alpha)),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 20])
                )
            }
        }
        .blendMode(.screen)
    }
}

private struct DustingParticleField: View, Animatable {
    var progress: Double
    let anchorBounds: CGRect?

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private let particles: [Particle] = [
        Particle(x: 0.18, y: 0.50, dx: -26, dy: -18, size: 5, delay: 0.00, color: Color(red: 1.0, green: 0.92, blue: 0.68)),
        Particle(x: 0.82, y: 0.46, dx: 24, dy: -24, size: 4, delay: 0.04, color: Color(red: 1.0, green: 0.78, blue: 0.32)),
        Particle(x: 0.50, y: 0.18, dx: -10, dy: -34, size: 4, delay: 0.08, color: .white),
        Particle(x: 0.50, y: 0.82, dx: 14, dy: 28, size: 5, delay: 0.12, color: Color(red: 0.96, green: 0.84, blue: 0.52)),
        Particle(x: 0.26, y: 0.28, dx: -24, dy: -26, size: 3, delay: 0.18, color: .white),
        Particle(x: 0.74, y: 0.72, dx: 26, dy: 22, size: 4, delay: 0.22, color: Color(red: 1.0, green: 0.88, blue: 0.44)),
        Particle(x: 0.30, y: 0.72, dx: -22, dy: 20, size: 4, delay: 0.28, color: Color(red: 1.0, green: 0.95, blue: 0.72)),
        Particle(x: 0.70, y: 0.25, dx: 20, dy: -30, size: 3, delay: 0.34, color: .white)
    ]

    var body: some View {
        Canvas { context, size in
            guard progress > 0 else { return }
            let rect = resolvedRect(in: size)
            for particle in particles {
                let localProgress = min(max((progress - particle.delay) / 0.62, 0), 1)
                guard localProgress > 0 else { continue }
                let alpha = pow(1 - localProgress, 0.8)
                let position = CGPoint(
                    x: rect.minX + rect.width * particle.x + particle.dx * CGFloat(localProgress),
                    y: rect.minY + rect.height * particle.y + particle.dy * CGFloat(localProgress)
                )
                let radius = particle.size * CGFloat(0.7 + localProgress * 0.8)
                let ellipse = CGRect(
                    x: position.x - radius / 2,
                    y: position.y - radius / 2,
                    width: radius,
                    height: radius
                )
                context.fill(
                    Path(ellipseIn: ellipse),
                    with: .color(particle.color.opacity(0.9 * alpha))
                )
            }
        }
        .blendMode(.screen)
    }

    private func resolvedRect(in size: CGSize) -> CGRect {
        let normalized = anchorBounds ?? CGRect(x: 0.2, y: 0.18, width: 0.6, height: 0.64)
        return CGRect(
            x: normalized.minX * size.width,
            y: normalized.minY * size.height,
            width: normalized.width * size.width,
            height: normalized.height * size.height
        ).insetBy(dx: -18, dy: -18)
    }

    private struct Particle {
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

struct StickerDustEmitterView: UIViewRepresentable {
    let anchorBounds: CGRect?
    let isActive: Bool

    func makeUIView(context: Context) -> DustEmitterUIView {
        DustEmitterUIView()
    }

    func updateUIView(_ uiView: DustEmitterUIView, context: Context) {
        uiView.configure(anchorBounds: anchorBounds, isActive: isActive)
    }
}

final class DustEmitterUIView: UIView {
    private let emitters = [CAEmitterLayer(), CAEmitterLayer(), CAEmitterLayer(), CAEmitterLayer()]
    private var wantsActive = false
    private var burstStarted = false
    private var currentAnchorBounds: CGRect?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        emitters.forEach { emitter in
            emitter.emitterShape = .point
            emitter.renderMode = .additive
            emitter.birthRate = 0
            layer.addSublayer(emitter)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitters.forEach { $0.frame = bounds }
        layoutEmitters(anchorBounds: currentAnchorBounds)
        if wantsActive, !burstStarted {
            startBurstIfReady()
        }
    }

    func configure(anchorBounds: CGRect?, isActive: Bool) {
        currentAnchorBounds = anchorBounds
        layoutEmitters(anchorBounds: anchorBounds)
        if isActive {
            wantsActive = true
            startBurstIfReady()
        } else {
            wantsActive = false
            burstStarted = false
            stopBurst()
        }
    }

    private func layoutEmitters(anchorBounds: CGRect?) {
        let normalized = anchorBounds ?? CGRect(x: 0.2, y: 0.18, width: 0.6, height: 0.64)
        let rect = CGRect(
            x: normalized.minX * bounds.width,
            y: normalized.minY * bounds.height,
            width: normalized.width * bounds.width,
            height: normalized.height * bounds.height
        ).insetBy(dx: -10, dy: -10)

        emitters[0].emitterPosition = CGPoint(x: rect.minX, y: rect.midY)
        emitters[1].emitterPosition = CGPoint(x: rect.maxX, y: rect.midY)
        emitters[2].emitterPosition = CGPoint(x: rect.midX, y: rect.minY)
        emitters[3].emitterPosition = CGPoint(x: rect.midX, y: rect.maxY)
    }

    private func startBurstIfReady() {
        guard bounds.width > 2, bounds.height > 2 else { return }
        guard !burstStarted else { return }
        burstStarted = true
        for (index, emitter) in emitters.enumerated() {
            emitter.emitterCells = [emitterCell(for: index)]
            emitter.beginTime = CACurrentMediaTime()
            emitter.birthRate = 0.8
        }
    }

    private func stopBurst() {
        emitters.forEach { $0.birthRate = 0 }
    }

    private func emitterCell(for index: Int) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = Self.particleImage.cgImage
        cell.birthRate = 18
        cell.duration = 0
        cell.lifetime = 0.78
        cell.lifetimeRange = 0.22
        cell.velocity = 54
        cell.velocityRange = 24
        cell.yAcceleration = 0
        cell.scale = 0.085
        cell.scaleRange = 0.04
        cell.scaleSpeed = -0.035
        cell.alphaSpeed = -1.25
        cell.spin = 1.8
        cell.spinRange = 3.2
        cell.emissionRange = .pi / 5
        cell.color = particleColor(for: index).cgColor
        cell.emissionLongitude = emissionLongitude(for: index)
        return cell
    }

    private func emissionLongitude(for index: Int) -> CGFloat {
        [CGFloat.pi, 0, -CGFloat.pi / 2, CGFloat.pi / 2][index]
    }

    private func particleColor(for index: Int) -> UIColor {
        let colors: [UIColor] = [
            UIColor(red: 1.00, green: 0.93, blue: 0.76, alpha: 1),
            UIColor(red: 0.97, green: 0.86, blue: 0.58, alpha: 1),
            UIColor(red: 1.00, green: 1.00, blue: 0.94, alpha: 1),
            UIColor(red: 0.92, green: 0.78, blue: 0.52, alpha: 1)
        ]
        return colors[index % colors.count].withAlphaComponent(0.76)
    }

    private static let particleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 18))
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: 14, height: 14))
        }
    }()
}
