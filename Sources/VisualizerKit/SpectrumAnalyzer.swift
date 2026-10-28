import Accelerate
import Foundation

/// Zerlegt den Ton per FFT in Frequenzbänder (tief bis hoch, logarithmisch verteilt)
/// und glättet sie fürs Bild: Ausschläge kommen schnell, klingen langsam ab.
public final class SpectrumAnalyzer {
    public let bandCount: Int
    public let fftSize: Int

    /// Stärke je Band, 0…1, geglättet.
    public private(set) var bands: [Float]
    /// Mittel der tiefsten Bänder, 0…1 – für Effekte, die mit dem Bass pulsieren.
    public private(set) var bass: Float = 0
    /// Mittel aller Bänder, 0…1 – wie laut es gerade ist.
    public private(set) var level: Float = 0
    /// true nach dem Aufruf, in dem ein Bassschlag einsetzt (z.B. eine Bassdrum).
    public private(set) var beat = false
    /// Wie lange schon (in Sekunden) praktisch Stille herrscht.
    public private(set) var silentFor: Double = 0

    /// Frequenzbereich der Bänder in Hz.
    public var lowestFrequency: Float = 40
    public var highestFrequency: Float = 16_000
    /// Pegelbereich in dB, der auf 0…1 abgebildet wird.
    public var floorDecibels: Float = -72
    public var ceilingDecibels: Float = -12

    struct BandRange {
        var lowFrequency: Float
        var highFrequency: Float
        var lowBin: Int
        var highBin: Int
        var centerBin: Float
        /// Ausgleich, weil Musik in der Höhe leiser ist (+3 dB pro Oktave, bezogen auf 1 kHz)
        var tiltDecibels: Float
    }

    private(set) var ranges: [BandRange] = []
    /// Amplitude je FFT-Bin (eine Sinuswelle mit Amplitude A ergibt etwa A).
    private(set) var amplitudes: [Float]

    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private var window: [Float]
    private var windowed: [Float]
    private var realPart: [Float]
    private var imagPart: [Float]
    private var rangesSampleRate: Double = 0
    /// FFT-Bins für die Schlagerkennung (tiefste Frequenz bis 150 Hz)
    private var beatBins = 1...1
    /// Gleitendes Mittel der Bassenergie, gegen das ein Schlag gemessen wird
    private var bassEnergyAverage: Float = 0
    /// Erst wenn die Bassenergie nach einem Schlag wieder abgefallen ist, zählt der nächste
    private var beatArmed = true

