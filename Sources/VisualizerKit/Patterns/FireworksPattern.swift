import SwiftUI

/// Bei jedem Bassschlag explodiert eine Rakete aus farbigen Funken mit Schweif, die Höhen
/// lassen Glitzer vom unteren Rand aufsteigen. Bleiben Schläge aus (ruhige Musik), knallt es
/// trotzdem ab und zu.
final class FireworksPattern: PatternRenderer {
    private struct Spark {
        var position: CGPoint
        var velocity: CGVector
        var hue: Double
        var life: Double
        var lifetime: Double
        var width: Double
    }

    /// Kurzes Aufleuchten am Ort einer Explosion
    private struct Flash {
        var center: CGPoint
        var hue: Double
        var life: Double
    }

    private let maxSparks = 1500
    private let flashDuration = 0.35
    private var sparks: [Spark] = []
    private var flashes: [Flash] = []
    private var sinceBurst: Double = 0
    /// Bruchteil des nächsten Glitzerfunkens
    private var glitterDebt: Double = 0

    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        let dt = frame.deltaTime
        let unit = min(size.width, size.height)
        move(by: dt, gravity: unit * 0.3)

        sinceBurst += dt
        if frame.beat || (sinceBurst > 1.5 && frame.level > 0.08) {
            burst(frame, size: size)
        }
        glitterDebt += dt * 90 * frame.average(from: 0.55, to: 0.9)
        while glitterDebt >= 1 {
            glitterDebt -= 1
            rise(frame, size: size)
        }
        if sparks.count > maxSparks { sparks.removeFirst(sparks.count - maxSparks) }

        // Nachthimmel: schwaches Leuchten vom Boden her, blau bis violett, pulsiert mit dem Bass
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    .clear,
                    Color(hue: 0.72 + 0.08 * sin(frame.time * 0.2), saturation: 0.8, brightness: 0.5)
                        .opacity(0.1 + 0.3 * frame.bass),
                ]),
                startPoint: CGPoint(x: 0, y: size.height * 0.5),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        context.blendMode = .plusLighter
        for flash in flashes {
            let progress = 1 - flash.life / flashDuration
            let radius = unit * (0.12 + 0.2 * progress)
            context.fill(
                Path(ellipseIn: CGRect(x: flash.center.x - radius, y: flash.center.y - radius, width: 2 * radius, height: 2 * radius)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hue: flash.hue, saturation: 0.4, brightness: 1).opacity(0.6 * (1 - progress)),
                        .clear,
                    ]),
                    center: flash.center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
        for spark in sparks {
            let fade = spark.life / spark.lifetime
            // Frisch fast weiss, dann farbig
            let color = Color(hue: spark.hue, saturation: min(0.85, (1 - fade) * 3 + 0.2), brightness: 1)
            // Schweif entgegen der Flugrichtung
            var path = Path()
            path.move(to: CGPoint(x: spark.position.x - spark.velocity.dx * 0.08, y: spark.position.y - spark.velocity.dy * 0.08))
            path.addLine(to: spark.position)
            context.stroke(path, with: .color(color.opacity(fade)), style: StrokeStyle(lineWidth: spark.width, lineCap: .round))
        }
    }

    /// Bewegt die Funken: Schwerkraft zieht nach unten, Luftwiderstand bremst.
    private func move(by dt: Double, gravity: Double) {
        let drag = exp(-dt * 1.6)
        for i in sparks.indices {
            sparks[i].velocity.dx *= drag
            sparks[i].velocity.dy = sparks[i].velocity.dy * drag + gravity * dt
            sparks[i].position.x += sparks[i].velocity.dx * dt
            sparks[i].position.y += sparks[i].velocity.dy * dt
            sparks[i].life -= dt
        }
        sparks.removeAll { $0.life <= 0 }
        for i in flashes.indices { flashes[i].life -= dt }
        flashes.removeAll { $0.life <= 0 }
    }

    /// Eine Explosion an zufälliger Stelle in der oberen Bildhälfte.
    private func burst(_ frame: AudioFrame, size: CGSize) {
        sinceBurst = 0
        let unit = min(size.width, size.height)
        let center = CGPoint(x: size.width * .random(in: 0.15...0.85), y: size.height * .random(in: 0.15...0.55))
        let hue = Double.random(in: 0..<1)
        // Manche Raketen sind zweifarbig
        let secondHue = Bool.random() ? cyclicHue(hue + .random(in: 0.25...0.5)) : hue
        let speed = unit * (0.45 + 0.5 * frame.bass)
        let count = 100 + Int(120 * frame.level)
        for index in 0..<count {
            let angle = Double.random(in: 0..<(2 * .pi))
            // Die meisten Funken fliegen fast gleich schnell – das ergibt eine Kugel, keinen Klumpen
            let velocity = speed * .random(in: 0.75...1) * (index.isMultiple(of: 5) ? 0.5 : 1)
            let lifetime = Double.random(in: 1.2...2.2)
            sparks.append(Spark(
                position: center,
                velocity: CGVector(dx: cos(angle) * velocity, dy: sin(angle) * velocity),
                hue: cyclicHue((index.isMultiple(of: 2) ? hue : secondHue) + .random(in: -0.04...0.04)),
                life: lifetime,
                lifetime: lifetime,
                width: unit * 0.006 * .random(in: 0.7...1.3)
            ))
        }
        flashes.append(Flash(center: center, hue: hue, life: flashDuration))
    }

    /// Ein Glitzerfunke steigt vom unteren Rand auf.
    private func rise(_ frame: AudioFrame, size: CGSize) {
        let unit = min(size.width, size.height)
        let x = Double.random(in: 0...1)
        let lifetime = Double.random(in: 0.8...1.6)
        sparks.append(Spark(
            position: CGPoint(x: x * size.width, y: size.height + 4),
            velocity: CGVector(dx: unit * .random(in: -0.05...0.05), dy: -unit * .random(in: 0.5...0.9)),
            hue: cyclicHue(frame.time * 0.1 + x * 0.5),
            life: lifetime,
            lifetime: lifetime,
            width: unit * 0.004
        ))
    }
}
