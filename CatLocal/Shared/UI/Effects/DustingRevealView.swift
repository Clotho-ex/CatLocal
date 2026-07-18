import Metal
import MetalKit
import OSLog
import QuartzCore
import Foundation
import SwiftUI
import UIKit

enum SubjectToCardTransitionPhase: Equatable {
    case preparing
    case dusting
    case lifting
    case settling
    case completed
    case failed
}

enum SubjectToCardTransitionGeometry {
    static func sourceRect(
        normalizedCropBounds: CGRect,
        imageSize: CGSize,
        containerRect: CGRect
    ) -> CGRect {
        let fitted = DustRevealGeometry.imageRect(
            imageSize: imageSize,
            containerSize: containerRect.size
        ).offsetBy(dx: containerRect.minX, dy: containerRect.minY)
        return CGRect(
            x: fitted.minX + fitted.width * normalizedCropBounds.minX,
            y: fitted.minY + fitted.height * normalizedCropBounds.minY,
            width: fitted.width * normalizedCropBounds.width,
            height: fitted.height * normalizedCropBounds.height
        )
    }

    static func interpolatedRect(
        from source: CGRect,
        to destination: CGRect,
        progress: CGFloat
    ) -> CGRect {
        let amount = min(max(progress, 0), 1)
        return CGRect(
            x: source.minX + (destination.minX - source.minX) * amount,
            y: source.minY + (destination.minY - source.minY) * amount,
            width: source.width + (destination.width - source.width) * amount,
            height: source.height + (destination.height - source.height) * amount
        )
    }
}

enum SubjectToCardTransitionTimeline {
    struct OpacitySnapshot: Equatable, Sendable {
        let card: Double
        let backdrop: Double
    }

    static let dustDuration: TimeInterval = DustRevealTimeline.standardDuration
    static let outlineStart: TimeInterval = 0.68
    static let outlineDuration: TimeInterval = 0.28
    static let liftStart: TimeInterval = 0.92
    static let liftDuration: TimeInterval = 0.64
    static let settleDuration: TimeInterval = 0.28
    static let scaleRiseDuration: TimeInterval = 0.16
    static let cardRevealDuration: TimeInterval = 0.42
    static let backdropRevealDuration: TimeInterval = 0.44
    static let totalDuration: TimeInterval = liftStart + liftDuration + settleDuration
    static let reducedMotionDuration: TimeInterval = 0.25
    static let maximumScale: CGFloat = 1.035

    static func phase(elapsed: TimeInterval) -> SubjectToCardTransitionPhase {
        guard elapsed >= 0 else { return .preparing }
        guard elapsed < totalDuration else { return .completed }
        if elapsed < liftStart { return .dusting }
        if elapsed < liftStart + liftDuration { return .lifting }
        return .settling
    }

    static func liftProgress(elapsed: TimeInterval) -> CGFloat {
        smoothProgress(elapsed: elapsed, start: liftStart, duration: liftDuration)
    }

    static func outlineOpacity(elapsed: TimeInterval) -> Double {
        Double(linearProgress(elapsed: elapsed, start: outlineStart, duration: outlineDuration))
    }

    static func cardOpacity(elapsed: TimeInterval) -> Double {
        Double(smoothProgress(
            elapsed: elapsed,
            start: outlineStart,
            duration: cardRevealDuration
        ))
    }

    static func backdropOpacity(elapsed: TimeInterval) -> Double {
        Double(smoothProgress(
            elapsed: elapsed,
            start: dustDuration,
            duration: backdropRevealDuration
        ))
    }

    static func opacitySnapshot(elapsed: TimeInterval) -> OpacitySnapshot {
        OpacitySnapshot(
            card: cardOpacity(elapsed: elapsed),
            backdrop: backdropOpacity(elapsed: elapsed)
        )
    }

    static func cardScale(elapsed: TimeInterval) -> CGFloat {
        let settleStart = liftStart + liftDuration
        let riseStart = settleStart - scaleRiseDuration
        guard elapsed >= riseStart else { return 1 }
        if elapsed < settleStart {
            let progress = smoothProgress(
                elapsed: elapsed,
                start: riseStart,
                duration: scaleRiseDuration
            )
            return 1 + (maximumScale - 1) * progress
        }
        let progress = smoothProgress(
            elapsed: elapsed,
            start: settleStart,
            duration: settleDuration
        )
        return maximumScale + (1 - maximumScale) * progress
    }

