import SwiftData
import SwiftUI

@main
struct CatLocalApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([CatRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            if CommandLine.arguments.contains("-ui-testing-reset") {
                let context = ModelContext(container)
                try context.delete(model: CatRecord.self)
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
}
