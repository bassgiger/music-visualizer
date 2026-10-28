import Foundation
import Testing
@testable import VisualizerKit

/// Sinuston mit gegebener Frequenz und Amplitude
private func sine(frequency: Double, amplitude: Float, sampleRate: Double, count: Int) -> [Float] {
    (0..<count).map { amplitude * Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
}

@Test func sinusErgibtSeineAmplitude() {
    let analyzer = SpectrumAnalyzer()
    analyzer.update(samples: sine(frequency: 1000, amplitude: 0.5, sampleRate: 48_000, count: 4096),
                    sampleRate: 48_000, deltaTime: 1)
    // Liegt die Frequenz zwischen zwei Bins, fällt der Spitzenwert bis 1.4 dB tiefer aus
    let peak = analyzer.amplitudes.max() ?? 0
    #expect(peak > 0.42 && peak < 0.52)
}

@Test func sinusSchlaegtNurImPassendenBandAus() {
    let analyzer = SpectrumAnalyzer()
    // Lange Zeitspanne: Glättung ist sofort eingeschwungen
    analyzer.update(samples: sine(frequency: 1000, amplitude: 0.5, sampleRate: 48_000, count: 4096),
                    sampleRate: 48_000, deltaTime: 10)
    for (i, range) in analyzer.ranges.enumerated() {
        if range.lowFrequency <= 1000 && 1000 < range.highFrequency {
            #expect(analyzer.bands[i] > 0.9)
        } else if range.highFrequency < 500 || range.lowFrequency > 2000 {
            #expect(analyzer.bands[i] < 0.05, "Band \(i) bei \(range.lowFrequency) Hz")
        }
    }
}

@Test func stilleWirdErkannt() {
    let analyzer = SpectrumAnalyzer()
    let silence = [Float](repeating: 0, count: 4096)
    for _ in 0..<5 { analyzer.update(samples: silence, sampleRate: 48_000, deltaTime: 1) }
    #expect(analyzer.silentFor == 5)
    #expect(analyzer.bands.allSatisfy { $0 == 0 })
}

@Test func ringpufferLiefertDieNeuestenWerteInReihenfolge() {
    let buffer = SampleBuffer(capacity: 4)
    let values: [Float] = [1, 2, 3, 4, 5, 6]
    values.withUnsafeBufferPointer { buffer.append($0) }
    #expect(buffer.latest(3) == [4, 5, 6])
    #expect(buffer.latest(10) == [3, 4, 5, 6])
}

@Test func bassSchlagWirdErkanntLangerTonZaehltEinmal() {
    let analyzer = SpectrumAnalyzer()
    let silence = [Float](repeating: 0, count: 4096)
    let kick = sine(frequency: 60, amplitude: 0.5, sampleRate: 48_000, count: 4096)
    for _ in 0..<30 { analyzer.update(samples: silence, sampleRate: 48_000, deltaTime: 1.0 / 60) }
    #expect(!analyzer.beat)

    analyzer.update(samples: kick, sampleRate: 48_000, deltaTime: 1.0 / 60)
    #expect(analyzer.beat)

    // Hält der Basston an, ist das kein neuer Schlag
    var furtherBeats = 0
    for _ in 0..<180 {
        analyzer.update(samples: kick, sampleRate: 48_000, deltaTime: 1.0 / 60)
        if analyzer.beat { furtherBeats += 1 }
    }
    #expect(furtherBeats == 0)

    // Nach einer Pause zählt der nächste Schlag wieder
    for _ in 0..<30 { analyzer.update(samples: silence, sampleRate: 48_000, deltaTime: 1.0 / 60) }
    analyzer.update(samples: kick, sampleRate: 48_000, deltaTime: 1.0 / 60)
    #expect(analyzer.beat)
}

@Test func hoheToeneSindKeinSchlag() {
    let analyzer = SpectrumAnalyzer()
    let tone = sine(frequency: 2000, amplitude: 0.5, sampleRate: 48_000, count: 4096)
    analyzer.update(samples: tone, sampleRate: 48_000, deltaTime: 1.0 / 60)
    #expect(!analyzer.beat)
    #expect(analyzer.level > 0)
}

@Test func musterWechselnReihum() {
    #expect(VisualizerPattern.bars.next == .ring)
    #expect(VisualizerPattern.fireworks.next == .bars)
    #expect(VisualizerPattern.bars.previous == .fireworks)
    for pattern in VisualizerPattern.allCases {
        #expect(pattern.next.previous == pattern)
    }
}

@Test func spektrumWirdInterpoliertUndGemittelt() {
    let frame = AudioFrame(bands: [0, 0.2, 0.6, 1], bass: 0, level: 0, beat: false, time: 0, flow: 0, deltaTime: 0)
    #expect(frame.band(at: 0) == 0)
    #expect(frame.band(at: 1) == 1)
    #expect(abs(frame.band(at: 0.5) - 0.4) < 1e-9)
    #expect(abs(frame.average(from: 0.5, to: 1) - 0.8) < 1e-9)
    #expect(abs(frame.average(from: 0, to: 1) - 0.45) < 1e-9)
    // Auf dem Kreis gespiegelt: gleich weit von oben → gleicher Wert
    #expect(abs(frame.band(aroundCircle: 0.2) - frame.band(aroundCircle: 0.8)) < 1e-9)
}
