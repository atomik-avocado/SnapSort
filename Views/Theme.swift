import SwiftUI
import UIKit

/// Tailwind-inspired palette that adapts to the device's light/dark mode.
/// Built on `UIColor(dynamicProvider:)` so each named color resolves
/// automatically based on the surrounding trait collection.
private func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

private extension UIColor {
    convenience init(rgb r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension Color {
    // MARK: - Surfaces
    /// App background — slate-50 / slate-950
    static let snapBg = dynamic(
        UIColor(rgb: 0.969, 0.976, 0.988),
        UIColor(rgb: 0.020, 0.024, 0.039)
    )

    /// Card surface — white / slate-900
    static let snapCard = dynamic(
        UIColor.white,
        UIColor(rgb: 0.094, 0.114, 0.169)
    )

    /// Subtle filled surface for chips, inputs — slate-100 / slate-800
    static let snapMuted = dynamic(
        UIColor(rgb: 0.953, 0.961, 0.973),
        UIColor(rgb: 0.118, 0.161, 0.231)
    )

    /// Borders — slate-200 / slate-800
    static let snapBorder = dynamic(
        UIColor(rgb: 0.886, 0.910, 0.941),
        UIColor(rgb: 0.118, 0.161, 0.231)
    )

    /// Dividers — slightly softer than borders
    static let snapDivider = dynamic(
        UIColor(rgb: 0.929, 0.945, 0.965),
        UIColor(rgb: 0.094, 0.114, 0.169)
    )

    // MARK: - Text
    /// Primary text — slate-900 / slate-50
    static let snapText = dynamic(
        UIColor(rgb: 0.059, 0.090, 0.165),
        UIColor(rgb: 0.969, 0.976, 0.988)
    )

    /// Muted text — slate-500 / slate-400
    static let snapTextMuted = dynamic(
        UIColor(rgb: 0.392, 0.455, 0.545),
        UIColor(rgb: 0.580, 0.639, 0.722)
    )

    /// Subtle text — slate-400 / slate-500
    static let snapTextSubtle = dynamic(
        UIColor(rgb: 0.580, 0.639, 0.722),
        UIColor(rgb: 0.392, 0.455, 0.545)
    )

    // MARK: - Accent (indigo)
    /// Brand accent — indigo-600 / indigo-400
    static let snapAccent = dynamic(
        UIColor(rgb: 0.310, 0.275, 0.898),
        UIColor(rgb: 0.506, 0.467, 0.969)
    )

    /// Pressed/hover accent — indigo-700 / indigo-300
    static let snapAccentHover = dynamic(
        UIColor(rgb: 0.263, 0.227, 0.776),
        UIColor(rgb: 0.624, 0.604, 1.000)
    )

    /// Tinted accent fill — indigo-100 / indigo-950 (alpha-mixed)
    static let snapAccentSoft = dynamic(
        UIColor(rgb: 0.929, 0.910, 1.000),
        UIColor(rgb: 0.180, 0.157, 0.380)
    )
}

struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.snapCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.snapBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func snapCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}
