import SpriteKit
import Foundation

@MainActor
struct TownArtwork {
    static let ink = SKColor(red: 0.16, green: 0.24, blue: 0.23, alpha: 1)
    static let grass = SKColor(red: 0.64, green: 0.73, blue: 0.52, alpha: 1)
    static let wood = SKColor(red: 0.68, green: 0.43, blue: 0.28, alpha: 1)
    static let coral = SKColor(red: 0.81, green: 0.40, blue: 0.30, alpha: 1)
    static let cream = SKColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1)

    static func shape(_ size: CGSize, color: SKColor, radius: CGFloat = 3) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.fillColor = color
        node.strokeColor = ink.withAlphaComponent(0.2)
        node.lineWidth = 1.5
        return node
    }

    static func polygon(_ points: [CGPoint], color: SKColor) -> SKShapeNode {
        let path = CGMutablePath()
        if let first = points.first {
            path.move(to: first)
            for p in points.dropFirst() { path.addLine(to: p) }
            path.closeSubpath()
        }
        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = ink.withAlphaComponent(0.22)
        node.lineWidth = 1
        return node
    }

    static func line(from: CGPoint, to: CGPoint, color: SKColor, width: CGFloat = 2) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.lineWidth = width
        return node
    }

    static func object(_ object: TownObject) -> SKNode {
        let node = SKNode()
        let w = CGFloat(object.width)
        let h = CGFloat(object.height)
        switch object.kind {
        case .stone:
            let points = (0..<9).map { index -> CGPoint in
                let angle = CGFloat(index) * .pi * 2 / 9
                let factor: CGFloat = index % 2 == 0 ? 0.94 : 1
                return CGPoint(x: cos(angle) * w / 2 * factor, y: sin(angle) * h / 2 * factor)
            }
            node.addChild(polygon(points, color: SKColor(red: 0.57, green: 0.63, blue: 0.62, alpha: 1)))
            node.addChild(line(from: CGPoint(x: -w * 0.2, y: h * 0.2), to: CGPoint(x: w * 0.2, y: h * 0.3), color: .white.withAlphaComponent(0.35), width: 4))
        case .cottage:
            node.addChild(shape(CGSize(width: w, height: h * 0.73), color: cream))
            let side = polygon([CGPoint(x: w / 2, y: -h * 0.36), CGPoint(x: w / 2 + 14, y: -h * 0.26), CGPoint(x: w / 2 + 14, y: h * 0.38), CGPoint(x: w / 2, y: h * 0.27)], color: SKColor(red: 0.79, green: 0.74, blue: 0.60, alpha: 1))
            node.addChild(side)
            let roof = polygon([CGPoint(x: -w * 0.6, y: h * 0.28), CGPoint(x: 0, y: h * 0.65), CGPoint(x: w * 0.6, y: h * 0.28)], color: coral)
            node.addChild(roof)
            let door = shape(CGSize(width: w * 0.2, height: h * 0.37), color: wood)
            door.position = CGPoint(x: 9, y: -h * 0.17)
            node.addChild(door)
            for x in [-w * 0.28, w * 0.31] {
                let window = shape(CGSize(width: w * 0.17, height: h * 0.19), color: SKColor(red: 0.53, green: 0.73, blue: 0.74, alpha: 1), radius: 1)
                window.position = CGPoint(x: x, y: h * 0.05)
                node.addChild(window)
                let cross = line(from: CGPoint(x: x, y: -h * 0.04), to: CGPoint(x: x, y: h * 0.14), color: cream, width: 2)
                node.addChild(cross)
            }
        case .tower:
            let face = shape(object.size, color: SKColor(red: 0.79 - Double(object.tint) * 0.035, green: 0.66 - Double(object.tint) * 0.025, blue: 0.49, alpha: 1), radius: 2)
            node.addChild(face)
            node.addChild(polygon([CGPoint(x: w / 2, y: -h / 2), CGPoint(x: w / 2 + 9, y: -h / 2 + 7), CGPoint(x: w / 2 + 9, y: h / 2 + 7), CGPoint(x: w / 2, y: h / 2)], color: wood))
            for y in [-h / 4, h / 4] {
                node.addChild(line(from: CGPoint(x: -w / 2 + 2, y: y), to: CGPoint(x: w / 2 - 2, y: y), color: cream.withAlphaComponent(0.6)))
            }
            let window = shape(CGSize(width: 15, height: 23), color: ink.withAlphaComponent(0.7), radius: 6)
            window.position.y = 3
            node.addChild(window)
        case .plank, .prop, .bridge, .ramp:
            let base = shape(object.size, color: object.kind == .prop ? coral : wood, radius: 2)
            node.addChild(base)
            if h > w {
                for y in stride(from: -h / 2 + 15, to: h / 2, by: 23) {
                    node.addChild(line(from: CGPoint(x: -w / 2 + 3, y: y), to: CGPoint(x: w / 2 - 3, y: y), color: cream.withAlphaComponent(0.45), width: 2))
                }
            } else {
                node.addChild(line(from: CGPoint(x: -w / 2 + 7, y: 0), to: CGPoint(x: w / 2 - 7, y: 0), color: cream.withAlphaComponent(0.45), width: 2))
            }
        case .weight:
            node.addChild(shape(object.size, color: ink, radius: 8))
            let stripe = shape(CGSize(width: w * 0.75, height: 10), color: SKColor(red: 0.92, green: 0.68, blue: 0.29, alpha: 1), radius: 1)
            node.addChild(stripe)
            let loop = SKShapeNode(circleOfRadius: 9)
            loop.position.y = h / 2 + 5
            loop.strokeColor = ink
            loop.lineWidth = 5
            node.addChild(loop)
        case .fan:
            let stand = shape(CGSize(width: 11, height: h * 0.65), color: ink)
            stand.position.y = -h * 0.2
            node.addChild(stand)
            let foot = shape(CGSize(width: w * 0.65, height: 10), color: ink)
            foot.position.y = -h / 2
            node.addChild(foot)
            let housing = SKShapeNode(circleOfRadius: w * 0.48)
            housing.fillColor = cream
            housing.strokeColor = ink
            housing.lineWidth = 4
            housing.position.y = h * 0.18
            node.addChild(housing)
            let rotor = SKNode()
            rotor.name = "rotor"
            rotor.position.y = h * 0.18
            for i in 0..<3 {
                let blade = shape(CGSize(width: 10, height: w * 0.29), color: grass, radius: 5)
                let angle = CGFloat(i) * .pi * 2 / 3
                blade.position = CGPoint(x: sin(angle) * 10, y: cos(angle) * 10)
                blade.zRotation = -angle
                rotor.addChild(blade)
            }
            node.addChild(rotor)
        case .rover:
            let body = shape(CGSize(width: w, height: h * 0.7), color: coral, radius: 6)
            body.position.y = 2
            node.addChild(body)
            let cabin = shape(CGSize(width: w * 0.5, height: h * 0.65), color: cream, radius: 5)
            cabin.position = CGPoint(x: 3, y: h * 0.4)
            node.addChild(cabin)
            let glass = shape(CGSize(width: w * 0.35, height: h * 0.35), color: SKColor(red: 0.57, green: 0.76, blue: 0.76, alpha: 1))
            glass.position = cabin.position
            node.addChild(glass)
            for x in [-w * 0.3, w * 0.3] {
                let wheel = SKShapeNode(circleOfRadius: 10)
                wheel.fillColor = ink
                wheel.strokeColor = cream
                wheel.lineWidth = 3
                wheel.position = CGPoint(x: x, y: -h * 0.26)
                node.addChild(wheel)
            }
        }
        node.name = object.id
        node.position = object.position
        node.zRotation = object.angle
        node.zPosition = 15
        return node
    }

    static func tree(at position: CGPoint, scale: CGFloat = 1) -> SKNode {
        let node = SKNode()
        let trunk = shape(CGSize(width: 10, height: 42), color: wood)
        trunk.position.y = 15
        node.addChild(trunk)
        for item in [(CGFloat(-12), CGFloat(50), CGFloat(23)), (15, 49, 22), (0, 69, 25)] {
            let crown = SKShapeNode(circleOfRadius: item.2)
            crown.fillColor = SKColor(red: 0.37 + Double(item.0) / 150, green: 0.55, blue: 0.39, alpha: 1)
            crown.strokeColor = .clear
            crown.position = CGPoint(x: item.0, y: item.1)
            node.addChild(crown)
        }
        node.position = position
        node.setScale(scale)
        node.zPosition = 3
        return node
    }

    static func scenery(rescue: Bool, creekWidth: Double) -> SKNode {
        let root = SKNode()
        let hill = SKShapeNode(ellipseOf: CGSize(width: 1800, height: 500))
        hill.fillColor = SKColor(red: 0.82, green: 0.86, blue: 0.73, alpha: 1)
        hill.strokeColor = .clear
        hill.position = CGPoint(x: 500, y: 0)
        hill.zPosition = -5
        root.addChild(hill)
        let land = shape(CGSize(width: 1600, height: 130), color: grass)
        land.position = CGPoint(x: 500, y: 30)
        land.zPosition = -2
        root.addChild(land)
        let road = shape(CGSize(width: 1500, height: 26), color: SKColor(red: 0.86, green: 0.81, blue: 0.68, alpha: 1))
        road.position = CGPoint(x: 500, y: 105)
        road.zPosition = 0
        root.addChild(road)
        if rescue {
            let creek = shape(CGSize(width: creekWidth, height: 180), color: SKColor(red: 0.52, green: 0.73, blue: 0.77, alpha: 1))
            creek.position = CGPoint(x: 460 + creekWidth / 2, y: 23)
            creek.zPosition = 1
            root.addChild(creek)
            for index in 0..<6 {
                let ripple = line(from: CGPoint(x: 480 + index * 12, y: 18 + index * 12), to: CGPoint(x: 555 + index * 12, y: 18 + index * 12), color: cream.withAlphaComponent(0.5), width: 3)
                ripple.zPosition = 2
                root.addChild(ripple)
            }
        }
        for index in 0..<9 {
            let x = CGFloat(index) * 130 - 30
            root.addChild(tree(at: CGPoint(x: x, y: 132), scale: index % 2 == 0 ? 0.8 : 0.55))
        }
        for index in 0..<5 {
            let cottage = TownObject(id: "backdrop\(index)", kind: .cottage, x: Double(70 + index * 210), y: 187, width: 65, height: 65, tint: index)
            let house = object(cottage)
            house.alpha = 0.36
            house.zPosition = 1
            root.addChild(house)
        }
        for index in 0..<4 {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: 100 + index * 9, height: 24))
            cloud.fillColor = .white.withAlphaComponent(0.55)
            cloud.strokeColor = .clear
            cloud.position = CGPoint(x: 70 + index * 270, y: 440 + (index % 2) * 55)
            cloud.zPosition = -10
            root.addChild(cloud)
        }
        return root
    }
}
