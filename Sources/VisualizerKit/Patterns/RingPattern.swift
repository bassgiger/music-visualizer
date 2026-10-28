import SwiftUI

/// Strahlen rund um einen Ring in allen Farben: oben die Tiefen, unten die Höhen, links und
/// rechts spiegelbildlich; nach innen kurze Strahlen zur Mitte. Das Ganze dreht sich (schneller,
/// je lauter), die Farben wandern, der Ring atmet mit dem Bass.
final class RingPattern: PatternRenderer {
    private let spokeCount = 120

    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let unit = min(size.width, size.height)
        let bass = frame.bass
        let radius = unit * (0.17 + 0.04 * bass)
        let hueShift = frame.time * 0.04
        let rotation = frame.flow * 0.12

        // Leuchten hinter dem Ring
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: cyclicHue(hueShift + 0.5), saturation: 0.8, brightness: 0.6).opacity(0.2 + 0.4 * bass),
                    .clear,
                ]),
                center: center,
                startRadius: radius * 0.5,
                endRadius: unit * (0.55 + 0.25 * bass)
            )
        )

        context.blendMode = .plusLighter
        let spokeWidth = 2 * Double.pi * radius / Double(spokeCount) * 0.55
        let outerLength = unit * 0.3
        for i in 0..<spokeCount {
            let fraction = Double(i) / Double(spokeCount)
            let value = frame.band(aroundCircle: fraction)
            let angle = rotation + fraction * 2 * .pi - .pi / 2
            let direction = CGVector(dx: cos(angle), dy: sin(angle))
            let color = Color(hue: cyclicHue(hueShift + fraction), saturation: 0.85, brightness: 0.55 + 0.45 * value)

            let outer = spoke(from: center, direction, start: radius * 1.12,
                              end: radius * 1.12 + max(spokeWidth, value * outerLength))
            context.stroke(outer, with: .color(color.opacity(0.22)),
                           style: StrokeStyle(lineWidth: spokeWidth * 2.8, lineCap: .round))
            context.stroke(outer, with: .color(color), style: StrokeStyle(lineWidth: spokeWidth, lineCap: .round))

            let inner = spoke(from: center, direction, start: radius * 0.86, end: radius * (0.86 - 0.5 * value))
            context.stroke(inner, with: .color(color.opacity(0.6)),
                           style: StrokeStyle(lineWidth: spokeWidth * 0.6, lineCap: .round))
        }

        // Der Ring selbst: Regenbogen in denselben Farben wie die Strahlen daneben
        let rainbow = Gradient(colors: (0...6).map {
            Color(hue: cyclicHue(hueShift + Double($0) / 6), saturation: 0.8, brightness: 1)
        })
        let shading = GraphicsContext.Shading.conicGradient(rainbow, center: center, angle: .radians(rotation - .pi / 2))
        let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        var glow = context
        glow.opacity = 0.3
        glow.stroke(ring, with: shading, lineWidth: radius * (0.15 + 0.3 * bass))
        context.stroke(ring, with: shading, lineWidth: radius * (0.04 + 0.06 * bass))
    }

    private func spoke(from center: CGPoint, _ direction: CGVector, start: Double, end: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x + direction.dx * start, y: center.y + direction.dy * start))
        path.addLine(to: CGPoint(x: center.x + direction.dx * end, y: center.y + direction.dy * end))
        return path
    }
}
