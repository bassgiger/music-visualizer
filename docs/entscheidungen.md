# Entscheidungsprotokoll

Neue Einträge **oben** anfügen. Ein Entscheid wird nicht gelöscht, sondern bei Bedarf
durch einen neuen ersetzt („ersetzt Entscheid vom …“).

```
## JJJJ-MM-TT – Kurztitel
**Entscheid:** was gilt ab jetzt.
**Warum:** Gründe, verworfene Alternativen.
**Wer:** Stefan / Claude (Vorschlag, von Stefan bestätigt) / …
**Betrifft:** Dateien, Funktionen.
```

## 2026-10-28 – Muster im Stil der iTunes-Visualisierungen, aber eigen
**Entscheid:** Zwei weitere Muster im Stil der früheren iTunes-Visualisierungen: „Sphären“
(Leuchtkugeln, Funkenströme, Nebel – wie Magnetosphere, seit iTunes 8) und „Spuren“
(Linien mit wachsenden, drehenden Spuren – wie der Classic Visualizer). Eigene Umsetzung und
eigene Namen, keine Kopie.
**Warum:** Stefan: „itunes hatte früher auch hübsche visualisationen - kannst du diese
finden / nachbauen?“, nach der Abklärung „baue beide“. Die Originale gibt es noch in Apples
Musik-App (⌘T), aber nur für deren eigene Wiedergabe. Eine genaue Kopie wäre heikel: Code und
Namen gehören Apple, und Apple weist im App Store Nachahmungen zurück (Richtlinie 4.1).
**Wer:** Stefan (Wunsch, beide bauen), Claude (Abklärung, Umsetzung).
**Betrifft:** `SpheresPattern.swift`, `TrailsPattern.swift`, `AudioFrame.waveform`.

## 2026-10-28 – Mehrere Muster zur Auswahl
**Entscheid:** Die App zeigt die Musik in wählbaren Mustern: Balken (unverändert), Kreis,
Wellen, Tunnel, Flammen, Feuerwerk – bunt und bewegt. Wahl über eine Leiste im Bild, das
Menü „Muster“, ⌘1–⌘6 und ← →; die Wahl bleibt gespeichert. Die Flammen brennen „im Stil der
Musik“: Die Farbe folgt dem Klang (dunkel/basslastig orange-rot, hell bis blau).
**Warum:** Stefan: „di eq anzeige ist hübsch, man soll jedoch unterschiedliche Muster
auswählen können, bunt und bewegt“; aus den Vorschlägen alle vier gewählt, dazu „Flammen
welche im Style der Musik brennen“. Die Muster liegen in `VisualizerKit`, damit iPhone und
Apple TV sie übernehmen.
**Wer:** Stefan (Wunsch, Auswahl der Muster), Claude (Gestaltung, Bedienung).
**Betrifft:** `Sources/VisualizerKit/` (Patterns, `VisualizerView`, `PatternPicker`,
Schlagerkennung in `SpectrumAnalyzer`), `MusicVisualizerApp.swift`.

## 2026-10-28 – TV über AirPlay statt eigener TV-App
**Entscheid:** Aufs TV kommt das Bild per AirPlay vom Mac (später vom iPhone). Eine eigene
App für Apple TV oder andere TVs gibt es vorerst nicht.
**Warum:** Stefan auf die Frage, welcher TV gemeint ist: „airplay“. Eine TV-App bekäme keinen
Ton der anderen Apps; per AirPlay läuft der Abgriff auf dem Mac/iPhone, wo die Musik spielt.
Mit der Mac-App geht das schon jetzt (Bildschirmsynchronisierung).
**Wer:** Stefan.
**Betrifft:** Plattformen (keine tvOS-App), später iPhone-App (Bild auf dem externen Bildschirm).

## 2026-10-28 – Ziel iPhone, Desktop, TV; zuerst eine einfache Mac-App in Swift
**Entscheid:** Die App soll auf iPhone, Desktop und TV laufen. Die erste Version ist eine
Mac-App in Swift/SwiftUI, gebaut mit dem Swift Package Manager der Command Line Tools (ohne
Xcode). Analyse und Bild liegen im plattformunabhängigen Modul `VisualizerKit`, damit iPhone
und Apple TV sie später übernehmen; der Ton kommt über einen globalen Core-Audio-Tap.
**Warum:** Stefan: „ich möchte eine einfache App die die aktuelle Musikwiedergabe
visualisiert“, auf die Frage nach der Plattform „Mac zuerst“, dazu „auf iphone, desktop, tv“.
Der Mac ist mit den vorhandenen Werkzeugen sofort baubar und gibt den Systemton offiziell
frei; Swift teilen sich iPhone, Mac und Apple TV. Vorerst verworfen: iPhone zuerst (braucht
Xcode, nur Mikrofon), Flutter o.ä. (mehr Werkzeuge, Tonabgriff trotzdem je Plattform).
**Wer:** Stefan (Plattformen, Mac zuerst), Claude (Vorschlag Swift, Aufbau).
**Betrifft:** `Package.swift`, `Sources/`, `Tests/`, `App/Info.plist`, `scripts/build-app.sh`.

## 2026-10-28 – Idee: die Musik visualisieren, die auf dem Gerät gerade läuft
**Entscheid:** Die App zeigt die Musik, die auf demselben Gerät gerade läuft (Spotify, Apple
Music, YouTube …), auf dem Handy wie auf Mac und PC – nicht nur eigene Dateien oder das Mikrofon.
**Warum:** Stefan: „die Idee war, wenn Musik auf dem Handy läuft, diese zu visualisieren, oder auf
dem Mac / PC“. Abgeklärt (Stand 2026-10-28): Mac, Windows und Android erlauben das mit
Zustimmung der Nutzer:in; das iPhone/iPad nicht direkt (Details in offene-punkte.md).
**Wer:** Stefan (Idee), Claude (Abklärung).
**Betrifft:** Aufbau der App (Tonquelle je Plattform).

## 2026-10-28 – Projekt angelegt: App für Handy und Computer über die App Stores
**Entscheid:** Eigenes Projekt „Music Visualizer“, Ordner `~/Projekte/music-visualizer`,
privates GitHub-Repo `bassgiger/music-visualizer`, Branch `main`. Ziel ist eine App für Handy
und Computer, verteilt über die App Stores (keine reine Web-App).
**Warum:** Stefan: „Bitte zwei neue Projekte anlegen: tintenshop.ch und Music Visualizer“, auf
die Frage nach der Art: „App für Handy und Desktop über AppStore etc“. Aufbau wie Buchplanet,
PFEV und Nochbere (eigene `CLAUDE.md`, `docs/`, Hook für `git pull`).
**Wer:** Stefan (Projekt, Ziel, GitHub privat), Claude (Aufbau).
**Betrifft:** `CLAUDE.md`, `docs/`, `.claude/settings.json`, `.gitignore`.
