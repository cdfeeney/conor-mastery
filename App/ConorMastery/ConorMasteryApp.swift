import SwiftData
import SwiftUI

@main
struct ConorMasteryApp: App {
    private let container: ModelContainer

    init() {
        #if DEBUG
        if TestLaunch.isActive {
            container = try! ModelContainer(for: Schema(Schema1.models),
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            TestLaunch.prepare(container.mainContext)
            return
        }
        #endif
        do {
            container = try ModelContainer(for: Schema(Schema1.models))
        } catch {
            // A broken store must not brick the app: fall back to memory and say so on screen.
            container = try! ModelContainer(for: Schema(Schema1.models),
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            StartupProblem.message = "Saved data couldn't open (\(error.localizedDescription)). Running without saving."
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(context: container.mainContext)
        }
        .modelContainer(container)
    }
}

enum StartupProblem {
    nonisolated(unsafe) static var message: String?
}
