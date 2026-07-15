@preconcurrency import Vision
import CoreImage
import UIKit

protocol CatAnalyzing: Sendable {
    func detectCats(in image: SendableImage) async throws -> [CatDetection]
    func cutout(
        from image: SendableImage,
        selection: ForegroundSelection
    ) async throws -> SendableImage
}

enum ForegroundSelection: Sendable {
    case detected(CatDetection)
    case normalizedSourcePoint(CGPoint)
}

struct InstanceMaskPixelCoordinate: Equatable, Sendable {
    let x: Int
    let y: Int
}

enum InstanceMaskPointMapping {
    static func pixelCoordinate(
        at normalizedSourcePoint: CGPoint,
        width: Int,
        height: Int
    ) -> InstanceMaskPixelCoordinate? {
        guard
            width > 0,
            height > 0,
            normalizedSourcePoint.x >= 0,
            normalizedSourcePoint.x < 1,
            normalizedSourcePoint.y >= 0,
            normalizedSourcePoint.y < 1
        else {
            return nil
        }

        return InstanceMaskPixelCoordinate(
            x: min(width - 1, Int(normalizedSourcePoint.x * CGFloat(width))),
            y: min(height - 1, Int(normalizedSourcePoint.y * CGFloat(height)))
        )
    }
}

enum InstanceMaskLabelEncoding: Equatable, Sendable {
    case oneComponent8
    case oneComponent32Float
}

enum InstanceMaskLabelDecoder {
    static func encoding(for pixelFormat: OSType) -> InstanceMaskLabelEncoding? {
        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8:
            .oneComponent8
        case kCVPixelFormatType_OneComponent32Float:
            .oneComponent32Float
        default:
            nil
        }
    }

    static func label(
        from value: UInt8,
        availableInstances: IndexSet
    ) -> Int? {
        let label = Int(value)
        return label > 0 && availableInstances.contains(label) ? label : nil
    }

    static func label(
        from value: Float,
        availableInstances: IndexSet
    ) -> Int? {
        let rounded = value.rounded()
        guard
            value.isFinite,
            abs(value - rounded) < 0.001,
            rounded > 0,
            rounded <= Float(Int.max)
        else {
            return nil
        }
        let label = Int(rounded)
        return availableInstances.contains(label) ? label : nil
    }
}

