import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PreparedCaptureTransition: Sendable {
    let alignedCutout: CGImage
    let sticker: CGImage
    let backgroundOnly: CGImage
    let subjectProtectionMask: CGImage
    let outlineMask: CGImage
    let normalizedSubjectBounds: CGRect
    let normalizedPaddedCropBounds: CGRect
    let sourceSize: CGSize
    let workingColorSpace: CaptureTransitionColorSpace
}

struct CaptureTransitionColorSpace: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case sourceRGB
        case extendedSRGB
        case sRGB
    }

    let source: Source
    let name: String?

    static func resolve(for image: CGImage) -> Self {
        if let sourceColorSpace = image.colorSpace,
           sourceColorSpace.model == .rgb,
           let sourceName = sourceColorSpace.name,
           sourceName as String != "kCGColorSpaceDeviceRGB" {
            return Self(source: .sourceRGB, name: sourceName as String)
        }
        if let extended = CGColorSpace(name: CGColorSpace.extendedSRGB) {
            return Self(source: .extendedSRGB, name: extended.name as String?)
        }
        let standard = CGColorSpace(name: CGColorSpace.sRGB)
        return Self(source: .sRGB, name: standard?.name as String?)
    }

    func makeColorSpace() -> CGColorSpace? {
        if let name,
           let resolved = CGColorSpace(name: name as CFString),
           resolved.model == .rgb {
            return resolved
        }
        if source == .extendedSRGB,
           let extended = CGColorSpace(name: CGColorSpace.extendedSRGB) {
            return extended
        }
        // Standard sRGB is the explicit production fallback; never use DeviceRGB.
        return CGColorSpace(name: CGColorSpace.sRGB)
    }
}

enum GalleryImagePreparationCheckpoint: Equatable, Sendable {
    case beforeSourceDecode
    case beforeOrientationNormalization
    case afterThumbnailCreation
    case afterDownsampling
    case beforeReturn
}

enum CaptureImagePreparation {
    static func cameraImage(
        from data: Data,
        maximumDimension: CGFloat
    ) throws -> UIImage {
        try Task.checkCancellation()
        guard
            maximumDimension > 0,
            let source = CGImageSourceCreateWithData(
                data as CFData,
                [kCGImageSourceShouldCache: false] as CFDictionary
            )
        else {
            throw CatVisionError.unreadableImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: ceil(maximumDimension),
        ]
        try Task.checkCancellation()
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw CatVisionError.unreadableImage
        }

        try Task.checkCancellation()
        return UIImage(cgImage: thumbnail, scale: 1, orientation: .up)
    }

    static func galleryImage(
        from data: Data,
        maximumDimension: CGFloat,
        checkpoint: (GalleryImagePreparationCheckpoint) throws -> Void = { _ in
            try Task.checkCancellation()
        }
    ) throws -> CGImage {
        try checkpoint(.beforeSourceDecode)
        guard
            maximumDimension > 0,
            let source = CGImageSourceCreateWithData(
                data as CFData,
                [kCGImageSourceShouldCache: false] as CFDictionary
            )
        else {
            throw CatVisionError.unreadableImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: ceil(maximumDimension),
        ]
        try checkpoint(.beforeOrientationNormalization)
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw CatVisionError.unreadableImage
        }
        try checkpoint(.afterThumbnailCreation)

        // ImageIO applies orientation normalization and downsampling in the same
        // thumbnail operation, so cancellation can resume immediately afterward.
        try checkpoint(.afterDownsampling)
        try checkpoint(.beforeReturn)
        return thumbnail
    }

    static func preparedGalleryImage(
        from data: Data,
        maximumDimension: CGFloat
    ) async throws -> CGImage {
        try await runGalleryWorker {
            try galleryImage(from: data, maximumDimension: maximumDimension)
        }
    }

    static func preparedGalleryImage(
        at url: URL,
        maximumDimension: CGFloat
    ) async throws -> CGImage {
        try await runGalleryWorker {
            try Task.checkCancellation()
            let data = try Data(contentsOf: url)
            try Task.checkCancellation()
            return try galleryImage(from: data, maximumDimension: maximumDimension)
        }
    }

    static func runGalleryWorker(
        didInstallCancellationHandler: (@Sendable () -> Void)? = nil,
        operation: @escaping @Sendable () throws -> CGImage
    ) async throws -> CGImage {
        let worker = Task.detached(priority: .userInitiated) {
            try operation()
        }
        return try await withTaskCancellationHandler {
            didInstallCancellationHandler?()
            let result = try await worker.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            worker.cancel()
        }
    }

    static func transitionAssets(
        original: CGImage,
        alignedCutout: CGImage,
        maximumDimension: Int = 1600
    ) throws -> PreparedCaptureTransition {
        try Task.checkCancellation()
        guard
            maximumDimension > 0,
            original.width == alignedCutout.width,
            original.height == alignedCutout.height,
            original.width > 0,
            original.height > 0
        else {
            throw CatVisionError.unreadableImage
        }

        let colorMetadata = CaptureTransitionColorSpace.resolve(for: original)
        guard let colorSpace = colorMetadata.makeColorSpace() else {
            throw CatVisionError.unreadableImage
        }
        let context = CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .cacheIntermediates: false,
        ])
        let sourceExtent = CGRect(x: 0, y: 0, width: original.width, height: original.height)
        let scale = min(CGFloat(maximumDimension) / max(sourceExtent.width, sourceExtent.height), 1)
        let targetSize = CGSize(
            width: max(1, (sourceExtent.width * scale).rounded()),
            height: max(1, (sourceExtent.height * scale).rounded())
        )
        let targetExtent = CGRect(origin: .zero, size: targetSize)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        // Preserve each image's embedded input profile. The CI context converts both
        // into the selected working space when rendering; overriding this option would
        // only relabel the cutout's samples when its profile differs from the photo.
        let sourceImage = CIImage(cgImage: original)
            .transformed(by: transform)
            .cropped(to: targetExtent)
        let cutoutImage = CIImage(cgImage: alignedCutout)
            .transformed(by: transform)
            .cropped(to: targetExtent)
        try Task.checkCancellation()

        guard
            let renderedCutout = context.createCGImage(
                cutoutImage,
                from: targetExtent,
                format: .RGBA8,
                colorSpace: colorSpace
            ),
            let subjectBounds = try alphaBounds(in: renderedCutout, colorSpace: colorSpace)
        else {
            throw CatVisionError.unreadableImage
        }

        let alphaMask = cutoutImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ]).cropped(to: targetExtent)
        let backgroundFilter = CIFilter.blendWithAlphaMask()
        backgroundFilter.inputImage = CIImage(color: .clear).cropped(to: targetExtent)
        backgroundFilter.backgroundImage = sourceImage
        backgroundFilter.maskImage = alphaMask

        let longEdge = max(targetExtent.width, targetExtent.height)
        let morphologyRadius = min(max(longEdge * 0.0075, 8), 16)
        let outline = alphaMask
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": morphologyRadius])
            .cropped(to: targetExtent)
        let protection = outline
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": morphologyRadius * 0.35])
            .cropped(to: targetExtent)
        let cropPadding = ceil(morphologyRadius + 2)
        let cropBounds = subjectBounds
            .insetBy(dx: -cropPadding, dy: -cropPadding)
            .intersection(targetExtent)
            .integral

        guard let backgroundImage = backgroundFilter.outputImage?.cropped(to: targetExtent),
              let fullOutlineMask = context.createCGImage(
                outline,
                from: targetExtent,
                format: .RGBA8,
                colorSpace: colorSpace
              ),
            let backgroundOnly = context.createCGImage(
                backgroundImage,
                from: targetExtent,
                format: .RGBA8,
                colorSpace: colorSpace
            ),
            let protectionMask = context.createCGImage(
                protection,
                from: targetExtent,
                format: .RGBA8,
                colorSpace: colorSpace
            ),
            let sticker = renderedCutout.cropping(to: cropBounds),
            let outlineMask = fullOutlineMask.cropping(to: cropBounds)
        else {
            throw CatVisionError.unreadableImage
        }

        let prepared = PreparedCaptureTransition(
            alignedCutout: renderedCutout,
            sticker: sticker,
            backgroundOnly: backgroundOnly,
            subjectProtectionMask: protectionMask,
            outlineMask: outlineMask,
            normalizedSubjectBounds: normalized(subjectBounds, in: targetExtent),
            normalizedPaddedCropBounds: normalized(cropBounds, in: targetExtent),
            sourceSize: targetSize,
            workingColorSpace: colorMetadata
        )
        try Task.checkCancellation()
        return prepared
    }

    private static func normalized(_ rect: CGRect, in extent: CGRect) -> CGRect {
        CGRect(
            x: (rect.minX - extent.minX) / extent.width,
            y: (rect.minY - extent.minY) / extent.height,
            width: rect.width / extent.width,
            height: rect.height / extent.height
        )
    }

    private static func alphaBounds(in image: CGImage, colorSpace: CGColorSpace) throws -> CGRect? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            if y.isMultiple(of: 64) {
                try Task.checkCancellation()
            }
            for x in 0..<width where pixels[y * bytesPerRow + x * 4 + 3] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

enum AspectFitPointMapping {
    static func normalizedSourcePoint(
        at location: CGPoint,
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGPoint? {
        guard
            imageSize.width > 0,
            imageSize.height > 0,
            containerSize.width > 0,
            containerSize.height > 0
        else {
            return nil
        }

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let fittedOrigin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )
        guard
            location.x >= fittedOrigin.x,
            location.x < fittedOrigin.x + fittedSize.width,
            location.y >= fittedOrigin.y,
            location.y < fittedOrigin.y + fittedSize.height
        else {
            return nil
        }

        return CGPoint(
            x: (location.x - fittedOrigin.x) / fittedSize.width,
            y: (location.y - fittedOrigin.y) / fittedSize.height
        )
    }
}

enum ForegroundSelectionAccessibility {
    static let defaultNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
}

enum CameraPrivacyBadgeLayout {
    static func textLineLimit(for dynamicTypeSize: DynamicTypeSize) -> Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }

    static func minimumScaleFactor(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 1 : 0.86
    }
}

private enum ForegroundSelectionArea: String, Identifiable, Sendable {
    case topLeft
    case topCenter
    case topRight
    case middleLeft
    case center
    case middleRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var id: Self { self }

