import CoreImage
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import CatLocal

struct CatLocalCoreTests {
    @Test
    func cardStyleDefaultsToArchiveForLegacySeeds() {
        for seed in [0, 1, 2, 3, 77, 9_999] {
            #expect(CardStyle.deterministic(seed: seed) == .archive)
        }
    }

    @Test
    func cardStyleCatalogIncludesTopographicVariants() {
        let topographicStyles = CardStyle.orderedCases.filter(\.isTopographic)

        #expect(topographicStyles == [.topo, .topoEmber, .topoLagoon, .topoMoss, .topoDusk])
        #expect(Set(CardStyle.orderedCases.map(\.rawValue)).count == CardStyle.orderedCases.count)
    }

    @Test
    func compactSequencesKeepsRemainingCardNumbersContiguous() {
        let first = makeRecord(sequence: 1)
        let third = makeRecord(sequence: 3)

        CatRecord.compactSequences([third, first])

        #expect(first.sequence == 1)
        #expect(third.sequence == 2)
    }

    @Test
    func unnamedCatsUseFriendlyNamePool() {
        #expect(CatNamePool.names.count == 130)
        #expect(Set(CatNamePool.names).count == 130)
        #expect(!CatNamePool.names.contains("Fresh Pawprint"))
        #expect(!CatNamePool.names.contains("Fresh Paw Print"))

        let record = CatRecord(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            sequence: 1,
            nickname: "",
            note: "",
            source: .camera,
            cardStyle: .archive,
            styleSeed: 0,
            originalImagePath: "id/original.heic",
            cutoutImagePath: "id/cutout.png",
            thumbnailImagePath: "id/thumbnail.png"
        )

        #expect(CatNamePool.names.contains(record.displayName))
        #expect(record.displayName != "Cat 1")
    }

    @Test
    func randomNameAvoidsExistingNamesWhenPossible() {
        let existingNames = Set(CatNamePool.names.dropLast())
        #expect(CatNamePool.randomName(excluding: existingNames) == CatNamePool.names.last)
    }

    @Test
    func recordPersistsMetadata() throws {
        let schema = Schema([CatRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let record = CatRecord(
            sequence: 4,
            nickname: "Local Cat",
            note: "Watched the ferry.",
            placeName: "Ferry Steps",
            placeDetail: "Beside the ticket booth",
            source: .photoLibrary,
            cardStyle: .sunstamp,
            styleSeed: 19,
            catBoundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5),
            originalImagePath: "id/original.heic",
            cutoutImagePath: "id/cutout.png",
            thumbnailImagePath: "id/thumbnail.png"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CatRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].displayName == "Local Cat")
        #expect(fetched[0].memoryPlaceName == "Ferry Steps")
        #expect(fetched[0].memoryPlaceDetail == "Beside the ticket booth")
        #expect(fetched[0].memoryPlaceLabel == "Ferry Steps, Beside the ticket booth")
        #expect(fetched[0].source == .photoLibrary)
        #expect(fetched[0].cardStyle == .sunstamp)
        #expect(fetched[0].catBoundingBox == CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5))
    }

    @Test
    func recordPlaceMemoryCanBeCleared() {
        let record = CatRecord(
            sequence: 7,
            nickname: "",
            note: "",
            placeName: "  Garden Wall  ",
            placeDetail: "  Afternoon sun  ",
            source: .camera,
            cardStyle: .archive,
            styleSeed: 0,
            originalImagePath: "id/original.heic",
            cutoutImagePath: "id/cutout.png",
            thumbnailImagePath: "id/thumbnail.png"
        )

        #expect(record.memoryPlaceName == "Garden Wall")
        #expect(record.memoryPlaceDetail == "Afternoon sun")
        record.placeName = "  "
        record.placeDetail = "\n"
        #expect(record.memoryPlaceName == nil)
        #expect(record.memoryPlaceDetail == nil)
        #expect(record.atlasGroupTitle == "Unplaced")
    }

    @Test
    func projectDoesNotRequestCoordinateLocationForAtlas() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectFile = repository
            .appendingPathComponent("CatLocal.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        let projectText = try String(contentsOf: projectFile, encoding: .utf8)
        #expect(!projectText.contains("NSLocation"))

        let sourceRoot = repository.appendingPathComponent("CatLocal")
        let sourcePaths = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }

        for path in sourcePaths {
            let text = try String(
                contentsOf: sourceRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            #expect(!text.contains("import CoreLocation"))
            #expect(!text.contains("import MapKit"))
        }
    }

