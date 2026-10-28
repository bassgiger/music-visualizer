import CoreAudio
import Foundation
import VisualizerKit

/// Greift den Ton aller Apps am Mac ab (Core-Audio-Tap, ab macOS 14.4) und schreibt ihn
/// als Mono in den SampleBuffer. Beim ersten Start fragt macOS nach der Erlaubnis
/// „Systemaudioaufnahme“; ohne Erlaubnis kommt nur Stille, kein Fehler.
final class SystemAudioTap {
    struct TapError: LocalizedError {
        let step: String
        let status: OSStatus

        var errorDescription: String? {
            "Der Ton des Macs konnte nicht abgegriffen werden (\(step), Fehler \(status))."
        }
    }

    /// Wird gerufen, wenn der Neuaufbau nach einem Wechsel der Tonausgabe scheitert.
    var onError: ((Error) -> Void)?

    private let buffer: SampleBuffer
    private let queue = DispatchQueue(label: "SystemAudioTap", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var outputListener: AudioObjectPropertyListenerBlock?
    /// Zwischenspeicher fürs Mischen auf Mono, nur auf `queue` benutzt
    private var mono: [Float] = []

    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    init(buffer: SampleBuffer) {
        self.buffer = buffer
    }

    deinit {
        stop()
    }

    func start() throws {
        try startCapture()
        guard outputListener == nil else { return }
        // Wechselt die Tonausgabe (z.B. auf AirPods), den Abgriff neu aufbauen
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            do { try self.startCapture() } catch { self.onError?(error) }
        }
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, .main, listener)
        outputListener = listener
    }

    func stop() {
        if let outputListener {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, .main, outputListener)
            self.outputListener = nil
        }
        stopCapture()
    }

    private func startCapture() throws {
        stopCapture()
        do {
            // Ein Tap auf den Ton aller Apps, zu Stereo gemischt
            let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
            description.uuid = UUID()
            try check(AudioHardwareCreateProcessTap(description, &tapID), "Tap anlegen")

            let format = try readTapFormat()
            guard format.mFormatID == kAudioFormatLinearPCM,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  format.mBitsPerChannel == 32 else {
                throw TapError(step: "Tonformat nicht unterstützt", status: 0)
            }
            buffer.sampleRate = format.mSampleRate

            // Der Tap lässt sich nur über ein (privates) Sammelgerät lesen, getaktet von der Tonausgabe
            let outputUID = try readDefaultOutputUID()
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Music Visualizer Tap",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                ]],
            ]
            try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "Sammelgerät anlegen")

            try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { [weak self] _, input, _, _, _ in
                self?.receive(input)
            }, "Empfang einrichten")
            try check(AudioDeviceStart(aggregateID, procID), "Empfang starten")
        } catch {
            stopCapture()
            throw error
        }
    }

    private func stopCapture() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    /// Mischt alle Kanäle (verschränkt oder je Kanal ein Puffer) zu Mono.
    private func receive(_ input: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = buffers.first, first.mNumberChannels > 0 else { return }
        let frames = Int(first.mDataByteSize) / (MemoryLayout<Float>.size * Int(first.mNumberChannels))
        guard frames > 0 else { return }
        if mono.count < frames { mono = [Float](repeating: 0, count: frames) }

        mono.withUnsafeMutableBufferPointer { out in
            for i in 0..<frames { out[i] = 0 }
            var channelCount = 0
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                let channels = Int(buffer.mNumberChannels)
                for i in 0..<frames {
                    for c in 0..<channels { out[i] += data[i * channels + c] }
                }
                channelCount += channels
            }
            let scale = 1 / Float(max(channelCount, 1))
            for i in 0..<frames { out[i] *= scale }
            buffer.append(UnsafeBufferPointer(rebasing: out[0..<frames]))
        }
    }

    private func readTapFormat() throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), "Tonformat lesen")
        return format
    }

    private func readDefaultOutputUID() throws -> String {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, 0, nil, &size, &deviceID), "Tonausgabe finden")

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid), "Tonausgabe lesen")
        guard let uid else { throw TapError(step: "Tonausgabe lesen", status: 0) }
        return uid.takeRetainedValue() as String
    }

    private func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw TapError(step: step, status: status) }
    }
}
