import SwiftUI

/// Das bewegte Bild im gewählten Muster.
public struct VisualizerView: View {
    private let buffer: SampleBuffer
    private let pattern: VisualizerPattern
    private let silenceHint: String?
    @State private var renderer = VisualizerRenderer()

    /// `silenceHint` erscheint, wenn einige Sekunden lang kein Ton ankommt.
    public init(buffer: SampleBuffer, pattern: VisualizerPattern = .bars, silenceHint: String? = nil) {
        self.buffer = buffer
        self.pattern = pattern
        self.silenceHint = silenceHint
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let frame = renderer.advance(to: timeline.date, buffer: buffer)
                renderer.draw(pattern, frame: frame, in: &context, size: size, silenceHint: silenceHint)
            }
        }
        .background(Color.black)
    }
}

/// Zeichnet ein Muster. Darf von Bild zu Bild Zustand behalten (Funken, Ringe …).
protocol PatternRenderer: AnyObject {
    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize)
}

/// Hält die Analyse und die Muster von Frame zu Frame und zeichnet das gewählte.
final class VisualizerRenderer {
    let analyzer = SpectrumAnalyzer()
    private var lastDate: Date?
    private var time: Double = 0
    private var flow: Double = 0
    private var patterns: [VisualizerPattern: any PatternRenderer] = [:]

    func advance(to date: Date, buffer: SampleBuffer) -> AudioFrame {
        let deltaTime = lastDate.map { min(max(date.timeIntervalSince($0), 0), 0.1) } ?? 1.0 / 60
        lastDate = date
        analyzer.update(samples: buffer.latest(analyzer.fftSize), sampleRate: buffer.sampleRate, deltaTime: deltaTime)
        time += deltaTime
        flow += deltaTime * (0.3 + 1.7 * Double(analyzer.level))
        return AudioFrame(
            bands: analyzer.bands.map(Double.init),
            bass: Double(analyzer.bass),
            level: Double(analyzer.level),
            beat: analyzer.beat,
            time: time,
            flow: flow,
            deltaTime: deltaTime
        )
    }

    func draw(_ pattern: VisualizerPattern, frame: AudioFrame, in context: inout GraphicsContext,
              size: CGSize, silenceHint: String?) {
        // Eigene Kopie, damit Mischmodus und Deckkraft des Musters nicht nachwirken
        var patternContext = context
        renderer(for: pattern).draw(frame, in: &patternContext, size: size)

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

    private func renderer(for pattern: VisualizerPattern) -> any PatternRenderer {
        if let existing = patterns[pattern] { return existing }
        let made: any PatternRenderer = switch pattern {
        case .bars: BarsPattern()
        case .ring: RingPattern()
        case .waves: WavesPattern()
        case .tunnel: TunnelPattern()
        case .flames: FlamesPattern()
        case .fireworks: FireworksPattern()
        }
        patterns[pattern] = made
        return made
    }
}
