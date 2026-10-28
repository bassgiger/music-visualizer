// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MusicVisualizer",
    // Core-Audio-Taps mit Erlaubnisabfrage gibt es ab macOS 14.4
    platforms: [.macOS("14.4")],
    targets: [
        // Analyse und Bild, ohne Mac-Eigenheiten – später auch für iPhone und Apple TV
        .target(name: "VisualizerKit"),
        // Mac-App: Fenster und Abgriff des Systemtons
        .executableTarget(name: "MusicVisualizer", dependencies: ["VisualizerKit"]),
        .testTarget(name: "VisualizerKitTests", dependencies: ["VisualizerKit"]),
    ]
)
