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
        let original = CIImage(cgImage: cgImage)
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        let clearBackground = CIImage(color: .clear).cropped(to: original.extent)
        let cutout = original.applyingFilter(
            "CIBlendWithAlphaMask",
            parameters: [
                kCIInputBackgroundImageKey: clearBackground,
                kCIInputMaskImageKey: mask
            ]
        )

        guard let output = context.createCGImage(cutout, from: original.extent) else {
            throw CatVisionError.cutoutFailed
        }
        return SendableImage(value: UIImage(cgImage: output))
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
        return bestInstance
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
            let row = baseAddress.advanced(by: y * rowBytes).assumingMemoryBound(to: Float.self)
            for x in stride(from: minX, through: maxX, by: strideX) {
                sum += row[x]
                samples += 1
            }
        }
        return samples == 0 ? 0 : sum / Float(samples)
    }

    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        return UIGraphicsImageRenderer(size: image.size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
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
