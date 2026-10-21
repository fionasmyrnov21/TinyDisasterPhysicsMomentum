import SwiftUI

extension Color {
    static let townInk = Color(red: 0.17, green: 0.25, blue: 0.23)
    static let townMuted = Color(red: 0.43, green: 0.49, blue: 0.43)
    static let townPaper = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let townCream = Color(red: 0.94, green: 0.92, blue: 0.86)
    static let townCoral = Color(red: 0.76, green: 0.34, blue: 0.24)
    static let townMoss = Color(red: 0.39, green: 0.49, blue: 0.32)
    static let townGold = Color(red: 0.79, green: 0.55, blue: 0.19)
}

struct PaperBackground: View {
    var body: some View {
        Color.townPaper.ignoresSafeArea()
    }
}

struct TownButtonStyle: ButtonStyle {
    var secondary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 16)
            .foregroundStyle(secondary ? Color.townInk : .white)
            .background(secondary ? Color.townCream : Color.townInk, in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .monospaced, weight: .semibold))
            .tracking(2)
            .foregroundStyle(Color.townMuted)
    }
}

struct StarsView: View {
    let count: Int
    var size: CGFloat = 15
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(index < count ? Color.townGold : Color.townMuted.opacity(0.3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 stars")
    }
}

struct SmallTag: View {
    let title: String
    let symbol: String
    var tint: Color = .townMoss

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(tint.opacity(0.09), in: Capsule())
    }
}