    public init(bandCount: Int = 64, fftSize: Int = 4096) {
        precondition(fftSize > 1 && fftSize & (fftSize - 1) == 0, "fftSize muss eine Zweierpotenz sein")
        self.bandCount = bandCount
        self.fftSize = fftSize
        bands = [Float](repeating: 0, count: bandCount)
        log2n = vDSP_Length(fftSize.trailingZeroBitCount)
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_DENORM))
        windowed = [Float](repeating: 0, count: fftSize)
        realPart = [Float](repeating: 0, count: fftSize / 2)
        imagPart = [Float](repeating: 0, count: fftSize / 2)
        amplitudes = [Float](repeating: 0, count: fftSize / 2)
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }

    /// Wertet die neuesten Abtastwerte aus. `deltaTime` ist die Zeit seit dem letzten Aufruf.
    public func update(samples: [Float], sampleRate: Double, deltaTime: Double) {
        let rate = sampleRate > 0 ? sampleRate : 48_000
        if rate != rangesSampleRate { buildRanges(sampleRate: rate) }

        let n = fftSize
        let half = n / 2
        // Die neuesten n Werte; fehlen welche, vorne mit Stille auffüllen
        let input = samples.count >= n
            ? Array(samples.suffix(n))
            : [Float](repeating: 0, count: n - samples.count) + samples

        var rms: Float = 0
        vDSP_rmsqv(input, 1, &rms, vDSP_Length(n))
        silentFor = rms < 1e-5 ? silentFor + deltaTime : 0

        vDSP_vmul(input, 1, window, 1, &windowed, 1, vDSP_Length(n))
        realPart.withUnsafeMutableBufferPointer { re in
            imagPart.withUnsafeMutableBufferPointer { im in
                var split = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                windowed.withUnsafeBufferPointer { samples in
                    samples.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                // Bin 0 enthält Gleichanteil und Nyquist-Wert zusammengepackt – wird nicht gebraucht
                split.imagp[0] = 0
                vDSP_zvabs(&split, 1, &amplitudes, 1, vDSP_Length(half))
            }
        }
        // zrip liefert das Doppelte der DFT, das Hann-Fenster halbiert die Summe: 2/n ergibt die Amplitude
        amplitudes = vDSP.multiply(2 / Float(n), amplitudes)

        let attack = Float(1 - exp(-deltaTime / 0.03))
        let release = Float(1 - exp(-deltaTime / 0.25))
        let bassBandCount = max(1, bandCount / 8)
        var bassSum: Float = 0
        for (i, range) in ranges.enumerated() {
            // Schmale Bänder (in der Tiefe) zwischen zwei Bins interpolieren, breite: lautester Bin
            var amplitude = interpolatedAmplitude(atBin: range.centerBin)
            if range.lowBin <= range.highBin {
                for bin in range.lowBin...range.highBin { amplitude = max(amplitude, amplitudes[bin]) }
            }
            let decibels = 20 * log10(max(amplitude, 1e-9)) + range.tiltDecibels
            let target = min(max((decibels - floorDecibels) / (ceilingDecibels - floorDecibels), 0), 1)
            bands[i] += (target - bands[i]) * (target > bands[i] ? attack : release)
            if i < bassBandCount { bassSum += bands[i] }
        }
        bass = bassSum / Float(bassBandCount)
        level = bands.reduce(0, +) / Float(bandCount)

        // Schlag: Die Bassenergie springt deutlich über ihr Mittel. Danach muss sie erst wieder
        // fallen, sonst zählt ein langer Basston mehrfach.
        var bassEnergy: Float = 0
        for bin in beatBins { bassEnergy += amplitudes[bin] * amplitudes[bin] }
        beat = false
        if beatArmed {
            if bassEnergy > 1e-5 && bassEnergy > bassEnergyAverage * 1.45 {
                beat = true
                beatArmed = false
            }
        } else if bassEnergy < bassEnergyAverage * 1.1 {
            beatArmed = true
        }
        bassEnergyAverage += (bassEnergy - bassEnergyAverage) * Float(1 - exp(-deltaTime / 0.6))
    }

    private func interpolatedAmplitude(atBin bin: Float) -> Float {
        let lower = Int(bin)
        let upper = min(lower + 1, amplitudes.count - 1)
        let fraction = bin - Float(lower)
        return amplitudes[lower] * (1 - fraction) + amplitudes[upper] * fraction
    }

    private func buildRanges(sampleRate: Double) {
        rangesSampleRate = sampleRate
        let binWidth = Float(sampleRate) / Float(fftSize)
        let top = min(highestFrequency, Float(sampleRate) / 2 * 0.95)
        let ratio = top / lowestFrequency
        let lastBin = fftSize / 2 - 1
        let firstBeatBin = min(max(1, Int((lowestFrequency / binWidth).rounded(.up))), lastBin)
        beatBins = firstBeatBin...max(firstBeatBin, min(Int((150 / binWidth).rounded(.down)), lastBin))
        ranges = (0..<bandCount).map { i in
            let low = lowestFrequency * pow(ratio, Float(i) / Float(bandCount))
            let high = lowestFrequency * pow(ratio, Float(i + 1) / Float(bandCount))
            let center = (low * high).squareRoot()
            return BandRange(
                lowFrequency: low,
                highFrequency: high,
                lowBin: min(Int((low / binWidth).rounded(.up)), lastBin),
                highBin: min(Int((high / binWidth).rounded(.down)), lastBin),
                centerBin: min(center / binWidth, Float(lastBin)),
                tiltDecibels: 3 * log2(center / 1000)
            )
        }
    }
}
