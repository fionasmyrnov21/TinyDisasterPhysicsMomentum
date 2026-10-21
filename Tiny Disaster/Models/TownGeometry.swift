import CoreGraphics
import Foundation

struct TownGeometry {
    static func point(_ local: CGPoint, in object: TownObject) -> CGPoint {
        CGPoint(x: object.x + local.x * cos(object.angle) - local.y * sin(object.angle),
                y: object.y + local.x * sin(object.angle) + local.y * cos(object.angle))
    }

    static func corners(_ object: TownObject) -> [CGPoint] {
        let w = object.kind == .stone ? object.width * 0.47 : object.width / 2
        let h = object.kind == .stone ? object.width * 0.47 : object.height / 2
        return [CGPoint(x: -w, y: -h), CGPoint(x: w, y: -h), CGPoint(x: w, y: h), CGPoint(x: -w, y: h)].map { point($0, in: object) }
    }

    static func overlap(_ first: TownObject, _ second: TownObject) -> Bool {
        let a = corners(first)
        let b = corners(second)
        for polygon in [a, b] {
            for index in 0..<4 {
                let next = polygon[(index + 1) % 4]
                let current = polygon[index]
                let length = hypot(next.x - current.x, next.y - current.y)
                guard length > 0 else { return true }
                let axis = CGPoint(x: (current.y - next.y) / length, y: (next.x - current.x) / length)
                let pa = a.map { $0.x * axis.x + $0.y * axis.y }
                let pb = b.map { $0.x * axis.x + $0.y * axis.y }
                if pa.max()! <= pb.min()! + 0.5 || pb.max()! <= pa.min()! + 0.5 { return false }
            }
        }
        return true
    }
}
