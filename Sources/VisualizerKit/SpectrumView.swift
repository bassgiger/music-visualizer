import SwiftUI

/// Das bewegte Bild: ein Balken je Frequenzband (tief links, hoch rechts) mit schwacher
/// Spiegelung darunter, dahinter ein Leuchten, das mit dem Bass pulsiert.
public struct SpectrumView: View {
    private let buffer: SampleBuffer
    private let silenceHint: String?
    @State private var renderer = SpectrumRenderer()

    /// `silenceHint` erscheint, wenn einige Sekunden lang kein Ton ankommt.
    public init(buffer: SampleBuffer, silenceHint: String? = nil) {
        self.buffer = buffer
        self.silenceHint = silenceHint
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                renderer.advance(to: timeline.date, buffer: buffer)
                renderer.draw(in: &context, size: size, silenceHint: silenceHint)
            }
        }
        .background(Color.black)
    }
}

/// Hält die Analyse von Frame zu Frame und zeichnet sie.
final class SpectrumRenderer {
    let analyzer = SpectrumAnalyzer()
    private var lastDate: Date?

    func advance(to date: Date, buffer: SampleBuffer) {
        let deltaTime = lastDate.map { min(max(date.timeIntervalSince($0), 0), 0.1) } ?? 1.0 / 60
        lastDate = date
        analyzer.update(samples: buffer.latest(analyzer.fftSize), sampleRate: buffer.sampleRate, deltaTime: deltaTime)
    }

    func draw(in context: inout GraphicsContext, size: CGSize, silenceHint: String?) {
        let bands = analyzer.bands
        let bass = CGFloat(analyzer.bass)
        let baseline = size.height * 0.62

        let glowRadius = max(size.width, size.height) * (0.35 + 0.35 * bass)
        let glowColor = Color(hue: 0.78, saturation: 0.8, brightness: 0.55).opacity(0.15 + 0.45 * bass)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [glowColor, .clear]),
                center: CGPoint(x: size.width / 2, y: baseline),
                startRadius: 0,
                endRadius: glowRadius
            )
        )

        let margin = size.width * 0.06
        let step = (size.width - 2 * margin) / CGFloat(bands.count)
        let barWidth = step * 0.62
        let maxHeight = size.height * 0.5
        for (i, value) in bands.enumerated() {
            let position = Double(i) / Double(max(bands.count - 1, 1))
            // Farbverlauf blau → violett → pink → orange
            let color = Color(
                hue: (0.58 + 0.47 * position).truncatingRemainder(dividingBy: 1),
                saturation: 0.85,
                brightness: 0.55 + 0.45 * Double(value)
            )
            // Bei Stille bleibt ein Punkt stehen
            let height = max(barWidth, CGFloat(value) * maxHeight)
            let x = margin + (CGFloat(i) + 0.5) * step - barWidth / 2
            let bar = CGRect(x: x, y: baseline - height, width: barWidth, height: height)
            context.fill(Path(roundedRect: bar, cornerRadius: barWidth / 2), with: .color(color))
            let mirror = CGRect(x: x, y: baseline + barWidth * 0.5, width: barWidth, height: height * 0.45)
            context.fill(Path(roundedRect: mirror, cornerRadius: barWidth / 2), with: .color(color.opacity(0.22)))
        }

        if let silenceHint, analyzer.silentFor > 3 {
            let text = context.resolve(
                Text(silenceHint).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
            )
            let textSize = text.measure(in: CGSize(width: size.width - 48, height: size.height / 3))
            context.draw(text, in: CGRect(
                x: (size.width - textSize.width) / 2,
                y: size.height - textSize.height - 24,
                width: textSize.width,
                height: textSize.height
            ))
        }
    }
}
