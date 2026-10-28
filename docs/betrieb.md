# Betrieb

## Voraussetzungen

macOS 14.4 oder neuer, Command Line Tools (Swift 6.1). Xcode ist erst für den App Store nötig.

## Bauen und Starten

- Tests: `swift test`
- App bauen: `./scripts/build-app.sh` → `build/Music Visualizer.app`
- Starten: `open "build/Music Visualizer.app"`
- In „Programme“ übernehmen: `cp -R build/Music\ Visualizer.app /Applications/` – nach jedem
  Neubau wiederholen, sonst startet weiter die alte Version.

Die App ist nur **ad-hoc signiert** (reicht für diesen Mac). Nach einem Neubau kann macOS die
Erlaubnis erneut verlangen; kommt nur Stille, in Systemeinstellungen › Datenschutz & Sicherheit ›
Bildschirm- und Systemaudioaufnahme den Eintrag entfernen und neu erlauben.

## Aufbau des Codes

- `Sources/VisualizerKit/` – plattformunabhängig: Ringpuffer (`SampleBuffer`), FFT-Analyse
  (`SpectrumAnalyzer`), Bild (`SpectrumView`). Später auch für iPhone und Apple TV.
- `Sources/MusicVisualizer/` – Mac-App: Fenster und Systemton-Abgriff (`SystemAudioTap`).
- `App/Info.plist` – Bundle-Angaben, Begründung für die Erlaubnis (`NSAudioCaptureUsageDescription`).

## Veröffentlichen

Noch nicht eingerichtet (siehe offene-punkte.md: Xcode, Developer-Zertifikat, Sandbox).
