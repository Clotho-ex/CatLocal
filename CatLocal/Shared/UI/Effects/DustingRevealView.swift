import Metal
import MetalKit
import OSLog
import QuartzCore
import Foundation
import SwiftUI
import UIKit

enum DustRevealGeometry {
    static func imageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard
            imageSize.width > 0,
            imageSize.height > 0,
            containerSize.width > 0,
            containerSize.height > 0
        else {
            return .zero
        }

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return CGRect(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    static func imagesAreAligned(originalSize: CGSize, cutoutSize: CGSize) -> Bool {
        originalSize.width > 0
            && originalSize.height > 0
            && originalSize == cutoutSize
    }

    static func pixelSize(of image: UIImage) -> CGSize? {
        guard let cgImage = image.cgImage else { return nil }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }
}

enum DustRevealTimeline {
    static let standardDuration: TimeInterval = 2.6
    static let terminalFadeStart = 0.82

    static func progress(elapsed: TimeInterval, duration: TimeInterval) -> Float {
        guard duration > 0 else { return elapsed >= 0 ? 1 : 0 }
        return Float(min(max(elapsed / duration, 0), 1))
    }

    static func isComplete(elapsed: TimeInterval, duration: TimeInterval) -> Bool {
        progress(elapsed: elapsed, duration: duration) >= 1
    }

    static func staggeredProgress(progress: Double, stagger: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let clampedStagger = min(max(stagger, 0), 0.999)
        return min(max(
            (clampedProgress - clampedStagger) / (1 - clampedStagger),
            0
        ), 1)
    }

    static func terminalSourceFade(progress: Double) -> Double {
        let width = 1 - terminalFadeStart
        let linear = min(max((progress - terminalFadeStart) / width, 0), 1)
        let smooth = linear * linear * (3 - 2 * linear)
        return 1 - smooth
    }
}

enum DustRevealAlpha {
    static let backgroundThreshold = 32.0 / 255.0

    static func isBackground(alpha: Double) -> Bool {
        alpha < backgroundThreshold
    }

    static func inverseWeight(alpha: Double) -> Double {
        1 - min(max(alpha, 0), 1)
    }

    static func sourceContribution(
        cutoutAlpha: Double,
        progress: Double,
        stagger: Double
    ) -> Double {
        let localProgress = DustRevealTimeline.staggeredProgress(
            progress: progress,
            stagger: stagger
        )
        let backgroundSurvival = 1 - localProgress * inverseWeight(alpha: cutoutAlpha)
        return backgroundSurvival * DustRevealTimeline.terminalSourceFade(progress: progress)
    }
}

enum DustRevealFallback {
    static func remainingSourceContribution(progress: Double) -> Double {
        1 - min(max(progress, 0), 1)
    }
}

struct DustRevealPreparationGate {
    typealias Generation = UInt64

    private var nextGeneration: Generation = 0
    private var activeGeneration: Generation?

    mutating func begin() -> Generation {
        let generation = nextGeneration
        nextGeneration &+= 1
        activeGeneration = generation
        return generation
    }

    mutating func cancel() {
        activeGeneration = nil
    }

    mutating func consume(_ generation: Generation) -> Bool {
        guard activeGeneration == generation else { return false }
        activeGeneration = nil
        return true
    }
}

struct DustRevealPresentationState: Equatable {
    private enum Phase: Equatable {
        case preparing
        case firstFramePresented
        case cancelled
    }

    private var phase = Phase.preparing

    var showsSourcePlaceholder: Bool {
        phase == .preparing
    }

    var showsRawCutout: Bool {
        phase == .firstFramePresented
    }

    mutating func presentFirstFrame() -> Bool {
        guard phase == .preparing else { return false }
        phase = .firstFramePresented
        return true
    }

    mutating func cancel() {
        phase = .cancelled
    }
}

final class DustFirstFramePresentationGate: @unchecked Sendable {
    private enum CommandState: Equatable {
        case pending
        case succeeded
        case failed
    }

    private let lock = NSLock()
    private var commandState = CommandState.pending
    private var didPresentDrawable = false
    private var isResolved = false
    private var isCancelled = false

    func commandCompleted(succeeded: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !isResolved, !isCancelled, commandState == .pending else { return false }
        commandState = succeeded ? .succeeded : .failed
        guard succeeded else {
            isResolved = true
            return false
        }
        return resolveIfReady()
    }

    func drawablePresented() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !isResolved, !isCancelled, !didPresentDrawable else { return false }
        didPresentDrawable = true
        return resolveIfReady()
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        isResolved = true
        lock.unlock()
    }

