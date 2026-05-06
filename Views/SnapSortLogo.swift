import SwiftUI

/// Reusable SwiftUI rendering of the SnapSort logo. Used in the welcome screen
/// and elsewhere — the actual home-screen app icon ships as a PNG in
/// Assets.xcassets/AppIcon.appiconset.
struct SnapSortLogo: View {
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            // Indigo gradient background, app-icon shape
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.36, blue: 0.97),
                            Color(red: 0.27, green: 0.22, blue: 0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: size * 0.06, x: 0, y: size * 0.03)

            // Stack of two screenshot tiles
            tile(rotation: -10, offsetX: -size * 0.10, offsetY: size * 0.02)
            tile(rotation: 8, offsetX: size * 0.06, offsetY: -size * 0.03)

            // Sparkle accent
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.20, weight: .black))
                .foregroundStyle(.white)
                .offset(x: size * 0.27, y: -size * 0.27)
                .shadow(color: .black.opacity(0.18), radius: size * 0.02, x: 0, y: size * 0.01)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("SnapSort")
    }

    private func tile(rotation: Double, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(Color.white)

            VStack(spacing: size * 0.04) {
                Spacer().frame(height: size * 0.06)
                Capsule()
                    .fill(Color(red: 0.27, green: 0.22, blue: 0.84).opacity(0.20))
                    .frame(width: size * 0.18, height: size * 0.025)
                Capsule()
                    .fill(Color(red: 0.27, green: 0.22, blue: 0.84).opacity(0.14))
                    .frame(width: size * 0.28, height: size * 0.022)
                Spacer()
            }
            .frame(width: size * 0.36, height: size * 0.50)
        }
        .frame(width: size * 0.36, height: size * 0.50)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: max(1, size * 0.012))
        )
        .shadow(color: .black.opacity(0.18), radius: size * 0.04, x: 0, y: size * 0.02)
        .rotationEffect(.degrees(rotation))
        .offset(x: offsetX, y: offsetY)
    }
}

#Preview {
    HStack(spacing: 24) {
        SnapSortLogo(size: 56)
        SnapSortLogo(size: 96)
        SnapSortLogo(size: 144)
    }
    .padding(40)
    .background(Color.snapBg)
}