    var title: String {
        switch self {
        case .topLeft: "Top left"
        case .topCenter: "Top center"
        case .topRight: "Top right"
        case .middleLeft: "Middle left"
        case .center: "Center"
        case .middleRight: "Middle right"
        case .bottomLeft: "Bottom left"
        case .bottomCenter: "Bottom center"
        case .bottomRight: "Bottom right"
        }
    }

    var normalizedPoint: CGPoint {
        let coordinate: (column: CGFloat, row: CGFloat) = switch self {
        case .topLeft: (0, 0)
        case .topCenter: (1, 0)
        case .topRight: (2, 0)
        case .middleLeft: (0, 1)
        case .center: (1, 1)
        case .middleRight: (2, 1)
        case .bottomLeft: (0, 2)
        case .bottomCenter: (1, 2)
        case .bottomRight: (2, 2)
        }
        return CGPoint(
            x: (coordinate.column + 0.5) / 3,
            y: (coordinate.row + 0.5) / 3
        )
    }
}

struct CaptureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.catLocalCardMotionEnabled) private var cardMotionEnabled
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var existingRecords: [CatRecord]

    @StateObject private var camera = CameraController()
    @State private var stage: CaptureStage = .camera
    @State private var photoItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var preparedTransition: PreparedCaptureTransition?
    @State private var cutoutImage: UIImage?
    @State private var cutoutOutlineMask: CGImage?
    @State private var pinchZoomStart: CGFloat?
    @State private var detections: [CatDetection] = []
    @State private var selectedBoundingBox: CGRect?
    @State private var source: CaptureSource = .camera
    @State private var nickname = ""
    @State private var note = ""
    @State private var placeName = ""
    @State private var placeDetail = ""
    @State private var selectedStyle: CardStyle = .archive
    @State private var draftSuggestedName = ""
    @State private var draftSequence: Int?
    @State private var persistedRecord: CatRecord?
    @State private var errorMessage: String?
    @State private var foregroundSelectionMessage: String?
    @State private var failureContext: LociContext = .failureRecovery
    @State private var processingGate = CaptureProcessingSessionGate()
    @State private var processingTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var isEditorSheetPresented = false
    @State private var isSavedCardDraftLoaded = false
    @State private var showsProcessingCancellation = false
    @State private var pendingDiscardAction: CaptureDiscardAction?
    @State private var isDiscardConfirmationPresented = false
    @State private var isCardMintingDone = false
    @State private var captureSelectionFeedbackTrigger = 0
    @State private var captureWarningFeedbackTrigger = 0
    @State private var captureSaveTapFeedbackTrigger = 0
    @State private var captureCompletionFeedbackTrigger = 0
    @State private var subjectToCardCompletionGate = SubjectToCardCompletionGate()
    @State private var transitionSessionGate = CaptureTransitionSessionGate()
    @FocusState private var focusedEditorField: EditorField?

    private let processor = CatVisionProcessor()

    private var cardMotionIsReduced: Bool {
        reduceMotion || !cardMotionEnabled
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch stage {
                case .camera:
                    cameraScreen
                case .analyzing, .creatingCutout, .stickerReveal:
                    subjectLiftScreen
                case .choosingCat:
                    catSelectionScreen
                case .choosingForeground:
                    foregroundSelectionScreen
                case .stickerInspecting:
                    stickerInspectionScreen
                case .cardCelebrating:
                    cardCelebrationScreen
                case .failure:
                    failureScreen
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .simultaneousGesture(cameraMagnifyGesture)
        .task {
            #if DEBUG
            if forcesCameraDeniedForValidation {
                return
            }
            #endif
            await camera.requestAccessAndConfigure()
            if effectiveCameraAuthorizationStatus == .authorized {
                camera.start()
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            startPhotoLoad(item)
        }
        .task(id: isProcessingCancellationEligible) {
            guard isProcessingCancellationEligible else {
                showsProcessingCancellation = false
                return
            }

            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }
            guard isProcessingCancellationEligible else { return }

            if reduceMotion {
                showsProcessingCancellation = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    showsProcessingCancellation = true
                }
            }
        }
        .sheet(isPresented: $isEditorSheetPresented) {
            editorSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(CatLocalTheme.background)
                .presentationContentInteraction(.resizes)
                .presentationBackgroundInteraction(.disabled)
                .interactiveDismissDisabled(true)
        }
        .onDisappear {
            cancelActiveProcessing()
            camera.stop()
        }
        .interactiveDismissDisabled(stage != .camera)
        .confirmationDialog(
            "Discard this draft?",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible,
            presenting: pendingDiscardAction
        ) { action in
            Button(role: .destructive) {
                performDiscardAction(action)
            } label: {
                Text(catLocalKey: action.destructiveTitle)
            }
            Button("Keep Draft") {
                pendingDiscardAction = nil
                isDiscardConfirmationPresented = false
            }
        } message: { action in
            Text(catLocalKey: action.message)
        }
        .onChange(of: isDiscardConfirmationPresented) { _, isPresented in
            if !isPresented {
                pendingDiscardAction = nil
            }
        }
        .catSensoryFeedback(.selection, trigger: captureSelectionFeedbackTrigger)
        .catSensoryFeedback(.warning, trigger: captureWarningFeedbackTrigger)
        .catSensoryFeedback(.impact(flexibility: .soft, intensity: 0.36), trigger: captureSaveTapFeedbackTrigger)
        .catSensoryFeedback(.success, trigger: captureCompletionFeedbackTrigger)
    }

    private var cameraScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isConfigured && effectiveCameraAuthorizationStatus == .authorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                cameraUnavailableBackground
            }

            LinearGradient(
                colors: [.black.opacity(0.56), .clear, .black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                cameraTopBar
                Spacer()
                cameraGuidance
                if camera.isConfigured, let cameraError = camera.errorMessage {
                    Text(cameraError.catLocalized)
                        .font(CatTypography.finePrint)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.46), in: Capsule())
                        .accessibilityIdentifier("camera-status-message")
                }
                cameraControls
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("capture-screen")
    }

    private var cameraTopBar: some View {
        CatGlassGroup(spacing: 18) {
            HStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
                spacing: 12
            ) {
                cameraPrivacyBadge

                Spacer(minLength: 12)

                Button {
                    closeCamera()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .catCameraOverlayIconSurface()
                }
                .buttonStyle(.catTactile)
                .layoutPriority(2)
                .accessibilityLabel("Close camera")
            }
        }
    }

    private var cameraPrivacyBadge: some View {
        HStack(spacing: 9) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Private scan")
                    .font(CatTypography.compactControl)
                Text("On this iPhone")
                    .font(CatTypography.finePrint)
                    .opacity(0.82)
            }
            .lineLimit(CameraPrivacyBadgeLayout.textLineLimit(for: dynamicTypeSize))
            .minimumScaleFactor(CameraPrivacyBadgeLayout.minimumScaleFactor(for: dynamicTypeSize))
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CatAttentionRole.info.strongForeground)
        .padding(.leading, 10)
        .padding(.trailing, 13)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
        .frame(minHeight: 50)
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
            alignment: .leading
        )
        .background(
            CatAttentionRole.info.accent.opacity(0.92),
            in: RoundedRectangle(
                cornerRadius: dynamicTypeSize.isAccessibilitySize ? 18 : 25,
                style: .continuous
            )
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: dynamicTypeSize.isAccessibilitySize ? 18 : 25,
                style: .continuous
            )
        )
        .layoutPriority(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Private scan on this iPhone")
    }

    private var cameraGuidance: some View {
        VStack(spacing: 7) {
            Text("Give them a little room")
                .font(CatTypography.momentTitle)
                .lineLimit(nil)
            Text("Keep the whole cat visible for the cleanest cutout.")
                .font(CatTypography.supporting)
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(nil)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.bottom, 20)
    }

    private var cameraControls: some View {
        CatGlassGroup(spacing: 18) {
            VStack(spacing: 14) {
                HStack {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .catCameraOverlayIconSurface()
                    }
                    .buttonStyle(.catTactile)
                    .disabled(!canImportPhoto)
                    .opacity(canImportPhoto ? 1 : 0.45)
                    .accessibilityLabel("Choose private photo")
                    .accessibilityHint("The selected photo stays on this iPhone")

                    Spacer(minLength: 12)

                    Button {
                        captureCameraPhoto()
                    } label: {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 82, height: 82)
                            .overlay {
                                Circle()
                                    .fill(.white)
                                    .padding(8)
                            }
                    }
                    .buttonStyle(.catTactile)
                    .disabled(!canTakePhoto)
                    .opacity(canTakePhoto ? 1 : 0.45)
                    .accessibilityLabel("Take photo")

                    Spacer(minLength: 12)

                    cameraZoomControl
                }

                #if DEBUG
                if showsValidationImport {
                    Button {
                        startValidationPhotoLoad()
                    } label: {
                        Label("Use validation photo", systemImage: "wand.and.stars")
                            .font(CatTypography.badge.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .catGlass(
                                cornerRadius: 20,
                                interactive: true,
                                legacyRole: .cameraOverlay
                            )
                    }
                    .buttonStyle(.catTactile)
                    .disabled(!canImportPhoto)
                    .opacity(canImportPhoto ? 1 : 0.45)
                    .accessibilityIdentifier("capture-validation-photo")
                }
                #endif
            }
        }
    }

    private var cameraZoomControl: some View {
        Menu {
            if camera.minimumDisplayZoomFactor <= 0.5,
               camera.maximumDisplayZoomFactor >= 0.5 {
                Button("0.5×") {
                    camera.setDisplayZoomFactor(0.5, animated: true)
                }
            }

            if camera.minimumDisplayZoomFactor <= 1,
               camera.maximumDisplayZoomFactor >= 1 {
                Button("1×") {
                    camera.setDisplayZoomFactor(1, animated: true)
                }
            }

            if camera.minimumDisplayZoomFactor <= 2,
               camera.maximumDisplayZoomFactor >= 2 {
                Button("2×") {
                    camera.setDisplayZoomFactor(2, animated: true)
                }
            }

            if camera.minimumDisplayZoomFactor <= 3,
               camera.maximumDisplayZoomFactor >= 3 {
                Button("3×") {
                    camera.setDisplayZoomFactor(3, animated: true)
                }
            }
        } label: {
            Text(cameraZoomLabel)
                .font(CatTypography.badge.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .catGlass(
                    cornerRadius: 28,
                    interactive: true,
                    legacyRole: .cameraOverlay
                )
        }
        .buttonStyle(.catTactile)
        .disabled(!camera.isConfigured)
        .opacity(camera.isConfigured ? 1 : 0.45)
        .accessibilityLabel("Camera zoom")
        .accessibilityValue(cameraZoomLabel)
        .accessibilityHint("Double tap to choose a zoom level. Swipe up or down to adjust.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                camera.setDisplayZoomFactor(camera.displayZoomFactor + 0.5, animated: true)
            case .decrement:
                camera.setDisplayZoomFactor(camera.displayZoomFactor - 0.5, animated: true)
            @unknown default:
                break
            }
        }
    }

    private var cameraZoomLabel: String {
        Double(camera.displayZoomFactor).formatted(
            .number.precision(.fractionLength(0...1))
        ) + "×"
    }

    private var cameraMagnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard stage == .camera, camera.isConfigured else { return }
                let base = pinchZoomStart ?? camera.displayZoomFactor
                if pinchZoomStart == nil {
                    pinchZoomStart = base
                }
                let target = CameraZoomMath.displayFactor(
                    baseDisplayFactor: base,
                    magnification: value.magnification,
                    minimumDisplayFactor: camera.minimumDisplayZoomFactor,
                    maximumDisplayFactor: camera.maximumDisplayZoomFactor
                )
                camera.setDisplayZoomFactor(target, animated: false)
            }
            .onEnded { _ in
                pinchZoomStart = nil
            }
    }

    private var cameraUnavailableBackground: some View {
        VStack(spacing: 15) {
            Image(systemName: effectiveCameraAuthorizationStatus == .denied ? "camera.fill.badge.xmark" : "camera.aperture")
                .font(.system(size: 58, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.9))

            if effectiveCameraAuthorizationStatus == .denied || effectiveCameraAuthorizationStatus == .restricted {
                Text("Camera access is off")
                    .font(CatTypography.momentTitle)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("camera-permission-denied-state")
                Text("You can still choose a private photo, or enable camera access in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: 300)

                VStack(spacing: 10) {
                    privatePhotoImportAction
                    openCameraSettingsButton
                }
                .frame(maxWidth: 280)
            } else if let cameraError = camera.errorMessage {
                Text(cameraError.catLocalized)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 300)

                privatePhotoImportAction
                    .frame(maxWidth: 280)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .accessibilityIdentifier(
            effectiveCameraAuthorizationStatus == .denied
                ? "camera-permission-denied-state"
                : "camera-unavailable-state"
        )
    }

    private var privatePhotoImportAction: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Label("Choose private photo", systemImage: "photo.on.rectangle")
                .font(CatTypography.control)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .catPrimaryActionSurface(role: .action, cornerRadius: 24)
        }
        .buttonStyle(.catTactile)
        .disabled(!canImportPhoto)
        .opacity(canImportPhoto ? 1 : 0.45)
        .accessibilityHint("The selected photo stays on this iPhone")
    }

    private var openCameraSettingsButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            Label("Open Settings", systemImage: "gearshape")
                .font(CatTypography.control)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .catSecondaryActionSurface(cornerRadius: 24, minHeight: 52)
        }
        .buttonStyle(.catTactile)
    }

    private var processingScreen: some View {
        ZStack {
            CatLocalTheme.primaryText.ignoresSafeArea()

            if let originalImage {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.12)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 18) {
                Image(systemName: stage == .analyzing ? "viewfinder" : "scissors")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityHidden(true)

                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text(catLocalKey: stage == .analyzing ? "Looking for cats" : "Removing the background")
                    .font(CatTypography.pageTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("This happens entirely on your iPhone.")
                    .font(CatTypography.supporting)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                stage == .analyzing
                    ? "Looking for cats".catLocalized
                    : "Creating cat cutout".catLocalized
            )
            .padding(24)
        }
    }

    private var subjectLiftScreen: some View {
        Group {
            if
                stage == .stickerReveal,
                let originalImage,
                let preparedTransition,
                let transitionID = transitionSessionGate.activeID
            {
                SubjectToCardTransitionView(
                    sourceImage: originalImage,
                    transition: preparedTransition,
                    reducesMotion: cardMotionIsReduced || forcesReducedMotionRevealForValidation,
                    onCompleted: {
                        completeSubjectToCardTransition(transitionID: transitionID)
                    }
                ) { catOpacity, cardOpacity, backdropOpacity, cardScale, coordinateSpaceName, onImageStageFrameChange in
                    draftCardInspectionLayout(
                        catOpacity: catOpacity,
                        cardOpacity: cardOpacity,
                        backdropOpacity: backdropOpacity,
                        cardScale: cardScale,
                        showsControls: false,
                        imageStageCoordinateSpaceName: coordinateSpaceName,
                        onImageStageFrameChange: { frame in
                            if onImageStageFrameChange.wrappedValue != frame {
                                onImageStageFrameChange.wrappedValue = frame
                            }
                        }
                    )
                }
            } else {
                FullScreenDustRevealView(
                    sourceImage: originalImage,
                    transition: nil,
                    forcesFallback: true
                ) {}
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsProcessingCancellation, isProcessingCancellationEligible {
                stopProcessingButton
                    .padding(.top, 12)
                    .padding(.trailing, CatLocalTheme.screenHorizontalPadding)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var isProcessingCancellationEligible: Bool {
        stage == .analyzing || stage == .creatingCutout
    }

    private var stopProcessingButton: some View {
        Button {
            reset()
        } label: {
            Label("Stop and return", systemImage: "xmark")
                .font(CatTypography.compactControl)
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .catGlass(
                    cornerRadius: 22,
                    interactive: true,
                    legacyRole: .cameraOverlay
                )
        }
        .buttonStyle(.catTactile)
        .accessibilityHint("Cancels on-device processing and returns to the camera")
        .accessibilityIdentifier("capture-stop-processing")
    }

    private var catSelectionScreen: some View {
        ZStack {
            CatLocalBackground()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button("Retake") { requestDiscardAction(.retake) }
                        Spacer()
                        Label(
                            CatLocalLocalization.plural("%lld cats found", count: detections.count),
                            systemImage: "checkmark.circle.fill"
                        )
                            .font(CatTypography.supportingEmphasized)
                            .catAttentionPillSurface(role: .success)
                    }

                    if let originalImage {
                        CatSelectionImage(
                            image: originalImage,
                            detections: detections
                        )
                    }

                    VStack(spacing: 8) {
                        Text("Which cat gets the card?")
                            .font(CatTypography.pageTitle)
                            .foregroundStyle(CatLocalTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Match a number in the photo, then choose that cat.")
                            .font(CatTypography.supporting)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    CatGlassGroup(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                                Button {
                                    startCutout(for: detection)
                                } label: {
                                    HStack(spacing: 14) {
                                        CatSelectionNumberBadge(number: index + 1, size: 34)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(
                                                CatLocalLocalization.format(
                                                    "Cat %lld",
                                                    Int64(index + 1)
                                                )
                                            )
                                                .font(CatTypography.control)

                                            Text(
                                                CatLocalLocalization.format(
                                                    "Marked %lld in the photo",
                                                    Int64(index + 1)
                                                )
                                            )
                                                .font(CatTypography.metadata)
                                                .foregroundStyle(CatLocalTheme.secondaryText)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundStyle(CatLocalTheme.primaryText)
                                    .padding(.horizontal, 18)
                                    .frame(minHeight: 56)
                                    .catGlass(
                                        cornerRadius: 20,
                                        interactive: true,
                                        legacyRole: .groupedAction
                                    )
                                }
                                .buttonStyle(.catTactile)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(
                                    CatLocalLocalization.format(
                                        "Cat %1$lld, marked %2$lld in the photo",
                                        Int64(index + 1),
                                        Int64(index + 1)
                                    )
                                )
                                .accessibilityHint("Selects this cat for the card")
                                .accessibilityIdentifier("cat-selection-option-\(index + 1)")
                            }
                        }
                    }
                }
                .padding(CatLocalTheme.screenHorizontalPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var foregroundSelectionScreen: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 18) {
                HStack {
                    Button("Retake") { reset() }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    Spacer()
                }

                VStack(spacing: 7) {
                    Text("Tap the cat")
                        .font(CatTypography.pageTitle)
                        .foregroundStyle(CatLocalTheme.primaryText)

                    Text("Tap directly on the cat, or choose a named photo area below.")
                        .font(CatTypography.supporting)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                if let originalImage {
                    ForegroundSelectionPhoto(image: originalImage) { normalizedPoint in
                        chooseForeground(at: normalizedPoint)
                    }
                    .frame(maxHeight: .infinity)
                }

                foregroundSelectionAreaMenu

                if let foregroundSelectionMessage {
                    Label {
                        Text(catLocalKey: foregroundSelectionMessage)
                    } icon: {
                        Image(systemName: "hand.tap.fill")
                    }
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatAttentionRole.warning.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            CatAttentionRole.warning.wash,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .accessibilityIdentifier("foreground-selection-guidance")
                }

                privatePhotoImportAction
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    private var foregroundSelectionAreaMenu: some View {
        Menu {
            Section("Top") {
                foregroundSelectionAreaButton(.topLeft)
                foregroundSelectionAreaButton(.topCenter)
                foregroundSelectionAreaButton(.topRight)
            }

            Section("Middle") {
                foregroundSelectionAreaButton(.middleLeft)
                foregroundSelectionAreaButton(.center)
                foregroundSelectionAreaButton(.middleRight)
            }

            Section("Bottom") {
                foregroundSelectionAreaButton(.bottomLeft)
                foregroundSelectionAreaButton(.bottomCenter)
                foregroundSelectionAreaButton(.bottomRight)
            }
        } label: {
            Label("Choose photo area", systemImage: "square.grid.3x3")
                .font(CatTypography.compactControl)
                .foregroundStyle(CatLocalTheme.primaryText)
                .catSingleActionPillSurface()
        }
        .accessibilityHint("Opens nine named regions for selecting the cat without an exact tap")
        .accessibilityIdentifier("foreground-area-menu")
    }

    private func foregroundSelectionAreaButton(_ area: ForegroundSelectionArea) -> some View {
        Button {
            chooseForeground(at: area.normalizedPoint)
        } label: {
            Text(catLocalKey: area.title)
        }
    }

    private var stickerInspectionScreen: some View {
        draftCardInspectionLayout(
            catOpacity: 1,
            cardOpacity: 1,
            backdropOpacity: 1,
            cardScale: 1,
            showsControls: true,
            imageStageCoordinateSpaceName: nil,
            onImageStageFrameChange: nil
        )
        .accessibilityIdentifier("draft-card-inspection")
    }

    private func draftCardInspectionLayout(
        catOpacity: Double,
        cardOpacity: Double,
        backdropOpacity: Double,
        cardScale: CGFloat,
        showsControls: Bool,
        imageStageCoordinateSpaceName: String?,
        onImageStageFrameChange: ((CGRect) -> Void)?
    ) -> some View {
        ZStack {
            CatLocalBackground()
                .opacity(backdropOpacity)

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        editorTopBar
                            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                            .padding(.top, 12)
                            .opacity(showsControls ? 1 : 0)
                            .allowsHitTesting(showsControls)
                            .accessibilityHidden(!showsControls)

                        if let cutoutImage {
                            DraftCatCardView(
                                image: cutoutImage,
                                sequence: activeSequence,
                                name: editorPreviewName,
                                note: note,
                                placeName: placeName,
                                placeDetail: placeDetail,
                                cardStyle: selectedStyle,
                                presentation: .focused,
                                showsFooter: true,
                                catBoundingBox: selectedBoundingBox,
                                patternSeed: activeSequence,
                                appliesStickerEffect: true,
                                stickerMotionIntensity: nil,
                                catOpacity: catOpacity,
                                outlineMask: cutoutOutlineMask,
                                imageStageCoordinateSpaceName: imageStageCoordinateSpaceName,
                                onImageStageFrameChange: onImageStageFrameChange
                            )
                            .frame(width: min(330, max(260, proxy.size.width - 44)))
                            .scaleEffect(cardScale)
                            .opacity(cardOpacity)
                            .accessibilityLabel("Draft cat card")
                        }

                        stickerInspectionActions
                            .padding(.bottom, 18)
                            .opacity(showsControls ? 1 : 0)
                            .allowsHitTesting(showsControls)
                            .accessibilityHidden(!showsControls)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var stickerInspectionActions: some View {
        VStack(spacing: 10) {
            quickSaveButton
            customizeButton
        }
    }

    private var quickSaveButton: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return Button {
            captureSaveTapFeedbackTrigger += 1
            Task { await finishCustomization() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CatAttentionRole.action.accent)

                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CatAttentionRole.action.strongForeground)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(CatAttentionRole.action.strongForeground)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(catLocalKey: isSaving ? "Preparing card" : "Save Cat")
                        .font(CatTypography.control)

                    Text(catLocalKey: isSaving ? "Adding finishing touches" : "Edit details later")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.82)

                Spacer(minLength: 8)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .contentShape(shape)
            .catCommitActionSurface(role: .action, cornerRadius: 24)
        }
        .buttonStyle(.catTactile)
        .contentShape(shape)
        .disabled(isSaving)
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        .accessibilityIdentifier("save-cat-immediate")
        .accessibilityLabel(
            isSaving ? "Preparing cat card".catLocalized : "Save Cat".catLocalized
        )
        .accessibilityHint("Saves this card now. You can edit the name, design, and Catlas details later.")
    }

    private var customizeButton: some View {
        Button {
            expandEditor()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CatAttentionRole.action.accent)
                    .frame(width: 34, height: 34)
                    .background(CatAttentionRole.action.wash, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Before Saving")
                        .font(CatTypography.control)
                        .foregroundStyle(CatLocalTheme.primaryText)

                    Text("Design, name, and Catlas labels")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.86)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .catSecondaryActionSurface(cornerRadius: 24, minHeight: 64)
        }
        .buttonStyle(.catTactile)
        .disabled(isSaving)
        .opacity(isSaving ? 0.55 : 1)
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        .accessibilityIdentifier("tap-to-customize")
        .accessibilityLabel("Edit Before Saving")
        .accessibilityHint("Opens design, name, note, and Catlas fields before saving.")
    }

    private var editorSheet: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                CatLocalBackground()
                    .onTapGesture {
                        dismissEditorKeyboard()
                    }

                editorForm

                editorSheetActionButton
                    .padding(.top, 14)
                    .padding(.trailing, CatLocalTheme.screenHorizontalPadding)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("sticker-editor-sheet")
    }

    private var editorSheetActionButton: some View {
        CatSheetActionButton(mode: .close) {
            collapseEditor()
        }
        .accessibilityIdentifier("sticker-editor-sheet-action")
    }

    private var editorSheetSaveButton: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return Button {
            dismissEditorKeyboard()
            captureSaveTapFeedbackTrigger += 1
            Task { await finishCustomization() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CatAttentionRole.action.accent)

                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CatAttentionRole.action.strongForeground)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(CatAttentionRole.action.strongForeground)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(catLocalKey: isSaving ? "Preparing card" : "Save Cat")
                        .font(CatTypography.control)

                    Text(catLocalKey: isSaving ? "Adding finishing touches" : "Save to Collection")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.86)

                Spacer(minLength: 8)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .contentShape(shape)
            .catCommitActionSurface(role: .action, cornerRadius: 24)
        }
        .buttonStyle(.catTactile)
        .contentShape(shape)
        .disabled(isSaving)
        .accessibilityLabel(
            isSaving ? "Preparing cat card".catLocalized : "Save Cat".catLocalized
        )
        .accessibilityIdentifier("capture-editor-save")
    }

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                makeItYoursHeading

                Text("Choose a card design now, or save first and edit later.")
                    .font(CatTypography.screenSubtitle)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                editorCardPreview

                CardStylePicker(
                    selectedStyle: $selectedStyle,
                    itemWidth: 154,
                    previewAspectRatio: 1.28,
                    itemPadding: 6,
                    itemCornerRadius: 22,
                    itemSpacing: 12,
                    titleMinHeight: 20
                ) { style in
                    CardStyleSwatch(style: style)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissEditorKeyboard()
                    }
                )

                editorFieldHeading("Name the Cat")

                TextField("Nickname", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .focused($focusedEditorField, equals: .nickname)
                    .catInputSurface()
                    .accessibilityIdentifier("capture-editor-nickname")

                editorFieldHeading("Catlas")

                TextField("Memory Place", text: $placeName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedEditorField, equals: .placeName)
                    .catInputSurface()
                    .accessibilityHint("Adds a manual place label to the private Catlas")
                    .accessibilityIdentifier("capture-editor-place")

                TextField("Place Detail", text: $placeDetail, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedEditorField, equals: .placeDetail)
                    .catInputSurface()
                    .accessibilityIdentifier("capture-editor-place-detail")

                editorFieldHeading("Encounter Note")

                TextField("A note about this encounter", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedEditorField, equals: .note)
                    .catInputSurface()
                    .accessibilityIdentifier("capture-editor-note")

                catlasPrivacyNote
            }
            .padding(18)
            .padding(.top, 52)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissEditorKeyboard()
                    }
            }
        }
        .accessibilityIdentifier("capture-editor-scroll")
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            editorSaveSection
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(CatLocalTheme.background.opacity(0.96))
        }
    }

    private var editorSaveSection: some View {
        VStack(spacing: 9) {
            editorSheetSaveButton

            Text("The card, details, and images stay on this iPhone.")
                .font(CatTypography.finePrint)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var editorCardPreview: some View {
        if let cutoutImage {
            DraftCatCardView(
                image: cutoutImage,
                sequence: activeSequence,
                name: editorPreviewName,
                note: note,
                placeName: placeName,
                placeDetail: placeDetail,
                cardStyle: selectedStyle,
                presentation: .focused,
                showsFooter: true,
                catBoundingBox: selectedBoundingBox,
                patternSeed: activeSequence,
                appliesStickerEffect: true,
                stickerMotionIntensity: nil,
                outlineMask: cutoutOutlineMask
            )
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .animation(.smooth(duration: 0.22, extraBounce: 0), value: selectedStyle)
            .accessibilityLabel("Live card preview")
        }
    }

    private var makeItYoursHeading: some View {
        Text("Make It Yours")
        .foregroundStyle(CatLocalTheme.primaryText)
        .font(CatTypography.pageTitle)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Make It Yours")
    }

    private var celebrationPreviewNote: String {
        persistedRecord?.note ?? note
    }

    private var celebrationPreviewPlaceName: String {
        persistedRecord?.placeName ?? placeName
    }

    private var celebrationPreviewPlaceDetail: String {
        persistedRecord?.placeDetail ?? placeDetail
    }

    private var celebrationPreviewStyle: CardStyle {
        persistedRecord?.cardStyle ?? selectedStyle
    }

    private var celebrationPreviewBoundingBox: CGRect? {
        persistedRecord?.catBoundingBox ?? selectedBoundingBox
    }

    private var celebrationPreviewPatternSeed: Int {
        persistedRecord?.sequence ?? activeSequence
    }

    private var cardCelebrationScreen: some View {
        Group {
            if let cutoutImage {
                CardMintingSuccessView(
                    isCustomizationDone: $isCardMintingDone,
                    showsCustomizationPanel: false,
                    showsLociCompanion: true,
                    onHome: {
                        requestDiscardAction(.close)
                    },
                    onKeepEditing: {
                        editSavedCard()
                    }
                ) { mintingSheen in
                    LiveInteractiveCardView(
                        width: nil,
                        height: nil,
                        cornerRadius: 34
                    ) { rotateX, rotateY, isInteracting in
                        DraftCatCardView(
                            image: cutoutImage,
                            sequence: activeSequence,
                            name: celebrationPreviewName,
                            note: celebrationPreviewNote,
                            placeName: celebrationPreviewPlaceName,
                            placeDetail: celebrationPreviewPlaceDetail,
                            cardStyle: celebrationPreviewStyle,
                            presentation: .focused,
                            rotateX: rotateX,
                            rotateY: rotateY,
                            isLightActive: isInteracting,
                            showsFooter: true,
                            catBoundingBox: celebrationPreviewBoundingBox,
                            patternSeed: celebrationPreviewPatternSeed,
                            showsSurfaceShadow: false,
                            appliesStickerEffect: true,
                            stickerMotionIntensity: nil,
                            outlineMask: cutoutOutlineMask
                        )
                        .overlay {
                            if mintingSheen.isVisible {
                                mintingSheen
                                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                            }
                        }
                    }
                    .aspectRatio(0.64, contentMode: .fit)
                }
            } else {
                processingScreen
            }
        }
    }

    private var editorTopBar: some View {
        CatGlassGroup(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    editorTopBarButton(
                        accessibilityIdentifier: "capture-editor-cancel",
                        accessibilityLabel: "Cancel",
                        systemImage: "xmark"
                    ) {
                        requestDiscardAction(.close)
                    }
                    Spacer()
                    editorStageTitle
                    Spacer()
                    editorTopBarButton(
                        accessibilityIdentifier: "capture-editor-retake",
                        accessibilityLabel: "Retake",
                        systemImage: "arrow.counterclockwise"
                    ) {
                        requestDiscardAction(.retake)
                    }
                }

                VStack(spacing: 10) {
                    HStack {
                        editorTopBarButton(
                            accessibilityIdentifier: "capture-editor-cancel",
                            accessibilityLabel: "Cancel",
                            systemImage: "xmark"
                        ) {
                            requestDiscardAction(.close)
                        }
                        Spacer()
                        editorTopBarButton(
                            accessibilityIdentifier: "capture-editor-retake",
                            accessibilityLabel: "Retake",
                            systemImage: "arrow.counterclockwise"
                        ) {
                            requestDiscardAction(.retake)
                        }
                    }
                    editorStageTitle
                }
            }
        }
    }

    private func editorTopBarButton(
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .catSingleActionIconSurface()
        }
        .buttonStyle(.catTactile)
        .accessibilityLabel(accessibilityLabel.catLocalized)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var editorStageTitle: some View {
        VStack(spacing: 2) {
            Text("A New Cat")
                .font(CatTypography.panelTitle)
                .foregroundStyle(CatLocalTheme.primaryText)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var catlasPrivacyNote: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(CatAttentionRole.info.wash)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CatAttentionRole.info.accent)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text("Typed labels only. No GPS is requested.")
                .font(CatTypography.bodyEmphasized)
                .foregroundStyle(CatAttentionRole.info.text)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(CatAttentionRole.info.wash)
        )
    }

    private func editorFieldHeading(_ title: String) -> some View {
        Text(catLocalKey: title)
            .font(CatTypography.fieldLabel)
            .foregroundStyle(CatLocalTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private var failureScreen: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 0) {
                failureTopBar
                    .padding(.top, 10)

                Spacer(minLength: 32)

                VStack(spacing: 22) {
                    LociMascotView(
                        state: failureLociState,
                        size: 136
                    )

                    VStack(spacing: 8) {
                        Text(catLocalKey: failureTitle)
                            .font(CatTypography.pageTitle)
                            .foregroundStyle(CatLocalTheme.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                        Text(catLocalKey: errorMessage ?? "CatLocal could not create a clean cutout from this photo. Try a photo with the whole cat in view.")
                            .font(CatTypography.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                            .frame(maxWidth: 320)
                            .lineLimit(nil)
                    }
                }

                Spacer(minLength: 48)
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
    }

    private var failureTopBar: some View {
        CatGlassGroup(spacing: 18) {
            HStack {
                Button {
                    reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .catSingleActionIconSurface()
                }
                .buttonStyle(.catTactile)
                .accessibilityLabel("Try another photo")

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .catSingleActionIconSurface()
                }
                .buttonStyle(.catTactile)
                .accessibilityLabel("Close")
            }
        }
    }

    private var nextSequence: Int {
        (existingRecords.map(\.sequence).max() ?? 0) + 1
    }

    private var canTakePhoto: Bool {
        camera.isConfigured && stage == .camera && processingGate.canStart(.camera)
    }

    private var effectiveCameraAuthorizationStatus: AVAuthorizationStatus {
        #if DEBUG
        if forcesCameraDeniedForValidation {
            return .denied
        }
        #endif
        return camera.authorizationStatus
    }

    private var canImportPhoto: Bool {
        (stage == .camera || stage == .choosingForeground) && processingGate.canStart(.gallery)
    }

    private var failureTitle: String {
        failureLociState.title
    }

    private var failureLociState: LociMascotState {
        LociMascotState.state(for: failureContext)
    }

    private var activeSequence: Int {
        persistedRecord?.sequence ?? draftSequence ?? nextSequence
    }

    #if DEBUG
    private var showsValidationImport: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-import-fixture")
    }

    private var forcesCameraDeniedForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-force-camera-denied")
    }

    private var usesSyntheticValidationPhoto: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-synthetic-photo")
    }

    private var bypassesVisionForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-synthetic-cutout")
    }

    private var forcesForegroundSelectionForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-force-foreground-fallback")
    }

    private var showsMultipleCatSelectionForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-multiple-cat-selection")
    }

    private var holdsProcessingForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-hold-processing")
    }

    private var skipsStickerRevealForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-skip-sticker-reveal")
    }

    private var prefillsValidationEditorFields: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-prefill-editor-fields")
            || usesLongValidationContent
    }

    private var usesLongValidationContent: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-seed-long-content")
    }

    private var forcesReducedMotionRevealForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-reduce-motion-reveal")
    }

    private func prefillValidationEditorFields() {
        if usesLongValidationContent {
            nickname = "Captain Marmalade of the Bosphorus"
            placeName = "Old Stone Garden Behind the Neighborhood Library"
            placeDetail = "Under the ivy-covered bench by the eastern wall"
            note = "A patient afternoon visitor who waited through the rain before saying hello."
            return
        }

        nickname = "Pixel"
        placeName = "Rooftop"
        placeDetail = "South ledge"
        note = "Warm orange hello."
    }

    private func startValidationPhotoLoad() {
        guard let sessionID = beginCaptureInput(kind: .gallery) else { return }
        processingTask = Task { await loadValidationPhoto(sessionID: sessionID) }
    }

    private func loadValidationPhoto(sessionID: UUID) async {
        do {
            if usesSyntheticValidationPhoto {
                let image = showsMultipleCatSelectionForValidation
                    ? Self.validationMultipleCatFixtureImage()
                    : Self.validationFixtureImage()
                await accept(
                    image: image,
                    source: .photoLibrary,
                    sessionID: sessionID
                )
                return
            }

            let preparedImage = try await CaptureImagePreparation.preparedGalleryImage(
                at: validationPhotoURL(),
                maximumDimension: CatImageStore.originalMaximumDimension
            )
            try Task.checkCancellation()
            guard CaptureGalleryCompletionDecision.resolve(
                outcome: .success,
                isCurrentSession: processingGate.isCurrent(sessionID)
            ) == .apply else {
                finishCaptureInput(sessionID)
                return
            }
            let image = UIImage(cgImage: preparedImage, scale: 1, orientation: .up)
            try Task.checkCancellation()
            await accept(
                image: image,
                source: .photoLibrary,
                sessionID: sessionID
            )
        } catch is CancellationError {
            guard CaptureGalleryCompletionDecision.resolve(
                outcome: .cancelled,
                isCurrentSession: processingGate.isCurrent(sessionID)
            ) == .ignore else { return }
            finishCaptureInput(sessionID)
        } catch {
            guard CaptureGalleryCompletionDecision.resolve(
                outcome: .failure,
                isCurrentSession: processingGate.isCurrent(sessionID)
            ) == .showRecovery else {
                finishCaptureInput(sessionID)
                return
            }
            guard finishCaptureInput(sessionID) else { return }
            fail(with: "The validation photo could not be opened. Add cat.png to Documents/CatLocalValidation and try again.")
        }
    }

    private func validationPhotoURL() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return documents
            .appendingPathComponent("CatLocalValidation", isDirectory: true)
            .appendingPathComponent("cat.png")
    }

    private static func validationFixtureImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 900, height: 900), format: format).image { context in
            UIColor(red: 0.93, green: 0.88, blue: 0.78, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 900))
            UIColor(red: 0.16, green: 0.11, blue: 0.08, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 260, y: 250, width: 380, height: 420))
            context.cgContext.fillEllipse(in: CGRect(x: 310, y: 145, width: 280, height: 250))
        }
    }

    private static func validationMultipleCatFixtureImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 900, height: 900), format: format).image { context in
            UIColor(red: 0.87, green: 0.92, blue: 0.89, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 900))

            UIColor(red: 0.22, green: 0.15, blue: 0.11, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 110, y: 315, width: 250, height: 360))
            context.cgContext.fillEllipse(in: CGRect(x: 130, y: 210, width: 210, height: 190))

            UIColor(red: 0.28, green: 0.32, blue: 0.31, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 520, y: 330, width: 240, height: 320))
            context.cgContext.fillEllipse(in: CGRect(x: 540, y: 230, width: 200, height: 170))
        }
    }

    private static func validationCutoutImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 900, height: 900), format: format).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 900))
            UIColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 260, y: 250, width: 380, height: 420))
            context.cgContext.fillEllipse(in: CGRect(x: 310, y: 145, width: 280, height: 250))
        }
    }

    private static let validationSyntheticSubjectBounds = CGRect(
        x: 0.24,
        y: 0.16,
        width: 0.52,
        height: 0.59
    )
    #endif

    #if !DEBUG
    private var forcesReducedMotionRevealForValidation: Bool { false }
    #endif

    private func startPhotoLoad(_ item: PhotosPickerItem) {
        guard let sessionID = beginCaptureInput(
            kind: .gallery,
            allowedStages: [.camera, .choosingForeground]
        ) else {
            photoItem = nil
            return
        }
        processingTask = Task { await loadPhoto(item, sessionID: sessionID) }
    }

    private func loadPhoto(_ item: PhotosPickerItem, sessionID: UUID) async {
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self)
            else {
                throw CatVisionError.unreadableImage
            }
            let preparedImage = try await CaptureImagePreparation.preparedGalleryImage(
                from: data,
                maximumDimension: CatImageStore.originalMaximumDimension
            )
            try Task.checkCancellation()
            guard CaptureGalleryCompletionDecision.resolve(
                outcome: .success,
                isCurrentSession: processingGate.isCurrent(sessionID)
            ) == .apply else {
                finishCaptureInput(sessionID)
                return
            }
            let image = UIImage(cgImage: preparedImage, scale: 1, orientation: .up)
            try Task.checkCancellation()
            await accept(
                image: image,
                source: .photoLibrary,
                sessionID: sessionID
            )
        } catch is CancellationError {
            guard CaptureGalleryCompletionDecision.resolve(
                outcome: .cancelled,
                isCurrentSession: processingGate.isCurrent(sessionID)
            ) == .ignore else { return }
            finishCaptureInput(sessionID)
        } catch {
            guard CaptureGalleryCompletionDecision.resolve(
                outcome: .failure,
                isCurrentSession: processingGate.isCurrent(sessionID)
            ) == .showRecovery else {
                finishCaptureInput(sessionID)
                return
            }
            guard finishCaptureInput(sessionID) else { return }
            fail(with: "This photo could not be opened. Choose another photo.")
        }
    }

    private func accept(
        image: UIImage,
        source: CaptureSource,
        sessionID: UUID
    ) async {
        guard processingGate.isCurrent(sessionID), !Task.isCancelled else { return }
        defer { finishCaptureInput(sessionID) }

        beginSubjectLift(image: image, source: source)
        draftSequence = nextSequence
        persistedRecord = nil
        isSavedCardDraftLoaded = false
        detections = []
        selectedBoundingBox = nil
        errorMessage = nil
        foregroundSelectionMessage = nil
        failureContext = .failureRecovery
        cutoutOutlineMask = nil
        subjectToCardCompletionGate.reset()
        stage = .analyzing

        do {
            #if DEBUG
            if holdsProcessingForValidation {
                try await Task.sleep(for: .seconds(30))
                try Task.checkCancellation()
            }

            if showsMultipleCatSelectionForValidation {
                detections = [
                    CatDetection(
                        boundingBox: CGRect(x: 0.08, y: 0.18, width: 0.36, height: 0.64),
                        confidence: 0.98
                    ),
                    CatDetection(
                        boundingBox: CGRect(x: 0.56, y: 0.24, width: 0.34, height: 0.58),
                        confidence: 0.87
                    )
                ]
                stage = .choosingCat
                return
            }

            if forcesForegroundSelectionForValidation {
                stage = .choosingForeground
                return
            }

            if bypassesVisionForValidation {
                let detection = CatDetection(
                    boundingBox: CGRect(x: 0.24, y: 0.18, width: 0.52, height: 0.66),
                    confidence: 0.99
                )
                detections = [detection]
                await beginStickerReveal(
                    cutout: Self.validationCutoutImage(),
                    detection: detection
                )
                return
            }
            #endif

            let found = try await processor.detectCats(in: SendableImage(value: image))
            try Task.checkCancellation()
            guard processingGate.isCurrent(sessionID) else { return }
            switch CatDetectionSelector.resolve(found) {
            case .none:
                detections = []
                stage = .choosingForeground
            case .single(let detection):
                detections = [detection]
                stage = .creatingCutout
                let result = try await processor.cutout(
                    from: SendableImage(value: image),
                    selection: .detected(detection)
                )
                try Task.checkCancellation()
                guard processingGate.isCurrent(sessionID) else { return }
                await beginStickerReveal(
                    cutout: result.value,
                    detection: detection
                )
            case .multiple(let detections):
                self.detections = detections
                stage = .choosingCat
            }
        } catch is CancellationError {
            return
        } catch {
            guard processingGate.isCurrent(sessionID) else { return }
            fail(with: CatVisionError.processingUnavailable)
        }
    }

    private func beginSubjectLift(image: UIImage, source: CaptureSource) {
        transitionSessionGate.invalidate()
        camera.stop()
        originalImage = image
        self.source = source
        stage = .analyzing
    }

    private func beginStickerReveal(cutout: UIImage, detection: CatDetection?) async {
        guard
            let originalCGImage = originalImage?.cgImage,
            let cutoutCGImage = cutout.cgImage
        else {
            fail(with: CatVisionError.processingUnavailable)
            return
        }
        let preparationTask = Task.detached(priority: .userInitiated) {
            try CaptureImagePreparation.transitionAssets(
                original: originalCGImage,
                alignedCutout: cutoutCGImage
            )
        }
        let transition: PreparedCaptureTransition
        do {
            transition = try await withTaskCancellationHandler {
                try await preparationTask.value
            } onCancel: {
                preparationTask.cancel()
            }
        } catch is CancellationError {
            return
        } catch {
            fail(with: CatVisionError.processingUnavailable)
            return
        }
        guard !Task.isCancelled else { return }
        selectedBoundingBox = detection?.boundingBox
        preparedTransition = transition
        cutoutImage = UIImage(cgImage: transition.sticker, scale: 1, orientation: .up)
        cutoutOutlineMask = transition.outlineMask
        draftSuggestedName = freshDraftName()
        #if DEBUG
        if prefillsValidationEditorFields {
            prefillValidationEditorFields()
        }
        #endif
        errorMessage = nil
        isEditorSheetPresented = false
        subjectToCardCompletionGate.reset()
        isCardMintingDone = false
        isSavedCardDraftLoaded = false
        persistedRecord = nil
        captureSelectionFeedbackTrigger += 1
        let transitionID = transitionSessionGate.begin()
        #if DEBUG
        if skipsStickerRevealForValidation {
            completeSubjectToCardTransition(transitionID: transitionID)
            return
        }
        #endif
        stage = .stickerReveal
    }

    private func completeSubjectToCardTransition(transitionID: UUID) {
        guard stage == .stickerReveal || skipsTransitionStageForValidation else { return }
        guard transitionSessionGate.consume(transitionID) else { return }
        guard subjectToCardCompletionGate.complete() else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            preparedTransition = nil
            stage = .stickerInspecting
        }
        captureCompletionFeedbackTrigger += 1
        UIAccessibility.post(notification: .announcement, argument: "Cat card ready.".catLocalized)
    }

    #if DEBUG
    private var skipsTransitionStageForValidation: Bool {
        skipsStickerRevealForValidation
    }
    #else
    private var skipsTransitionStageForValidation: Bool { false }
    #endif

    private func expandEditor() {
        captureSelectionFeedbackTrigger += 1
        isEditorSheetPresented = true
    }

    private func collapseEditor() {
        dismissEditorKeyboard()
        isEditorSheetPresented = false
    }

    private func dismissEditorKeyboard() {
        if focusedEditorField != nil {
            focusedEditorField = nil
        }
    }

    private func startCutout(for detection: CatDetection) {
        startCutout(selection: .detected(detection), detection: detection)
    }

    private func chooseForeground(at normalizedPoint: CGPoint?) {
        guard let normalizedPoint else {
            showForegroundSelectionRetry()
            return
        }
        foregroundSelectionMessage = nil
        startCutout(selection: .normalizedSourcePoint(normalizedPoint), detection: nil)
    }

    private func startCutout(
        selection: ForegroundSelection,
        detection: CatDetection?
    ) {
        guard let sessionID = beginCurrentPhotoProcessing(
            allowedStages: [.choosingCat, .choosingForeground]
        ) else {
            return
        }

        processingTask = Task {
            await createCutout(
                selection: selection,
                detection: detection,
                sessionID: sessionID
            )
        }
    }

    private func createCutout(
        selection: ForegroundSelection,
        detection: CatDetection?,
        sessionID: UUID
    ) async {
        defer { finishCaptureInput(sessionID) }
        guard processingGate.isCurrent(sessionID), !Task.isCancelled else { return }
        guard let originalImage else {
            fail(with: CatVisionError.unreadableImage)
            return
        }

        stage = .creatingCutout
        do {
            #if DEBUG
            if bypassesVisionForValidation,
               case .normalizedSourcePoint(let point) = selection {
                guard Self.validationSyntheticSubjectBounds.contains(point) else {
                    throw CatVisionError.noMatchingForeground
                }
                try Task.checkCancellation()
                guard processingGate.isCurrent(sessionID) else { return }
                await beginStickerReveal(
                    cutout: Self.validationCutoutImage(),
                    detection: nil
                )
                return
            }
            #endif

            let result = try await processor.cutout(
                from: SendableImage(value: originalImage),
                selection: selection
            )
            try Task.checkCancellation()
            guard processingGate.isCurrent(sessionID) else { return }
            await beginStickerReveal(
                cutout: result.value,
                detection: detection
            )
        } catch is CancellationError {
            return
        } catch {
            guard processingGate.isCurrent(sessionID) else { return }
            if
                case .normalizedSourcePoint = selection,
                let visionError = error as? CatVisionError,
                case .noMatchingForeground = visionError
            {
                showForegroundSelectionRetry()
                return
            }
            fail(with: error)
        }
    }

    private func showForegroundSelectionRetry() {
        foregroundSelectionMessage = "That spot wasn't a clear foreground subject. Tap directly on the cat and try again."
        captureWarningFeedbackTrigger += 1
        stage = .choosingForeground
    }

    private func finishCustomization() async {
        guard !isSaving else { return }
        let shouldCelebrateSave = isInitialCardDesignSave || stage == .cardCelebrating
        let saveStartedAt = Date()
        isSaving = true
        do {
            let record = try await persistCard()
            await holdForSaveAnticipation(since: saveStartedAt)
            persistedRecord = record
            isSaving = false
            isSavedCardDraftLoaded = false
            focusedEditorField = nil
            isEditorSheetPresented = false
            if shouldCelebrateSave {
                isCardMintingDone = true
                stage = .cardCelebrating
            } else {
                dismiss()
            }
        } catch {
            isSaving = false
            fail(with: error)
        }
    }

    private func holdForSaveAnticipation(since startDate: Date) async {
        let minimumDuration: TimeInterval = 0.72
        let remaining = minimumDuration - Date().timeIntervalSince(startDate)
        guard remaining > 0 else { return }

        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    private var isInitialCardDesignSave: Bool {
        persistedRecord == nil
    }

    private var hasDiscardableDraft: Bool {
        if persistedRecord == nil {
            return cutoutImage != nil
        }

        return hasUnsavedSavedCardDraft
    }

    private var hasUnsavedSavedCardDraft: Bool {
        guard isSavedCardDraftLoaded, let persistedRecord else { return false }

        return trimmedMemoryText(nickname) != trimmedMemoryText(persistedRecord.nickname)
            || note != persistedRecord.note
            || trimmedMemoryText(placeName) != trimmedMemoryText(persistedRecord.placeName)
            || trimmedMemoryText(placeDetail) != trimmedMemoryText(persistedRecord.placeDetail)
            || selectedStyle != persistedRecord.cardStyle
    }

    @discardableResult
    private func persistCard() async throws -> CatRecord {
        if let persistedRecord {
            applyDraft(to: persistedRecord)
            try modelContext.save()
            return persistedRecord
        }

        guard let originalImage, let cutoutImage else {
            throw CatVisionError.unreadableImage
        }

        let id = UUID()
        let stored = try await CatImageStore.shared.save(
            id: id,
            original: SendableImage(value: originalImage),
            cutout: SendableImage(value: cutoutImage)
        )
        let record = CatRecord(
            id: id,
            sequence: activeSequence,
            nickname: savedNickname,
            note: note,
            placeName: trimmedMemoryText(placeName),
            placeDetail: trimmedMemoryText(placeDetail),
            source: source,
            cardStyle: selectedStyle,
            styleSeed: 0,
            catBoundingBox: selectedBoundingBox,
            originalImagePath: stored.originalPath,
            cutoutImagePath: stored.cutoutPath,
            thumbnailImagePath: stored.thumbnailPath
        )
        do {
            modelContext.insert(record)
            try modelContext.save()
        } catch {
            let persistenceError = error
            modelContext.delete(record)
            do {
                try await CatImageStore.shared.deleteRecord(id: id)
            } catch {
                throw CatImageStoreError.persistenceSaveCleanupFailed(
                    persistenceError: persistenceError.localizedDescription,
                    cleanupError: error.localizedDescription
                )
            }
            throw persistenceError
        }
        return record
    }

    private func applyDraft(to record: CatRecord) {
        let trimmedName = trimmedMemoryText(nickname)
        if !trimmedName.isEmpty {
            record.nickname = trimmedName
        }
        record.note = note
        record.placeName = trimmedMemoryText(placeName)
        record.placeDetail = trimmedMemoryText(placeDetail)
        record.cardStyle = selectedStyle
    }

    private func fail(with message: String, context: LociContext = .failureRecovery) {
        cancelActiveProcessing()
        errorMessage = message
        failureContext = context
        captureWarningFeedbackTrigger += 1
        stage = .failure
    }

    private func fail(with error: Error) {
        fail(
            with: error.localizedDescription,
            context: failureContext(for: error)
        )
    }

    private func failureContext(for error: Error) -> LociContext {
        guard let visionError = error as? CatVisionError else {
            return .failureRecovery
        }

        switch visionError {
        case .noCat:
            return .noCatFound
        case .unreadableImage:
            return .imageQualityWarning
        case .noForeground, .noMatchingForeground, .cutoutFailed:
            return .recoverableWarning
        case .processingUnavailable:
            return .failureRecovery
        }
    }

    private func closeCamera() {
        cancelActiveProcessing()
        camera.stop()
        dismiss()
    }

    private func requestDiscardAction(_ action: CaptureDiscardAction) {
        guard !isSaving else { return }

        dismissEditorKeyboard()
        guard hasDiscardableDraft else {
            performDiscardAction(action)
            return
        }

        pendingDiscardAction = action
        captureWarningFeedbackTrigger += 1
        isDiscardConfirmationPresented = true
    }

    private func performDiscardAction(_ action: CaptureDiscardAction) {
        pendingDiscardAction = nil
        isDiscardConfirmationPresented = false

        switch action {
        case .close:
            cancelCapture()
        case .retake:
            reset()
        }
    }

    private func cancelCapture() {
        cancelActiveProcessing()
        camera.stop()
        dismiss()
    }

    private func captureCameraPhoto() {
        guard let sessionID = beginCaptureInput(kind: .camera) else { return }

        camera.capture { result in
            switch result {
            case .success(let data):
                guard processingGate.isCurrent(sessionID) else { return }
                processingTask = Task {
                    do {
                        let image = try await optimizedCameraWorkingImage(from: data)
                        guard processingGate.isCurrent(sessionID), !Task.isCancelled else { return }
                        await accept(
                            image: image,
                            source: .camera,
                            sessionID: sessionID
                        )
                    } catch is CancellationError {
                        finishCaptureInput(sessionID)
                    } catch {
                        guard finishCaptureInput(sessionID) else { return }
                        fail(with: error)
                    }
                }
            case .failure(let error):
                guard finishCaptureInput(sessionID) else { return }
                fail(with: error.localizedDescription, context: .failureRecovery)
            }
        }
    }

    private func beginCaptureInput(
        kind: CaptureInputOperationKind,
        allowedStages: [CaptureStage] = [.camera]
    ) -> UUID? {
        guard allowedStages.contains(stage) else { return nil }
        guard let start = processingGate.start(kind) else { return nil }
        if start.replacedSessionID != nil {
            processingTask?.cancel()
            processingTask = nil
        }
        return start.sessionID
    }

    private func beginCurrentPhotoProcessing(
        allowedStages: [CaptureStage]
    ) -> UUID? {
        guard originalImage != nil, allowedStages.contains(stage) else { return nil }
        return processingGate.begin()
    }

    @discardableResult
    private func finishCaptureInput(_ sessionID: UUID) -> Bool {
        let didFinish = processingGate.finish(sessionID)
        if didFinish {
            processingTask = nil
        }
        return didFinish
    }

    private func cancelActiveProcessing() {
        processingTask?.cancel()
        processingTask = nil
        processingGate.cancel()
        transitionSessionGate.invalidate()
        showsProcessingCancellation = false
    }

    private func optimizedCameraWorkingImage(
        from data: Data
    ) async throws -> UIImage {
        let preparationTask = Task.detached(priority: .userInitiated) {
            SendableImage(value: try CaptureImagePreparation.cameraImage(
                from: data,
                maximumDimension: CatImageStore.originalMaximumDimension
            ))
        }
        let result = try await withTaskCancellationHandler {
            try await preparationTask.value
        } onCancel: {
            preparationTask.cancel()
        }
        return result.value
    }

    private func reset() {
        cancelActiveProcessing()
        originalImage = nil
        preparedTransition = nil
        cutoutImage = nil
        cutoutOutlineMask = nil
        pinchZoomStart = nil
        detections = []
        selectedBoundingBox = nil
        nickname = ""
        note = ""
        placeName = ""
        placeDetail = ""
        selectedStyle = .archive
        draftSuggestedName = ""
        draftSequence = nil
        persistedRecord = nil
        photoItem = nil
        errorMessage = nil
        foregroundSelectionMessage = nil
        failureContext = .failureRecovery
        isSaving = false
        isEditorSheetPresented = false
        isSavedCardDraftLoaded = false
        pendingDiscardAction = nil
        isDiscardConfirmationPresented = false
        subjectToCardCompletionGate.reset()
        isCardMintingDone = false
        stage = .camera
        if effectiveCameraAuthorizationStatus == .authorized {
            camera.start()
        }
    }

    private func trimmedMemoryText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var savedNickname: String {
        let trimmedName = trimmedMemoryText(nickname)
        guard trimmedName.isEmpty else { return trimmedName }

        let existingNames = Set(existingRecords.map(\.displayName))
        let suggestedName = trimmedMemoryText(draftSuggestedName)
        if !suggestedName.isEmpty, !existingNames.contains(suggestedName) {
            return suggestedName
        }

        return CatNamePool.randomName(excluding: existingNames)
    }

    private var editorPreviewName: String {
        let trimmedName = trimmedMemoryText(nickname)
        guard trimmedName.isEmpty else { return trimmedName }
        return draftSuggestedName.isEmpty ? CatNamePool.names.first ?? "Miso" : draftSuggestedName
    }

    private var celebrationPreviewName: String {
        persistedRecord?.displayName ?? editorPreviewName
    }

    private func freshDraftName() -> String {
        let existingNames = Set(existingRecords.map(\.displayName))
        return CatNamePool.randomName(excluding: existingNames)
    }

    private func editSavedCard() {
        hydrateEditorFromSavedRecord()
        expandEditor()
    }

    private func hydrateEditorFromSavedRecord() {
        guard let persistedRecord else { return }

        nickname = persistedRecord.nickname
        note = persistedRecord.note
        placeName = persistedRecord.placeName
        placeDetail = persistedRecord.placeDetail
        selectedStyle = persistedRecord.cardStyle
        isSavedCardDraftLoaded = true
    }
}

