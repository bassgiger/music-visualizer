# Offene Punkte

## Zu klären (2026-10-28)

- **Ton anderer Apps abgreifen, je Plattform** (Entscheid: die Musik, die auf dem Gerät läuft;
  Abklärung 2026-10-28, vor dem Bau mit einem Prototyp prüfen):
  - **Mac:** ja. Core-Audio-Taps (ab macOS 14.4; Erlaubnis „Bildschirm- und Systemaudioaufnahme“,
    Begründung in `NSAudioCaptureUsageDescription`; ohne Erlaubnis kommt Stille, kein Fehler)
    oder ScreenCaptureKit (ab macOS 13).
  - **Windows:** ja, WASAPI-Loopback (Ton des Ausgabegeräts), ohne besondere Erlaubnis.
  - **Android:** ja, mit Grenzen. AudioPlaybackCapture (ab Android 10, Zustimmung wie bei einer
    Bildschirmaufnahme; Apps können sich ausschliessen) oder die ältere Visualizer-Schnittstelle
    auf dem Gesamtton (grobe Daten, reicht fürs Bild; versagt auf manchen Geräten).
  - **iPhone/iPad:** keine offizielle Schnittstelle für den Ton anderer Apps. Möglich sind das
    Mikrofon (Musik über den Lautsprecher, nicht mit Kopfhörern/AirPods) oder ein Umweg über die
    Bildschirmübertragung (ReplayKit-Broadcast: Start im Kontrollzentrum, roter Aufnahmepunkt,
    die Erweiterung erhält den Ton der Apps). Offen: ob Apple Music (Kopierschutz) dabei Ton
    liefert und ob Apple die App so im App Store zulässt. Bestehende iOS-Visualizer arbeiten
    meist mit dem Mikrofon.
- **Mac-App mit echter Musik testen** (Erlaubnis „Systemaudioaufnahme“, Ausgabewechsel
  z.B. auf AirPods, Aussehen der Balken).
- **Plattformen:** Ziel iPhone, Desktop, TV (Entscheid 2026-10-28). Offen: „Desktop“ nur Mac
  oder auch Windows? Welcher TV (Apple TV, Google TV, Smart-TV)? Apple TV erhält voraussichtlich
  keinen Ton anderer Apps – denkbar: Bild vom Mac/iPhone per AirPlay auf den TV spiegeln (geht
  schon jetzt), oder eine TV-App erhält die Daten vom Handy übers Netz. Vor dem Bau abklären.
- **Bundle-ID** `ch.giger.musicvisualizer` ist vorläufig; vor dem ersten Store-Upload festlegen.
- **App Store (Mac):** braucht Xcode, Sandbox und Developer-Zertifikat; prüfen, ob der
  Core-Audio-Tap in der Sandbox funktioniert.
- **Technik:** eine gemeinsame Codebasis für alle Plattformen (z.B. Flutter, React Native,
  Web-Technik in einer App-Hülle) oder je Plattform eigen (z.B. Swift für Apple). Für
  flüssige Grafik zählt der Zugang zur Grafikkarte (Metal, OpenGL/Vulkan, WebGL/WebGPU).
- **Konten und Werkzeuge:** Apple Developer Program und Google Play Console sind
  kostenpflichtig und brauchen eine Anmeldung auf Stefans Namen; für Apple-Apps Xcode auf
  einem der Macs (fehlt bisher).
- **Name und Aussehen:** endgültiger App-Name (für die Stores), Stil der Bilder, Gratis oder
  kostenpflichtig.

## Erledigt

- 2026-10-28: Erste Mac-App (Spektrum-Balken zum Systemton), Tests für die Analyse.
