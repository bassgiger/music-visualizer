/// Die Muster, aus denen man wählen kann.
public enum VisualizerPattern: String, CaseIterable, Identifiable, Sendable {
    /// Ein Balken je Frequenzband mit Spiegelung (das erste Muster)
    case bars
    /// Strahlen rund um einen Ring in allen Farben
    case ring
    /// Leuchtende Wellen quer über das Bild
    case waves
    /// Ringe, die aus der Mitte heranfliegen
    case tunnel
    /// Lagerfeuer, dessen Farbe sich nach dem Klang richtet
    case flames
    /// Explosionen bei jedem Bassschlag
    case fireworks
    /// Leuchtkugeln im Raum mit Funkenströmen und Nebel (im Stil der iTunes-Visualisierung)
    case spheres
    /// Linien, die als wachsende, drehende Spuren stehen bleiben (im Stil des alten iTunes)
    case trails

    public var id: String { rawValue }

    /// Name in Menü und Auswahlleiste
    public var title: String {
        switch self {
        case .bars: "Balken"
        case .ring: "Kreis"
        case .waves: "Wellen"
        case .tunnel: "Tunnel"
        case .flames: "Flammen"
        case .fireworks: "Feuerwerk"
        case .spheres: "Sphären"
        case .trails: "Spuren"
        }
    }

    /// Bildzeichen (SF Symbol) in der Auswahlleiste
    public var symbolName: String {
        switch self {
        case .bars: "chart.bar.fill"
        case .ring: "sun.max.fill"
        case .waves: "water.waves"
        case .tunnel: "circle.circle"
        case .flames: "flame.fill"
        case .fireworks: "sparkles"
        case .spheres: "atom"
        case .trails: "scribble.variable"
        }
    }

    /// Das folgende Muster, nach dem letzten wieder das erste
    public var next: VisualizerPattern { offset(by: 1) }

    /// Das vorige Muster, vor dem ersten das letzte
    public var previous: VisualizerPattern { offset(by: -1) }

    private func offset(by step: Int) -> VisualizerPattern {
        let all = Self.allCases
        let index = all.firstIndex(of: self)!
        return all[(index + step + all.count) % all.count]
    }
}
