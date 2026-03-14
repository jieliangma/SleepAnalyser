import Foundation
import SwiftData

final class PersistenceController: @unchecked Sendable {
    let container: ModelContainer

    static let shared = PersistenceController()

    static var preview: PersistenceController {
        PersistenceController(inMemory: true)
    }

    init(inMemory: Bool = false) {
        let schema = Schema([
            SDUserProfile.self,
            SDSleepSession.self,
            SDSleepEpoch.self,
            SDAudioEvent.self,
            SDCalibration.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    @MainActor
    var mainContext: ModelContext {
        container.mainContext
    }

    func newBackgroundContext() -> ModelContext {
        ModelContext(container)
    }
}