    private func resolveIfReady() -> Bool {
        guard commandState == .succeeded, didPresentDrawable else { return false }
        isResolved = true
        return true
    }
}

final class DustCommandCompletionTracker: @unchecked Sendable {
    typealias Submission = UInt64

    enum Outcome: Equatable, Sendable {
        case finish
        case fallback(String?)
    }

    private let lock = NSLock()
    private var nextSubmission: Submission = 0
    private var outstanding: Set<Submission> = []
    private var terminalSubmission: Submission?
    private var isResolved = false
    private var isCancelled = false

    func submit(isTerminalFrame: Bool) -> Submission? {
        lock.lock()
        defer { lock.unlock() }

        guard !isResolved, !isCancelled, terminalSubmission == nil else { return nil }
        let submission = nextSubmission
        nextSubmission += 1
        outstanding.insert(submission)
        if isTerminalFrame {
            terminalSubmission = submission
        }
        return submission
    }

    func complete(
        submission: Submission,
        succeeded: Bool,
        errorDescription: String?
    ) -> Outcome? {
        lock.lock()
        defer { lock.unlock() }

        guard
            !isResolved,
            !isCancelled,
            outstanding.remove(submission) != nil
        else {
            return nil
        }

        if !succeeded {
            isResolved = true
            outstanding.removeAll()
            return .fallback(errorDescription)
        }

        guard terminalSubmission != nil, outstanding.isEmpty else { return nil }
        isResolved = true
        return .finish
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        outstanding.removeAll()
        lock.unlock()
    }
}

struct FullScreenDustRevealView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.catLocalCardMotionEnabled) private var cardMotionEnabled

    let sourceImage: UIImage?
    let cutoutImage: UIImage
    var onCompleted: () -> Void

    @State private var fallbackRequested = false
    @State private var fallbackBackgroundOpacity = 1.0
    @State private var hasCompleted = false
    @State private var presentationState = DustRevealPresentationState()

    var body: some View {
        GeometryReader { proxy in
            let imageRect = DustRevealGeometry.imageRect(
                imageSize: sourcePixelSize ?? cutoutPixelSize ?? cutoutImage.size,
                containerSize: proxy.size
            )

            ZStack {
                CatLocalBackground()
                softBackdrop

                if usesFallback {
                    fallbackBackground(in: imageRect)
                } else if let sourceImage {
                    MetalBackgroundDustView(
                        sourceImage: sourceImage,
                        cutoutImage: cutoutImage,
                        imageRect: imageRect,
                        duration: DustRevealTimeline.standardDuration,
                        onFirstFramePresented: presentFirstFrame,
                        onCompleted: complete,
                        onFailure: requestFallback
                    )

                    alignedSource(sourceImage, in: imageRect)
                        .opacity(presentationState.showsSourcePlaceholder ? 1 : 0)
                }

                alignedCutout(in: imageRect)
                    .opacity(rawCutoutOpacity)
                revealCopy
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .task(id: usesFallback) {
            guard usesFallback else { return }
            await runFallback()
        }
        .onDisappear {
            presentationState.cancel()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lifting the cat subject")
        .accessibilityIdentifier("cutout-reveal")
    }

    @ViewBuilder
    private var softBackdrop: some View {
        if let sourceImage {
            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFill()
                .saturation(0.62)
                .blur(radius: 34)
                .scaleEffect(1.14)
                .overlay(CatLocalTheme.background.opacity(0.56))
                .clipped()
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func fallbackBackground(in rect: CGRect) -> some View {
        if let sourceImage {
            Image(uiImage: sourceImage)
                .resizable()
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .opacity(fallbackBackgroundOpacity)
                .accessibilityHidden(true)
        }
    }

    private func alignedCutout(in rect: CGRect) -> some View {
        Image(uiImage: cutoutImage)
            .resizable()
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .accessibilityHidden(true)
    }

    private func alignedSource(_ image: UIImage, in rect: CGRect) -> some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .accessibilityHidden(true)
    }

    private var revealCopy: some View {
        VStack(spacing: 7) {
            Spacer()

            Text("Lifting the subject")
                .font(CatTypography.pageTitle)
                .foregroundStyle(CatLocalTheme.primaryText)

            Text("Separating the cat on this iPhone.")
                .font(CatTypography.supporting)
                .foregroundStyle(CatLocalTheme.secondaryText)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        .padding(.bottom, 54)
        .shadow(color: CatLocalTheme.background.opacity(0.9), radius: 9)
    }

    private var sourcePixelSize: CGSize? {
        sourceImage.flatMap(DustRevealGeometry.pixelSize(of:))
    }

    private var cutoutPixelSize: CGSize? {
        DustRevealGeometry.pixelSize(of: cutoutImage)
    }

    private var canRenderMetal: Bool {
        guard let sourcePixelSize, let cutoutPixelSize else { return false }
        return !motionIsReduced
            && DustRevealGeometry.imagesAreAligned(
                originalSize: sourcePixelSize,
                cutoutSize: cutoutPixelSize
            )
    }

    private var motionIsReduced: Bool {
        reduceMotion || !cardMotionEnabled
    }

    private var usesFallback: Bool {
        fallbackRequested || !canRenderMetal
    }

    private var rawCutoutOpacity: Double {
        guard sourceImage != nil else { return 1 }
        if usesFallback, !presentationState.showsRawCutout {
            return 1 - fallbackBackgroundOpacity
        }
        return presentationState.showsRawCutout ? 1 : 0
    }

    @MainActor
    private func presentFirstFrame() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            _ = presentationState.presentFirstFrame()
        }
    }

    @MainActor
    private func requestFallback(progress: Double) {
        guard !hasCompleted, !fallbackRequested else { return }
        fallbackBackgroundOpacity = DustRevealFallback.remainingSourceContribution(
            progress: progress
        )
        fallbackRequested = true
    }

    @MainActor
    private func runFallback() async {
        withAnimation(.easeOut(duration: 0.35)) {
            fallbackBackgroundOpacity = 0
        }

        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }
        complete()
    }

    @MainActor
    private func complete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        onCompleted()
    }
}