private struct SubjectToCardTransitionView<Destination: View>: View {
    private static var coordinateSpaceName: String { "subject-to-card-transition" }

    let sourceImage: UIImage
    let transition: PreparedCaptureTransition
    let reducesMotion: Bool
    let onCompleted: () -> Void
    @ViewBuilder let destination: (
        Double,
        Double,
        Double,
        CGFloat,
        String,
        Binding<CGRect>
    ) -> Destination

    @State private var elapsed: TimeInterval = 0
    @State private var phase: SubjectToCardTransitionPhase = .preparing
    @State private var destinationRect: CGRect = .zero
    @State private var showsTemporarySticker = true
    @State private var showsFinalCat = false
    @State private var rendererFailed = false
    @State private var timelineStart: Date?
    @State private var timelineStartGate = SubjectToCardTimelineStartGate(
        requiresMetalFirstFrame: true
    )
    @State private var overrideCardOpacity: Double?
    @State private var overrideBackdropOpacity: Double?
    @State private var completionGate = SubjectToCardCompletionGate()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FullScreenDustRevealView(
                    sourceImage: sourceImage,
                    transition: transition,
                    forcesFallback: reducesMotion,
                    showsCutoutOverlay: false,
                    fallbackDuration: SubjectToCardTransitionTimeline.reducedMotionDuration,
                    onMetalFirstFramePresented: handleFirstPresentedMetalFrame,
                    onRendererFailed: handleRendererFailure
                ) {}