    private static func linearProgress(
        elapsed: TimeInterval,
        start: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard duration > 0 else { return elapsed >= start ? 1 : 0 }
        return min(max(CGFloat((elapsed - start) / duration), 0), 1)
    }

    private static func smoothProgress(
        elapsed: TimeInterval,
        start: TimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        let value = linearProgress(elapsed: elapsed, start: start, duration: duration)
        return value * value * (3 - 2 * value)
    }
}

enum SubjectToCardTimelineStartEvent: Equatable {
    case metalFirstFrame
    case fallback
}

struct SubjectToCardTimelineStartGate {
    let requiresMetalFirstFrame: Bool
    private(set) var isStarted = false

    mutating func startIfReady(for event: SubjectToCardTimelineStartEvent) -> Bool {
        guard !isStarted else { return false }
        guard !requiresMetalFirstFrame || event == .metalFirstFrame else { return false }
        isStarted = true
        return true
    }
}

struct SubjectToCardCompletionGate {
    private(set) var isCompleted = false

    mutating func complete() -> Bool {
        guard !isCompleted else { return false }
        isCompleted = true
        return true
    }

    mutating func reset() {
        isCompleted = false
    }
}

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

    static func containsEffectPoint(_ point: CGPoint, imageRect: CGRect) -> Bool {
        !imageRect.isEmpty && imageRect.contains(point)
    }

    static func pixelSize(of image: UIImage) -> CGSize? {
        guard let cgImage = image.cgImage else { return nil }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }
}

enum DustRevealTimeline {
    static let standardDuration: TimeInterval = 1.10

    static func progress(elapsed: TimeInterval, duration: TimeInterval) -> Float {
        guard duration > 0 else { return elapsed >= 0 ? 1 : 0 }
        return Float(min(max(elapsed / duration, 0), 1))
    }

    static func isComplete(elapsed: TimeInterval, duration: TimeInterval) -> Bool {
        progress(elapsed: elapsed, duration: duration) >= 1
    }

}

enum DustRevealAlpha {
    static func inverseWeight(alpha: Double) -> Double {
        1 - min(max(alpha, 0), 1)
    }

}

enum DustRevealBlend {
    static func backgroundOutput(
        premultipliedSource: SIMD4<Double>,
        survival: Double
    ) -> SIMD4<Double> {
        premultipliedSource * min(max(survival, 0), 1)
    }

    static func particleOutput(
        straightRGB: SIMD3<Double>,
        sourceAlpha: Double,
        particleAlpha: Double
    ) -> SIMD4<Double> {
        let alpha = min(max(sourceAlpha, 0), 1) * min(max(particleAlpha, 0), 1)
        return SIMD4(straightRGB * alpha, alpha)
    }
}

enum DustSubjectProtection {
    static func weight(maskValue: Double) -> Double {
        let value = min(max((maskValue - 0.08) / (0.72 - 0.08), 0), 1)
        return value * value * (3 - 2 * value)
    }
}

enum DustParticleEligibility {
    static func contribution(
        background: SIMD4<Double>,
        subjectProtection: Double
    ) -> Double {
        let hasAlpha = background.w > 1.0 / 255.0
        let hasColor = background.x + background.y + background.z > 1.0 / 1024.0
        guard hasAlpha, hasColor else { return 0 }
        return 1 - min(max(subjectProtection, 0), 1)
    }
}

struct DustRendererClock {
    private(set) var startedAt: CFTimeInterval?

    mutating func progress(
        at time: CFTimeInterval,
        hasDrawable: Bool,
        duration: TimeInterval
    ) -> Float? {
        guard hasDrawable else { return nil }
        if startedAt == nil {
            startedAt = time
        }
        guard let startedAt else { return nil }
        return DustRevealTimeline.progress(elapsed: time - startedAt, duration: duration)
    }
}

final class DustRendererTerminalGate: @unchecked Sendable {
    enum State: Equatable, Sendable {
        case active
        case completed
        case failed
        case cancelled
    }

    private let lock = NSLock()
    private var storedState = State.active

    var state: State {
        lock.withLock { storedState }
    }

    func resolve(_ terminalState: State) -> Bool {
        precondition(terminalState != .active)
        return lock.withLock {
            guard storedState == .active else { return false }
            storedState = terminalState
            return true
        }
    }
}

