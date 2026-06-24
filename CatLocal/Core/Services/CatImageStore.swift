import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

struct StoredCatImages: Sendable {
    let originalPath: String
    let cutoutPath: String
    let thumbnailPath: String
}

struct StoredCatImageReferences: Sendable {
    let id: UUID
    let originalPath: String
    let cutoutPath: String
}

struct SendableImage: @unchecked Sendable {
    let value: UIImage
}

protocol CatImageStoring: Sendable {
    func save(id: UUID, original: SendableImage, cutout: SendableImage) async throws -> StoredCatImages
    func data(at relativePath: String) async throws -> Data
    func deleteRecord(id: UUID) async throws
    func deleteAll() async throws
    func storageSize() async throws -> Int64
}

actor CatImageStore: CatImageStoring {
    static let shared = CatImageStore()

    static let originalMaximumDimension: CGFloat = 1_800
    static let cutoutMaximumDimension: CGFloat = 1_400
    static let thumbnailMaximumDimension: CGFloat = 512
    static let originalCompressionQuality: CGFloat = 0.72
    static let thumbnailCompressionQuality: CGFloat = 0.78

    private let fileManager: FileManager
    private let rootURL: URL

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.rootURL = applicationSupport
                .appendingPathComponent("CatLocal", isDirectory: true)
                .appendingPathComponent("Cats", isDirectory: true)
        }
    }

    func save(
        id: UUID,
        original: SendableImage,
        cutout: SendableImage
    ) async throws -> StoredCatImages {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let directory = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let temporaryDirectory = rootURL.appendingPathComponent(
            "\(id.uuidString).tmp-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        do {
            let optimizedOriginal = Self.downsampledOpaqueImage(
                from: original.value,
                maximumDimension: Self.originalMaximumDimension
            )
            let optimizedCutout = Self.optimizedCutout(from: cutout.value)
            let thumbnail = Self.downsampledOpaqueImage(
                from: optimizedCutout,
                maximumDimension: Self.thumbnailMaximumDimension
            )

            let originalData = try Self.heicData(
                from: optimizedOriginal,
                quality: Self.originalCompressionQuality
            )
            let cutoutData = try Self.pngData(from: optimizedCutout)
            let thumbnailData = try Self.jpegData(
                from: thumbnail,
                quality: Self.thumbnailCompressionQuality
            )

            let originalURL = temporaryDirectory.appendingPathComponent("original.heic")
            let cutoutURL = temporaryDirectory.appendingPathComponent("cutout.png")
            let thumbnailURL = temporaryDirectory.appendingPathComponent("thumbnail.jpg")

            try originalData.write(to: originalURL, options: .atomic)
            try cutoutData.write(to: cutoutURL, options: .atomic)
            try thumbnailData.write(to: thumbnailURL, options: .atomic)

            if fileManager.fileExists(atPath: directory.path) {
                _ = try fileManager.replaceItemAt(
                    directory,
                    withItemAt: temporaryDirectory,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: temporaryDirectory, to: directory)
            }

            return StoredCatImages(
                originalPath: "\(id.uuidString)/original.heic",
                cutoutPath: "\(id.uuidString)/cutout.png",
                thumbnailPath: "\(id.uuidString)/thumbnail.jpg"
            )
        } catch {
            try? fileManager.removeItem(at: temporaryDirectory)
            throw error
        }
    }

    func data(at relativePath: String) async throws -> Data {
        let url = rootURL.appendingPathComponent(relativePath)
        guard url.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path) else {
            throw CatImageStoreError.invalidPath
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    func deleteRecord(id: UUID) async throws {
        let directory = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    func deleteAll() async throws {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        try fileManager.removeItem(at: rootURL)
    }

    func storageSize() async throws -> Int64 {
        guard fileManager.fileExists(atPath: rootURL.path) else { return 0 }
        var total: Int64 = 0
        let paths = try fileManager.subpathsOfDirectory(atPath: rootURL.path)
        for path in paths {
            let fileURL = rootURL.appendingPathComponent(path)
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    func optimizeExisting(records: [StoredCatImageReferences]) async {
        for record in records {
            do {
                let original = try await image(at: record.originalPath)
                let cutout = try await image(at: record.cutoutPath)
                _ = try await save(
                    id: record.id,
                    original: SendableImage(value: original),
                    cutout: SendableImage(value: cutout)
                )
            } catch {
                continue
            }
        }
    }

    private func relativePath(for url: URL) -> String {
        url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
    }

    private func image(at relativePath: String) async throws -> UIImage {
        let imageData = try await data(at: relativePath)
        guard let image = UIImage(data: imageData) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return image
    }

    private static func heicData(from image: UIImage, quality: CGFloat) throws -> Data {
        guard let cgImage = opaqueNormalizedCGImage(from: image) else {
            throw CatImageStoreError.imageEncodingFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw CatImageStoreError.imageEncodingFailed
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyExifDictionary: [:],
            kCGImagePropertyGPSDictionary: [:]
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return data as Data
    }

    private static func pngData(from image: UIImage) throws -> Data {
        guard let data = image.pngData() else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return data
    }

    private static func jpegData(from image: UIImage, quality: CGFloat) throws -> Data {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return data
    }

    static func optimizedCutout(from image: UIImage) -> UIImage {
        let trimmed = trimTransparentPixels(from: image, padding: 32)
        return downsampledTransparentImage(
            from: trimmed,
            maximumDimension: cutoutMaximumDimension
        )
    }

    static func downsampledOpaqueImage(from image: UIImage, maximumDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let targetSize: CGSize
        if longest > maximumDimension {
            let scale = maximumDimension / longest
            targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        } else {
            targetSize = image.size
        }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = image.scale

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func downsampledTransparentImage(from image: UIImage, maximumDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maximumDimension else { return normalizedImage(from: image) }

        let scale = maximumDimension / longest
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = image.scale

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func trimTransparentPixels(from image: UIImage, padding: CGFloat) -> UIImage {
        guard
            let cgImage = normalizedCGImage(from: image),
            let alphaBounds = alphaBounds(in: cgImage)
        else {
            return normalizedImage(from: image)
        }

        let scale = image.scale
        let inset = Int((padding * scale).rounded())
        let minX = max(0, Int(alphaBounds.minX) - inset)
        let minY = max(0, Int(alphaBounds.minY) - inset)
        let maxX = min(cgImage.width, Int(alphaBounds.maxX) + inset)
        let maxY = min(cgImage.height, Int(alphaBounds.maxY) + inset)
        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        guard
            cropRect.width > 0,
            cropRect.height > 0,
            let cropped = cgImage.cropping(to: cropRect.integral)
        else {
            return normalizedImage(from: image)
        }

        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    private static func alphaBounds(in cgImage: CGImage) -> CGRect? {
        let width = cgImage.width
        let height = cgImage.height
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

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundAlpha = false

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * bytesPerRow) + (x * bytesPerPixel) + 3]
                if alpha > 8 {
                    foundAlpha = true
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x + 1)
                    maxY = max(maxY, y + 1)
                }
            }
        }

        guard foundAlpha else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func normalizedImage(from image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    private static func opaqueNormalizedCGImage(from image: UIImage) -> CGImage? {
        guard let source = normalizedCGImage(from: image) else { return nil }

        let width = source.width
        let height = source.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)
        context.draw(source, in: rect)
        return context.makeImage()
    }
}

enum CatImageStoreError: LocalizedError {
    case imageEncodingFailed
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            "CatLocal could not prepare this image for private storage."
        case .invalidPath:
            "CatLocal blocked an invalid local image path."
        }
    }
}
