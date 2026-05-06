import SwiftUI

struct AppGroupCardView: View {
    let group: AppGroup
    var isSelectable: Bool = false
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScatteredThumbnailsView(
                screenshots: Array(group.screenshots.prefix(3))
            )
            .frame(height: 96)
            .frame(maxWidth: .infinity)

            HStack(alignment: .center, spacing: 10) {
                AvatarCircle(letter: group.initial, color: group.avatarColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.snapText)
                        .lineLimit(1)
                    Text(group.totalCount == 1 ? "1 shot" : "\(group.totalCount) shots")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.snapTextMuted)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .snapCard()
        .overlay(alignment: .topTrailing) {
            if isSelectable {
                SelectionCheckmark(isSelected: isSelected)
                    .padding(10)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.snapAccent, lineWidth: isSelected ? 2 : 0)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct AvatarCircle: View {
    let letter: String
    let color: Color

    var body: some View {
        Text(letter)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(color)
                    .shadow(color: color.opacity(0.30), radius: 4, x: 0, y: 2)
            )
    }
}

/// Circular selection indicator that flips between an empty stroked circle
/// and a filled accent-colored checkmark, matching the iOS Photos app pattern.
struct SelectionCheckmark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.snapAccent : Color.black.opacity(0.35))
                .frame(width: 24, height: 24)
            Circle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: 24, height: 24)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 1)
    }
}