enum DustRevealDissolve {
    static func erosionThreshold(
        noise: Double,
        horizontalPosition: Double,
        verticalPosition: Double
    ) -> Double {
        let noise = min(max(noise, 0), 1)
        let horizontalPosition = min(max(horizontalPosition, 0), 1)
        let verticalPosition = min(max(verticalPosition, 0), 1)
        return min(max(
            0.04
                + horizontalPosition * 0.68
                + (1 - verticalPosition) * 0.18
                + (noise - 0.5) * 0.14,
            0.02
        ), 0.94)
    }

    static func survival(
        progress: Double,
        threshold: Double,
        feather: Double = 0.025
    ) -> Double {
        let progress = min(max(progress, 0), 1)
        guard progress > 0 else { return 1 }
        guard progress < 1 else { return 0 }
        let threshold = min(max(threshold, 0), 1)
        let feather = max(feather, .leastNonzeroMagnitude)
        let edge0 = threshold - feather
        let edge1 = threshold + feather
        let linear = min(max((progress - edge0) / (edge1 - edge0), 0), 1)
        let smooth = linear * linear * (3 - 2 * linear)
        return 1 - smooth
    }

    static func sourceSurvival(
        progress: Double,
        noise: Double,
        horizontalPosition: Double,
        verticalPosition: Double
    ) -> Double {
        survival(
            progress: progress,
            threshold: erosionThreshold(
                noise: noise,
                horizontalPosition: horizontalPosition,
                verticalPosition: verticalPosition
            )
        )
    }

    static func combinedAlpha(
        cutoutAlpha: Double,
        progress: Double,
        noise: Double,
        horizontalPosition: Double = 0.5,
        verticalPosition: Double = 0.5
    ) -> Double {
        let alpha = min(max(cutoutAlpha, 0), 1)
        let underlay = sourceSurvival(
            progress: progress,
            noise: noise,
            horizontalPosition: horizontalPosition,
            verticalPosition: verticalPosition
        )
        return alpha + underlay * (1 - alpha)
    }
}

enum DustParticleTimeline {
    static func age(
        progress: Double,
        emissionThreshold: Double
    ) -> Double {
        let progress = min(max(progress, 0), 1)
        let threshold = min(max(emissionThreshold, 0), 1)
        let lifetime = max(1 - threshold, 0.06)
        return min(max((progress - threshold) / lifetime, 0), 1)
    }
}

enum DustParticleMotion {
    struct Sample: Equatable {
        let textureCoordinate: SIMD2<Double>
        let forwardProgress: Double
        let pointSize: Double
        let opacity: Double
    }

    static let initialDepthScale = 0.82
    static let finalDepthScale = 2.05
    static let minimumDepthVariation = 0.88
    static let maximumDepthVariation = 1.12
    static let forwardExponent = 1.2
    static let maximumPointSize = 20.0
    static let maximumPerspectiveExpansion = 0.065
    static let maximumLateralVariation = 0.012
    static let birthEndAge = 0.10
    static let fadeStartAge = 0.48
    static let fadeEndAge = 0.92

    static func sample(
        textureCoordinate: SIMD2<Double>,
        age: Double,
        directionSeed: Double,
        depthSeed: Double,
        basePointSize: Double,
        imageAspectRatio: Double,
        lateralVariation: Double? = nil
    ) -> Sample {
        let progress = forwardProgress(age: age, depthSeed: depthSeed)
        let aspectRatio = max(imageAspectRatio, 0.01)
        var centered = textureCoordinate * 2 - SIMD2(repeating: 1)
        centered.x *= aspectRatio
        centered *= 1 + maximumPerspectiveExpansion * progress
        centered.x /= aspectRatio

        let normalizedDirectionSeed = directionSeed - floor(directionSeed)
        let angle = normalizedDirectionSeed * 2 * Double.pi
        var direction = SIMD2(cos(angle), sin(angle))
        direction.x /= aspectRatio
        let lateralAmount = min(
            max(lateralVariation ?? maximumLateralVariation, 0),
            maximumLateralVariation
        )
        let animatedCoordinate = (centered + SIMD2(repeating: 1)) / 2
            + direction * lateralAmount * progress
        let depthScale = mix(initialDepthScale, finalDepthScale, progress)

        return Sample(
            textureCoordinate: animatedCoordinate,
            forwardProgress: progress,
            pointSize: min(max(basePointSize, 0) * depthScale, maximumPointSize),
            opacity: opacity(age: age)
        )
    }

