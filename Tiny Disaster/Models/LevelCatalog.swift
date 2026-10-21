import Foundation
import CoreGraphics

struct LevelCatalog {
    static let districts = ["Willow Lane", "Copper Heights", "Creekside", "Meadow Crossing"]
    static let districtNotes = ["Small nudges. Lovely consequences.", "A new perspective on gravity.", "Build a way to the other side.", "A whole town counting on one move."]
    static let levels: [LevelDefinition] = (1...20).map { makeLevel($0) }
    private static let actionOrders = [
        ["primary", "alternate"],
        ["alternate", "primary"],
        ["alternate", "primary"],
        ["primary", "alternate"],
        ["alternate", "extra", "primary"],
        ["primary", "extra", "alternate"],
        ["extra", "primary", "alternate"],
        ["extra", "alternate", "primary"],
        ["alternate", "primary", "extra"],
        ["alternate", "extra", "primary"],
        ["primary", "alternate", "extra"],
        ["extra", "alternate", "primary"],
        ["alternate", "primary", "extra"],
        ["primary", "extra", "alternate"],
        ["alternate", "extra", "primary"],
        ["extra", "primary", "alternate"],
        ["primary", "extra", "alternate"],
        ["alternate", "primary", "extra"],
        ["extra", "alternate", "primary"],
        ["primary", "alternate", "extra"]
    ]

    static func makeLevel(_ id: Int) -> LevelDefinition {
        let rescue = id > 10
        let mechanism = Mechanism.allCases[(id - 1) % 4]
        let variant = (id - 1) % 5
        let names = ["First domino", "A missing piece", "A change of air", "Let gravity help", "The quiet street", "Timber & stone", "A gentle breeze", "Perfect timing", "The leaning landmark", "One last nudge", "Across the creek", "A bridge to home", "The long way round", "A safer landing", "Little engineer", "The morning crossing", "A helping hand", "River delivery", "Bring them home", "A town together"]
        var objects: [TownObject] = []
        var choices: [ActionChoice] = []
        var targets: [String] = []
        let shift = Double(variant) * 9

        if rescue {
            let bridgeAngle = (mechanism == .support || mechanism == .release) ? -0.045 : 0.0
            let center = SimulationRules.bridgeCenter(height: 240 + shift, angle: bridgeAngle)
            objects.append(TownObject(id: "bridge", kind: .bridge, x: center.x, y: center.y, width: 16, height: 240 + shift, angle: bridgeAngle, dynamic: true, mass: mechanism == .push ? 8 : 2.5))
            objects.append(TownObject(id: "rover", kind: .rover, x: 105 + shift / 2, y: 121, width: 56, height: 32, dynamic: true, mass: 1.4))
            objects.append(TownObject(id: "home", kind: .cottage, x: 888 + shift, y: 153, width: 95, height: 106, tint: variant))
            switch mechanism {
            case .push:
                objects.append(TownObject(id: "starter", kind: .stone, x: 300 - shift, y: 285, width: 66, height: 66, dynamic: true, mass: 3, restitution: 0.8))
            case .support:
                objects.append(TownObject(id: "starter", kind: .prop, x: 491, y: 182 + shift / 2, width: 24, height: 164 + shift))
            case .fan:
                objects.append(TownObject(id: "starter", kind: .fan, x: 340 - shift / 2, y: 229, width: 64, height: 72))
            case .release:
                objects.append(TownObject(id: "starter", kind: .weight, x: 491, y: 182 + shift / 2, width: 24, height: 164 + shift, mass: 3.5))
            }
        } else {
            for index in 0..<3 {
                let x = 455 + shift + Double(index) * 62
                objects.append(TownObject(id: "domino\(index)", kind: .plank, x: x, y: 166, width: 22, height: 132, dynamic: true, mass: 0.65, tint: index))
            }
            for index in 0..<3 {
                let key = "tower\(index)"
                targets.append(key)
                objects.append(TownObject(id: key, kind: .tower, x: 650 + shift, y: 135 + Double(index) * 70, width: 44, height: 68, dynamic: true, mass: 0.4, tint: index))
            }
            objects.append(TownObject(id: "home", kind: .cottage, x: 950, y: 150, width: 92, height: 100, tint: variant))
            switch mechanism {
            case .push:
                objects.append(TownObject(id: "starter", kind: .stone, x: 245, y: 135, width: 68, height: 68, dynamic: true, mass: 3))
            case .support:
                objects.append(TownObject(id: "starter", kind: .prop, x: 295, y: 359, width: 100, height: 18))
                objects.append(TownObject(id: "load", kind: .stone, x: 295, y: 400, width: 62, height: 62, dynamic: true, mass: 3))
                objects.append(TownObject(id: "ramp", kind: .ramp, x: 315, y: 215, width: 235, height: 18, angle: -0.48))
            case .fan:
                objects.append(TownObject(id: "starter", kind: .fan, x: 290, y: 165, width: 64, height: 72))
                objects.append(TownObject(id: "sail", kind: .plank, x: 377, y: 167, width: 46, height: 134, dynamic: true, mass: 0.3, tint: 3))
            case .release:
                objects.append(TownObject(id: "starter", kind: .weight, x: 290, y: 420, width: 64, height: 64, mass: 3))
                objects.append(TownObject(id: "ramp", kind: .ramp, x: 315, y: 222, width: 245, height: 18, angle: -0.47))
            }
        }
        choices.append(ActionChoice(id: "primary", mechanism: mechanism, objectID: "starter", title: mechanism.title, detail: rescue ? "Watch how the bridge connects to the mechanism." : "Follow the path toward the old tower.", affectedIDs: mechanism == .fan ? [rescue ? "bridge" : "sail"] : []))
        objects.append(TownObject(id: "spare", kind: .prop, x: rescue ? 55 : 865, y: rescue ? 151 : 230, width: rescue ? 22 : 26, height: rescue ? 102 : 260))
        choices.append(ActionChoice(id: "alternate", mechanism: .support, objectID: "spare", title: rescue ? "Remove the garden prop" : "Remove the safety screen", detail: rescue ? "A quiet corner, far from the main structure." : "This screen keeps the cottage clear of falling timber."))
        if id > 4 {
            if rescue {
                objects.append(TownObject(id: "ledge", kind: .ramp, x: mechanism == .push ? 300 : 175, y: 245, width: mechanism == .push ? 280 : 100, height: 16))
            }
            objects.append(TownObject(id: "extra", kind: .stone, x: rescue ? 175 : 125, y: rescue ? 274 : 122, width: 42, height: 42, dynamic: true, mass: 0.6))
            choices.append(ActionChoice(id: "extra", mechanism: .push, objectID: "extra", title: "Nudge the small pebble", detail: "A lighter object carries less momentum."))
        }
        let available = Dictionary(uniqueKeysWithValues: choices.map { ($0.id, $0) })
        choices = actionOrders[id - 1].compactMap { available[$0] }
        let hints: [Mechanism: String] = [
            .push: "Look for a heavy rounded stone with a clear path ahead.",
            .support: "Trace what rests on each support before removing one.",
            .fan: "Air needs a nearby surface to push. Look for a tall, light shape.",
            .release: "Look below the hanging weight. A slope can turn a drop into a nudge."
        ]
        return LevelDefinition(id: id, name: names[id - 1], district: (id - 1) / 5, kind: rescue ? .rescue : .demolition, story: rescue ? "The creek has cut the neighborhood in two. One clever move can bring our little rover home." : "The old landmark is ready to come down. The neighbors would prefer their lovely cottage stays exactly where it is.", hint: rescue && mechanism == .release ? "The suspended counterweight holds the bridge upright. Let it fall clear of the hinge." : hints[mechanism] ?? "Follow the connections.", objects: objects, choices: choices, targetIDs: targets, protectedIDs: rescue ? ["rover", "home"] : ["home"], rescueZone: rescue ? CGRect(x: 755 + shift, y: 95, width: 85, height: 100) : nil, creekWidth: rescue ? 220 + shift : 0, twoStars: rescue ? 3 : 5, threeStars: rescue ? 4 : 7)
    }

