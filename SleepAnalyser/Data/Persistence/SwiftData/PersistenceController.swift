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
            if !inMemory {
                Self.deleteStoreFiles()
                do {
                    container = try ModelContainer(for: schema, configurations: [config])
                    return
                } catch {
                    fatalError("Failed to create ModelContainer after reset: \(error)")
                }
            }
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

    private static func deleteStoreFiles() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeBase = appSupport.appendingPathComponent("default.store")
        for suffix in ["", "-wal", "-shm"] {
            let url = storeBase.appendingPathExtension(suffix.isEmpty ? "" : String(suffix.dropFirst()))
            let path = suffix.isEmpty ? storeBase.path : storeBase.path + suffix
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}
