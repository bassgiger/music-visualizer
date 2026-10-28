import Foundation

/// Ringpuffer mit den zuletzt gehörten Abtastwerten (mono).
/// Die Tonquelle schreibt aus ihrem eigenen Thread, das Bild liest einmal pro Frame.
public final class SampleBuffer: @unchecked Sendable {
    private var samples: [Float]
    private var writeIndex = 0
    private var rate: Double = 48_000
    private let lock = NSLock()

    public init(capacity: Int = 8192) {
        samples = [Float](repeating: 0, count: capacity)
    }

    /// Abtastrate der Tonquelle in Hz.
    public var sampleRate: Double {
        get { lock.withLock { rate } }
        set { lock.withLock { rate = newValue } }
    }

    /// Hängt neue Werte an; die ältesten werden überschrieben.
    public func append(_ newSamples: UnsafeBufferPointer<Float>) {
        lock.withLock {
            for sample in newSamples {
                samples[writeIndex] = sample
                writeIndex = (writeIndex + 1) % samples.count
            }
        }
    }

    /// Die letzten `count` Werte, der älteste zuerst.
    public func latest(_ count: Int) -> [Float] {
        lock.withLock {
            let n = min(count, samples.count)
            var result = [Float](repeating: 0, count: n)
            var index = (writeIndex - n + samples.count) % samples.count
            for i in 0..<n {
                result[i] = samples[index]
                index = (index + 1) % samples.count
            }
            return result
        }
    }
}
