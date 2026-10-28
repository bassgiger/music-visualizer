import SwiftUI

/// Leiste zum Wählen des Musters: je Muster ein Bildzeichen mit Namen, das gewählte hell.
/// Ist zu wenig Platz, fallen die Namen weg.
public struct PatternPicker: View {
    @Binding private var selection: VisualizerPattern

    public init(selection: Binding<VisualizerPattern>) {
        _selection = selection
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(withTitles: true)
            bar(withTitles: false)
        }
    }

    private func bar(withTitles: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(VisualizerPattern.allCases) { pattern in
                let selected = pattern == selection
                Button {
                    selection = pattern
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: pattern.symbolName)
                            .font(.system(size: 18))
                            .frame(height: 22)
                        if withTitles {
                            Text(pattern.title)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .frame(width: withTitles ? 76 : 44, height: withTitles ? 54 : 40)
                    .foregroundStyle(selected ? Color.black : Color.white)
                    .background(selected ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(pattern.title)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.15)))
        .fixedSize()
    }
}
