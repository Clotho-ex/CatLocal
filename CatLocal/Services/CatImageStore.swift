import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

struct StoredCatImages: Sendable {
    let originalPath: String
    let cutoutPath: String
    let thumbnailPath: String
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
        let directory = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            let originalData = try Self.heicData(from: original.value)
            let cutoutData = try Self.pngData(from: cutout.value)
            let thumbnail = Self.thumbnail(from: cutout.value, maximumDimension: 900)
            let thumbnailData = try Self.jpegData(from: thumbnail, quality: 0.82)

            let originalURL = directory.appendingPathComponent("original.heic")
            let cutoutURL = directory.appendingPathComponent("cutout.png")
            let thumbnailURL = directory.appendingPathComponent("thumbnail.jpg")

            try originalData.write(to: originalURL, options: .atomic)
            try cutoutData.write(to: cutoutURL, options: .atomic)
            try thumbnailData.write(to: thumbnailURL, options: .atomic)

            return StoredCatImages(
                originalPath: relativePath(for: originalURL),
                cutoutPath: relativePath(for: cutoutURL),
                thumbnailPath: relativePath(for: thumbnailURL)
            )
        } catch {
            try? fileManager.removeItem(at: directory)
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

    private func relativePath(for url: URL) -> String {
        url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
    }

    private static func heicData(from image: UIImage) throws -> Data {
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
            kCGImageDestinationLossyCompressionQuality: 0.9,
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

    private static func thumbnail(from image: UIImage, maximumDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maximumDimension else { return image }

        let scale = maximumDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
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
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
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