                destination(
                    showsFinalCat ? 1 : 0,
                    cardOpacity,
                    backdropOpacity,
                    cardScale,
                    Self.coordinateSpaceName,
                    $destinationRect
                )

                if showsTemporarySticker, !reducesMotion {
                    temporarySticker(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .coordinateSpace(.named(Self.coordinateSpaceName))
        .task {
            if reducesMotion {
                await runReducedMotionTransition()
            } else {
                await runAnimatedTransition()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preparing cat card".catLocalized)
        .accessibilityValue(phaseIdentifier)
        .accessibilityIdentifier("subject-card-transition-active")
    }

    private var cardOpacity: Double {
        if let overrideCardOpacity { return overrideCardOpacity }
        return reducesMotion
            ? 0
            : SubjectToCardTransitionTimeline.cardOpacity(elapsed: elapsed)
    }

    private var cardScale: CGFloat {
        reducesMotion ? 1 : SubjectToCardTransitionTimeline.cardScale(elapsed: elapsed)
    }

    private var backdropOpacity: Double {
        if let overrideBackdropOpacity { return overrideBackdropOpacity }
        return reducesMotion
            ? 0
            : SubjectToCardTransitionTimeline.backdropOpacity(elapsed: elapsed)
    }

    private var phaseIdentifier: String {
        switch phase {
        case .preparing: "Preparing".catLocalized
        case .dusting: "Removing background".catLocalized
        case .lifting: "Positioning cat cutout".catLocalized
        case .settling: "Settling card".catLocalized
        case .completed: "Completed".catLocalized
        case .failed: "Failed".catLocalized
        }
    }

    private func temporarySticker(in size: CGSize) -> some View {
        let sourceRect = SubjectToCardTransitionGeometry.sourceRect(
            normalizedCropBounds: transition.normalizedPaddedCropBounds,
            imageSize: transition.sourceSize,
            containerRect: CGRect(origin: .zero, size: size)
        )
        let resolvedDestination = destinationRect.isEmpty ? sourceRect : destinationRect
        let rect = SubjectToCardTransitionGeometry.interpolatedRect(
            from: sourceRect,
            to: resolvedDestination,
            progress: SubjectToCardTransitionTimeline.liftProgress(elapsed: elapsed)
        )

        return ZStack {
            Image(decorative: transition.outlineMask, scale: 1, orientation: .up)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(CatLocalTheme.cardSurface)
                .opacity(SubjectToCardTransitionTimeline.outlineOpacity(elapsed: elapsed))

            Image(decorative: transition.sticker, scale: 1, orientation: .up)
                .resizable()
                .scaledToFit()
        }
        .compositingGroup()
        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
        .position(x: rect.midX, y: rect.midY)
        .accessibilityHidden(true)
    }

    @MainActor
    private func runAnimatedTransition() async {
        while timelineStart == nil {
            if rendererFailed {
                await runFailureContinuity()
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
        }

        guard let timelineStart else { return }
        phase = .dusting
        let handoffTime = SubjectToCardTransitionTimeline.liftStart
            + SubjectToCardTransitionTimeline.liftDuration

        while elapsed < SubjectToCardTransitionTimeline.totalDuration {
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            if rendererFailed {
                await runFailureContinuity()
                return
            }

            elapsed = min(
                Date().timeIntervalSince(timelineStart),
                SubjectToCardTransitionTimeline.totalDuration
            )
            phase = SubjectToCardTransitionTimeline.phase(elapsed: elapsed)

            if elapsed >= handoffTime, showsTemporarySticker {
                atomicStickerHandoff()
            }
        }

        atomicStickerHandoff()
        complete()
    }

    @MainActor
    private func runReducedMotionTransition() async {
        phase = .dusting
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showsFinalCat = true
            showsTemporarySticker = false
            overrideCardOpacity = 0
            overrideBackdropOpacity = 0
        }
        withAnimation(.easeOut(duration: SubjectToCardTransitionTimeline.reducedMotionDuration)) {
            overrideCardOpacity = 1
            overrideBackdropOpacity = 1
        }

        do {
            try await Task.sleep(for: .seconds(SubjectToCardTransitionTimeline.reducedMotionDuration))
        } catch {
            return
        }
        complete()
    }

    @MainActor
    private func runFailureContinuity() async {
        phase = .failed
        let currentOpacity = SubjectToCardTransitionTimeline.opacitySnapshot(elapsed: elapsed)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showsFinalCat = true
            showsTemporarySticker = false
            overrideCardOpacity = currentOpacity.card
            overrideBackdropOpacity = currentOpacity.backdrop
        }
        withAnimation(.easeOut(duration: SubjectToCardTransitionTimeline.reducedMotionDuration)) {
            overrideCardOpacity = 1
            overrideBackdropOpacity = 1
        }

        do {
            try await Task.sleep(for: .seconds(SubjectToCardTransitionTimeline.reducedMotionDuration))
        } catch {
            return
        }
        complete()
    }

    @MainActor
    private func atomicStickerHandoff() {
        guard showsTemporarySticker || !showsFinalCat else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showsFinalCat = true
            showsTemporarySticker = false
        }
    }

    private func handleFirstPresentedMetalFrame() {
        guard timelineStartGate.startIfReady(for: .metalFirstFrame) else { return }
        timelineStart = Date()
    }

    private func handleRendererFailure() {
        rendererFailed = true
    }

    @MainActor
    private func complete() {
        guard completionGate.complete() else { return }
        phase = .completed
        onCompleted()
    }
}

enum CatSelectionOverlayLayout {
    static func rect(
        for boundingBox: CGRect,
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {
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
        let fittedOrigin = CGPoint(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2
        )
        let unitBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let normalizedBox = boundingBox.standardized.intersection(unitBounds)
        guard !normalizedBox.isNull, !normalizedBox.isEmpty else { return .zero }

        return CGRect(
            x: fittedOrigin.x + normalizedBox.minX * fittedSize.width,
            y: fittedOrigin.y + (1 - normalizedBox.maxY) * fittedSize.height,
            width: normalizedBox.width * fittedSize.width,
            height: normalizedBox.height * fittedSize.height
        )
    }
}

enum CaptureInputOperationKind: Equatable, Sendable {
    case camera
    case gallery
    case currentPhoto
}

struct CaptureInputSessionStart: Equatable, Sendable {
    let sessionID: UUID
    let replacedSessionID: UUID?
}

enum CaptureGalleryOperationOutcome: Equatable, Sendable {
    case success
    case cancelled
    case failure
}

enum CaptureGalleryCompletionDecision: Equatable, Sendable {
    case apply
    case ignore
    case showRecovery

