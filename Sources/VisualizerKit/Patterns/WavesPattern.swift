import SwiftUI

/// Leuchtende Wellenbänder quer über das Bild, je eines für einen Tonbereich (vom Bass bis zu
/// den Höhen). Sie fliessen schneller, je lauter die Musik ist, laufen zu den Rändern hin aus
/// und wechseln langsam die Farbe; wo sie sich kreuzen, mischen sich die Farben.
final class WavesPattern: PatternRenderer {
    private let waveCount = 6
    private let steps = 160

    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        let middle = size.height / 2
        let start = CGPoint(x: 0, y: middle)
        let end = CGPoint(x: size.width, y: middle)
        context.blendMode = .plusLighter

        for wave in 0..<waveCount {
            let part = Double(wave) / Double(waveCount)
            let strength = frame.average(from: part * 0.85, to: (part + 1 / Double(waveCount)) * 0.85)
            let breathing = 0.8 + 0.2 * sin(frame.time * 0.6 + Double(wave) * 1.3)
            let amplitude = size.height * (0.03 + 0.38 * strength) * breathing
            let cycles = 1.1 + 0.45 * Double(wave)
            // Benachbarte Wellen fliessen gegeneinander
            let direction: Double = wave.isMultiple(of: 2) ? 1 : -1
            let phase = frame.flow * (0.9 + 0.35 * Double(wave)) * direction + Double(wave) * 1.7
            let hue = cyclicHue(frame.time * 0.05 + part * 0.8)

            // Zwei Kurven, leicht gegeneinander verschoben, spannen ein Band auf, das sich verdreht
            var edge: [CGPoint] = []
            var otherEdge: [CGPoint] = []
            for step in 0...steps {
                let u = Double(step) / Double(steps)
                // Zu den Rändern hin ausklingen lassen
                let envelope = pow(sin(.pi * u), 1.5)
                let angle = 2 * .pi * cycles * u + phase
                edge.append(CGPoint(x: u * size.width, y: middle + amplitude * envelope * sin(angle)))
                otherEdge.append(CGPoint(x: u * size.width, y: middle + amplitude * 0.75 * envelope * sin(angle + 0.6)))
            }
            var curve = Path()
            curve.addLines(edge)
            var otherCurve = Path()
            otherCurve.addLines(otherEdge)
            var ribbon = Path()
            ribbon.addLines(edge + otherEdge.reversed())
            ribbon.closeSubpath()

            let gradient = Gradient(colors: [0, 0.12, 0.24].map {
                Color(hue: cyclicHue(hue + $0), saturation: 0.85, brightness: 1)
            })
            let shading = GraphicsContext.Shading.linearGradient(gradient, startPoint: start, endPoint: end)
            var fill = context
            fill.opacity = 0.2 + 0.25 * strength
            fill.fill(ribbon, with: shading)
            var glow = context
            glow.opacity = 0.25
            glow.stroke(curve, with: shading, lineWidth: 10 + 14 * strength)
            context.stroke(curve, with: shading, lineWidth: 2 + 3 * strength)
            var thin = context
            thin.opacity = 0.6
            thin.stroke(otherCurve, with: shading, lineWidth: 1 + strength)
        }
    }
}
