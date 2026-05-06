import SwiftUI

struct MagnifyingScanAnimation: View {
    private let rowCount = 6
    private let cycle: Double = 3.6

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle

            GeometryReader { geo in
                let rowHeight = geo.size.height / CGFloat(rowCount + 1)
                let listInset: CGFloat = 18

                ZStack(alignment: .topLeading) {
                    // The list itself
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.snapBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                    VStack(spacing: rowHeight * 0.45) {
                        ForEach(0..<rowCount, id: \.self) { i in
                            ScanRow(
                                index: i,
                                rowHeight: rowHeight,
                                isHighlighted: shouldHighlight(rowIndex: i, phase: phase)
                            )
                        }
                    }
                    .padding(.horizontal, listInset)
                    .padding(.vertical, rowHeight * 0.6)

                    // Magnifying glass moves down through the rows
                    let glassY = magnifierOffset(in: geo.size.height, phase: phase)
                    MagnifyingGlassIcon()
                        .frame(width: 56, height: 56)
                        .offset(x: geo.size.width - 70, y: glassY - 28)
                        .shadow(color: Color.snapAccent.opacity(0.30), radius: 8, x: 0, y: 4)
                }
            }
        }
    }

    private func magnifierOffset(in height: CGFloat, phase: Double) -> CGFloat {
        let inset: CGFloat = 28
        let span = height - inset * 2
        let p = (sin(phase * .pi * 2 - .pi / 2) + 1) / 2 // 0 → 1 → 0 ease
        return inset + span * CGFloat(p)
    }

    private func shouldHighlight(rowIndex: Int, phase: Double) -> Bool {
        // Each row gets a brief highlight as the glass passes its vertical band.
        let band = 1.0 / Double(rowCount + 1)
        let position = (sin(phase * .pi * 2 - .pi / 2) + 1) / 2 // 0..1
        let target = (Double(rowIndex) + 0.5) / Double(rowCount)
        return abs(position - target) < band * 0.7
    }
}

private struct ScanRow: View {
    let index: Int
    let rowHeight: CGFloat
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isHighlighted ? Color.snapAccent : Color.snapMuted)
                .frame(width: rowHeight * 0.8, height: rowHeight * 0.8)
                .overlay(
                    Group {
                        if isHighlighted {
                            Image(systemName: "checkmark")
                                .font(.system(size: rowHeight * 0.4, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                )
                .animation(.easeInOut(duration: 0.18), value: isHighlighted)

            VStack(alignment: .leading, spacing: 4) {
                Capsule()
                    .fill(barColor(highlighted: isHighlighted, intensity: 1.0))
                    .frame(width: barWidth(for: index, weight: 1.0), height: 6)
                Capsule()
                    .fill(barColor(highlighted: isHighlighted, intensity: 0.5))
                    .frame(width: barWidth(for: index, weight: 0.6), height: 4)
            }
            .animation(.easeInOut(duration: 0.18), value: isHighlighted)

            Spacer()
        }
    }

    private func barColor(highlighted: Bool, intensity: Double) -> Color {
        if highlighted {
            return Color.snapAccent.opacity(intensity)
        }
        return Color.snapMuted.opacity(intensity > 0.6 ? 1.0 : 0.7)
    }

    private func barWidth(for index: Int, weight: CGFloat) -> CGFloat {
        let bases: [CGFloat] = [110, 95, 130, 100, 120, 90]
        return bases[index % bases.count] * weight
    }
}

private struct MagnifyingGlassIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .overlay(
                    Circle().strokeBorder(Color.snapAccent, lineWidth: 3)
                )
                .frame(width: 38, height: 38)
                .offset(x: -6, y: -6)

            // Handle
            Capsule()
                .fill(Color.snapAccent)
                .frame(width: 5, height: 18)
                .rotationEffect(.degrees(45))
                .offset(x: 13, y: 13)
        }
    }
}