    static func validationIssues() -> [String] {
        var issues: [String] = []
        if levels.count != 20 || Set(levels.map(\.id)) != Set(1...20) { issues.append("Invalid level sequence") }
        for level in levels {
            let ids = Set(level.objects.map(\.id))
            if ids.count != level.objects.count { issues.append("Repeated object in level \(level.id)") }
            if Set(level.choices.map(\.id)).count != level.choices.count { issues.append("Repeated action in level \(level.id)") }
            if level.choices.count < 2 { issues.append("Missing choices in level \(level.id)") }
            for reference in level.targetIDs + level.protectedIDs + level.choices.map(\.objectID) + level.choices.flatMap(\.affectedIDs) {
                if !ids.contains(reference) { issues.append("Missing object \(reference) in level \(level.id)") }
            }
            if !Set(level.targetIDs).isDisjoint(with: Set(level.protectedIDs)) { issues.append("Conflicting goal in level \(level.id)") }
            if level.kind == .demolition && level.targetIDs.isEmpty { issues.append("Missing target in level \(level.id)") }
            if level.kind == .rescue && level.rescueZone == nil { issues.append("Missing safe area in level \(level.id)") }
            if level.twoStars < 2 || level.threeStars <= level.twoStars { issues.append("Invalid score in level \(level.id)") }
            if level.objects.contains(where: { $0.width <= 0 || $0.height <= 0 || $0.mass <= 0 || !(0...1).contains($0.restitution) }) { issues.append("Invalid physics in level \(level.id)") }
            for choice in level.choices {
                guard let object = level.objects.first(where: { $0.id == choice.objectID }) else { continue }
                let expected: [Mechanism: ObjectKind] = [.push: .stone, .support: .prop, .fan: .fan, .release: .weight]
                if expected[choice.mechanism] != object.kind { issues.append("Mismatched mechanism in level \(level.id)") }
                if choice.mechanism == .fan && choice.affectedIDs.isEmpty { issues.append("Airflow has no recipient in level \(level.id)") }
            }
            for first in level.objects.indices {
                for second in level.objects.indices where second > first {
                    if TownGeometry.overlap(level.objects[first], level.objects[second]) {
                        issues.append("Overlapping objects \(level.objects[first].id) and \(level.objects[second].id) in level \(level.id)")
                    }
                }
            }
            if level.kind == .rescue, let bridge = level.objects.first(where: { $0.kind == .bridge }), let zone = level.rescueZone {
                let base = TownGeometry.point(CGPoint(x: 0, y: -bridge.height / 2), in: bridge)
                if hypot(base.x - SimulationRules.hinge.x, base.y - SimulationRules.hinge.y) > 0.01 { issues.append("Misaligned hinge in level \(level.id)") }
                if bridge.height < level.creekWidth + 16 || zone.minX < SimulationRules.hinge.x + level.creekWidth { issues.append("Invalid crossing in level \(level.id)") }
                if zone.width < 56 || zone.height < 45 { issues.append("Safe area is too small in level \(level.id)") }
            }
        }
        return issues
    }
}
