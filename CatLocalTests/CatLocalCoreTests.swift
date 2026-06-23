import ImageIO
import SwiftData
import Testing
import UIKit
@testable import CatLocal

struct CatLocalCoreTests {
    @Test
    func cardStyleIsDeterministic() {
        for seed in [0, 1, 2, 3, 77, 9_999] {
            #expect(CardStyle.deterministic(seed: seed) == CardStyle.deterministic(seed: seed))
        }
        #expect(CardStyle.deterministic(seed: 0) == .archive)
        #expect(CardStyle.deterministic(seed: 1) == .sunstamp)
        #expect(CardStyle.deterministic(seed: 2) == .clear)
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
            source: .photoLibrary,
            cardStyle: .sunstamp,
            styleSeed: 19,
            originalImagePath: "id/original.heic",
            cutoutImagePath: "id/cutout.png",
            thumbnailImagePath: "id/thumbnail.jpg"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CatRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].displayName == "Local Cat")
        #expect(fetched[0].source == .photoLibrary)
        #expect(fetched[0].cardStyle == .sunstamp)
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
        #expect(paths.thumbnailPath == "\(id.uuidString)/thumbnail.jpg")

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
}
