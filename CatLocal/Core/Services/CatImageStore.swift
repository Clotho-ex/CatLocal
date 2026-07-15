import Darwin
import Foundation
import ImageIO
import OSLog
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

    private static let logger = Logger(
        subsystem: "app.catlocal.ios",
        category: "ImageStorage"
    )

    static let originalMaximumDimension: CGFloat = 1_800
    static let cutoutMaximumDimension: CGFloat = 1_400
    static let thumbnailMaximumDimension: CGFloat = 512
    static let originalCompressionQuality: CGFloat = 0.72
    private static let storedImageFilenames: Set<String> = [
        "original.heic",
        "cutout.png",
        "thumbnail.png",
    ]

    private let fileManager: FileManager
    private let rootURL: URL
    private var inFlightRecordIDs: Set<UUID> = []
    private var finalizedRecordIDs: Set<UUID> = []

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
        inFlightRecordIDs.insert(id)
        defer { inFlightRecordIDs.remove(id) }

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let directory = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
        let temporaryDirectory = rootURL.appendingPathComponent(
            "\(id.uuidString).tmp-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        var didFinalizeRecord = false
        do {
            let optimizedOriginal = Self.downsampledOpaqueImage(
                from: original.value,
                maximumDimension: Self.originalMaximumDimension
            )
            let optimizedCutout = Self.optimizedCutout(from: cutout.value)
            let thumbnail = Self.downsampledTransparentImage(
                from: optimizedCutout,
                maximumDimension: Self.thumbnailMaximumDimension
            )

            let originalData = try Self.heicData(
                from: optimizedOriginal,
                quality: Self.originalCompressionQuality
            )
            let cutoutData = try Self.pngData(from: optimizedCutout)
            let thumbnailData = try Self.pngData(from: thumbnail)

            let originalURL = temporaryDirectory.appendingPathComponent("original.heic")
            let cutoutURL = temporaryDirectory.appendingPathComponent("cutout.png")
            let thumbnailURL = temporaryDirectory.appendingPathComponent("thumbnail.png")

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
            didFinalizeRecord = true
            try hardenFinalRecordDirectory(directory)
            finalizedRecordIDs.insert(id)

            return StoredCatImages(
                originalPath: "\(id.uuidString)/original.heic",
                cutoutPath: "\(id.uuidString)/cutout.png",
                thumbnailPath: "\(id.uuidString)/thumbnail.png"
            )
        } catch {
            let saveError = error
            let cleanupFailures = cleanupFailedSave(
                temporaryDirectory: temporaryDirectory,
                finalDirectory: didFinalizeRecord ? directory : nil
            )
            if !cleanupFailures.isEmpty {
                throw CatImageStoreError.imageSaveCleanupFailed(
                    saveError: saveError.localizedDescription,
                    cleanupError: cleanupFailures.joined(separator: "; ")
                )
            }
            throw saveError
        }
    }

    func data(at relativePath: String) async throws -> Data {
        let url = try validatedStoredImageURL(for: relativePath)
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    func deleteRecord(id: UUID) async throws {
        let directory = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else {
            finalizedRecordIDs.remove(id)
            return
        }
        try fileManager.removeItem(at: directory)
        finalizedRecordIDs.remove(id)
    }

    func cleanupOrphanedDirectories(validRecordIDs: Set<UUID>) async throws {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        let preservedRecordIDs = validRecordIDs
            .union(inFlightRecordIDs)
            .union(finalizedRecordIDs)

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            Self.logger.error(
                "Could not enumerate image storage for orphan cleanup: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }

        for url in contents {
            let isDirectory: Bool
            do {
                isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            } catch {
                Self.logger.error(
                    "Could not inspect image storage entry \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                throw error
            }

            guard isDirectory else { continue }
            let name = url.lastPathComponent
            guard !name.contains(".tmp-") else { continue }
            guard let id = UUID(uuidString: name), id.uuidString == name else { continue }
            guard !preservedRecordIDs.contains(id) else { continue }

            do {
                try fileManager.removeItem(at: url)
                Self.logger.info("Removed orphaned image directory \(name, privacy: .public)")
            } catch {
                Self.logger.error(
                    "Could not remove orphaned image directory \(name, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        }
    }

    func deleteAll() async throws {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            finalizedRecordIDs.removeAll()
            return
        }
        try fileManager.removeItem(at: rootURL)
        finalizedRecordIDs.removeAll()
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

    private func validatedStoredImageURL(for relativePath: String) throws -> URL {
        let components = relativePath.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard !relativePath.isEmpty,
              !NSString(string: relativePath).isAbsolutePath,
              components.count == 2,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              let recordID = UUID(uuidString: components[0]),
              recordID.uuidString == components[0],
              Self.storedImageFilenames.contains(components[1]) else {
            throw CatImageStoreError.invalidPath
        }

        let standardizedRoot = rootURL.standardizedFileURL
        let recordDirectory = standardizedRoot.appendingPathComponent(
            components[0],
            isDirectory: true
        )
        let candidate = recordDirectory.appendingPathComponent(components[1])

        for url in [standardizedRoot, recordDirectory, candidate] {
            guard try !isSymbolicLink(at: url) else {
                throw CatImageStoreError.invalidPath
            }
        }

        let resolvedRoot = standardizedRoot
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let resolvedCandidate = candidate
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let rootComponents = resolvedRoot.pathComponents
        let candidateComponents = resolvedCandidate.pathComponents
        guard candidateComponents.count == rootComponents.count + 2,
              candidateComponents.prefix(rootComponents.count).elementsEqual(rootComponents) else {
            throw CatImageStoreError.invalidPath
        }
        return resolvedCandidate
    }

    private func isSymbolicLink(at url: URL) throws -> Bool {
        var info = stat()
        let status = url.withUnsafeFileSystemRepresentation { path -> Int32? in
            path.map { Darwin.lstat($0, &info) }
        }
        guard let status else { throw CatImageStoreError.invalidPath }
        if status == 0 {
            return (info.st_mode & S_IFMT) == S_IFLNK
        }

        let errorCode = errno
        guard errorCode != ENOENT, errorCode != ENOTDIR else { return false }
        throw NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(errorCode),
            userInfo: [NSFilePathErrorKey: url.path]
        )
    }

    private func hardenFinalRecordDirectory(_ directory: URL) throws {
        let relativePaths = try fileManager.subpathsOfDirectory(atPath: directory.path)
        let protectedURLs = [directory] + relativePaths.map(directory.appendingPathComponent)
        for url in protectedURLs {
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        }

        var excludedDirectory = directory
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try excludedDirectory.setResourceValues(resourceValues)

        guard try Self.backupExclusionIsEnabledOnDisk(at: directory) else {
            throw CatImageStoreError.backupExclusionFailed
        }
    }

    static func backupExclusionIsEnabledOnDisk(at directory: URL) throws -> Bool {
        let readbackURL = URL(fileURLWithPath: directory.path, isDirectory: true)
        return try readbackURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        ).isExcludedFromBackup == true
    }

    private func cleanupFailedSave(
        temporaryDirectory: URL,
        finalDirectory: URL?
    ) -> [String] {
        var cleanupTargets = [temporaryDirectory]
        if let finalDirectory {
            cleanupTargets.append(finalDirectory)
        }
        var failures: [String] = []

        for url in cleanupTargets where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                let detail = "\(url.lastPathComponent): \(error.localizedDescription)"
                failures.append(detail)
                Self.logger.error(
                    "Could not roll back failed image save at \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return failures
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

        // Encoding a normalized raster with only compression settings prevents
        // ImageIO from carrying source photo dictionaries into the retained HEIC.
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
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
    case backupExclusionFailed
    case imageSaveCleanupFailed(saveError: String, cleanupError: String)
    case imageEncodingFailed
    case invalidPath
    case persistenceSaveCleanupFailed(persistenceError: String, cleanupError: String)

    var errorDescription: String? {
        switch self {
        case .backupExclusionFailed:
            "CatLocal could not exclude this private image from backups."
        case let .imageSaveCleanupFailed(saveError, cleanupError):
            "CatLocal could not finish saving private images (\(saveError)) and could not clean up incomplete files (\(cleanupError))."
        case .imageEncodingFailed:
            "CatLocal could not prepare this image for private storage."
        case .invalidPath:
            "CatLocal blocked an invalid local image path."
        case let .persistenceSaveCleanupFailed(persistenceError, cleanupError):
            "CatLocal could not save this cat's card details (\(persistenceError)) and could not remove its newly stored images (\(cleanupError))."
        }
    }
}
