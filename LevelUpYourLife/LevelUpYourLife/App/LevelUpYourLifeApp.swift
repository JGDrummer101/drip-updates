import SwiftUI
import SwiftData

@main
@MainActor
struct LevelUpYourLifeApp: App {
    private let container: ModelContainer
    @State private var appState = AppState()

    init() {
        container = Self.makeContainer()
        SeedService.seedIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(Color.luGoldBright)
        }
        .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(AppSchema.models)
        do {
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema)]
            )
        } catch {
            // A broken store should never brick the demo — fall back to memory.
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                )
            } catch {
                fatalError("Unable to create any model container: \(error)")
            }
        }
    }
}