    static func resolve(
        outcome: CaptureGalleryOperationOutcome,
        isCurrentSession: Bool
    ) -> Self {
        guard isCurrentSession else { return .ignore }
        switch outcome {
        case .success:
            return .apply
        case .cancelled:
            return .ignore
        case .failure:
            return .showRecovery
        }
    }
}

struct CaptureProcessingSessionGate {
    private struct ActiveSession: Equatable {
        let id: UUID
        let kind: CaptureInputOperationKind
    }

    private var activeSession: ActiveSession?

    var isActive: Bool {
        activeSession != nil
    }

    func canStart(_ kind: CaptureInputOperationKind) -> Bool {
        guard let activeSession else { return true }
        return activeSession.kind == .gallery && (kind == .gallery || kind == .camera)
    }

    mutating func start(_ kind: CaptureInputOperationKind) -> CaptureInputSessionStart? {
        guard canStart(kind) else { return nil }
        let replacedSessionID = activeSession?.id
        let sessionID = UUID()
        activeSession = ActiveSession(id: sessionID, kind: kind)
        return CaptureInputSessionStart(
            sessionID: sessionID,
            replacedSessionID: replacedSessionID
        )
    }

    mutating func begin() -> UUID? {
        start(.currentPhoto)?.sessionID
    }

