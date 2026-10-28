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
