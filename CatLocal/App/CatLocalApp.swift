import SwiftData
import SwiftUI

enum CatLocalUserDefaults {
    static let hasCompletedOnboardingKey = "catlocal.hasCompletedOnboarding"
    static let hasSeenFocusedCardGlintHintKey = "catlocal.hasSeenFocusedCardGlintHint"
}

@main
struct CatLocalApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([CatRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let arguments = CommandLine.arguments
            if arguments.contains("-ui-testing-show-onboarding") {
                UserDefaults.standard.set(false, forKey: CatLocalUserDefaults.hasCompletedOnboardingKey)
            }
            if arguments.contains("-ui-testing-reset") {
                UserDefaults.standard.set(
                    !arguments.contains("-ui-testing-show-onboarding"),
                    forKey: CatLocalUserDefaults.hasCompletedOnboardingKey
                )
                UserDefaults.standard.set(false, forKey: CatLocalUserDefaults.hasSeenFocusedCardGlintHintKey)
                let context = ModelContext(container)
                try context.delete(model: CatRecord.self)
                if arguments.contains("-ui-testing-seed-atlas") {
                    Self.seedAtlasRecords(in: context)
                }
                try context.save()
            }
            modelContainer = container
        } catch {
            fatalError("CatLocal could not open its private collection: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }

    private static func seedAtlasRecords(in context: ModelContext) {
        let baseDate = Date(timeIntervalSinceReferenceDate: 780_000_000)
        let records = [
            CatRecord(
                sequence: 1,
                capturedAt: baseDate,
                nickname: "Miso",
                note: "Sat by the ferry steps.",
                placeName: "Ferry Steps",
                placeDetail: "Morning shade by the ticket booth",
                source: .photoLibrary,
                cardStyle: .archive,
                styleSeed: 0,
                originalImagePath: "ui-test/original.heic",
                cutoutImagePath: "ui-test/cutout.png",
                thumbnailImagePath: "ui-test/thumbnail.png"
            ),
            CatRecord(
                sequence: 2,
                capturedAt: baseDate.addingTimeInterval(60),
                nickname: "Simit",
                note: "Watched the garden wall.",
                placeName: "Garden Wall",
                placeDetail: "",
                source: .photoLibrary,
                cardStyle: .archive,
                styleSeed: 0,
                originalImagePath: "ui-test/original.heic",
                cutoutImagePath: "ui-test/cutout.png",
                thumbnailImagePath: "ui-test/thumbnail.png"
            ),
            CatRecord(
                sequence: 3,
                capturedAt: baseDate.addingTimeInterval(120),
                nickname: "",
                note: "",
                placeName: "",
                placeDetail: "",
                source: .camera,
                cardStyle: .archive,
                styleSeed: 0,
                originalImagePath: "ui-test/original.heic",
                cutoutImagePath: "ui-test/cutout.png",
                thumbnailImagePath: "ui-test/thumbnail.png"
            )
        ]

        records.forEach(context.insert)
    }
}