    func isCurrent(_ sessionID: UUID) -> Bool {
        activeSession?.id == sessionID
    }

    @discardableResult
    mutating func finish(_ sessionID: UUID) -> Bool {
        guard isCurrent(sessionID) else { return false }
        activeSession = nil
        return true
    }

    mutating func cancel() {
        activeSession = nil
    }
}

struct CaptureTransitionSessionGate {
    private(set) var activeID: UUID?

    mutating func begin() -> UUID {
        let transitionID = UUID()
        activeID = transitionID
        return transitionID
    }

    func isCurrent(_ transitionID: UUID) -> Bool {
        activeID == transitionID
    }

    @discardableResult
    mutating func consume(_ transitionID: UUID) -> Bool {
        guard isCurrent(transitionID) else { return false }
        activeID = nil
        return true
    }

    mutating func invalidate() {
        activeID = nil
    }
}

private struct ForegroundSelectionPhoto: View {
    let image: UIImage
    let onSelection: (CGPoint?) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CatLocalTheme.cardSurface

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        onSelection(AspectFitPointMapping.normalizedSourcePoint(
                            at: value.location,
                            imageSize: image.size,
                            containerSize: proxy.size
                        ))
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo for foreground selection")
        .accessibilityHint(
            "Double-tap to try the center of the photo. Use Retake or Choose private photo if the cat is elsewhere."
        )
        .accessibilityAction {
            onSelection(ForegroundSelectionAccessibility.defaultNormalizedPoint)
        }
        .accessibilityAction(named: "Try the center") {
            onSelection(ForegroundSelectionAccessibility.defaultNormalizedPoint)
        }
        .accessibilityIdentifier("foreground-selection-photo")
    }
}

private struct CatSelectionImage: View {
    let image: UIImage
    let detections: [CatDetection]

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay {
                    ZStack {
                        ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                            let markerRect = CatSelectionOverlayLayout.rect(
                                for: detection.boundingBox,
                                imageSize: image.size,
                                containerSize: proxy.size
                            )

                            if !markerRect.isEmpty {
                                CatSelectionMarker(number: index + 1)
                                    .frame(width: markerRect.width, height: markerRect.height)
                                    .position(x: markerRect.midX, y: markerRect.midY)
                            }
                        }
                    }
                }
        }
        .aspectRatio(image.size, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            CatLocalLocalization.plural(
                "Photo with %lld cats marked by number",
                count: detections.count
            )
        )
        .accessibilityHint("Use the numbered choices below to select a cat")
    }
}

