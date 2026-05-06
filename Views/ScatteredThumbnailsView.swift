import SwiftUI

struct ScatteredThumbnailsView: View {
    let screenshots: [ScreenshotItem]

    var body: some View {
        ZStack {
            ForEach(Array(screenshots.enumerated()), id: \.element.id) { index, item in
                ThumbnailTile(item: item)
                    .rotationEffect(rotation(for: item.id, index: index))
                    .offset(offset(for: index, total: screenshots.count))
                    .zIndex(Double(index))
            }
            if screenshots.isEmpty {
                EmptyTile()
            }
        }
    }

    private func rotation(for id: String, index: Int) -> Angle {
        // Deterministic rotation per asset id, in [-7, +7] degrees.
        var generator = SeededGenerator(seed: UInt64(abs(id.hashValue &+ index)))
        let degrees = Double.random(in: -7...7, using: &generator)
        return .degrees(degrees)
    }

    private func offset(for index: Int, total: Int) -> CGSize {
        guard total > 1 else { return .zero }
        let spacing: CGFloat = 28
        let center = CGFloat(total - 1) / 2.0
        let dx = (CGFloat(index) - center) * spacing
        let dy = CGFloat(index) * 2.0 - 2.0
        return CGSize(width: dx, height: dy)
    }
}

private struct ThumbnailTile: View {
    let item: ScreenshotItem
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.snapMuted
            }
        }
        .frame(width: 52, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
        .task(id: item.id) {
            let loader = PhotoLibraryService()
            let img = await loader.loadThumbnail(
                for: item.asset,
                targetSize: CGSize(width: 156, height: 240)
            )
            await MainActor.run {
                self.image = img
            }
        }
    }
}

private struct EmptyTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 52, height: 80)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            )
    }
}

// Deterministic PRNG so the rotation for a given screenshot is stable across renders.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdeadbeef : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
