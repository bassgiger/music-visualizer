import AppKit
import Observation
import SwiftUI
import VisualizerKit

@main
struct MusicVisualizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var audio = AudioController()

    var body: some Scene {
        Window("Music Visualizer", id: "main") {
            ContentView(audio: audio)
                .frame(minWidth: 480, minHeight: 300)
        }
        .defaultSize(width: 1100, height: 640)
        .windowStyle(.hiddenTitleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// Verbindet den Tonabgriff mit dem Bild und hält Fehler fürs Fenster bereit.
@Observable
final class AudioController {
    let buffer = SampleBuffer()
    private(set) var errorMessage: String?
    @ObservationIgnored private let tap: SystemAudioTap
    @ObservationIgnored private var started = false

    init() {
        tap = SystemAudioTap(buffer: buffer)
        tap.onError = { [weak self] error in self?.errorMessage = error.localizedDescription }
    }

    func start() {
        guard !started else { return }
        started = true
        do {
            try tap.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ContentView: View {
    let audio: AudioController

    var body: some View {
        SpectrumView(
            buffer: audio.buffer,
            silenceHint: """
                Es kommt kein Ton an. Läuft Musik? Sonst die Erlaubnis prüfen: Systemeinstellungen › \
                Datenschutz & Sicherheit › Bildschirm- und Systemaudioaufnahme › Music Visualizer.
                """
        )
        .overlay {
            if let message = audio.errorMessage {
                Text(message)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.red.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .ignoresSafeArea()
        .onAppear { audio.start() }
    }
}
