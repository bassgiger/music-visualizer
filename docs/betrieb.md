# Betrieb

## Voraussetzungen

macOS 14.4 oder neuer, Xcode (installiert seit 2026-10-28, Swift 6.4; die Command Line
Tools allein reichen zum Bauen auch). Nach einem Xcode-Update muss evtl. die Lizenz neu
bestätigt werden (`sudo xcodebuild -license`), sonst brechen `git` und `swift` ab.

## Bauen und Starten

- Tests: `swift test` (prüft auch, dass jedes Muster mit und ohne Ton zeichnet)
- App bauen: `./scripts/build-app.sh` → `build/Music Visualizer.app`
- Starten: `open "build/Music Visualizer.app"`
- In „Programme“ übernehmen: `cp -R build/Music\ Visualizer.app /Applications/` – nach jedem
  Neubau wiederholen, sonst startet weiter die alte Version.

Die App ist nur **ad-hoc signiert** (reicht für diesen Mac). Nach einem Neubau kann macOS die
Erlaubnis erneut verlangen; kommt nur Stille, in Systemeinstellungen › Datenschutz & Sicherheit ›
Bildschirm- und Systemaudioaufnahme den Eintrag entfernen und neu erlauben.

## Aufbau des Codes

- `Sources/VisualizerKit/` – plattformunabhängig, später auch für iPhone und Apple TV:
  Ringpuffer (`SampleBuffer`), FFT-Analyse mit Lautstärke und Bassschlag (`SpectrumAnalyzer`),
  Bild (`VisualizerView` mit `VisualizerRenderer`), Liste der Muster (`VisualizerPattern`),
  Auswahlleiste (`PatternPicker`).
- `Sources/VisualizerKit/Patterns/` – je Muster eine Klasse (`PatternRenderer`); sie bekommt
  pro Bild einen `AudioFrame` (Bänder, Bass, Lautstärke, Schlag, Zeit) und darf Zustand
  behalten (Funken, Ringe). Neues Muster: Klasse anlegen, Fall in `VisualizerPattern`
  ergänzen, in `VisualizerRenderer.renderer(for:)` eintragen.
- `Sources/MusicVisualizer/` – Mac-App: Fenster, Menü „Muster“, Systemton-Abgriff
  (`SystemAudioTap`).
- `App/Info.plist` – Bundle-Angaben, Begründung für die Erlaubnis (`NSAudioCaptureUsageDescription`).

## Veröffentlichen

Noch nicht eingerichtet (siehe offene-punkte.md: Xcode, Developer-Zertifikat, Sandbox).
