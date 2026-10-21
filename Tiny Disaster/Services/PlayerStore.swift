import Foundation
import Combine

@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var progress: ProgressData
    @Published private(set) var avatarData: Data?
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "tactileFeedback") } }
    @Published var reducedEffects: Bool { didSet { defaults.set(reducedEffects, forKey: "gentleEffects") } }
    private let defaults: UserDefaults
    private let photos: ProfilePhotoStore
    private let progressKey = "townProgressV1"

    init(defaults: UserDefaults = .standard, photos: ProfilePhotoStore? = nil) {
        self.defaults = defaults
        let photoStorage = photos ?? ProfilePhotoStore()
        self.photos = photoStorage
        avatarData = photoStorage.load()
        if let data = defaults.data(forKey: progressKey), let saved = try? JSONDecoder().decode(ProgressData.self, from: data) {
            var clean = ProgressData()
            for id in 1...LevelCatalog.levels.count {
                guard clean.isUnlocked(id), let record = saved.records[id], (1...3).contains(record.stars), record.events >= 0 else { continue }
                clean.records[id] = record
            }
            let next = (1...20).first(where: { clean.records[$0] == nil }) ?? 20
            clean.lastLevel = clean.isUnlocked(saved.lastLevel) && (1...20).contains(saved.lastLevel) ? saved.lastLevel : next
            progress = clean
        } else {
            progress = ProgressData()
        }
        haptics = defaults.object(forKey: "tactileFeedback") as? Bool ?? true
        reducedEffects = defaults.bool(forKey: "gentleEffects")
    }

    var totalStars: Int { progress.records.values.reduce(0) { $0 + $1.stars } }
    var completed: Int { progress.records.count }
    var continueLevel: LevelDefinition { LevelCatalog.levels[max(0, min(19, progress.lastLevel - 1))] }

    func record(_ result: AttemptResult) {
        progress.save(result)
        persist()
    }

    func visit(_ level: LevelDefinition) {
        guard progress.isUnlocked(level.id) else { return }
        progress.lastLevel = level.id
        persist()
    }

    func replaceProfilePhoto(with data: Data) throws {
        try photos.save(data)
        avatarData = data
    }

    func removeProfilePhoto() throws {
        try photos.remove()
        avatarData = nil
    }

    func reset() {
        progress = ProgressData()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: progressKey) }
    }
}
