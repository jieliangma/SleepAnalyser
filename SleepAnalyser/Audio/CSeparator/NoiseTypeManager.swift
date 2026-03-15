import Foundation
import Observation

@Observable
final class NoiseTypeManager: @unchecked Sendable {
    var types: [NoiseTypeConfig] = []
    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SleepAnalyser", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("noise_types.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([NoiseTypeConfig].self, from: data) {
            types = saved
        } else {
            types = NoiseTypeConfig.builtIn
            save()
        }
    }

    func save() {
        try? JSONEncoder().encode(types).write(to: storageURL, options: .atomic)
    }

    func add(_ config: NoiseTypeConfig) {
        types.append(config)
        save()
    }

    func update(_ config: NoiseTypeConfig) {
        if let idx = types.firstIndex(where: { $0.id == config.id }) {
            types[idx] = config
            save()
        }
    }

    func delete(id: UUID) {
        types.removeAll { $0.id == id }
        save()
    }

    func config(for name: String) -> NoiseTypeConfig? {
        types.first { $0.name == name }
    }

    func colorHex(for name: String) -> String {
        config(for: name)?.colorHex ?? "64748B"
    }

    func addSoundClip(to typeName: String, url: URL) {
        guard let idx = types.firstIndex(where: { $0.name == typeName }) else { return }
        types[idx].soundClipURLs.append(url)
        save()
    }

    func removeSoundClip(from typeName: String, at clipIndex: Int) {
        guard let idx = types.firstIndex(where: { $0.name == typeName }),
              clipIndex < types[idx].soundClipURLs.count else { return }
        let url = types[idx].soundClipURLs.remove(at: clipIndex)
        try? FileManager.default.removeItem(at: url)
        save()
    }
}
