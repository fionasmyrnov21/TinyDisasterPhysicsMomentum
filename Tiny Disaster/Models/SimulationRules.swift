import Foundation
import CoreGraphics

struct SimulationClock {
    private(set) var elapsed: TimeInterval = 0
    private var previous: TimeInterval?

    mutating func advance(to time: TimeInterval) -> TimeInterval {
        guard time.isFinite else { return 0 }
        guard let previous else {
            self.previous = time
            return 0
        }
        guard time >= previous else { return 0 }
        self.previous = time
        let delta = time - previous
        elapsed += delta
        return delta
    }

    mutating func suspend() { previous = nil }
}

enum SimulationRules {
    static let forceScale: CGFloat = 150
    static let pushSpeed: CGFloat = 300
    static let bankHeight: CGFloat = 100
    static let hinge = CGPoint(x: 460, y: bankHeight)

    static func bridgeCenter(height: Double, angle: Double) -> CGPoint {
        CGPoint(x: hinge.x - sin(angle) * height / 2, y: hinge.y + cos(angle) * height / 2)
    }

    static func bridgeEnd(center: CGPoint, height: Double, angle: Double) -> CGPoint {
        CGPoint(x: center.x - sin(angle) * height / 2, y: center.y + cos(angle) * height / 2)
    }

    static func crossingReady(center: CGPoint, height: Double, angle: Double, angularSpeed: Double, creekWidth: Double) -> Bool {
        let end = bridgeEnd(center: center, height: height, angle: angle)
        return angle < 0 && abs(angularSpeed) < 0.4 && end.x >= hinge.x + creekWidth + 8 && end.y >= bankHeight && end.y <= bankHeight + 24
    }

    static func roverArrived(center: CGPoint, zone: CGRect) -> Bool {
        zone.contains(CGRect(x: center.x - 28, y: center.y - 19, width: 56, height: 45))
    }

    static func missionReached(level: LevelDefinition, toppled: Set<String>, safeArrival: Bool, damaged: Set<String>) -> Bool {
        guard damaged.isEmpty else { return false }
        if level.kind == .rescue { return safeArrival }
        return !level.targetIDs.isEmpty && level.targetIDs.allSatisfy { toppled.contains($0) }
    }
}
