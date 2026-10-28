import SwiftUI

/// Ringe wachsen aus der Mitte heran, jeder mit der Form des Spektrums im Moment seiner
/// Entstehung – wie ein Flug durch einen farbigen Tunnel. Je lauter, desto schneller; ein
/// Bassschlag gibt einen hellen, dicken Ring und einen Farbsprung. Die Mitte wandert, so
/// wirkt der Tunnel gekrümmt.
final class TunnelPattern: PatternRenderer {
    private struct Ring {
        /// Grösse, 1 = halbe Bilddiagonale
        var radius: Double
        /// Ausschlag je Ecke, 0…1
        var shape: [Double]
        var hue: Double
        var rotation: Double
        /// 1 normal, mehr bei einem Bassschlag
        var strength: Double
    }

    private let cornerCount = 144
    private var rings: [Ring] = []
    private var sinceRing: Double = 0
    /// Wächst bei jedem Schlag, damit die Farbe springt
    private var hueJump: Double = 0

    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        // Ringe wachsen exponentiell – das wirkt wie Perspektive
        let growth = exp(frame.deltaTime * (0.5 + 1.6 * frame.level))
        for i in rings.indices { rings[i].radius *= growth }
        rings.removeAll { $0.radius > 1.4 }

        sinceRing += frame.deltaTime
        if frame.beat { hueJump += 0.13 }
        if frame.beat || sinceRing >= 0.08 {
            sinceRing = 0
            rings.append(Ring(
                radius: 0.04,
                shape: (0..<cornerCount).map { frame.band(aroundCircle: Double($0) / Double(cornerCount)) },
                hue: cyclicHue(frame.time * 0.2 + hueJump),
                rotation: frame.flow * 0.2,
                strength: frame.beat ? 2.5 : 1
            ))
        }

        let halfDiagonal = hypot(size.width, size.height) / 2
        let drift = CGVector(dx: size.width * 0.12 * sin(frame.time * 0.31),
                             dy: size.height * 0.12 * sin(frame.time * 0.23 + 1))
        context.blendMode = .plusLighter
        for ring in rings {
            // Ferne (kleine) Ringe folgen der wandernden Mitte ganz, nahe kaum
            let nearness = min(ring.radius, 1)
            let center = CGPoint(x: size.width / 2 + drift.dx * (1 - nearness),
                                 y: size.height / 2 + drift.dy * (1 - nearness))
            let radius = ring.radius * halfDiagonal
            var path = Path()
            for corner in 0..<cornerCount {
                let angle = ring.rotation + Double(corner) / Double(cornerCount) * 2 * .pi
                let distance = radius * (1 + 0.5 * ring.shape[corner])
                let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()

            // Aus der Tiefe einblenden
            let fade = min(1, ring.radius / 0.15)
            let color = Color(hue: ring.hue, saturation: 0.8, brightness: 1)
            var glow = context
            glow.opacity = min(1, 0.15 * fade * ring.strength)
            glow.stroke(path, with: .color(color), lineWidth: radius * 0.06)
            var line = context
            line.opacity = min(1, 0.7 * fade * ring.strength)
            line.stroke(path, with: .color(color), lineWidth: max(1, radius * 0.012 * ring.strength))
        }
    }
}
