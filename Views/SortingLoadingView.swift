import SwiftUI

struct SortingLoadingView: View {
    let done: Int
    let total: Int
    var onCancel: (() -> Void)? = nil

    @State private var cancelled = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.snapBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                AnimationStage()
                    .frame(width: 280, height: 220)
                    .opacity(cancelled ? 0.45 : 1)

                statusBlock
                    .padding(.top, 40)

                Spacer(minLength: 0)

                if onCancel != nil {
                    cancelButton
                        .padding(.bottom, 32)
                }
            }
            .padding(.horizontal, 32)
        }
        .interactiveDismissDisabled()
    }

    private var cancelButton: some View {
        Button {
            cancelled = true
            onCancel?()
        } label: {
            HStack(spacing: 8) {
                if cancelled {
                    ProgressView().controlSize(.small)
                    Text("Cancelling…")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(Color.snapTextMuted)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(Color.snapMuted)
            )
            .overlay(
                Capsule().strokeBorder(Color.snapBorder, lineWidth: 1)
            )
        }
        .disabled(cancelled)
        .animation(.easeInOut(duration: 0.18), value: cancelled)
    }

    private var statusBlock: some View {
        VStack(spacing: 14) {
            Text(cancelled ? "Wrapping up the current batch…" : "Sorting your screenshots")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.snapText)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.18), value: cancelled)

            Text(progressLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.snapTextMuted)
                .monospacedDigit()

            ProgressBar(fraction: fraction)
                .frame(width: 220, height: 6)
                .padding(.top, 6)
        }
    }

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(done) / Double(total)
    }

    private var progressLabel: String {
        if total == 0 { return "Preparing…" }
        return "\(done) of \(total) classified"
    }
}

// MARK: - Animation

private struct AnimationStage: View {
    private let cycle: Double = 2.6
    private let photoCount = 4

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            ZStack {
                FolderArt()
                    .frame(width: 220, height: 150)
                    .offset(y: 38)

                ForEach(0..<photoCount, id: \.self) { index in
                    let phase = phase(for: index, time: t)
                    FlyingScreenshot(phase: phase, columnIndex: index)
                }
            }
        }
    }

    private func phase(for index: Int, time: TimeInterval) -> Double {
        let stagger = cycle / Double(photoCount)
        let raw = time + Double(index) * stagger
        return raw.truncatingRemainder(dividingBy: cycle) / cycle
    }
}

private struct FlyingScreenshot: View {
    let phase: Double // 0..1
    let columnIndex: Int

    var body: some View {
        let columnX: CGFloat = (CGFloat(columnIndex) - 1.5) * 26
        let startY: CGFloat = -110
        let endY: CGFloat = 50

        let y = startY + (endY - startY) * CGFloat(phase)

        let opacity: Double = {
            if phase < 0.08 { return phase / 0.08 }
            if phase > 0.82 { return max(0, (1 - phase) / 0.18) }
            return 1
        }()

        let scale: CGFloat = {
            if phase > 0.78 {
                let t = CGFloat(phase - 0.78) / 0.22
                return max(0.25, 1 - t * 0.85)
            }
            return 1
        }()

        let rotation = sin(phase * .pi * 2 + Double(columnIndex)) * 6

        return MiniScreenshotTile()
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(x: columnX, y: y)
    }
}

private struct MiniScreenshotTile: View {
    var width: CGFloat = 44
    var height: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Capsule()
                .fill(Color.snapTextSubtle.opacity(0.45))
                .frame(width: width * 0.4, height: 2)
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(Color.snapTextSubtle.opacity(0.30))
                    .frame(height: 2)
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.snapAccentSoft)
                .frame(height: height * 0.30)
        }
        .padding(6)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.snapBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
    }
}

private struct FolderArt: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cornerRadius: CGFloat = 14
            let tabHeight = h * 0.18
            let tabWidth = w * 0.42

            ZStack {
                // Folder back
                FolderShape(cornerRadius: cornerRadius, tabHeight: tabHeight, tabWidth: tabWidth)
                    .fill(Color.snapAccent.opacity(0.18))
                FolderShape(cornerRadius: cornerRadius, tabHeight: tabHeight, tabWidth: tabWidth)
                    .strokeBorder(Color.snapAccent.opacity(0.45), lineWidth: 1.5)

                // Folder mouth (front lip — same shape, slightly raised)
                MouthShape(cornerRadius: cornerRadius)
                    .fill(Color.snapAccent)
                    .frame(height: h * 0.74)
                    .offset(y: tabHeight + h * 0.13)
                    .shadow(color: Color.snapAccent.opacity(0.30), radius: 14, x: 0, y: 8)

                // Subtle highlight on the front lip
                MouthShape(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    .frame(height: h * 0.74)
                    .offset(y: tabHeight + h * 0.13)
            }
        }
    }
}

private struct FolderShape: InsettableShape {
    var cornerRadius: CGFloat
    var tabHeight: CGFloat
    var tabWidth: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()

        // Top-left tab
        path.move(to: CGPoint(x: r.minX + cornerRadius, y: r.minY))
        path.addLine(to: CGPoint(x: r.minX + tabWidth - cornerRadius, y: r.minY))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + tabWidth + cornerRadius, y: r.minY + tabHeight),
            control: CGPoint(x: r.minX + tabWidth, y: r.minY + tabHeight * 0.6)
        )
        // Top edge of folder body
        path.addLine(to: CGPoint(x: r.maxX - cornerRadius, y: r.minY + tabHeight))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.minY + tabHeight + cornerRadius),
            control: CGPoint(x: r.maxX, y: r.minY + tabHeight)
        )
        // Right edge
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - cornerRadius, y: r.maxY),
            control: CGPoint(x: r.maxX, y: r.maxY)
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: r.minX + cornerRadius, y: r.maxY))
        path.addQuadCurve(
            to: CGPoint(x: r.minX, y: r.maxY - cornerRadius),
            control: CGPoint(x: r.minX, y: r.maxY)
        )
        // Left edge back up to tab top
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: r.minX + cornerRadius, y: r.minY),
            control: CGPoint(x: r.minX, y: r.minY)
        )

        return path
    }
}

private struct MouthShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Progress bar

private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.snapMuted)
                Capsule()
                    .fill(Color.snapAccent)
                    .frame(width: max(8, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
                    .animation(.easeInOut(duration: 0.25), value: fraction)
            }
        }
    }
}
