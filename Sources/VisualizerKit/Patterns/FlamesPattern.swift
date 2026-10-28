import SwiftUI

/// Ein Lagerfeuer am unteren Rand, das im Stil der Musik brennt: in der Mitte lodert der Bass,
/// nach aussen die Höhen; Lautstärke und Schläge lassen es auflodern, Glut steigt auf. Die Farbe
/// richtet sich nach dem Klang – basslastige, dunkle Musik brennt rot-orange, helle über
/// Magenta und Violett bis blau.
final class FlamesPattern: PatternRenderer {
    private struct Ember {
        var position: CGPoint
        var speed: Double
        /// Für das Hin- und Herschweben, je Glutstück verschieden
        var seed: Double
        var life: Double
        var lifetime: Double
        var size: Double
    }

    /// Eine Schicht der Flammenzungen: aussen gross und farbig, innen klein und hell
    private struct Layer {
        var height: Double
        var width: Double
        var hueOffset: Double
        var saturation: Double
        var opacity: Double
    }

    private let tongueCount = 28
    private let layers = [
        Layer(height: 1, width: 1, hueOffset: 0, saturation: 0.95, opacity: 0.45),
        Layer(height: 0.72, width: 0.6, hueOffset: 0.05, saturation: 0.9, opacity: 0.45),
        Layer(height: 0.42, width: 0.28, hueOffset: 0.12, saturation: 0.55, opacity: 0.5),
    ]
    private let maxEmbers = 400
    /// 0 = dunkler, basslastiger Klang … 1 = heller Klang, langsam nachgeführt
    private var brightness: Double = 0
    /// Auflodern nach einem Bassschlag, klingt rasch ab
    private var flare: Double = 0
    private var embers: [Ember] = []
    /// Bruchteil des nächsten Glutstücks
    private var emberDebt: Double = 0

    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        let dt = frame.deltaTime
        let unit = min(size.width, size.height)
        follow(frame)
        // Rot-orange (dunkler Klang) über Violett bis blau (heller Klang)
        let baseHue = cyclicHue(0.02 - 0.4 * brightness)
        let bottom = size.height * 1.02

        // Glühen über dem Feuer
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: cyclicHue(baseHue + 0.04), saturation: 0.9, brightness: 0.8).opacity(0.15 + 0.35 * frame.level),
                    .clear,
                ]),
                center: CGPoint(x: size.width / 2, y: size.height),
                startRadius: 0,
                endRadius: size.width * (0.35 + 0.35 * frame.level + 0.15 * flare)
            )
        )

        context.blendMode = .plusLighter
        let step = size.width / Double(tongueCount)
        let t = frame.time
        for layer in layers {
            let color = Color(hue: cyclicHue(baseHue + layer.hueOffset), saturation: layer.saturation, brightness: 1)
            for i in 0..<tongueCount {
                let x = (Double(i) + 0.5) * step
                // Bass in der Mitte, Höhen aussen
                let distance = abs(x - size.width / 2) / (size.width / 2)
                let value = frame.band(at: distance * 0.85)
                // Jede Zunge ist etwas anders gross und flackert für sich
                let character = 0.7 + 0.3 * abs(sin(Double(i) * 78.233))
                let flicker = 0.8 + 0.12 * sin(t * 11 + Double(i) * 2.1) + 0.08 * sin(t * 17.3 + Double(i) * 0.7)
                let height = size.height * (0.06 + 0.6 * value) * character * flicker * (1 + 0.35 * flare) * layer.height
                let sway = (sin(t * 2.1 + Double(i) * 0.8) * 0.8 + sin(t * 0.7) * 0.5) * step * layer.height
                let tongue = tongue(x: x, bottom: bottom, width: step * 1.7 * layer.width, height: height, sway: sway)
                context.fill(tongue, with: .linearGradient(
                    Gradient(colors: [color.opacity(layer.opacity), color.opacity(layer.opacity * 0.6), .clear]),
                    startPoint: CGPoint(x: x, y: bottom),
                    endPoint: CGPoint(x: x + sway, y: bottom - height)
                ))
            }
        }

        // Glut: steigt auf, je lauter und je mehr Höhen, desto mehr
        emberDebt += dt * 50 * (frame.level + frame.average(from: 0.55, to: 0.9))
        while emberDebt >= 1 {
            emberDebt -= 1
            let lifetime = Double.random(in: 1.2...2.6)
            embers.append(Ember(
                position: CGPoint(x: size.width * .random(in: 0.05...0.95), y: size.height * .random(in: 0.85...1)),
                speed: unit * .random(in: 0.2...0.5),
                seed: .random(in: 0...100),
                life: lifetime,
                lifetime: lifetime,
                size: unit * .random(in: 0.003...0.008)
            ))
        }
        if embers.count > maxEmbers { embers.removeFirst(embers.count - maxEmbers) }
        for i in embers.indices {
            embers[i].position.y -= embers[i].speed * dt
            embers[i].position.x += sin(t * 2.5 + embers[i].seed) * unit * 0.06 * dt
            embers[i].life -= dt
        }
        embers.removeAll { $0.life <= 0 }
        let emberColor = Color(hue: cyclicHue(baseHue + 0.1), saturation: 0.6, brightness: 1)
        for ember in embers {
            let glow = 0.6 + 0.4 * sin(t * 13 + ember.seed)
            let r = ember.size
            context.fill(
                Path(ellipseIn: CGRect(x: ember.position.x - r, y: ember.position.y - r, width: 2 * r, height: 2 * r)),
                with: .color(emberColor.opacity(ember.life / ember.lifetime * glow))
            )
        }
    }

    /// Führt Klangfarbe und Auflodern nach.
    private func follow(_ frame: AudioFrame) {
        flare = max(flare * exp(-frame.deltaTime / 0.25), frame.beat ? 1 : 0)
        // Bei Stille bleibt die Farbe, wie sie war
        let total = frame.bands.reduce(0, +)
        guard frame.level > 0.02, total > 0 else { return }
        // Schwerpunkt des Spektrums: wo im Bereich tief … hoch die Energie liegt
        let last = Double(max(frame.bands.count - 1, 1))
        let centroid = frame.bands.enumerated().reduce(0) { $0 + Double($1.offset) / last * $1.element } / total
        let target = min(max((centroid - 0.42) / 0.18, 0), 1)
        brightness += (target - brightness) * (1 - exp(-frame.deltaTime / 2))
    }

    /// Eine Flammenzunge: breit am Boden, spitz oben, die Spitze schwingt zur Seite.
    private func tongue(x: Double, bottom: Double, width: Double, height: Double, sway: Double) -> Path {
        let tip = CGPoint(x: x + sway, y: bottom - height)
        var path = Path()
        path.move(to: CGPoint(x: x - width / 2, y: bottom))
        path.addCurve(
            to: tip,
            control1: CGPoint(x: x - width / 2, y: bottom - height * 0.45),
            control2: CGPoint(x: x + sway * 0.3 - width * 0.12, y: bottom - height * 0.75)
        )
        path.addCurve(
            to: CGPoint(x: x + width / 2, y: bottom),
            control1: CGPoint(x: x + sway * 0.3 + width * 0.12, y: bottom - height * 0.75),
            control2: CGPoint(x: x + width / 2, y: bottom - height * 0.45)
        )
        path.closeSubpath()
        return path
    }
}
