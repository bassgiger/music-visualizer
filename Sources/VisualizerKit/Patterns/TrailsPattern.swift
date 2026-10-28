import CoreGraphics
import SwiftUI

/// Leuchtende Linien aus der Schwingung der Musik, die als Spuren stehen bleiben: Jedes Bild
/// wird etwas grösser (oder kleiner), dreht sich und verblasst – es entstehen fliessende
/// Farbtunnel. Alle 20 s wechselt die Figur (Kreis, Linie, Stern), ein Bassschlag setzt einen
/// Ring, der mitwandert. Im Stil des alten iTunes-Visualizers, aber eigen umgesetzt.
final class TrailsPattern: PatternRenderer {
    private enum Figure: CaseIterable {
        /// Die Schwingung um einen Kreis gelegt, Spuren wachsen nach aussen
        case circle
        /// Die Schwingung als Linie quer durch die Mitte, langsam drehend
        case line
        /// Sechs gespiegelte Strahlen, Spuren ziehen nach innen
        case star

        /// Wie stark die Spuren pro Sekunde wachsen (negativ: schrumpfen)
        var growth: Double {
            switch self {
            case .circle: 0.9
            case .line: 0.6
            case .star: -0.7
            }
        }
    }

    /// Breite des Spurenspeichers in Pixeln; die Spuren dürfen weich sein, das spart Rechenzeit
    private let maxBufferWidth = 800.0
    private var buffer: CGContext?
    private var bufferSize: CGSize = .zero
    /// Grösse der Ansicht, für die der Speicher angelegt wurde
    private var viewSize: CGSize = .zero
    private var trails: CGImage?
    private var figure = Figure.circle
    private var sinceFigure: Double = 0
    /// Schub nach einem Schlag: Die Spuren wachsen kurz schneller
    private var kick: Double = 0
    /// Wächst bei jedem Schlag, damit die Farbe springt
    private var hueJump: Double = 0

    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        guard size.width >= 1, size.height >= 1, let buffer = buffer(for: size) else { return }
        let dt = frame.deltaTime
        sinceFigure += dt
        if sinceFigure > 20 {
            sinceFigure = 0
            let all = Figure.allCases
            figure = all[(all.firstIndex(of: figure)! + 1) % all.count]
        }
        kick = max(kick * exp(-dt / 0.2), frame.beat ? 1 : 0)
        if frame.beat { hueJump += 0.15 }

        let rect = CGRect(origin: .zero, size: bufferSize)
        let center = CGPoint(x: bufferSize.width / 2, y: bufferSize.height / 2)
        buffer.clear(rect)

        // Die alten Spuren: wachsen, drehen sich, verblassen
        if let trails {
            let zoom = exp(dt * (figure.growth + 2.5 * kick * (figure.growth > 0 ? 1 : -1)))
            buffer.saveGState()
            buffer.setAlpha(pow(0.93, dt * 60))
            buffer.translateBy(x: center.x, y: center.y)
            buffer.rotate(by: dt * (0.2 + 0.6 * frame.bass))
            buffer.scaleBy(x: zoom, y: zoom)
            buffer.translateBy(x: -center.x, y: -center.y)
            buffer.draw(trails, in: rect)
            buffer.restoreGState()
        }

        // Die neue Figur in den Speicher: Ansichtspunkte → Pixel, y zeigt dort nach oben.
        // Die Farbe wandert rasch, so werden die Spuren zum Regenbogen.
        let hue = cyclicHue(frame.time * 0.4 + hueJump)
        let shape = path(for: frame, size: size)
        let toBuffer = CGAffineTransform(a: bufferSize.width / size.width, b: 0, c: 0,
                                         d: -bufferSize.height / size.height, tx: 0, ty: bufferSize.height)
        buffer.setBlendMode(.plusLighter)
        buffer.setLineCap(.round)
        buffer.setLineJoin(.round)
        buffer.addPath(shape.applying(toBuffer).cgPath)
        buffer.setStrokeColor(cgColor(hue: hue, saturation: 0.8, alpha: 1))
        buffer.setLineWidth(3)
        buffer.strokePath()
        if frame.beat {
            let radius = min(bufferSize.width, bufferSize.height) * 0.12
            buffer.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
            buffer.setStrokeColor(cgColor(hue: hue + 0.5, saturation: 0.6, alpha: 1))
            buffer.setLineWidth(6)
            buffer.strokePath()
        }
        buffer.setBlendMode(.normal)
        trails = buffer.makeImage()

        // In die Ansicht: die Spuren weich vergrössert, darüber die Figur scharf
        if let trails {
            context.draw(Image(decorative: trails, scale: 1).interpolation(.medium), in: CGRect(origin: .zero, size: size))
        }
        context.blendMode = .plusLighter
        let color = Color(hue: hue, saturation: 0.35, brightness: 1)
        var glow = context
        glow.opacity = 0.35
        glow.stroke(shape, with: .color(color), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        context.stroke(shape, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    /// Legt den Spurenspeicher an, neu wenn sich die Grösse der Ansicht ändert.
    private func buffer(for size: CGSize) -> CGContext? {
        if let buffer, size == viewSize { return buffer }
        let width = min(size.width, maxBufferWidth).rounded()
        let height = max(1, (width * size.height / size.width).rounded())
        buffer = CGContext(
            data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        buffer?.interpolationQuality = .medium
        bufferSize = CGSize(width: width, height: height)
        viewSize = size
        trails = nil
        return buffer
    }

    /// Die Figur aus der Schwingung, in Punkten der Ansicht.
    private func path(for frame: AudioFrame, size: CGSize) -> Path {
        let wave = frame.waveform.isEmpty ? [Double](repeating: 0, count: 256) : frame.waveform
        let count = wave.count
        let unit = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // An den Enden ausblenden, damit sich die Figur ohne Sprung schliesst
        func value(_ k: Int) -> Double { wave[k] * sin(.pi * Double(k) / Double(count - 1)) }

        var path = Path()
        switch figure {
        case .circle:
            let radius = unit * (0.2 + 0.05 * frame.bass)
            let turn = frame.flow * 0.3
            path.addLines((0..<count).map { k in
                let angle = turn + 2 * .pi * Double(k) / Double(count)
                let distance = radius + value(k) * unit * 0.1
                return CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            })
            path.closeSubpath()
        case .line:
            let angle = frame.flow * 0.2
            let length = unit * 0.9
            path.addLines((0..<count).map { k in
                let along = (Double(k) / Double(count - 1) - 0.5) * length
                let across = value(k) * unit * 0.15
                return CGPoint(x: center.x + cos(angle) * along - sin(angle) * across,
                               y: center.y + sin(angle) * along + cos(angle) * across)
            })
        case .star:
            let arms = 6
            let turn = frame.flow * 0.25
            for arm in 0..<arms {
                for mirror in [1.0, -1.0] {
                    let angle = turn + 2 * .pi * Double(arm) / Double(arms)
                    path.addLines((0..<count).map { k in
                        let along = unit * (0.05 + 0.35 * Double(k) / Double(count - 1))
                        let across = mirror * value(k) * unit * 0.06
                        return CGPoint(x: center.x + cos(angle) * along - sin(angle) * across,
                                       y: center.y + sin(angle) * along + cos(angle) * across)
                    })
                }
            }
        }
        return path
    }

    private func cgColor(hue: Double, saturation: Double, alpha: Double) -> CGColor {
        let color = rgb(hue: hue, saturation: saturation, brightness: 1)
        return CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: alpha)
    }
}
