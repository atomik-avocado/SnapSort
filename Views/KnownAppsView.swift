import SwiftUI
import PhotosUI

struct KnownAppsView: View {
    @EnvironmentObject private var knownAppsStore: KnownAppsStore
    @Environment(\.dismiss) private var dismiss

    let vision: VisionService

    @State private var newAppName = ""
    @State private var presentScan = false
    @State private var pendingDelete: KnownApp?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.snapBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        addCard
                        if knownAppsStore.apps.isEmpty {
                            emptyCard
                        } else {
                            listCard
                        }
                        Button {
                            presentScan = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "viewfinder.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Detect More from Screenshots")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color.snapAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.snapAccentSoft)
                            )
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Apps")
            .navigationBarTitleDisplayMode(.large)
            .tint(.snapAccent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .fullScreenCover(isPresented: $presentScan) {
                NavigationStack {
                    AppDetectionView(vision: vision, knownAppsStore: knownAppsStore)
                        .navigationTitle("Detect Apps")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { presentScan = false }
                            }
                        }
                }
                .onChange(of: knownAppsStore.apps.count) { _, _ in
                    // dismiss handled by user via Close
                }
            }
            .alert(
                "Remove app?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { app in
                Button("Remove", role: .destructive) {
                    knownAppsStore.remove(app)
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { app in
                Text("\(app.name) will no longer be used as a hint when classifying screenshots.")
            }
        }
    }

    // MARK: - Sections

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add an App")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 10) {
                TextField("App name", text: $newAppName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(size: 14))
                    .foregroundStyle(Color.snapText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.snapMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.snapBorder, lineWidth: 1)
                    )
                    .onSubmit(addManual)

                Button(action: addManual) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(canAdd ? Color.snapAccent : Color.snapTextSubtle)
                        )
                }
                .disabled(!canAdd)
                .animation(.easeInOut(duration: 0.15), value: canAdd)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(knownAppsStore.apps.count) apps")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.snapTextMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(Array(knownAppsStore.sortedApps.enumerated()), id: \.element.id) { idx, app in
                AppRow(app: app, onDelete: { pendingDelete = app })
                if idx < knownAppsStore.apps.count - 1 {
                    Divider().background(Color.snapDivider)
                        .padding(.leading, 50)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.snapTextSubtle)
            Text("No apps yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.snapText)
            Text("Add one above or detect them from screenshots.")
                .font(.system(size: 12))
                .foregroundStyle(Color.snapTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .snapCard()
    }

    private var canAdd: Bool {
        let trimmed = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }

    private func addManual() {
        let trimmed = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        knownAppsStore.addManual(trimmed)
        newAppName = ""
    }
}

private struct AppRow: View {
    let app: KnownApp
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.snapAccentSoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(app.name.first ?? "?").uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.snapAccent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.snapText)
                Text(app.source == .detected ? "Detected" : "Manually added")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.snapTextMuted)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.snapTextSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