private struct CatSelectionMarker: View {
    let number: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(CatLocalTheme.blueAction, lineWidth: 4)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white, lineWidth: 1.5)
            }
            .overlay(alignment: .topLeading) {
                CatSelectionNumberBadge(number: number, size: 30)
                    .offset(x: -7, y: -7)
            }
            .shadow(color: .black.opacity(0.34), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

private struct CatSelectionNumberBadge: View {
    let number: Int
    let size: CGFloat

    var body: some View {
        Text(number, format: .number)
            .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
            .foregroundStyle(CatLocalTheme.actionForeground)
            .frame(width: size, height: size)
            .background(CatLocalTheme.blueAction, in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.92), lineWidth: 1.5)
            }
            .accessibilityHidden(true)
    }
}

private enum CaptureDiscardAction {
    case close
    case retake

    var destructiveTitle: String {
        switch self {
        case .close:
            "Discard Draft"
        case .retake:
            "Discard and Retake"
        }
    }

    var message: String {
        switch self {
        case .close:
            "Your cutout and unsaved details will be lost. Saved cats stay in your collection."
        case .retake:
            "Your cutout and unsaved details will be lost before the camera opens."
        }
    }
}

private enum CaptureStage: Equatable {
    case camera
    case analyzing
    case choosingCat
    case choosingForeground
    case creatingCutout
    case stickerReveal
    case stickerInspecting
    case cardCelebrating
    case failure
}

private enum EditorField: Hashable {
    case nickname
    case note
    case placeName
    case placeDetail
}
