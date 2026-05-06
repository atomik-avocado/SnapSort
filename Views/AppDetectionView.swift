import SwiftUI
import PhotosUI

struct AppDetectionView: View {
    @StateObject private var viewModel: AppDetectionViewModel
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showPicker = false

    init(vision: VisionService, knownAppsStore: KnownAppsStore) {
        _viewModel = StateObject(
            wrappedValue: AppDetectionViewModel(
                vision: vision,
                knownAppsStore: knownAppsStore
            )
        )
    }

    var body: some View {
        ZStack {
            Color.snapBg.ignoresSafeArea()
            content
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(.snapAccent)
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickedItems,
            maxSelectionCount: 30,
            matching: .screenshots
        )
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await viewModel.process(items: items)
                pickedItems = []
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            IntroPanel(onChoose: { showPicker = true }, onSkip: { viewModel.skipSetup() })
        case .loadingImages:
            ScanningPanel(label: "Loading screenshots…", done: 0, total: 0)
        case .detecting(let done, let total):
            ScanningPanel(label: "Detecting apps…", done: done, total: total)
        case .review(let names, let skipped):
            ReviewPanel(
                names: names,
                skipped: skipped,
                onSave: {
                    viewModel.saveDetected(names)
                },
                onScanMore: {
                    viewModel.reset()
                }
            )
        case .error(let message):
            ErrorPanel(message: message,
                       onRetry: { viewModel.reset() },
                       onSkip: { viewModel.skipSetup() })
        }
    }
}

// MARK: - Panels

private struct IntroPanel: View {
    let onChoose: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                SnapSortLogo(size: 64)
                Text("Teach SnapSort your apps")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.snapText)
                Text("On your iPhone, open Settings → Apps and take screenshots of the full list. SnapSort uses them to learn which apps you have so it can sort more accurately.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.snapTextMuted)
                    .lineSpacing(3)
            }

            stepsCard

            Button(action: onChoose) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Choose Screenshots")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.snapAccent)
                )
                .shadow(color: Color.snapAccent.opacity(0.3), radius: 12, x: 0, y: 6)
            }

            Button(action: onSkip) {
                Text("Skip for now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.snapTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            Spacer(minLength: 0)
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepRow(number: 1, text: "Open Settings → Apps on this phone")
            stepRow(number: 2, text: "Scroll and screenshot every page")
            stepRow(number: 3, text: "Come back and pick those screenshots")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapAccent)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.snapAccentSoft))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.snapText)
        }
    }
}

private struct ScanningPanel: View {
    let label: String
    let done: Int
    let total: Int

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            MagnifyingScanAnimation()
                .frame(width: 240, height: 220)

            VStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.snapText)
                if total > 0 {
                    Text("\(done) of \(total) screenshots")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.snapTextMuted)
                        .monospacedDigit()
                }
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReviewPanel: View {
    let names: [String]
    let skipped: Int
    let onSave: () -> Void
    let onScanMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Found \(names.count) apps")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.snapText)
                if skipped > 0 {
                    Text("\(skipped) screenshot\(skipped == 1 ? "" : "s") couldn't be read.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.snapTextMuted)
                } else {
                    Text("Tap Save to teach SnapSort these apps.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.snapTextMuted)
                }
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(names.enumerated()), id: \.offset) { idx, name in
                        DetectedRow(name: name)
                        if idx < names.count - 1 {
                            Divider().background(Color.snapDivider)
                                .padding(.leading, 36)
                        }
                    }
                }
            }
            .frame(maxHeight: 360)
            .snapCard()

            VStack(spacing: 10) {
                Button(action: onSave) {
                    Text("Save \(names.count) Apps")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.snapAccent)
                        )
                        .shadow(color: Color.snapAccent.opacity(0.25), radius: 10, x: 0, y: 6)
                }
                Button(action: onScanMore) {
                    Text("Scan More")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.snapTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct DetectedRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.snapAccent)
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.snapText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ErrorPanel: View {
    let message: String
    let onRetry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.orange)

            Text("Detection failed")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.snapText)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.snapTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.snapAccent)
                        )
                }
                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.snapTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }
}