struct PaperCard<Content: View>: View {
    var color: Color = .white.opacity(0.7)
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.townInk.opacity(0.06), lineWidth: 1))
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(Color.townInk)
            Text(detail).font(.subheadline).foregroundStyle(Color.townMuted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TownPostcard: View {
    var rescue = false
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 400
            let sy = size.height / 280
            context.scaleBy(x: sx, y: sy)
            let ink = Color.townInk
            func polygon(_ points: [CGPoint], _ fill: Color) {
                var path = Path()
                path.addLines(points)
                path.closeSubpath()
                context.fill(path, with: .color(fill))
            }
            func ellipse(_ rect: CGRect, _ fill: Color) {
                context.fill(Path(ellipseIn: rect), with: .color(fill))
            }
            func box(_ rect: CGRect, _ fill: Color, radius: CGFloat = 3) {
                context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(fill))
            }
            func tree(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat) {
                box(CGRect(x: x - 3, y: y - 20 * scale, width: 6, height: 25 * scale), Color(red: 0.54, green: 0.36, blue: 0.24))
                ellipse(CGRect(x: x - 19 * scale, y: y - 65 * scale, width: 38 * scale, height: 49 * scale), Color(red: 0.42, green: 0.57, blue: 0.35))
                ellipse(CGRect(x: x - 9 * scale, y: y - 62 * scale, width: 24 * scale, height: 35 * scale), Color(red: 0.53, green: 0.65, blue: 0.40))
            }
            func house(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ tint: Color) {
                polygon([CGPoint(x: x, y: y), CGPoint(x: x + width, y: y + 16), CGPoint(x: x + width, y: y - height + 16), CGPoint(x: x, y: y - height)], Color(red: 0.94, green: 0.88, blue: 0.71))
                polygon([CGPoint(x: x + width, y: y + 16), CGPoint(x: x + width + 25, y: y + 1), CGPoint(x: x + width + 25, y: y - height + 1), CGPoint(x: x + width, y: y - height + 16)], Color(red: 0.77, green: 0.71, blue: 0.54))
                polygon([CGPoint(x: x - 7, y: y - height), CGPoint(x: x + width / 2, y: y - height - 28), CGPoint(x: x + width + 8, y: y - height + 16), CGPoint(x: x + width / 2 + 25, y: y - height - 12)], tint)
                polygon([CGPoint(x: x + width / 2, y: y - height - 28), CGPoint(x: x + width / 2 + 25, y: y - height - 43), CGPoint(x: x + width + 32, y: y - height + 1), CGPoint(x: x + width + 8, y: y - height + 16)], tint.opacity(0.8))
                for offset: CGFloat in [12, width - 21] {
                    box(CGRect(x: x + offset, y: y - height + 20 + offset * 0.18, width: 10, height: 15), Color(red: 0.39, green: 0.58, blue: 0.59), radius: 1)
                }
                box(CGRect(x: x + width / 2 - 6, y: y - 22 + width * 0.12, width: 13, height: 27), Color(red: 0.53, green: 0.37, blue: 0.26), radius: 2)
            }
            ellipse(CGRect(x: 35, y: 180, width: 345, height: 75), ink.opacity(0.07))
            polygon([CGPoint(x: 28, y: 165), CGPoint(x: 226, y: 74), CGPoint(x: 382, y: 159), CGPoint(x: 183, y: 258)], Color(red: 0.59, green: 0.69, blue: 0.44))
            polygon([CGPoint(x: 28, y: 165), CGPoint(x: 183, y: 258), CGPoint(x: 183, y: 270), CGPoint(x: 28, y: 177)], Color(red: 0.49, green: 0.40, blue: 0.28))
            polygon([CGPoint(x: 183, y: 258), CGPoint(x: 382, y: 159), CGPoint(x: 382, y: 171), CGPoint(x: 183, y: 270)], Color(red: 0.58, green: 0.48, blue: 0.32))
            polygon([CGPoint(x: 66, y: 182), CGPoint(x: 260, y: 90), CGPoint(x: 281, y: 103), CGPoint(x: 88, y: 195)], Color(red: 0.86, green: 0.80, blue: 0.64))
            polygon([CGPoint(x: 113, y: 124), CGPoint(x: 130, y: 116), CGPoint(x: 311, y: 204), CGPoint(x: 293, y: 212)], rescue ? Color(red: 0.48, green: 0.71, blue: 0.75) : Color(red: 0.85, green: 0.79, blue: 0.62))
            tree(230, 104, 0.7)
            house(155, 131, 46, 45, .townCoral)
            tree(301, 154, 0.85)
            house(269, 180, 43, 40, Color(red: 0.42, green: 0.53, blue: 0.44))
            house(102, 201, 52, 52, .townCoral)
            let towerX: CGFloat = 211
            box(CGRect(x: towerX, y: 116, width: 29, height: 82), Color(red: 0.79, green: 0.67, blue: 0.48))
            polygon([CGPoint(x: towerX + 29, y: 116), CGPoint(x: towerX + 43, y: 108), CGPoint(x: towerX + 43, y: 190), CGPoint(x: towerX + 29, y: 198)], Color(red: 0.62, green: 0.50, blue: 0.34))
            polygon([CGPoint(x: towerX - 4, y: 116), CGPoint(x: towerX + 15, y: 94), CGPoint(x: towerX + 35, y: 116)], Color.townCoral)
            for y: CGFloat in [128, 152, 176] {
                box(CGRect(x: towerX + 10, y: y, width: 8, height: 12), ink.opacity(0.6))
            }
            tree(73, 155, 0.78)
            tree(337, 188, 0.75)
            tree(182, 244, 0.65)
            ellipse(CGRect(x: 72, y: 199, width: 23, height: 16), Color(red: 0.49, green: 0.57, blue: 0.55))
            ellipse(CGRect(x: 76, y: 198, width: 16, height: 10), Color(red: 0.64, green: 0.69, blue: 0.65))
            box(CGRect(x: 251, y: 129, width: 24, height: 12), .townCoral, radius: 4)
            box(CGRect(x: 256, y: 124, width: 13, height: 9), .townCream)
            for x: CGFloat in [255, 270] { ellipse(CGRect(x: x, y: 137, width: 6, height: 6), ink) }
            var trail = Path()
            trail.move(to: CGPoint(x: 83, y: 220))
            trail.addCurve(to: CGPoint(x: 240, y: 211), control1: CGPoint(x: 118, y: 266), control2: CGPoint(x: 212, y: 253))
            context.stroke(trail, with: .color(Color.townCoral.opacity(0.7)), style: StrokeStyle(lineWidth: 1.7, dash: [4, 5]))
            ellipse(CGRect(x: 235, y: 206, width: 7, height: 7), .townCoral)
        }
        .accessibilityLabel("A miniature neighborhood with cottages, trees, an old tower, and a tiny rover")
        .accessibilityHidden(true)
    }
}