    @Test @MainActor
    func imageStoreWritesExifFreeFilesAndDeletesThem() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CatImageStore(rootURL: root)
        let id = UUID()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }

        let paths = try await store.save(
            id: id,
            original: SendableImage(value: image),
            cutout: SendableImage(value: image)
        )

        #expect(paths.originalPath == "\(id.uuidString)/original.heic")
        #expect(paths.cutoutPath == "\(id.uuidString)/cutout.png")
        #expect(paths.thumbnailPath == "\(id.uuidString)/thumbnail.png")

        let originalData = try await store.data(at: paths.originalPath)
        let source = CGImageSourceCreateWithData(originalData as CFData, nil)
        let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let gps = properties?[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        #expect(exif?.isEmpty != false)
        #expect(gps?.isEmpty != false)

        try await store.deleteRecord(id: id)
        await #expect(throws: Error.self) {
            try await store.data(at: paths.originalPath)
        }
    }

    @Test
    func imageStoreRejectsSiblingPrefixTraversal() async throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = parent.appendingPathComponent("Cats", isDirectory: true)
        let sibling = parent.appendingPathComponent("CatsBackup", isDirectory: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try Data("outside".utf8).write(to: sibling.appendingPathComponent("secret.txt"))

        let store = CatImageStore(rootURL: root)
        await #expect(throws: CatImageStoreError.self) {
            _ = try await store.data(at: "../CatsBackup/secret.txt")
        }
    }

    @Test @MainActor
    func imageStoreDownsamplesAndTrimsStoredImages() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = CatImageStore(rootURL: root)
        let id = UUID()
        let original = renderedImage(size: CGSize(width: 2_400, height: 1_600), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 1_600))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 160, y: 160, width: 280, height: 240))
        }
        let cutout = renderedImage(size: CGSize(width: 1_000, height: 1_000), opaque: false) { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_000, height: 1_000))
            UIColor.black.setFill()
            context.fill(CGRect(x: 380, y: 330, width: 220, height: 260))
        }

        let paths = try await store.save(
            id: id,
            original: SendableImage(value: original),
            cutout: SendableImage(value: cutout)
        )

        let originalData = try await store.data(at: paths.originalPath)
        let cutoutData = try await store.data(at: paths.cutoutPath)
        let thumbnailData = try await store.data(at: paths.thumbnailPath)

        #expect(originalData.count < 1_500_000)
        #expect(cutoutData.count < 1_500_000)
        #expect(thumbnailData.count < 250_000)
        #expect(try imagePixelSize(from: originalData).width <= CatImageStore.originalMaximumDimension)
        #expect(try imagePixelSize(from: thumbnailData).width <= CatImageStore.thumbnailMaximumDimension)

        let cutoutSize = try imagePixelSize(from: cutoutData)
        #expect(cutoutSize.width < 340)
        #expect(cutoutSize.height < 380)
    }

    @Test
    func dustingAnchorSamplerIgnoresTransparentPixels() throws {
        let image = renderedImage(size: CGSize(width: 100, height: 100), opaque: false) { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.black.setFill()
            context.fill(CGRect(x: 40, y: 40, width: 20, height: 20))
        }

        let cgImage = try #require(image.cgImage)
        let bounds = try #require(DustingAnchorSampler.visibleBounds(in: cgImage))
        let anchors = DustingAnchorSampler.sampleVisibleAnchors(
            in: cgImage,
            maximumAnchors: 20
        )

        #expect(bounds.minX >= 0.35)
        #expect(bounds.maxX <= 0.65)
        #expect(bounds.minY >= 0.35)
        #expect(bounds.maxY <= 0.65)
        #expect(!anchors.isEmpty)
        #expect(anchors.allSatisfy { anchor in
            anchor.x >= 0.35
                && anchor.x <= 0.65
                && anchor.y >= 0.35
                && anchor.y <= 0.65
        })
    }

    @Test
    func dustingAnchorSamplerCapsAnchorCount() throws {
        let image = renderedImage(size: CGSize(width: 120, height: 120), opaque: true) { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }

        let anchors = DustingAnchorSampler.sampleVisibleAnchors(
            in: try #require(image.cgImage),
            maximumAnchors: 8
        )

        #expect(anchors.count <= 8)
        #expect(!anchors.isEmpty)
    }

    @Test
    func dustingAnchorSamplerHandlesTransparentImages() throws {
        let image = renderedImage(size: CGSize(width: 80, height: 80), opaque: false) { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }

        let anchors = DustingAnchorSampler.sampleVisibleAnchors(
            in: try #require(image.cgImage),
            maximumAnchors: 40
        )

        #expect(anchors.isEmpty)
        #expect(DustingAnchorSampler.visibleBounds(in: try #require(image.cgImage)) == nil)
        #expect(DustingAnchorSampler.sampleVisibleAnchors(
            in: try #require(image.cgImage),
            maximumAnchors: 0
        ).isEmpty)
    }

    @Test
    func detectionResolutionCoversEmptySingleAndMultipleResults() {
        let low = CatDetection(
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            confidence: 0.55
        )
        let high = CatDetection(
            boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.3, height: 0.4),
            confidence: 0.91
        )

        #expect(CatDetectionSelector.resolve([]) == .none)
        #expect(CatDetectionSelector.resolve([low]) == .single(low))
        #expect(CatDetectionSelector.resolve([low, high]) == .multiple([high, low]))
    }

    @Test
    func visionCutoutUsesMaskLuminanceForTransparency() async throws {
        let original = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let mask = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
            UIColor.white.setFill()
            context.fill(CGRect(x: 24, y: 24, width: 32, height: 32))
        }

        let processor = CatVisionProcessor()
        let cutout = try await processor.makeTransparentCutout(
            from: try #require(original.cgImage),
            mask: CIImage(cgImage: try #require(mask.cgImage))
        )

        #expect(processor.hasVisibleSubjectAndTransparentBackground(cutout))
        #expect(try alphaValue(in: cutout, x: 4, y: 4) == 0)
        #expect(try alphaValue(in: cutout, x: 40, y: 40) > 200)
    }

    @Test
    func visionCutoutRejectsWholeRectangleMask() async throws {
        let original = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let mask = renderedImage(size: CGSize(width: 80, height: 80), opaque: true) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }

        let processor = CatVisionProcessor()
        await #expect(throws: CatVisionError.self) {
            _ = try await processor.makeTransparentCutout(
                from: try #require(original.cgImage),
                mask: CIImage(cgImage: try #require(mask.cgImage))
            )
        }
    }

    @Test
    func catCropExpandsDetectionAndStaysInsideImageBounds() {
        let processor = CatVisionProcessor()
        let crop = processor.expandedCatCropRect(
            for: CGRect(x: 0.4, y: 0.25, width: 0.2, height: 0.3),
            imageWidth: 1_000,
            imageHeight: 800
        )

        let detectedPixelRect = CGRect(x: 400, y: 360, width: 200, height: 240)
        #expect(crop.contains(detectedPixelRect.origin))
        #expect(crop.contains(CGPoint(x: detectedPixelRect.maxX, y: detectedPixelRect.maxY)))
        #expect(crop.width > detectedPixelRect.width)
        #expect(crop.height > detectedPixelRect.height)
        #expect(crop.minX >= 0)
        #expect(crop.minY >= 0)
        #expect(crop.maxX <= 1_000)
        #expect(crop.maxY <= 800)
    }

    @Test
    func liveInteractiveCardTiltClampsAndDetectsLimit() {
        let size = CGSize(width: 350, height: 220)
        let center = LiveInteractiveCardMath.tilt(
            for: CGPoint(x: 175, y: 110),
            in: size,
            maxTiltAngle: 12
        )
        #expect(center.rotateX == 0)
        #expect(center.rotateY == 0)
        #expect(center.isAtLimit == false)

        let edge = LiveInteractiveCardMath.tilt(
            for: CGPoint(x: 350, y: 0),
            in: size,
            maxTiltAngle: 12
        )
        #expect(edge.rotateX == 12)
        #expect(edge.rotateY == 12)
        #expect(edge.isAtLimit)

        let outOfBounds = LiveInteractiveCardMath.tilt(
            for: CGPoint(x: 700, y: -220),
            in: size,
            maxTiltAngle: 12
        )
        #expect(outOfBounds.location == CGPoint(x: 350, y: 0))
        #expect(outOfBounds.rotateX == 12)
        #expect(outOfBounds.rotateY == 12)
        #expect(outOfBounds.isAtLimit)
    }

    private func makeRecord(sequence: Int) -> CatRecord {
        CatRecord(
            id: UUID(),
            sequence: sequence,
            capturedAt: Date(timeIntervalSinceReferenceDate: TimeInterval(sequence)),
            nickname: "Cat \(sequence)",
            note: "",
            source: .camera,
            cardStyle: .archive,
            styleSeed: 0,
            originalImagePath: "\(sequence)/original.heic",
            cutoutImagePath: "\(sequence)/cutout.png",
            thumbnailImagePath: "\(sequence)/thumbnail.png"
        )
    }

    private func renderedImage(
        size: CGSize,
        opaque: Bool,
        actions: (CGContext) -> Void
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = opaque
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            actions(context.cgContext)
        }
    }

    private func imagePixelSize(from data: Data) throws -> CGSize {
        let source = CGImageSourceCreateWithData(data as CFData, nil)
        let properties = source.flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        }
        guard
            let width = properties?[kCGImagePropertyPixelWidth] as? Int,
            let height = properties?[kCGImagePropertyPixelHeight] as? Int
        else {
            throw CatImageStoreError.imageEncodingFailed
        }
        return CGSize(width: width, height: height)
    }

    private func alphaValue(in image: CGImage, x: Int, y: Int) throws -> UInt8 {
        let width = image.width
        let height = image.height
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
            throw CatImageStoreError.imageEncodingFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels[(y * bytesPerRow) + (x * bytesPerPixel) + 3]
    }
}
