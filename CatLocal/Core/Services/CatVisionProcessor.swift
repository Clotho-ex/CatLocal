@preconcurrency import Vision
import CoreImage
import UIKit

protocol CatAnalyzing: Sendable {
    func detectCats(in image: SendableImage) async throws -> [CatDetection]
    func cutout(
        from image: SendableImage,
        detection: CatDetection?
    ) async throws -> SendableImage
}

actor CatVisionProcessor: CatAnalyzing {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let minimumInstanceOverlapScore: Float = 0.08
    private let catCropExpansion: CGFloat = 0.28

    func detectCats(in image: SendableImage) async throws -> [CatDetection] {
        guard let cgImage = normalizedCGImage(from: image.value) else {
            throw CatVisionError.unreadableImage
        }

        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        return (request.results ?? [])
            .compactMap { observation in
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
            .sorted { $0.confidence > $1.confidence }
    }

    func cutout(
        from image: SendableImage,
        detection: CatDetection?
    ) async throws -> SendableImage {
        guard let cgImage = normalizedCGImage(from: image.value) else {
            throw CatVisionError.unreadableImage
        }

        if let detection {
            let output = try makeCatFocusedCutout(from: cgImage, detection: detection)
            return SendableImage(value: UIImage(cgImage: output))
        }

        // Explicit fallback path for "Use the foreground anyway" when cat detection fails.
        // The normal cat path uses a cropped ROI so nearby foreground objects do not win.
        let handler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw CatVisionError.noForeground
        }

        let instances: IndexSet
        if let detection {
            guard let selected = bestInstance(
                in: observation,
                overlapping: detection.boundingBox
            ) else {
                throw CatVisionError.noMatchingForeground
            }
            instances = IndexSet(integer: selected)
        } else {
            instances = observation.allInstances
        }

        guard !instances.isEmpty else {
            throw CatVisionError.noForeground
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: instances,
            from: handler
        )
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        let output = try makeTransparentCutout(from: cgImage, mask: mask)
        return SendableImage(value: UIImage(cgImage: output))
    }

    private func makeCatFocusedCutout(
        from image: CGImage,
        detection: CatDetection
    ) throws -> CGImage {
        let cropRect = expandedCatCropRect(
            for: detection.boundingBox,
            imageWidth: image.width,
            imageHeight: image.height,
            expansion: catCropExpansion
        )
        guard
            cropRect.width > 0,
            cropRect.height > 0,
            let croppedImage = image.cropping(to: cropRect)
        else {
            throw CatVisionError.cutoutFailed
        }

        let handler = VNImageRequestHandler(cgImage: croppedImage)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw CatVisionError.noForeground
        }
        guard let selected = bestCenteredInstance(in: observation) else {
            throw CatVisionError.noMatchingForeground
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: IndexSet(integer: selected),
            from: handler
        )
        return try makeTransparentCutout(
            from: croppedImage,
            mask: CIImage(cvPixelBuffer: maskBuffer)
        )
    }

    nonisolated func expandedCatCropRect(
        for boundingBox: CGRect,
        imageWidth: Int,
        imageHeight: Int,
        expansion: CGFloat = 0.28
    ) -> CGRect {
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        let pixelBox = CGRect(
            x: boundingBox.minX * imageSize.width,
            y: (1 - boundingBox.maxY) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        let minimumPadding = max(imageSize.width, imageSize.height) * 0.035
        let padX = max(pixelBox.width * expansion, minimumPadding)
        let padY = max(pixelBox.height * expansion, minimumPadding)
        let expanded = pixelBox.insetBy(dx: -padX, dy: -padY)
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        return expanded.intersection(imageBounds).integral
    }

    private func bestInstance(
        in observation: VNInstanceMaskObservation,
        overlapping boundingBox: CGRect
    ) -> Int? {
        var bestInstance: Int?
        var bestScore: Float = -1

        for instance in observation.allInstances {
            let score = overlapScore(
                observation: observation,
                instance: instance,
                boundingBox: boundingBox
            )
            if score > bestScore {
                bestScore = score
                bestInstance = instance
            }
        }
        guard bestScore >= minimumInstanceOverlapScore else { return nil }
        return bestInstance
    }

    private func bestCenteredInstance(in observation: VNInstanceMaskObservation) -> Int? {
        var bestInstance: Int?
        var bestScore: Float = -1

        for instance in observation.allInstances {
            guard
                let mask = try? observation.generateMask(forInstances: IndexSet(integer: instance)),
                let score = centeredMaskScore(mask)
            else {
                continue
            }

            if score > bestScore {
                bestScore = score
                bestInstance = instance
            }
        }

        return bestInstance
    }

    private func centeredMaskScore(_ mask: CVPixelBuffer) -> Float? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        let pixelFormat = CVPixelBufferGetPixelFormatType(mask)
        guard width > 0, height > 0 else { return nil }

        var visible: Float = 0
        var weightedX: Float = 0
        var weightedY: Float = 0
        var samples: Float = 0
        let strideX = max(1, width / 64)
        let strideY = max(1, height / 64)

        for y in stride(from: 0, to: height, by: strideY) {
            for x in stride(from: 0, to: width, by: strideX) {
                guard let value = maskValue(
                    baseAddress: baseAddress,
                    rowBytes: rowBytes,
                    pixelFormat: pixelFormat,
                    x: x,
                    y: y
                ) else {
                    continue
                }
                samples += 1
                guard value > 0.12 else { continue }
                visible += value
                weightedX += Float(x) * value
                weightedY += Float(y) * value
            }
        }

        guard samples > 0, visible / samples > 0.01 else { return nil }
        let centerX = weightedX / visible / Float(width)
        let centerY = weightedY / visible / Float(height)
        let distanceFromCenter = hypot(centerX - 0.5, centerY - 0.5)
        let centrality = max(0, 1 - distanceFromCenter * 1.35)
        return (visible / samples) * centrality
    }

    private func overlapScore(
        observation: VNInstanceMaskObservation,
        instance: Int,
        boundingBox: CGRect
    ) -> Float {
        guard let mask = try? observation.generateMask(forInstances: IndexSet(integer: instance)) else {
            return 0
        }

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(mask) else { return 0 }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        let pixelFormat = CVPixelBufferGetPixelFormatType(mask)

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

    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        return UIGraphicsImageRenderer(size: image.size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    func makeTransparentCutout(from image: CGImage, mask: CIImage) throws -> CGImage {
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
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        else {
            throw CatVisionError.cutoutFailed
        }
        guard cutoutAlphaQuality(in: output).isUsableCutout else {
            throw CatVisionError.noForeground
        }
        return output
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
