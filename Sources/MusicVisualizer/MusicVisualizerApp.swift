import AppKit
import Observation
import SwiftUI
import VisualizerKit

@main
struct MusicVisualizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var audio = AudioController()
    /// Das gewählte Muster, bleibt über einen Neustart erhalten
    @AppStorage("pattern") private var pattern: VisualizerPattern = .bars

    var body: some Scene {
        Window("Music Visualizer", id: "main") {
            ContentView(audio: audio, pattern: $pattern)
                .frame(minWidth: 480, minHeight: 300)
        }
        .defaultSize(width: 1100, height: 640)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Muster") {
                ForEach(Array(VisualizerPattern.allCases.enumerated()), id: \.element) { index, item in
                    Toggle(item.title, isOn: Binding(
                        get: { pattern == item },
                        set: { if $0 { pattern = item } }
                    ))
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
                }
                Divider()
                Button("Nächstes Muster") { pattern = pattern.next }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Voriges Muster") { pattern = pattern.previous }
                    .keyboardShortcut(.leftArrow, modifiers: [])
            }
        }
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
    @Binding var pattern: VisualizerPattern
    @State private var pickerVisible = false
    @State private var pointerOnPicker = false
    @State private var hidePicker: Task<Void, Never>?

    var body: some View {
        VisualizerView(
            buffer: audio.buffer,
            pattern: pattern,
            silenceHint: """
                Es kommt kein Ton an. Läuft Musik? Sonst die Erlaubnis prüfen: Systemeinstellungen › \
                Datenschutz & Sicherheit › Bildschirm- und Systemaudioaufnahme › Music Visualizer.
                """
        )
        .overlay(alignment: .bottom) {
            if pickerVisible {
                PatternPicker(selection: $pattern)
                    .onHover { pointerOnPicker = $0 }
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
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
        .onContinuousHover { phase in
            if case .active = phase { showPicker() }
        }
        .onChange(of: pattern) { showPicker() }
        .onAppear {
            audio.start()
            showPicker()
        }
    }

    /// Blendet die Auswahl ein und nach 3 s ohne Mausbewegung wieder aus – ausser der Zeiger
    /// liegt auf ihr.
    private func showPicker() {
        withAnimation(.easeOut(duration: 0.2)) { pickerVisible = true }
        hidePicker?.cancel()
        hidePicker = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !pointerOnPicker else { return }
            withAnimation(.easeIn(duration: 0.5)) { pickerVisible = false }
        }
    }
}
