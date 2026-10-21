import Foundation
import CoreGraphics

enum Mechanism: String, Codable, CaseIterable {
    case push, support, fan, release

    var title: String {
        switch self {
        case .push: return "Push the stone"
        case .support: return "Remove the support"
        case .fan: return "Start the fan"
        case .release: return "Release the weight"
        }
    }

    var symbol: String {
        switch self {
        case .push: return "hand.draw.fill"
        case .support: return "rectangle.portrait.slash"
        case .fan: return "wind"
        case .release: return "arrow.down.to.line"
        }
    }

    var explanation: String {
        switch self {
        case .push: return "Give a rounded stone a single nudge. Its momentum can set an entire street in motion."
        case .support: return "Take away one wooden prop. Everything resting on it must find a new place to land."
        case .fan: return "Turn on a steady breeze. Light objects move first, heavier structures need a clever connection."
        case .release: return "Let a suspended weight fall. Gravity does the rest — watch what waits underneath."
        }
    }
}

enum ObjectKind: String, Codable {
    case stone, prop, fan, weight, plank, tower, cottage, rover, bridge, ramp
}

struct TownObject: Identifiable {
    let id: String
    let kind: ObjectKind
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    var angle: Double = 0
    var dynamic = false
    var mass: Double = 1
    var restitution: Double = 0.02
    var tint = 0

    var position: CGPoint { CGPoint(x: x, y: y) }
    var size: CGSize { CGSize(width: width, height: height) }
}

struct ActionChoice: Identifiable {
    let id: String
    let mechanism: Mechanism
    let objectID: String
    let title: String
    let detail: String
    var affectedIDs: [String] = []
}

enum MissionKind: String, Codable {
    case demolition, rescue

    var title: String { self == .demolition ? "Careful demolition" : "A little rescue" }
    var symbol: String { self == .demolition ? "building.2.crop.circle" : "shield.lefthalf.filled" }
}

struct LevelDefinition: Identifiable {
    let id: Int
    let name: String
    let district: Int
    let kind: MissionKind
    let story: String
    let hint: String
    let objects: [TownObject]
    let choices: [ActionChoice]
    let targetIDs: [String]
    let protectedIDs: [String]
    let rescueZone: CGRect?
    let creekWidth: Double
    let twoStars: Int
    let threeStars: Int

    var number: String { String(format: "%02d", id) }
    var districtName: String { LevelCatalog.districts[district] }
    var objective: String {
        kind == .demolition ? "Bring down the old tower. Keep the cottage standing." : "Lower the bridge. Guide the rover safely across the creek."
    }
}

struct ChainEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
}

struct AttemptResult: Identifiable {
    let id = UUID()
    let levelID: Int
    let succeeded: Bool
    let events: [ChainEvent]
    let stars: Int
    let reason: String
}

struct LevelRecord: Codable, Equatable {
    var stars: Int
    var events: Int
}

struct ProgressData: Codable {
    var records: [Int: LevelRecord] = [:]
    var lastLevel = 1

    func isUnlocked(_ id: Int) -> Bool {
        guard (1...LevelCatalog.levels.count).contains(id) else { return false }
        return id == 1 || (records[id - 1]?.stars ?? 0) > 0
    }

    mutating func save(_ result: AttemptResult) {
        guard result.succeeded, isUnlocked(result.levelID), (1...3).contains(result.stars) else { return }
        let old = records[result.levelID] ?? LevelRecord(stars: 0, events: 0)
        records[result.levelID] = LevelRecord(stars: max(old.stars, result.stars), events: max(old.events, result.events.count))
        lastLevel = min(LevelCatalog.levels.count, result.levelID + 1)
    }
}

enum Scoring {
    static func stars(success: Bool, events: Int, level: LevelDefinition) -> Int {
        guard success else { return 0 }
        return events >= level.threeStars ? 3 : events >= level.twoStars ? 2 : 1
    }
}

struct EventLedger {
    private(set) var events: [ChainEvent] = []
    private var identifiers: Set<String> = []

    @discardableResult
    mutating func record(_ event: ChainEvent) -> Bool {
        guard identifiers.insert(event.id).inserted else { return false }
        events.append(event)
        return true
    }
}

enum AttemptPhase: Equatable {
    case planning, running, paused, finished
}

struct AttemptGate {
    private(set) var phase: AttemptPhase = .planning

    mutating func begin() -> Bool {
        guard phase == .planning else { return false }
        phase = .running
        return true
    }

    mutating func pause() {
        if phase == .running { phase = .paused }
    }

    mutating func resume() {
        if phase == .paused { phase = .running }
    }

    mutating func finish() { phase = .finished }
}
