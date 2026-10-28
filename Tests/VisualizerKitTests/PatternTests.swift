import SwiftUI
import Testing
@testable import VisualizerKit

/// Künstlicher Ton: viel Bass, abfallend zu den Höhen, wogend; alle halbe Sekunde ein Schlag.
func syntheticFrame(_ index: Int, fps: Double = 60) -> AudioFrame {
    let time = Double(index) / fps
    let bands = (0..<64).map { i -> Double in
        let position = Double(i) / 63
        return min(max(0.85 - 0.6 * position + 0.15 * sin(time * 3 + Double(i) * 0.4), 0), 1)
    }
    return AudioFrame(
        bands: bands,
        bass: bands.prefix(8).reduce(0, +) / 8,
        level: bands.reduce(0, +) / 64,
        beat: index % Int(fps / 2) == 0,
        time: time,
        flow: time * 1.2,
        deltaTime: 1 / fps
    )
}

/// Zeichnet ein Muster `count` Bilder lang und gibt das letzte zurück.
@MainActor
func render(_ pattern: VisualizerPattern, frames count: Int, size: CGSize,
            frame: (Int) -> AudioFrame = { syntheticFrame($0) }) -> CGImage? {
    let renderer = VisualizerRenderer()
    var image: CGImage?
    for index in 0..<count {
        let current = frame(index)
        let view = Canvas { context, canvasSize in
            renderer.draw(pattern, frame: current, in: &context, size: canvasSize, silenceHint: nil)
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        image = ImageRenderer(content: view).cgImage
    }
    return image
}

@MainActor
@Test(arguments: VisualizerPattern.allCases)
func musterZeichnetMitUndOhneTon(_ pattern: VisualizerPattern) {
    #expect(render(pattern, frames: 120, size: CGSize(width: 320, height: 200)) != nil)
    let silence = AudioFrame(bands: [Double](repeating: 0, count: 64), bass: 0, level: 0,
                             beat: false, time: 0, flow: 0, deltaTime: 1.0 / 60)
    #expect(render(pattern, frames: 30, size: CGSize(width: 320, height: 200), frame: { _ in silence }) != nil)
}
