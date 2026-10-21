import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class GameScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    let level: LevelDefinition
    var onEvent: ((ChainEvent) -> Void)?
    var onFinish: ((AttemptResult) -> Void)?
    var onSelect: ((String) -> Void)?
    var reducedEffects = false
    private(set) var gate = AttemptGate()
    private var ledger = EventLedger()
    private var entities: [String: SKNode] = [:]
    private var definitions: [String: TownObject] = [:]
    private var damaged: Set<String> = []
    private var toppled: Set<String> = []
    private var clock = SimulationClock()
    private var stepDelta: TimeInterval = 0
    private var bridgeStableTime: TimeInterval = 0
    private var roverDeparted = false
    private var quietTime: TimeInterval = 0
    private var activeFan: ActionChoice?
    private var cameraRig = SKCameraNode()
    private var ready = false
    private var selectedID: String?
    private var rope: SKShapeNode?
    private var safeArrival = false

    init(level: LevelDefinition) {
        self.level = level
        super.init(size: CGSize(width: 1000, height: 600))
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.9, green: 0.93, blue: 0.86, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -7)
        physicsWorld.contactDelegate = self
        physicsWorld.speed = 0
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        prepareScene()
    }

    func prepareScene() {
        clock.suspend()
        guard !ready else { fitCamera(); return }
        ready = true
        addChild(TownArtwork.scenery(rescue: level.kind == .rescue, creekWidth: level.creekWidth))
        makeGround()
        for object in level.objects {
            let node = TownArtwork.object(object)
            entities[object.id] = node
            definitions[object.id] = object
            addChild(node)
            configureBody(node, object: object)
            if object.kind == .weight {
                let tether = TownArtwork.line(from: CGPoint(x: object.x, y: object.y + object.height / 2), to: CGPoint(x: object.x, y: 535), color: TownArtwork.ink.withAlphaComponent(0.5), width: 3)
                tether.zPosition = 12
                addChild(tether)
                rope = tether
                let bar = TownArtwork.shape(CGSize(width: 95, height: 12), color: TownArtwork.wood)
                bar.position = CGPoint(x: object.x, y: 535)
                addChild(bar)
            }
        }
        if let bridge = entities["bridge"]?.physicsBody, let ground = entities["groundLeft"]?.physicsBody {
            let pin = SKPhysicsJointPin.joint(withBodyA: ground, bodyB: bridge, anchor: SimulationRules.hinge)
            pin.frictionTorque = 0.02
            pin.shouldEnableLimits = true
            pin.lowerAngleLimit = -.pi / 2 - (entities["bridge"]?.zRotation ?? 0)
            pin.upperAngleLimit = -(entities["bridge"]?.zRotation ?? 0)
            physicsWorld.add(pin)
        }
        for (index, choice) in level.choices.enumerated() {
            guard let parent = entities[choice.objectID], let object = definitions[choice.objectID] else { continue }
            let badge = SKShapeNode(circleOfRadius: 16)
            badge.name = "choice:\(choice.id)"
            badge.fillColor = TownArtwork.cream
            badge.strokeColor = TownArtwork.ink
            badge.lineWidth = 2
            badge.position = CGPoint(x: 0, y: object.height / 2 + 29)
            badge.zPosition = 25
            let text = SKLabelNode(fontNamed: "AvenirNext-Bold")
            text.text = String(index + 1)
            text.fontSize = 17
            text.fontColor = TownArtwork.ink
            text.verticalAlignmentMode = .center
            badge.addChild(text)
            parent.addChild(badge)
        }
        if let zone = level.rescueZone {
            let post = TownArtwork.line(from: CGPoint(x: zone.midX, y: 100), to: CGPoint(x: zone.midX, y: 200), color: TownArtwork.ink, width: 3)
            post.zPosition = 9
            addChild(post)
            let flag = TownArtwork.polygon([CGPoint(x: zone.midX, y: 200), CGPoint(x: zone.midX + 43, y: 185), CGPoint(x: zone.midX, y: 170)], color: TownArtwork.coral)
            flag.zPosition = 10
            addChild(flag)
        }
        addChild(cameraRig)
        camera = cameraRig
        fitCamera()
        highlight(selectedID)
    }

    override func didChangeSize(_ oldSize: CGSize) { fitCamera() }

    private func fitCamera() {
        guard size.width > 0, size.height > 0 else { return }
        let scale = max(1040 / size.width, 560 / size.height)
        cameraRig.setScale(scale)
        cameraRig.position = CGPoint(x: 500, y: 295)
    }

    private func makeGround() {
        let pieces: [(String, CGRect)] = level.kind == .rescue ? [
            ("groundLeft", CGRect(x: -500, y: -100, width: 960, height: 200)),
            ("groundRight", CGRect(x: 460 + level.creekWidth, y: -100, width: 1000, height: 200))
        ] : [("groundLeft", CGRect(x: -500, y: -100, width: 2200, height: 200))]
        for (id, rect) in pieces {
            let node = SKNode()
            node.name = id
            node.position = CGPoint(x: rect.midX, y: rect.midY)
            node.physicsBody = SKPhysicsBody(rectangleOf: rect.size)
            node.physicsBody?.isDynamic = false
            node.physicsBody?.friction = 0.6
            node.physicsBody?.categoryBitMask = 1
            addChild(node)
            entities[id] = node
        }
    }

    private func configureBody(_ node: SKNode, object: TownObject) {
        let body: SKPhysicsBody
        if object.kind == .stone {
            body = SKPhysicsBody(circleOfRadius: object.width * 0.47)
        } else if object.kind == .bridge {
            let path = CGMutablePath()
            path.addLines(between: [
                CGPoint(x: 0, y: -object.height / 2),
                CGPoint(x: -8, y: -object.height / 2 + 22),
                CGPoint(x: -8, y: object.height / 2),
                CGPoint(x: 8, y: object.height / 2),
                CGPoint(x: 8, y: -object.height / 2 + 22)
            ])
            path.closeSubpath()
            body = SKPhysicsBody(polygonFrom: path)
        } else if object.kind == .rover {
            let chassis = SKPhysicsBody(rectangleOf: CGSize(width: 49, height: 19), center: CGPoint(x: 0, y: 3))
            let front = SKPhysicsBody(circleOfRadius: 11, center: CGPoint(x: 17, y: -8))
            let rear = SKPhysicsBody(circleOfRadius: 11, center: CGPoint(x: -17, y: -8))
            body = SKPhysicsBody(bodies: [chassis, front, rear])
        } else {
            body = SKPhysicsBody(rectangleOf: object.size)
        }
        body.isDynamic = object.dynamic
        body.mass = object.mass
        body.friction = object.kind == .rover ? 0.05 : object.kind == .stone ? 0.35 : object.kind == .weight ? 0.18 : 0.55
        body.restitution = object.restitution
        body.linearDamping = object.kind == .stone ? 0.12 : 0.35
        body.angularDamping = 0.45
        body.allowsRotation = object.kind != .rover
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = 2
        body.collisionBitMask = UInt32.max
        body.contactTestBitMask = UInt32.max
        node.physicsBody = body
    }

    func highlight(_ choiceID: String?) {
        selectedID = choiceID
        for choice in level.choices {
            guard let badge = entities[choice.objectID]?.childNode(withName: "choice:\(choice.id)") as? SKShapeNode else { continue }
            let selected = choice.id == choiceID
            badge.fillColor = selected ? TownArtwork.coral : TownArtwork.cream
            (badge.children.first as? SKLabelNode)?.fontColor = selected ? .white : TownArtwork.ink
        }
    }

    @discardableResult
    func perform(_ proposed: ActionChoice) -> Bool {
        guard ready, !isPaused, let choice = level.choices.first(where: { $0.id == proposed.id }),
              let node = entities[choice.objectID], gate.begin() else { return false }
        for candidate in level.choices { entities[candidate.objectID]?.childNode(withName: "choice:\(candidate.id)")?.isHidden = true }
        physicsWorld.speed = 1
        switch choice.mechanism {
        case .push:
            if let body = node.physicsBody {
                body.isDynamic = true
                let speed = SimulationRules.pushSpeed
                body.applyImpulse(CGVector(dx: body.mass * speed, dy: 0))
                let radius = max(1, (definitions[choice.objectID]?.width ?? 2) * 0.47)
                body.angularVelocity = -speed / radius
            }
        case .support:
            node.removeFromParent()
            entities.removeValue(forKey: choice.objectID)
        case .fan:
            activeFan = choice
            if !reducedEffects, let rotor = node.childNode(withName: "rotor") {
                rotor.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.65)))
            }
        case .release:
            node.physicsBody?.isDynamic = true
            rope?.removeFromParent()
        }
        record(id: "action", title: choice.title, symbol: choice.mechanism.symbol)
        return true
    }

    func pauseSimulation() {
        gate.pause()
        physicsWorld.speed = 0
        isPaused = true
        clock.suspend()
    }

    func resumeSimulation() {
        gate.resume()
        isPaused = false
        physicsWorld.speed = gate.phase == .running ? 1 : 0
        clock.suspend()
    }

    #if canImport(UIKit)
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gate.phase == .planning, let location = touches.first?.location(in: self) else { return }
        for hit in nodes(at: location) {
            var current: SKNode? = hit
            while let node = current {
                if let name = node.name, name.hasPrefix("choice:") {
                    onSelect?(String(name.dropFirst(7)))
                    return
                }
                if let choice = level.choices.first(where: { $0.objectID == node.name }) {
                    onSelect?(choice.id)
                    return
                }
                current = node.parent
            }
        }
        let nearest = level.choices.min { left, right in
            guard let a = entities[left.objectID], let b = entities[right.objectID] else { return false }
            return hypot(a.position.x - location.x, a.position.y - location.y) < hypot(b.position.x - location.x, b.position.y - location.y)
        }
        if let nearest, let node = entities[nearest.objectID], hypot(node.position.x - location.x, node.position.y - location.y) < 95 { onSelect?(nearest.id) }
    }

    #endif

    func didBegin(_ contact: SKPhysicsContact) {
        guard gate.phase == .running else { return }
        for pair in [(contact.bodyA, contact.bodyB), (contact.bodyB, contact.bodyA)] {
            guard let id = pair.0.node?.name, level.protectedIDs.contains(id), let other = pair.1.node?.name, definitions[other] != nil else { continue }
            let falling = pair.1.velocity.dy < -145
            let inverseMass = (pair.0.isDynamic ? 1 / pair.0.mass : 0) + (pair.1.isDynamic ? 1 / pair.1.mass : 0)
            let effectiveMass = inverseMass > 0 ? 1 / inverseMass : 1
            let impactSpeed = contact.collisionImpulse / effectiveMass
            let severe = id == "rover" ? impactSpeed > 220 : contact.collisionImpulse > 7
            if severe || (id == "rover" && falling && pair.1.mass > 1.5) { damage(id) }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard gate.phase == .running else { clock.suspend(); return }
        stepDelta = clock.advance(to: currentTime)
        if let fan = activeFan, clock.elapsed < 3.2 {
            for id in fan.affectedIDs {
                if let node = entities[id], let body = node.physicsBody, let source = entities[fan.objectID], node.position.x > source.position.x, node.position.x < source.position.x + 340, abs(node.position.y - source.position.y) < 220 {
                    body.applyForce(CGVector(dx: (level.kind == .rescue ? 4 : 2.3) * SimulationRules.forceScale, dy: 0), at: CGPoint(x: node.position.x, y: node.position.y + 50))
                }
            }
        }
        if level.kind == .rescue, roverDeparted, let rover = entities["rover"], let body = rover.physicsBody, !safeArrival {
            if rover.position.y >= 90 && body.velocity.dx < 88 { body.applyForce(CGVector(dx: 10 * SimulationRules.forceScale, dy: 0)) }
        }
    }

    override func didSimulatePhysics() {
        guard gate.phase == .running else { return }
        if let bridge = entities["bridge"], let definition = definitions["bridge"], let body = bridge.physicsBody {
            let readyToCross = SimulationRules.crossingReady(center: bridge.position, height: definition.height, angle: bridge.zRotation, angularSpeed: body.angularVelocity, creekWidth: level.creekWidth)
            bridgeStableTime = readyToCross ? bridgeStableTime + stepDelta : 0
            if bridgeStableTime >= 0.4 {
                roverDeparted = true
                record(id: "bridge:lowered", title: "A bridge across the creek", symbol: "point.topleft.down.to.point.bottomright.curvepath")
            }
        }
        if level.kind == .rescue, let rover = entities["rover"], let zone = level.rescueZone,
           roverDeparted, damaged.isEmpty, SimulationRules.roverArrived(center: rover.position, zone: zone) {
            safeArrival = true
            rover.physicsBody?.velocity = .zero
            record(id: "rescue:rover", title: "Rover reached the safe bank", symbol: "checkmark.shield.fill")
        }
        var moving = false
        for (id, node) in entities {
            guard let definition = definitions[id], let body = node.physicsBody, body.isDynamic else { continue }
            let distance = hypot(node.position.x - definition.x, node.position.y - definition.y)
            let turned = abs(node.zRotation - definition.angle)
            if (distance > 28 || turned > 0.42), !toppled.contains(id), definition.kind != .rover, definition.kind != .bridge {
                toppled.insert(id)
                if level.targetIDs.contains(id) {
                    record(id: "topple:\(id)", title: "Tower section came down", symbol: "building.2.fill")
                } else if definition.kind == .plank {
                    record(id: "topple:\(id)", title: "Timber set in motion", symbol: "rectangle.portrait.on.rectangle.portrait")
                } else if definition.kind == .stone || definition.kind == .weight {
                    record(id: "topple:\(id)", title: "Momentum passed along", symbol: "arrow.right.circle")
                }
            }
            if level.protectedIDs.contains(id), node.position.y < 65 { damage(id) }
            if abs(body.velocity.dx) + abs(body.velocity.dy) > 5 || abs(body.angularVelocity) > 0.1 { moving = true }
            if node.position.y < -500 || node.position.x > 1800 || node.position.x < -700 {
                body.isDynamic = false
                node.isHidden = true
            }
        }
        quietTime = moving ? 0 : quietTime + stepDelta
        if !damaged.isEmpty || safeArrival || clock.elapsed >= 20 || (level.kind == .demolition && clock.elapsed > 3.5 && quietTime > 1.4) {
            finish()
        } else if level.kind == .rescue && clock.elapsed > 5 && quietTime > 2 && (!roverDeparted || damaged.contains("rover")) {
            finish()
        }
    }

    private func damage(_ id: String) {
        guard damaged.insert(id).inserted else { return }
        entities[id]?.alpha = 0.5
        record(id: "damage:\(id)", title: id == "rover" ? "Rover needs a safer route" : "The cottage was damaged", symbol: "exclamationmark.shield")
    }

    private func record(id: String, title: String, symbol: String) {
        let event = ChainEvent(id: id, title: title, symbol: symbol)
        if ledger.record(event) { onEvent?(event) }
    }

    private func finish() {
        guard gate.phase == .running else { return }
        let success = SimulationRules.missionReached(level: level, toppled: toppled, safeArrival: safeArrival, damaged: damaged)
        if success {
            record(id: "protected", title: "The neighborhood stayed safe", symbol: "checkmark.shield")
        }
        gate.finish()
        physicsWorld.speed = 0
        removeAllActions()
        for node in entities.values { node.enumerateChildNodes(withName: "rotor") { rotor, _ in rotor.removeAllActions() } }
        let reason = !damaged.isEmpty ? "A protected neighbor was hurt. Try a gentler chain." : success ? "One thoughtful move made all the difference." : level.kind == .rescue ? "The rover still needs a clear crossing. Try a different connection." : "Part of the old tower is still standing. Trace a longer chain."
        let result = AttemptResult(levelID: level.id, succeeded: success, events: ledger.events, stars: Scoring.stars(success: success, events: ledger.events.count, level: level), reason: reason)
        onFinish?(result)
    }
}
