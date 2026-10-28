import SwiftUI

/// Ein Balken je Frequenzband (tief links, hoch rechts) mit schwacher Spiegelung darunter,
/// dahinter ein Leuchten, das mit dem Bass pulsiert.
final class BarsPattern: PatternRenderer {
    func draw(_ frame: AudioFrame, in context: inout GraphicsContext, size: CGSize) {
        let bands = frame.bands
        let bass = frame.bass
        let baseline = size.height * 0.62

        let glowRadius = max(size.width, size.height) * (0.35 + 0.35 * bass)
        let glowColor = Color(hue: 0.78, saturation: 0.8, brightness: 0.55).opacity(0.15 + 0.45 * bass)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [glowColor, .clear]),
                center: CGPoint(x: size.width / 2, y: baseline),
                startRadius: 0,
                endRadius: glowRadius
            )
        )

        let margin = size.width * 0.06
        let step = (size.width - 2 * margin) / CGFloat(bands.count)
        let barWidth = step * 0.62
        let maxHeight = size.height * 0.5
        for (i, value) in bands.enumerated() {
            let position = Double(i) / Double(max(bands.count - 1, 1))
            // Farbverlauf blau → violett → pink → orange
            let color = Color(
                hue: (0.58 + 0.47 * position).truncatingRemainder(dividingBy: 1),
                saturation: 0.85,
                brightness: 0.55 + 0.45 * value
            )
            // Bei Stille bleibt ein Punkt stehen
            let height = max(barWidth, value * maxHeight)
            let x = margin + (CGFloat(i) + 0.5) * step - barWidth / 2
            let bar = CGRect(x: x, y: baseline - height, width: barWidth, height: height)
            context.fill(Path(roundedRect: bar, cornerRadius: barWidth / 2), with: .color(color))
            let mirror = CGRect(x: x, y: baseline + barWidth * 0.5, width: barWidth, height: height * 0.45)
            context.fill(Path(roundedRect: mirror, cornerRadius: barWidth / 2), with: .color(color.opacity(0.22)))
        }
    }
}
