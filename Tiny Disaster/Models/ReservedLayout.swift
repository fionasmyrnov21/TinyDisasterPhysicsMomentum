import CoreGraphics

struct ReservedLayout {
    static func largestRegion(in bounds: CGRect, excluding regions: [CGRect], padding: CGFloat = 8) -> CGRect {
        guard bounds.width > 0, bounds.height > 0, !bounds.isInfinite, !bounds.isNull else { return .zero }
        let blocked = regions.compactMap { region -> CGRect? in
            guard !region.isNull, !region.isInfinite else { return nil }
            let clipped = bounds.intersection(region.insetBy(dx: -padding, dy: -padding))
            return clipped.isNull || clipped.isEmpty ? nil : clipped
        }
        guard !blocked.isEmpty else { return bounds }
        let xs = Set([bounds.minX, bounds.maxX] + blocked.flatMap { [$0.minX, $0.maxX] }).sorted()
        let ys = Set([bounds.minY, bounds.maxY] + blocked.flatMap { [$0.minY, $0.maxY] }).sorted()
        var best = CGRect.zero
        for left in 0..<(xs.count - 1) {
            for right in (left + 1)..<xs.count {
                for top in 0..<(ys.count - 1) {
                    for bottom in (top + 1)..<ys.count {
                        let candidate = CGRect(x: xs[left], y: ys[top], width: xs[right] - xs[left], height: ys[bottom] - ys[top])
                        guard candidate.width * candidate.height > best.width * best.height else { continue }
                        guard !blocked.contains(where: { obstacle in
                            let overlap = candidate.intersection(obstacle)
                            return !overlap.isNull && overlap.width > 0 && overlap.height > 0
                        }) else { continue }
                        best = candidate
                    }
                }
            }
        }
        return best
    }
}