@MainActor
struct MetalBackgroundDustView: UIViewRepresentable {
    let sourceImage: UIImage
    let cutoutImage: UIImage
    let imageRect: CGRect
    let duration: TimeInterval
    let onFirstFramePresented: @MainActor () -> Void
    let onCompleted: @MainActor () -> Void
    let onFailure: @MainActor (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = inactiveView()
        context.coordinator.startPreparation(
            view: view,
            sourceImage: SendableImage(value: sourceImage),
            cutoutImage: SendableImage(value: cutoutImage),
            imageRect: imageRect,
            duration: duration,
            onFirstFramePresented: onFirstFramePresented,
            onCompleted: onCompleted,
            onFailure: onFailure
        )
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(imageRect: imageRect)
    }

    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        coordinator.stop()
        view.delegate = nil
        view.isPaused = true
    }

    private func inactiveView() -> MTKView {
        let view = MTKView(frame: .zero, device: nil)
        view.backgroundColor = .clear
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.framebufferOnly = true
        view.isOpaque = false
        view.autoResizeDrawable = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        return view
    }

    @MainActor
    final class Coordinator {
        private var renderer: DustParticleRenderer?
        private var preparationTask: Task<DustRendererResources, Error>?
        private var attachmentTask: Task<Void, Never>?
        private var preparationGate = DustRevealPreparationGate()
        private var firstFrameGate = DustRevealPreparationGate()
        private var latestImageRect = CGRect.zero
        private var didReportFailure = false

        func startPreparation(
            view: MTKView,
            sourceImage: SendableImage,
            cutoutImage: SendableImage,
            imageRect: CGRect,
            duration: TimeInterval,
            onFirstFramePresented: @escaping @MainActor () -> Void,
            onCompleted: @escaping @MainActor () -> Void,
            onFailure: @escaping @MainActor (Double) -> Void
        ) {
            latestImageRect = imageRect
            let generation = preparationGate.begin()
            let firstFrameGeneration = firstFrameGate.begin()
            let task = Task.detached(priority: .userInitiated) {
                try DustRendererResourcePreparer.prepare(
                    sourceImage: sourceImage,
                    cutoutImage: cutoutImage,
                    pixelFormat: .bgra8Unorm_srgb
                )
            }
            preparationTask = task
            attachmentTask = Task { @MainActor [weak self, weak view] in
                do {
                    let resources = try await task.value
                    try Task.checkCancellation()
                    guard
                        let self,
                        self.preparationGate.consume(generation),
                        let view
                    else {
                        return
                    }

                    view.device = resources.device
                    let renderer = DustParticleRenderer(
                        view: view,
                        resources: resources,
                        imageRect: self.latestImageRect,
                        duration: duration,
                        onFirstFramePresented: { [weak self] in
                            guard
                                let self,
                                self.firstFrameGate.consume(firstFrameGeneration)
                            else {
                                return
                            }
                            onFirstFramePresented()
                        },
                        onCompleted: onCompleted,
                        onFailure: onFailure
                    )
                    self.renderer = renderer
                    self.preparationTask = nil
                    self.attachmentTask = nil
                    view.delegate = renderer
                    view.isPaused = false
                } catch is CancellationError {
                    return
                } catch {
                    guard
                        let self,
                        self.preparationGate.consume(generation)
                    else {
                        return
                    }
                    self.preparationTask = nil
                    self.attachmentTask = nil
                    self.firstFrameGate.cancel()
                    Self.logger.error(
                        "Metal dust reveal setup failed: \(error.localizedDescription, privacy: .public)"
                    )
                    self.reportFailure(onFailure, progress: 0)
                }
            }
        }

        func update(imageRect: CGRect) {
            latestImageRect = imageRect
            renderer?.imageRect = imageRect
        }

        func stop() {
            preparationGate.cancel()
            firstFrameGate.cancel()
            preparationTask?.cancel()
            attachmentTask?.cancel()
            preparationTask = nil
            attachmentTask = nil
            renderer?.stop()
            renderer = nil
        }

        private func reportFailure(
            _ action: @escaping @MainActor (Double) -> Void,
            progress: Double
        ) {
            guard !didReportFailure else { return }
            didReportFailure = true
            action(progress)
        }

        private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "CatLocal",
            category: "DustReveal"
        )
    }
}