    static func forwardProgress(age: Double, depthSeed: Double) -> Double {
        let depthProgress = smoothstep(min(max(age, 0), 1))
        let variation = mix(
            minimumDepthVariation,
            maximumDepthVariation,
            min(max(depthSeed, 0), 1)
        )
        return min(max(pow(depthProgress, forwardExponent) * variation, 0), 1)
    }

    static func opacity(age: Double) -> Double {
        let age = min(max(age, 0), 1)
        guard !isExpired(age: age) else { return 0 }
        let birth = smoothstep(min(max(age / birthEndAge, 0), 1))
        let fadeProgress = min(
            max((age - fadeStartAge) / (fadeEndAge - fadeStartAge), 0),
            1
        )
        return birth * (1 - smoothstep(fadeProgress))
    }

    static func isExpired(age: Double) -> Bool {
        age >= fadeEndAge
    }

    private static func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private static func mix(_ start: Double, _ end: Double, _ amount: Double) -> Double {
        start + (end - start) * amount
    }
}

enum DustRevealFallback {
    enum Action: Equatable, Sendable {
        case crossfade
        case completeImmediately
    }

    static func remainingSourceContribution(progress: Double) -> Double {
        1 - min(max(progress, 0), 1)
    }

    static func action(remainingSourceContribution: Double) -> Action {
        remainingSourceContribution > 0 ? .crossfade : .completeImmediately
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

    let sourceImage: UIImage?
    let transition: PreparedCaptureTransition?
    var forcesFallback = false
    var showsCutoutOverlay = true
    var fallbackDuration: TimeInterval = 0.4
    var onMetalFirstFramePresented: (() -> Void)?
    var onRendererFailed: (() -> Void)?
    var onCompleted: () -> Void

    @State private var fallbackRequested = false
    @State private var fallbackBackgroundOpacity = 1.0
    @State private var hasCompleted = false
    @State private var hasReportedRendererFailure = false
    @State private var presentationState = DustRevealPresentationState()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CatLocalTheme.primaryText.ignoresSafeArea()
                softBackdrop(in: proxy.size)

                if let sourceImage {
                    if let transition, !usesFallback {
                        MetalBackgroundDustView(
                            backgroundOnly: transition.backgroundOnly,
                            subjectProtectionMask: transition.subjectProtectionMask,
                            workingColorSpace: transition.workingColorSpace,
                            duration: DustRevealTimeline.standardDuration,
                            onFirstFramePresented: presentFirstFrame,
                            onCompleted: finishReveal,
                            onFailure: requestFallback
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .ignoresSafeArea()
                    }

                    alignedImage(sourceImage, in: proxy.size)
                        .opacity(sourceOpacity)
                }

                if let transition, showsCutoutOverlay {
                    transitionOverlay(transition, in: proxy.size)
                        .opacity(rawCutoutOpacity)
                }

                revealChrome
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .task(id: transition != nil) {
            guard transition != nil, usesFallback else { return }
            if !reduceMotion, !forcesFallback {
                reportRendererFailureOnce()
            }
            await runFallback()
        }
        .task(id: fallbackRequested) {
            guard transition != nil, fallbackRequested else { return }
            await runFallback()
        }
        .onDisappear {
            presentationState.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cutout-reveal")
    }

    @ViewBuilder
    private func softBackdrop(in size: CGSize) -> some View {
        if let sourceImage {
            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .saturation(0.62)
                .blur(radius: 34)
                .scaleEffect(1.14)
                .overlay(Color.black.opacity(0.32))
                .clipped()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }

    private func alignedImage(_ image: UIImage, in size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height, alignment: .center)
            .accessibilityHidden(true)
    }

    private func transitionOverlay(
        _ transition: PreparedCaptureTransition,
        in size: CGSize
    ) -> some View {
        let imageRect = DustRevealGeometry.imageRect(
            imageSize: transition.sourceSize,
            containerSize: size
        )
        let crop = transition.normalizedPaddedCropBounds
        let outlineRect = CGRect(
            x: imageRect.minX + imageRect.width * crop.minX,
            y: imageRect.minY + imageRect.height * crop.minY,
            width: imageRect.width * crop.width,
            height: imageRect.height * crop.height
        )

        return ZStack {
            Image(decorative: transition.outlineMask, scale: 1, orientation: .up)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(CatLocalTheme.cutoutOutline)
                .frame(width: outlineRect.width, height: outlineRect.height)
                .position(x: outlineRect.midX, y: outlineRect.midY)

            Image(decorative: transition.alignedCutout, scale: 1, orientation: .up)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private var revealChrome: some View {
        VStack {
            Spacer()

            HStack(spacing: 11) {
                ProgressView()
                    .tint(.white)
                Text("Removing background...")
                    .font(CatTypography.control)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 54)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Removing the background")
            .accessibilityIdentifier("lifting-status")
        }
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        .padding(.bottom, 34)
    }

    private var canRenderMetal: Bool {
        guard let transition else { return false }
        let sourceSize = transition.sourceSize
        let backgroundSize = CGSize(
            width: transition.backgroundOnly.width,
            height: transition.backgroundOnly.height
        )
        let protectionSize = CGSize(
            width: transition.subjectProtectionMask.width,
            height: transition.subjectProtectionMask.height
        )
        return !reduceMotion && !forcesFallback
            && DustRevealGeometry.imagesAreAligned(
                originalSize: sourceSize,
                cutoutSize: backgroundSize
            )
            && backgroundSize == protectionSize
    }

    private var usesFallback: Bool {
        transition != nil && (fallbackRequested || !canRenderMetal)
    }

    private var sourceOpacity: Double {
        guard transition != nil else { return 1 }
        if usesFallback {
            return fallbackBackgroundOpacity
        }
        return presentationState.showsSourcePlaceholder ? 1 : 0
    }

    private var rawCutoutOpacity: Double {
        guard transition != nil else { return 0 }
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
            if presentationState.presentFirstFrame() {
                onMetalFirstFramePresented?()
            }
        }
    }

    @MainActor
    private func requestFallback(progress: Double) {
        guard !hasCompleted, !fallbackRequested else { return }
        fallbackBackgroundOpacity = DustRevealFallback.remainingSourceContribution(
            progress: progress
        )
        fallbackRequested = true
        reportRendererFailureOnce()
    }

    private func reportRendererFailureOnce() {
        guard !hasReportedRendererFailure else { return }
        hasReportedRendererFailure = true
        onRendererFailed?()
    }

    @MainActor
    private func runFallback() async {
        guard !hasCompleted else { return }
        guard DustRevealFallback.action(
            remainingSourceContribution: fallbackBackgroundOpacity
        ) == .crossfade else {
            complete()
            return
        }
        withAnimation(.easeOut(duration: fallbackDuration)) {
            fallbackBackgroundOpacity = 0
        }

        do {
            try await Task.sleep(for: .seconds(fallbackDuration))
        } catch {
            return
        }
        complete()
    }

    @MainActor
    private func finishReveal() {
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
    let backgroundOnly: CGImage
    let subjectProtectionMask: CGImage
    let workingColorSpace: CaptureTransitionColorSpace
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
            backgroundOnly: backgroundOnly,
            subjectProtectionMask: subjectProtectionMask,
            workingColorSpace: workingColorSpace,
            duration: duration,
            onFirstFramePresented: onFirstFramePresented,
            onCompleted: onCompleted,
            onFailure: onFailure
        )
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {}

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
        private let terminalGate = DustRendererTerminalGate()

        func startPreparation(
            view: MTKView,
            backgroundOnly: CGImage,
            subjectProtectionMask: CGImage,
            workingColorSpace: CaptureTransitionColorSpace,
            duration: TimeInterval,
            onFirstFramePresented: @escaping @MainActor () -> Void,
            onCompleted: @escaping @MainActor () -> Void,
            onFailure: @escaping @MainActor (Double) -> Void
        ) {
            let generation = preparationGate.begin()
            let firstFrameGeneration = firstFrameGate.begin()
            let task = Task.detached(priority: .userInitiated) {
                try DustRendererResourcePreparer.prepare(
                    backgroundOnly: backgroundOnly,
                    subjectProtectionMask: subjectProtectionMask,
                    workingColorSpace: workingColorSpace,
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
                    (view.layer as? CAMetalLayer)?.colorspace = workingColorSpace.makeColorSpace()
                    let renderer = DustParticleRenderer(
                        view: view,
                        resources: resources,
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
                        onCompleted: { [weak self] in
                            guard let self,
                                  self.terminalGate.resolve(.completed) else { return }
                            self.renderer = nil
                            onCompleted()
                        },
                        onFailure: { [weak self] progress in
                            guard let self,
                                  self.terminalGate.resolve(.failed) else { return }
                            self.renderer = nil
                            onFailure(progress)
                        }
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
                    guard self.terminalGate.resolve(.failed) else { return }
                    onFailure(0)
                }
            }
        }

        func stop() {
            _ = terminalGate.resolve(.cancelled)
            preparationGate.cancel()
            firstFrameGate.cancel()
            preparationTask?.cancel()
            attachmentTask?.cancel()
            preparationTask = nil
            attachmentTask = nil
            renderer?.stop()
            renderer = nil
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
    let backgroundTexture: MTLTexture
    let protectionTexture: MTLTexture
    let particleCount: Int
}

enum DustRendererResourcePreparer {
    static func prepare(
        backgroundOnly: CGImage,
        subjectProtectionMask: CGImage,
        workingColorSpace: CaptureTransitionColorSpace,
        pixelFormat: MTLPixelFormat
    ) throws -> DustRendererResources {
        try Task.checkCancellation()
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw DustRendererError.metalUnavailable
        }
        guard DustRevealGeometry.imagesAreAligned(
            originalSize: CGSize(width: backgroundOnly.width, height: backgroundOnly.height),
            cutoutSize: CGSize(
                width: subjectProtectionMask.width,
                height: subjectProtectionMask.height
            )
        ) else {
            throw DustRendererError.imageDimensionsMismatch
        }
        guard backgroundOnly.colorSpace?.model == .rgb,
              let resolvedWorkingColorSpace = workingColorSpace.makeColorSpace(),
              resolvedWorkingColorSpace.model == .rgb else {
            throw DustRendererError.imageUnavailable
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
        let backgroundTexture = try loader.newTexture(cgImage: backgroundOnly, options: options)
        try Task.checkCancellation()
        let protectionTexture = try loader.newTexture(
            cgImage: subjectProtectionMask,
            options: options
        )
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
            backgroundTexture: backgroundTexture,
            protectionTexture: protectionTexture,
            particleCount: adaptiveParticleCount(
                pixelCount: backgroundOnly.width * backgroundOnly.height
            )
        )
    }

    static func adaptiveParticleCount(pixelCount: Int) -> Int {
        min(max(pixelCount / 6, 90_000), 180_000)
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
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}

@MainActor
final class DustParticleRenderer: NSObject, MTKViewDelegate {
    private weak var view: MTKView?
    private var commandQueue: MTLCommandQueue?
    private var backgroundPipeline: MTLRenderPipelineState?
    private var particlePipeline: MTLRenderPipelineState?
    private var backgroundTexture: MTLTexture?
    private var protectionTexture: MTLTexture?
    private let particleCount: Int
    private let duration: TimeInterval
    private let onFirstFramePresented: @MainActor () -> Void
    private let onCompleted: @MainActor () -> Void
    private let onFailure: @MainActor (Double) -> Void
    private let commandCompletionTracker = DustCommandCompletionTracker()
    private let firstFramePresentationGate = DustFirstFramePresentationGate()
    private let terminalGate = DustRendererTerminalGate()
    private var clock = DustRendererClock()
    private var unavailableFrameCount = 0
    private var lastSubmittedProgress = 0.0
    private var hasPresentedFirstFrame = false

    init(
        view: MTKView,
        resources: DustRendererResources,
        duration: TimeInterval,
        onFirstFramePresented: @escaping @MainActor () -> Void,
        onCompleted: @escaping @MainActor () -> Void,
        onFailure: @escaping @MainActor (Double) -> Void
    ) {
        commandQueue = resources.commandQueue
        backgroundPipeline = resources.backgroundPipeline
        particlePipeline = resources.particlePipeline
        backgroundTexture = resources.backgroundTexture
        protectionTexture = resources.protectionTexture
        particleCount = resources.particleCount
        self.duration = duration
        self.onFirstFramePresented = onFirstFramePresented
        self.onCompleted = onCompleted
        self.onFailure = onFailure
        self.view = view
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard terminalGate.state == .active else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            unavailableFrameCount += 1
            if unavailableFrameCount >= 30 {
                fail(with: .drawableUnavailable)
            }
            return
        }
        unavailableFrameCount = 0
        guard
            let commandQueue,
            let backgroundPipeline,
            let particlePipeline,
            let backgroundTexture,
            let protectionTexture
        else {
            fail(with: .resourcesReleased)
            return
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fail(with: .commandBufferUnavailable)
            return
        }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            fail(with: .renderEncoderUnavailable)
            return
        }

        let now = CACurrentMediaTime()
        guard let progress = clock.progress(
            at: now,
            hasDrawable: true,
            duration: duration
        ) else { return }
        var uniforms = makeUniforms(view: view, progress: progress)

        encoder.setRenderPipelineState(backgroundPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<DustRevealUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DustRevealUniforms>.stride, index: 0)
        encoder.setFragmentTexture(backgroundTexture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.setRenderPipelineState(particlePipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<DustRevealUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DustRevealUniforms>.stride, index: 0)
        encoder.setVertexTexture(backgroundTexture, index: 0)
        encoder.setVertexTexture(protectionTexture, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
        encoder.endEncoding()

        let isTerminalFrame = progress >= 1
        guard let submission = commandCompletionTracker.submit(
            isTerminalFrame: isTerminalFrame
        ) else {
            view.isPaused = true
            return
        }
        lastSubmittedProgress = Double(progress)
        if isTerminalFrame {
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
        guard terminalGate.resolve(.cancelled) else { return }
        stopRendering(hideView: false)
    }

    private func stopRendering(hideView: Bool) {
        commandCompletionTracker.cancel()
        firstFramePresentationGate.cancel()
        view?.isPaused = true
        view?.isHidden = hideView
        view?.delegate = nil
        view = nil
        commandQueue = nil
        backgroundPipeline = nil
        particlePipeline = nil
        backgroundTexture = nil
        protectionTexture = nil
    }

    private func makeUniforms(view: MTKView, progress: Float) -> DustRevealUniforms {
        let scale = view.contentScaleFactor
        let pixelRect = DustRevealGeometry.imageRect(
            imageSize: CGSize(
                width: backgroundTexture?.width ?? 0,
                height: backgroundTexture?.height ?? 0
            ),
            containerSize: view.drawableSize
        )
        let textureWidth = Float(backgroundTexture?.width ?? 1)
        let textureHeight = Float(backgroundTexture?.height ?? 1)
        let aspect = max(textureWidth / textureHeight, 0.01)
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
            particleSize: Float(max(6.5, min(10, scale * 2.8))),
            subjectProtectionRange: SIMD2(0.08, 0.72),
            particleMotion: SIMD4(
                Float(DustParticleMotion.maximumPointSize),
                Float(DustParticleMotion.maximumPerspectiveExpansion),
                Float(DustParticleMotion.maximumLateralVariation),
                aspect
            ),
            particleDepth: SIMD4(
                Float(DustParticleMotion.initialDepthScale),
                Float(DustParticleMotion.finalDepthScale),
                Float(DustParticleMotion.minimumDepthVariation),
                Float(DustParticleMotion.maximumDepthVariation)
            ),
            particleFade: SIMD4(
                Float(DustParticleMotion.birthEndAge),
                Float(DustParticleMotion.fadeStartAge),
                Float(DustParticleMotion.fadeEndAge),
                Float(DustParticleMotion.forwardExponent)
            ),
            particleInfo: SIMD4(
                UInt32(particleCount),
                UInt32(columns),
                UInt32(rows),
                0
            )
        )
    }

    private func finish() {
        guard terminalGate.resolve(.completed) else { return }
        stopRendering(hideView: true)
        onCompleted()
    }

    private func presentFirstFrameIfNeeded() {
        guard terminalGate.state == .active else { return }
        guard !hasPresentedFirstFrame else { return }
        hasPresentedFirstFrame = true
        onFirstFramePresented()
    }

    private func handleCommandCompletion(_ outcome: DustCommandCompletionTracker.Outcome) {
        guard terminalGate.state == .active else { return }

        switch outcome {
        case .finish:
            finish()
        case .fallback(let errorDescription):
            fail(with: .commandBufferExecutionFailed(errorDescription))
        }
    }

    private func fail(with error: DustRendererError) {
        guard terminalGate.resolve(.failed) else { return }
        Self.logger.error("Metal dust reveal stopped: \(error.localizedDescription, privacy: .public)")
        stopRendering(hideView: true)
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
    var subjectProtectionRange: SIMD2<Float>
    var particleMotion: SIMD4<Float>
    var particleDepth: SIMD4<Float>
    var particleFade: SIMD4<Float>
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
    case resourcesReleased

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
        case .resourcesReleased:
            "The Metal reveal resources were released before rendering completed."
        }
    }
}
