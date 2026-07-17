import OSLog
import SwiftData
import SwiftUI

enum CatLocalUserDefaults {
    static let hasCompletedOnboardingKey = "catlocal.hasCompletedOnboarding"
    static let hasSeenFocusedCardGlintHintKey = "catlocal.hasSeenFocusedCardGlintHint"
    static let appearanceKey = "catlocal.appearance"
    static let cardMotionEnabledKey = "catlocal.cardMotionEnabled"
    static let hapticsEnabledKey = "catlocal.hapticsEnabled"
    static let languageKey = "catlocal.language"
    static let homeViewKey = "catlocal.homeView"
    static let sortOrderKey = "catlocal.sortOrder"
}

enum CatLocalAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static func resolved(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .system
    }
}

enum CatLocalHomeView: String, CaseIterable, Identifiable {
    case cards
    case catlas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cards: "Cards"
        case .catlas: "Catlas"
        }
    }

    static func resolved(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .cards
    }
}

enum CatLocalSortOrder: String, CaseIterable, Identifiable {
    case number
    case place
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .number: "Number"
        case .place: "Place"
        case .alphabetical: "A-Z"
        }
    }

    var systemImage: String {
        switch self {
        case .number: "number"
        case .place: "mappin.and.ellipse"
        case .alphabetical: "textformat.abc"
        }
    }

    static func resolved(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .number
    }
}

extension EnvironmentValues {
    @Entry var catLocalCardMotionEnabled = true
    @Entry var catLocalHapticsEnabled = true
}

private struct CatSensoryFeedbackModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.catLocalHapticsEnabled) private var hapticsEnabled

    let feedback: SensoryFeedback
    let trigger: Trigger

    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { _, _ in
            hapticsEnabled
        }
    }
}

extension View {
    func catSensoryFeedback<Trigger: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: Trigger
    ) -> some View {
        modifier(CatSensoryFeedbackModifier(feedback: feedback, trigger: trigger))
    }
}

@main
struct CatLocalApp: App {
    nonisolated private static let logger = Logger(
        subsystem: "app.catlocal.ios",
        category: "StorageLifecycle"
    )

    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([CatRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let arguments = CommandLine.arguments
#if DEBUG
            let uiTestingLanguage: CatLocalLanguage? = {
                guard let flagIndex = arguments.firstIndex(of: "-ui-testing-language") else {
                    return nil
                }
                let valueIndex = arguments.index(after: flagIndex)
                guard arguments.indices.contains(valueIndex) else {
                    return nil
                }
                return CatLocalLanguage(rawValue: arguments[valueIndex])
            }()
#else
            let uiTestingLanguage: CatLocalLanguage? = nil
#endif
            if arguments.contains("-ui-testing-show-onboarding") {
                UserDefaults.standard.set(false, forKey: CatLocalUserDefaults.hasCompletedOnboardingKey)
            }
            if arguments.contains("-ui-testing-reset") {
                UserDefaults.standard.set(
                    !arguments.contains("-ui-testing-show-onboarding"),
                    forKey: CatLocalUserDefaults.hasCompletedOnboardingKey
                )
                UserDefaults.standard.set(false, forKey: CatLocalUserDefaults.hasSeenFocusedCardGlintHintKey)
                UserDefaults.standard.set(
                    (uiTestingLanguage ?? .system).rawValue,
                    forKey: CatLocalUserDefaults.languageKey
                )
                let context = ModelContext(container)
                try context.delete(model: CatRecord.self)
                if arguments.contains("-ui-testing-seed-atlas") {
                    Self.seedAtlasRecords(in: context)
                }
                try context.save()
            }
            modelContainer = container
            Self.scheduleOrphanCleanup(using: container)
        } catch {
            fatalError("CatLocal could not open its private collection: \(error)")
        }
    }

    private static func scheduleOrphanCleanup(using container: ModelContainer) {
        Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let validRecordIDs: Set<UUID>
            do {
                validRecordIDs = Set(
                    try context.fetch(FetchDescriptor<CatRecord>()).map(\.id)
                )
            } catch {
                logger.error(
                    "Skipped orphan cleanup because saved record IDs could not be read: \(error.localizedDescription, privacy: .public)"
                )
                return
            }

            do {
                try await CatImageStore.shared.cleanupOrphanedDirectories(
                    validRecordIDs: validRecordIDs
                )
            } catch {
                logger.error(
                    "Launch orphan cleanup failed without blocking the app: \(error.localizedDescription, privacy: .public)"
                )
            }
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