struct DustRendererResources: @unchecked Sendable {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let backgroundPipeline: MTLRenderPipelineState
    let particlePipeline: MTLRenderPipelineState
    let sourceTexture: MTLTexture
    let cutoutTexture: MTLTexture
    let particleCount: Int
}

enum DustRendererResourcePreparer {
    static func prepare(
        sourceImage: SendableImage,
        cutoutImage: SendableImage,
        pixelFormat: MTLPixelFormat
    ) throws -> DustRendererResources {
        try Task.checkCancellation()
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw DustRendererError.metalUnavailable
        }
        guard
            let sourceCGImage = sourceImage.value.cgImage,
            let cutoutCGImage = cutoutImage.value.cgImage
        else {
            throw DustRendererError.imageUnavailable
        }
        guard DustRevealGeometry.imagesAreAligned(
            originalSize: CGSize(width: sourceCGImage.width, height: sourceCGImage.height),
            cutoutSize: CGSize(width: cutoutCGImage.width, height: cutoutCGImage.height)
        ) else {
            throw DustRendererError.imageDimensionsMismatch
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw DustRendererError.commandQueueUnavailable
        }
        guard let library = device.makeDefaultLibrary() else {
            throw DustRendererError.shaderLibraryUnavailable
        }

        try Task.checkCancellation()
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.topLeft,
            .SRGB: true,
            .textureUsage: MTLTextureUsage.shaderRead.rawValue
        ]
        let sourceTexture = try loader.newTexture(cgImage: sourceCGImage, options: options)
        try Task.checkCancellation()
        let cutoutTexture = try loader.newTexture(cgImage: cutoutCGImage, options: options)
        try Task.checkCancellation()
        let backgroundPipeline = try makePipeline(
            device: device,
            library: library,
            vertexFunction: "dustBackgroundVertex",
            fragmentFunction: "dustBackgroundFragment",
            pixelFormat: pixelFormat
        )
        let particlePipeline = try makePipeline(
            device: device,
            library: library,
            vertexFunction: "dustParticleVertex",
            fragmentFunction: "dustParticleFragment",
            pixelFormat: pixelFormat
        )
        try Task.checkCancellation()

        return DustRendererResources(
            device: device,
            commandQueue: commandQueue,
            backgroundPipeline: backgroundPipeline,
            particlePipeline: particlePipeline,
            sourceTexture: sourceTexture,
            cutoutTexture: cutoutTexture,
            particleCount: adaptiveParticleCount(
                pixelCount: sourceCGImage.width * sourceCGImage.height
            )
        )
    }

    private static func adaptiveParticleCount(pixelCount: Int) -> Int {
        min(max(pixelCount / 14, 45_000), 80_000)
    }

    private static func makePipeline(
        device: MTLDevice,
        library: MTLLibrary,
        vertexFunction: String,
        fragmentFunction: String,
        pixelFormat: MTLPixelFormat
    ) throws -> MTLRenderPipelineState {
        guard
            let vertex = library.makeFunction(name: vertexFunction),
            let fragment = library.makeFunction(name: fragmentFunction)
        else {
            throw DustRendererError.shaderFunctionUnavailable
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}

@MainActor
final class DustParticleRenderer: NSObject, MTKViewDelegate {
    var imageRect: CGRect

    private weak var view: MTKView?
    private let commandQueue: MTLCommandQueue
    private let backgroundPipeline: MTLRenderPipelineState
    private let particlePipeline: MTLRenderPipelineState
    private let sourceTexture: MTLTexture
    private let cutoutTexture: MTLTexture
    private let particleCount: Int
    private let duration: TimeInterval
    private let onFirstFramePresented: @MainActor () -> Void
    private let onCompleted: @MainActor () -> Void
    private let onFailure: @MainActor (Double) -> Void
    private let commandCompletionTracker = DustCommandCompletionTracker()
    private let firstFramePresentationGate = DustFirstFramePresentationGate()
    private var startTime: CFTimeInterval?
    private var hasFinished = false
    private var hasFailed = false
    private var isStopped = false
    private var isFinishing = false
    private var unavailableFrameCount = 0
    private var lastSubmittedProgress = 0.0
    private var hasPresentedFirstFrame = false

    init(
        view: MTKView,
        resources: DustRendererResources,
        imageRect: CGRect,
        duration: TimeInterval,
        onFirstFramePresented: @escaping @MainActor () -> Void,
        onCompleted: @escaping @MainActor () -> Void,
        onFailure: @escaping @MainActor (Double) -> Void
    ) {
        commandQueue = resources.commandQueue
        backgroundPipeline = resources.backgroundPipeline
        particlePipeline = resources.particlePipeline
        sourceTexture = resources.sourceTexture
        cutoutTexture = resources.cutoutTexture
        particleCount = resources.particleCount
        self.imageRect = imageRect
        self.duration = duration
        self.onFirstFramePresented = onFirstFramePresented
        self.onCompleted = onCompleted
        self.onFailure = onFailure
        self.view = view
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard !isStopped, !hasFinished, !hasFailed, !isFinishing else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            unavailableFrameCount += 1
            if unavailableFrameCount >= 30 {
                fail(with: .drawableUnavailable)
            }
            return
        }
        unavailableFrameCount = 0
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fail(with: .commandBufferUnavailable)
            return
        }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            fail(with: .renderEncoderUnavailable)
            return
        }

        let now = CACurrentMediaTime()
        let startedAt = startTime ?? now
        startTime = startedAt
        let elapsed = now - startedAt
        let progress = DustRevealTimeline.progress(elapsed: elapsed, duration: duration)
        var uniforms = makeUniforms(view: view, progress: progress)

        encoder.setRenderPipelineState(backgroundPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<DustRevealUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DustRevealUniforms>.stride, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentTexture(cutoutTexture, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.setRenderPipelineState(particlePipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<DustRevealUniforms>.stride, index: 0)
        encoder.setVertexTexture(sourceTexture, index: 0)
        encoder.setVertexTexture(cutoutTexture, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
        encoder.endEncoding()

        let isTerminalFrame = DustRevealTimeline.isComplete(
            elapsed: elapsed,
            duration: duration
        )
        guard let submission = commandCompletionTracker.submit(
            isTerminalFrame: isTerminalFrame
        ) else {
            isFinishing = true
            view.isPaused = true
            return
        }
        lastSubmittedProgress = Double(progress)
        if isTerminalFrame {
            isFinishing = true
            view.isPaused = true
        }
        let completionTracker = commandCompletionTracker
        let firstFrameGate = firstFramePresentationGate
        if submission == 0 {
#if targetEnvironment(simulator)
            // The Simulator SDK omits MTLDrawable.addPresentedHandler.
#else
            drawable.addPresentedHandler { _ in
                guard firstFrameGate.drawablePresented() else { return }
                Task { @MainActor [weak self] in
                    self?.presentFirstFrameIfNeeded()
                }
            }
#endif
        }
        commandBuffer.addCompletedHandler { completedBuffer in
            let succeeded = completedBuffer.status == .completed
            let errorDescription = completedBuffer.error?.localizedDescription
            var resolvedFirstFrame = submission == 0
                && firstFrameGate.commandCompleted(succeeded: succeeded)
#if targetEnvironment(simulator)
            if submission == 0, succeeded {
                resolvedFirstFrame = firstFrameGate.drawablePresented() || resolvedFirstFrame
            }
#endif
            let outcome = completionTracker.complete(
                submission: submission,
                succeeded: succeeded,
                errorDescription: errorDescription
            )
            guard resolvedFirstFrame || outcome != nil else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if resolvedFirstFrame {
                    self.presentFirstFrameIfNeeded()
                }
                if let outcome {
                    self.handleCommandCompletion(outcome)
                }
            }
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        commandCompletionTracker.cancel()
        firstFramePresentationGate.cancel()
        view?.isPaused = true
        view = nil
    }

    private func makeUniforms(view: MTKView, progress: Float) -> DustRevealUniforms {
        let scale = view.contentScaleFactor
        let pixelRect = CGRect(
            x: imageRect.minX * scale,
            y: imageRect.minY * scale,
            width: imageRect.width * scale,
            height: imageRect.height * scale
        )
        let aspect = max(Float(sourceTexture.width) / Float(sourceTexture.height), 0.01)
        let columns = max(Int(ceil(sqrt(Double(particleCount) * Double(aspect)))), 1)
        let rows = max(Int(ceil(Double(particleCount) / Double(columns))), 1)

        return DustRevealUniforms(
            imageRect: SIMD4(
                Float(pixelRect.minX),
                Float(pixelRect.minY),
                Float(pixelRect.width),
                Float(pixelRect.height)
            ),
            drawableSize: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            progress: progress,
            particleSize: Float(max(1.5, min(3.4, scale * 1.15))),
            backgroundAlphaThreshold: Float(DustRevealAlpha.backgroundThreshold),
            particleInfo: SIMD4(
                UInt32(particleCount),
                UInt32(columns),
                UInt32(rows),
                0
            )
        )
    }

    private func finish() {
        guard !hasFinished, !isStopped else { return }
        hasFinished = true
        view?.isPaused = true
        view?.isHidden = true
        onCompleted()
    }

    private func presentFirstFrameIfNeeded() {
        guard !isStopped, !hasFinished, !hasFailed else { return }
        guard !hasPresentedFirstFrame else { return }
        hasPresentedFirstFrame = true
        onFirstFramePresented()
    }

    private func handleCommandCompletion(_ outcome: DustCommandCompletionTracker.Outcome) {
        guard !isStopped, !hasFinished, !hasFailed else { return }

        switch outcome {
        case .finish:
            finish()
        case .fallback(let errorDescription):
            fail(with: .commandBufferExecutionFailed(errorDescription))
        }
    }

    private func fail(with error: DustRendererError) {
        guard !hasFailed, !hasFinished, !isStopped else { return }
        hasFailed = true
        commandCompletionTracker.cancel()
        firstFramePresentationGate.cancel()
        Self.logger.error("Metal dust reveal stopped: \(error.localizedDescription, privacy: .public)")
        view?.isPaused = true
        onFailure(lastSubmittedProgress)
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CatLocal",
        category: "DustReveal"
    )
}

private struct DustRevealUniforms {
    var imageRect: SIMD4<Float>
    var drawableSize: SIMD2<Float>
    var progress: Float
    var particleSize: Float
    var backgroundAlphaThreshold: Float
    var particleInfo: SIMD4<UInt32>
}

private enum DustRendererError: LocalizedError {
    case metalUnavailable
    case imageUnavailable
    case imageDimensionsMismatch
    case commandQueueUnavailable
    case shaderLibraryUnavailable
    case shaderFunctionUnavailable
    case drawableUnavailable
    case commandBufferUnavailable
    case commandBufferExecutionFailed(String?)
    case renderEncoderUnavailable

    var errorDescription: String? {
        switch self {
        case .metalUnavailable:
            "Metal is unavailable on this device."
        case .imageUnavailable:
            "The reveal images could not be converted to textures."
        case .imageDimensionsMismatch:
            "The original and cutout image dimensions do not align."
        case .commandQueueUnavailable:
            "The Metal command queue could not be created."
        case .shaderLibraryUnavailable:
            "The Metal shader library could not be loaded."
        case .shaderFunctionUnavailable:
            "The Metal dust shader functions could not be loaded."
        case .drawableUnavailable:
            "The Metal drawable remained unavailable."
        case .commandBufferUnavailable:
            "A Metal command buffer could not be created."
        case .commandBufferExecutionFailed(let details):
            if let details, !details.isEmpty {
                "The Metal command buffer failed: \(details)"
            } else {
                "The Metal command buffer failed during execution."
            }
        case .renderEncoderUnavailable:
            "A Metal render encoder could not be created."
        }
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
