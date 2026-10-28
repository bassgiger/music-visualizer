# Music Visualizer – Projektkontext für Claude Code

## Projekt

App, die Musik als bewegtes Bild darstellt – für Handy und Computer, verteilt über die App
Stores. Projekt von Stefan Giger, angelegt 2026-10-28. Technik, Plattformen im Einzelnen und
woher die Musik kommt, sind noch offen – siehe `docs/offene-punkte.md`. Nichts davon annehmen,
sondern Stefan fragen und den Entscheid in `docs/entscheidungen.md` festhalten.

- Lokal: `~/Projekte/music-visualizer`. GitHub: github.com/bassgiger/music-visualizer (privat),
  Branch `main` – direkt auf `main` committen und pushen (Einzelentwickler).
- Beim Start von Claude Code holt ein SessionStart-Hook (`.claude/settings.json`) per
  `git pull --ff-only` den neuesten Stand; ist seine Ausgabe ein Fehler, zuerst klären.
  Zu Beginn jeder Aufgabe zusätzlich `git fetch`, bei Rückstand zuerst `git pull`.
- Stefan arbeitet auf zwei Macs. Dort gibt es (Stand 2026-10-28) kein Node und kein Docker.
  Xcode ist seit 2026-10-28 installiert (auf welchem der beiden Macs, ist unklar); bricht
  `git` oder `swift` mit einem Hinweis auf die Xcode-Lizenz ab, muss Stefan
  `sudo xcodebuild -license` ausführen.

## Sprache & Stil

- Antworten, Code-Kommentare und Doku auf Deutsch (Schweizer Schreibweise, „ss“).
- Terminalbefehle für Stefan immer einzeln vorschlagen, nie mehrere auf einmal.

## Dokumentation & Entscheidungen (Pflicht)

Doku in `docs/` (Einstieg `docs/README.md`), gehört zu jeder Änderung, im selben Commit:
- Entscheide mit Tragweite oben in `docs/entscheidungen.md` (Datum, Entscheid, Warum, Wer,
  Betrifft). Vor der Arbeit lesen; widerspricht eine Aufgabe einem Entscheid, Stefan darauf
  hinweisen. Abgelehntes auch festhalten.
- Baustellen und Erledigtes in `docs/offene-punkte.md`, „Stand:“ in `docs/README.md`.
- Sobald es Code gibt: `funktionen.md` (was die App kann) und `betrieb.md` (Bauen, Signieren,
  Veröffentlichen in den Stores).

## Sicherheit

- Signierschlüssel, Zertifikate, Provisioning-Profile und Store-Zugänge nie ins Repo und nie
  ausgeben (`.gitignore` schliesst die üblichen Dateien aus).
