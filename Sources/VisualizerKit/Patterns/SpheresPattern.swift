import SwiftUI

/// Leuchtkugeln schweben im Raum, aus ihnen strömen Funken in Strahlen, die sich wie geladene
/// Teilchen in einem Magnetfeld zu Spiralen winden; dahinter wabert farbiger Nebel. Jede Kugel gehört zu
/// einem Tonbereich (Bass … Höhen) und sprüht umso mehr, je stärker er klingt; ein Bassschlag
/// lässt eine Kugel aufblitzen. Die Kamera kreist langsam, die Farbpalette wechselt alle 30 s.
/// Im Stil der iTunes-Visualisierung, aber eigen umgesetzt.
final class SpheresPattern: PatternRenderer {
    private struct Vector {
        var x: Double
        var y: Double
        var z: Double

        static func + (a: Vector, b: Vector) -> Vector { Vector(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
        static func * (a: Vector, s: Double) -> Vector { Vector(x: a.x * s, y: a.y * s, z: a.z * s) }

        func cross(_ b: Vector) -> Vector {
            Vector(x: y * b.z - z * b.y, y: z * b.x - x * b.z, z: x * b.y - y * b.x)
        }

        /// Zufällige Richtung, gleichmässig über die Kugel verteilt
        static func randomDirection() -> Vector {
            let z = Double.random(in: -1...1)
            let angle = Double.random(in: 0..<(2 * .pi))
            let ring = (1 - z * z).squareRoot()
            return Vector(x: ring * cos(angle), y: ring * sin(angle), z: z)
        }
    }

    private struct Particle {
        var position: Vector
        var velocity: Vector
        /// +1 oder −1: bestimmt, in welche Richtung sich die Spirale windet
        var charge: Double
        var core: Int
        var life: Double
        var lifetime: Double
    }

    /// Ein Punkt nach der Projektion auf den Bildschirm
    private struct Projected {
        var point: CGPoint
        /// Grösse im Verhältnis zur Bildmitte: nahe Dinge sind grösser
        var scale: Double
    }

    private let coreCount = 4
    private let maxParticles = 3000
    private let cameraDistance = 3.2
    private var particles: [Particle] = []
    private var emitDebt: [Double]
    /// Aufblitzen je Kugel nach einem Schlag, klingt rasch ab
    private var pulse: [Double]
    /// Grundfarbton der Palette und der, auf den sie gerade überblendet
    private var paletteHue = Double.random(in: 0..<1)
    private var paletteTarget: Double
    private var sincePalette: Double = 0

    init() {
        emitDebt = [Double](repeating: 0, count: coreCount)
        pulse = [Double](repeating: 0, count: coreCount)
        paletteTarget = paletteHue
    }

    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        let dt = frame.deltaTime
        let unit = min(size.width, size.height)
        updatePalette(dt)

        let cores = (0..<coreCount).map { corePosition($0, flow: frame.flow) }
        let strengths = (0..<coreCount).map { core in
            frame.average(from: Double(core) / Double(coreCount) * 0.85, to: Double(core + 1) / Double(coreCount) * 0.85)
        }
        let hues = (0..<coreCount).map { cyclicHue(paletteHue + Double($0) * 0.09) }

        emit(frame, cores: cores, strengths: strengths, time: frame.time)
        move(dt, time: frame.time)
        for core in pulse.indices { pulse[core] *= exp(-dt / 0.3) }

        // Kamera: kreist um die Hochachse (schneller bei lauter Musik) und neigt sich leicht
        let yaw = frame.flow * 0.12
        let pitch = 0.35 * sin(frame.time * 0.05)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let screenScale = unit * 0.42
        func project(_ p: Vector) -> Projected? {
            let x1 = p.x * cos(yaw) + p.z * sin(yaw)
            let z1 = -p.x * sin(yaw) + p.z * cos(yaw)
            let y2 = p.y * cos(pitch) - z1 * sin(pitch)
            let z2 = p.y * sin(pitch) + z1 * cos(pitch) + cameraDistance
            guard z2 > 0.3 else { return nil }
            let scale = cameraDistance / z2
            return Projected(point: CGPoint(x: center.x + x1 * scale * screenScale, y: center.y - y2 * scale * screenScale),
                             scale: scale)
        }

        context.blendMode = .plusLighter
        drawNebula(frame, in: &context, size: size, unit: unit)

        // Funken: je Kugel und Helligkeitsstufe ein gemeinsamer Pfad – viel schneller als einzeln
        let steps = 4
        var paths = [[Path]](repeating: [Path](repeating: Path(), count: steps), count: coreCount)
        for particle in particles {
            guard let projected = project(particle.position) else { continue }
            let fade = particle.life / particle.lifetime
            let step = min(steps - 1, Int(fade * Double(steps)))
            let radius = unit * 0.0035 * projected.scale
            paths[particle.core][step].addEllipse(in: CGRect(
                x: projected.point.x - radius, y: projected.point.y - radius, width: 2 * radius, height: 2 * radius))
        }
        for core in 0..<coreCount {
            let color = Color(hue: hues[core], saturation: 0.65, brightness: 1)
            for step in 0..<steps {
                context.fill(paths[core][step], with: .color(color.opacity(0.9 * Double(step + 1) / Double(steps))))
            }
        }

        // Kugeln: weites Glühen und ein heller Kern
        for core in 0..<coreCount {
            guard let projected = project(cores[core]) else { continue }
            let color = Color(hue: hues[core], saturation: 0.8, brightness: 1)
            let glow = unit * 0.12 * projected.scale * (0.6 + 0.8 * strengths[core] + 0.6 * pulse[core])
            context.fill(
                Path(ellipseIn: CGRect(x: projected.point.x - glow, y: projected.point.y - glow, width: 2 * glow, height: 2 * glow)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.9), color.opacity(0.25), .clear]),
                    center: projected.point, startRadius: 0, endRadius: glow
                )
            )
            let heart = glow * 0.16
            context.fill(
                Path(ellipseIn: CGRect(x: projected.point.x - heart, y: projected.point.y - heart, width: 2 * heart, height: 2 * heart)),
                with: .color(.white.opacity(0.85))
            )
        }
    }

    /// Alle 30 s ein neuer Grundton, sanft und auf dem kürzeren Weg um den Farbkreis überblendet.
    private func updatePalette(_ dt: Double) {
        sincePalette += dt
        if sincePalette > 30 {
            sincePalette = 0
            paletteTarget = cyclicHue(paletteTarget + .random(in: 0.2...0.5))
        }
        var difference = paletteTarget - paletteHue
        difference -= difference.rounded()
        paletteHue = cyclicHue(paletteHue + difference * (1 - exp(-dt / 3)))
    }

    /// Jede Kugel zieht ihre eigene, langsame Schleife durch den Raum.
    private func corePosition(_ core: Int, flow: Double) -> Vector {
        let phase = Double(core) * 1.7
        let t = flow * 0.35
        return Vector(x: 0.9 * sin(t * 0.7 + phase), y: 0.55 * sin(t * 0.9 + phase * 1.3), z: 0.8 * cos(t * 0.5 + phase * 0.7))
    }

    private func emit(_ frame: AudioFrame, cores: [Vector], strengths: [Double], time: Double) {
        for core in 0..<coreCount {
            emitDebt[core] += frame.deltaTime * (30 + 350 * strengths[core])
            while emitDebt[core] >= 1 {
                emitDebt[core] -= 1
                // Die meisten Funken fliessen in einem der Strahlen, einige sprühen frei
                let jet = Int.random(in: 0..<7)
                let direction = jet < 6
                    ? jetDirection(core: core, jet: jet % 3, time: time) + Vector.randomDirection() * 0.08
                    : Vector.randomDirection()
                spawn(at: cores[core], core: core, velocity: direction * (.random(in: 0.55...0.75) * (0.6 + strengths[core])))
            }
        }
        if frame.beat {
            let core = Int.random(in: 0..<coreCount)
            pulse[core] = 1
            for _ in 0..<200 {
                spawn(at: cores[core], core: core, velocity: Vector.randomDirection() * .random(in: 1.0...1.6))
            }
        }
        if particles.count > maxParticles { particles.removeFirst(particles.count - maxParticles) }
    }

    /// Richtung eines Strahls: Jede Kugel hat drei, die sich langsam drehen.
    private func jetDirection(core: Int, jet: Int, time: Double) -> Vector {
        let around = time * 0.3 + Double(core) * 2.1 + Double(jet) * 2 * .pi / 3
        let up = 0.8 * sin(time * 0.2 + Double(core) + Double(jet))
        return Vector(x: cos(around) * cos(up), y: sin(up), z: sin(around) * cos(up))
    }

    private func spawn(at position: Vector, core: Int, velocity: Vector) {
        let lifetime = Double.random(in: 1.5...3)
        particles.append(Particle(
            position: position,
            velocity: velocity,
            charge: Bool.random() ? 1 : -1,
            core: core,
            life: lifetime,
            lifetime: lifetime
        ))
    }

    /// Bewegt die Funken: Das Magnetfeld lenkt sie quer zur Flugrichtung ab (Spiralen),
    /// der Luftwiderstand bremst sie. Das Feld neigt sich langsam.
    private func move(_ dt: Double, time: Double) {
        let field = Vector(x: 0.5 * sin(time * 0.1), y: 1.2, z: 0.5 * cos(time * 0.13))
        let drag = exp(-dt * 0.35)
        for i in particles.indices {
            let force = particles[i].velocity.cross(field) * particles[i].charge
            particles[i].velocity = (particles[i].velocity + force * dt) * drag
            particles[i].position = particles[i].position + particles[i].velocity * dt
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    /// Nebel: grosse, weiche Farbflecken, die langsam wandern und mit der Lautstärke aufhellen.
    private func drawNebula(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize, unit: Double) {
        let t = frame.time
        for cloud in 0..<5 {
            let n = Double(cloud)
            let center = CGPoint(
                x: size.width * (0.5 + 0.35 * sin(t * 0.05 * (n + 1) + n)),
                y: size.height * (0.5 + 0.3 * cos(t * 0.04 * (n + 2) + n * 2))
            )
            let radius = unit * (0.55 + 0.15 * sin(t * 0.1 + n))
            let color = Color(hue: cyclicHue(paletteHue - 0.1 + n * 0.07), saturation: 0.8, brightness: 0.7)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.1 + 0.15 * frame.level), .clear]),
                    center: center, startRadius: 0, endRadius: radius
                )
            )
        }
    }
}
