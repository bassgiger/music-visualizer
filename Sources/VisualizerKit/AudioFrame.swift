import Foundation

/// Was ein Muster für ein Bild vom Ton wissen muss.
struct AudioFrame {
    /// Stärke je Frequenzband, 0…1, tief zuerst
    var bands: [Double]
    /// Stärke der tiefsten Bänder, 0…1
    var bass: Double
    /// Mittel aller Bänder, 0…1
    var level: Double
    /// true in dem Bild, in dem ein Bassschlag einsetzt
    var beat: Bool
    /// Sekunden seit dem Start – für Bewegung, die auch bei Stille weiterläuft
    var time: Double
    /// Läuft wie `time`, aber schneller, je lauter die Musik ist
    var flow: Double
    /// Sekunden seit dem letzten Bild
    var deltaTime: Double

    /// Stärke an einer Stelle des Spektrums (0 = tief, 1 = hoch), zwischen den Bändern interpoliert.
    func band(at position: Double) -> Double {
        guard bands.count > 1 else { return bands.first ?? 0 }
        let x = min(max(position, 0), 1) * Double(bands.count - 1)
        let lower = Int(x)
        let upper = min(lower + 1, bands.count - 1)
        let fraction = x - Double(lower)
        return bands[lower] * (1 - fraction) + bands[upper] * fraction
    }

    /// Mittlere Stärke eines Abschnitts des Spektrums (Stellen wie bei `band(at:)`).
    func average(from start: Double, to end: Double) -> Double {
        guard !bands.isEmpty else { return 0 }
        let count = Double(bands.count)
        let lower = min(max(Int(start * count), 0), bands.count - 1)
        let upper = min(max(Int((end * count).rounded(.up)), lower + 1), bands.count)
        return bands[lower..<upper].reduce(0, +) / Double(upper - lower)
    }

    /// Stärke für eine Stelle auf einem Kreis (0…1 = einmal herum): Die eine Hälfte geht von
    /// tief nach hoch, die andere spiegelbildlich zurück. Die obersten Höhen (meist leer) fehlen.
    func band(aroundCircle fraction: Double) -> Double {
        let turn = fraction - fraction.rounded(.down)
        return band(at: (turn <= 0.5 ? turn : 1 - turn) * 2 * 0.85)
    }
}

/// Führt einen Farbton auf den Farbkreis zurück (0…1), auch bei negativen Werten.
func cyclicHue(_ value: Double) -> Double {
    value - value.rounded(.down)
}