actor CatVisionProcessor: CatAnalyzing {
    static let minimumDetectionConfidence: Float = 0.55

    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let minimumInstanceOverlapScore: Float = 0.08

    nonisolated static func confidentDetections(
        _ detections: [CatDetection]
    ) -> [CatDetection] {
        detections
            .filter { $0.confidence >= minimumDetectionConfidence }
            .sorted { $0.confidence > $1.confidence }
    }

    func detectCats(in image: SendableImage) async throws -> [CatDetection] {
        try Task.checkCancellation()
        guard let cgImage = normalizedCGImage(from: image.value) else {
            throw CatVisionError.unreadableImage
        }

        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        try Task.checkCancellation()

        let detections: [CatDetection] = (request.results ?? [])
            .compactMap { observation -> CatDetection? in
                guard let catLabel = observation.labels.first(where: {
                    $0.identifier.caseInsensitiveCompare("Cat") == .orderedSame
                }) else {
                    return nil
                }
                return CatDetection(
                    boundingBox: observation.boundingBox,
                    confidence: catLabel.confidence
                )
            }
        return Self.confidentDetections(detections)
    }

    func cutout(
        from image: SendableImage,
        selection: ForegroundSelection
    ) async throws -> SendableImage {
        try Task.checkCancellation()
        guard let cgImage = normalizedCGImage(from: image.value) else {
            throw CatVisionError.unreadableImage
        }

        let handler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        try Task.checkCancellation()

        guard let observation = request.results?.first else {
            throw CatVisionError.noForeground
        }

        let selectedInstance: Int
        switch selection {
        case .detected(let detection):
            guard let selected = bestMatchingInstance(
                in: observation,
                overlapping: detection.boundingBox
            ) else {
                throw CatVisionError.noMatchingForeground
            }
            selectedInstance = selected
        case .normalizedSourcePoint(let point):
            guard let selected = instanceLabel(
                at: point,
                in: observation.instanceMask,
                availableInstances: observation.allInstances
            ) else {
                throw CatVisionError.noMatchingForeground
            }
            selectedInstance = selected
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: IndexSet(integer: selectedInstance),
            from: handler
        )
        try Task.checkCancellation()
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        let output = try makeTransparentCutout(from: cgImage, mask: mask)
        return SendableImage(value: UIImage(cgImage: output))
    }

    private func bestMatchingInstance(
        in observation: VNInstanceMaskObservation,
        overlapping boundingBox: CGRect
    ) -> Int? {
        var bestInstance: Int?
        var bestScore: Float = -1

        for instance in observation.allInstances {
            guard let mask = try? observation.generateMask(
                forInstances: IndexSet(integer: instance)
            ) else {
                continue
            }

            let score = maskOverlapScore(mask, boundingBox: boundingBox)
            if score > bestScore {
                bestScore = score
                bestInstance = instance
            }
        }

        return bestScore >= minimumInstanceOverlapScore ? bestInstance : nil
    }

    private func maskOverlapScore(
        _ mask: CVPixelBuffer,
        boundingBox: CGRect
    ) -> Float {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(mask) else { return 0 }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        let pixelFormat = CVPixelBufferGetPixelFormatType(mask)
        guard width > 0, height > 0 else { return 0 }

        let minX = max(0, Int(boundingBox.minX * CGFloat(width)))
        let maxX = min(width - 1, Int(boundingBox.maxX * CGFloat(width)))
        let minY = max(0, Int((1 - boundingBox.maxY) * CGFloat(height)))
        let maxY = min(height - 1, Int((1 - boundingBox.minY) * CGFloat(height)))
        guard minX <= maxX, minY <= maxY else { return 0 }

        var sum: Float = 0
        var samples = 0
        let strideX = max(1, (maxX - minX) / 24)
        let strideY = max(1, (maxY - minY) / 24)

        for y in stride(from: minY, through: maxY, by: strideY) {
            for x in stride(from: minX, through: maxX, by: strideX) {
                if let value = maskValue(
                    baseAddress: baseAddress,
                    rowBytes: rowBytes,
                    pixelFormat: pixelFormat,
                    x: x,
                    y: y
                ) {
                    sum += value
                    samples += 1
                }
            }
        }

        return samples == 0 ? 0 : sum / Float(samples)
    }

    private func maskValue(
        baseAddress: UnsafeMutableRawPointer,
        rowBytes: Int,
        pixelFormat: OSType,
        x: Int,
        y: Int
    ) -> Float? {
        let row = baseAddress.advanced(by: y * rowBytes)
        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8:
            return Float(row.assumingMemoryBound(to: UInt8.self)[x]) / 255
        case kCVPixelFormatType_OneComponent32Float:
            guard x < rowBytes / MemoryLayout<Float>.stride else { return nil }
            return row.assumingMemoryBound(to: Float.self)[x]
        default:
            return nil
        }
    }

    func instanceLabel(
        at normalizedSourcePoint: CGPoint,
        in mask: CVPixelBuffer,
        availableInstances: IndexSet
    ) -> Int? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        guard let coordinate = InstanceMaskPointMapping.pixelCoordinate(
            at: normalizedSourcePoint,
            width: width,
            height: height
        ) else {
            return nil
        }
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        let row = baseAddress.advanced(by: coordinate.y * rowBytes)

        guard let encoding = InstanceMaskLabelDecoder.encoding(
            for: CVPixelBufferGetPixelFormatType(mask)
        ) else {
            return nil
        }

        switch encoding {
        case .oneComponent8:
            return InstanceMaskLabelDecoder.label(
                from: row.assumingMemoryBound(to: UInt8.self)[coordinate.x],
                availableInstances: availableInstances
            )
        case .oneComponent32Float:
            guard coordinate.x < rowBytes / MemoryLayout<Float>.stride else { return nil }
            return InstanceMaskLabelDecoder.label(
                from: row.assumingMemoryBound(to: Float.self)[coordinate.x],
                availableInstances: availableInstances
            )
        }
    }

    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        return UIGraphicsImageRenderer(size: image.size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    func makeTransparentCutout(from image: CGImage, mask: CIImage) throws -> CGImage {
        guard let outputColorSpace = Self.namedOutputColorSpace(for: image) else {
            throw CatVisionError.cutoutFailed
        }
        let original = CIImage(cgImage: image)
        let clearBackground = CIImage(color: .clear).cropped(to: original.extent)
        let cutout = original.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: clearBackground,
                kCIInputMaskImageKey: mask
            ]
        )

        guard
            let output = context.createCGImage(
                cutout,
                from: original.extent,
                format: .RGBA8,
                colorSpace: outputColorSpace
            )
        else {
            throw CatVisionError.cutoutFailed
        }
        guard cutoutAlphaQuality(in: output).isUsableCutout else {
            throw CatVisionError.noForeground
        }
        return output
    }

    private nonisolated static func namedOutputColorSpace(for image: CGImage) -> CGColorSpace? {
        if let sourceColorSpace = image.colorSpace,
           sourceColorSpace.model == .rgb,
           let sourceName = sourceColorSpace.name,
           sourceName != CGColorSpaceCreateDeviceRGB().name {
            return sourceColorSpace
        }
        return CGColorSpace(name: CGColorSpace.extendedSRGB)
            ?? CGColorSpace(name: CGColorSpace.sRGB)
    }

    nonisolated func hasVisibleSubjectAndTransparentBackground(_ image: CGImage) -> Bool {
        cutoutAlphaQuality(in: image).isUsableCutout
    }

    nonisolated func cutoutAlphaQuality(in image: CGImage) -> CutoutAlphaQuality {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return .empty }

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
            return .empty
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var transparentSamples = 0
        var visibleSamples = 0
        var totalSamples = 0
        var topEdgeVisible = 0
        var bottomEdgeVisible = 0
        var leadingEdgeVisible = 0
        var trailingEdgeVisible = 0
        let stepX = max(1, width / 96)
        let stepY = max(1, height / 96)

        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                totalSamples += 1
                let alpha = pixels[(y * bytesPerRow) + (x * bytesPerPixel) + 3]
                if alpha <= 8 {
                    transparentSamples += 1
                } else if alpha >= 32 {
                    visibleSamples += 1
                    if y < stepY { topEdgeVisible += 1 }
                    if y >= height - stepY { bottomEdgeVisible += 1 }
                    if x < stepX { leadingEdgeVisible += 1 }
                    if x >= width - stepX { trailingEdgeVisible += 1 }
                }
            }
        }

        guard totalSamples > 0 else { return .empty }
        return CutoutAlphaQuality(
            visibleRatio: Double(visibleSamples) / Double(totalSamples),
            transparentRatio: Double(transparentSamples) / Double(totalSamples),
            touchesAllEdges: topEdgeVisible > 0
                && bottomEdgeVisible > 0
                && leadingEdgeVisible > 0
                && trailingEdgeVisible > 0
        )
    }
}

struct CutoutAlphaQuality: Equatable, Sendable {
    let visibleRatio: Double
    let transparentRatio: Double
    let touchesAllEdges: Bool

    static let empty = CutoutAlphaQuality(
        visibleRatio: 0,
        transparentRatio: 0,
        touchesAllEdges: false
    )

    var isUsableCutout: Bool {
        visibleRatio >= 0.04
            && visibleRatio <= 0.92
            && transparentRatio >= 0.03
            && !touchesAllEdges
    }
}

enum CatVisionError: LocalizedError {
    case unreadableImage
    case noCat
    case noForeground
    case noMatchingForeground
    case cutoutFailed
    case processingUnavailable

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "This photo could not be read. Try another one."
        case .noCat:
            "CatLocal could not confidently find a cat in this photo."
        case .noForeground:
            "No clear foreground subject could be separated from the background."
        case .noMatchingForeground:
            "The selected cat could not be separated cleanly. Try a photo with more space around them."
        case .cutoutFailed:
            "The cat was found, but the cutout could not be created."
        case .processingUnavailable:
            "CatLocal could not process this photo on this device right now. Try another photo or try again later."
        }
    }
}
