import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: ScreenshotsViewModel
    @EnvironmentObject private var knownAppsStore: KnownAppsStore

    let vision: VisionService

    @State private var showSettings = false
    @State private var showApps = false
    @State private var showSortScreen = false

    // Select mode
    @State private var isSelecting = false
    @State private var selectedGroups: Set<String> = []
    @State private var pendingDeleteGroups = false

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.snapBg.ignoresSafeArea()
                content

                if isSelecting {
                    selectionToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isSelecting)
            .navigationTitle("Screenshots")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { topBarToolbar }
            .sheet(isPresented: $showSettings) {
                SettingsView(isFirstLaunch: false)
            }
            .sheet(isPresented: $showApps) {
                KnownAppsView(vision: vision)
            }
            .fullScreenCover(isPresented: $showSortScreen) {
                SortingLoadingView(
                    done: progressDone,
                    total: progressTotal
                )
            }
            .alert(
                deleteAlertTitle,
                isPresented: $pendingDeleteGroups
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        let toDelete = selectedGroups
                        await viewModel.deleteGroups(named: toDelete)
                        exitSelectionMode()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteAlertMessage)
            }
        }
        .task { await viewModel.bootstrap() }
        .tint(.snapAccent)
    }

    @ToolbarContentBuilder
    private var topBarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !viewModel.groups.isEmpty {
                Button(isSelecting ? "Done" : "Select") {
                    if isSelecting { exitSelectionMode() } else { isSelecting = true }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.snapAccent)
            }
        }
    }

    private func exitSelectionMode() {
        isSelecting = false
        selectedGroups.removeAll()
    }

    private var deleteAlertTitle: String {
        let total = totalSelectedScreenshots
        return total == 1 ? "Delete 1 screenshot?" : "Delete \(total) screenshots?"
    }

    private var deleteAlertMessage: String {
        let groupCount = selectedGroups.count
        let groupLabel = groupCount == 1 ? "1 group" : "\(groupCount) groups"
        return "Every screenshot in \(groupLabel) will be removed from your Photos library. This can't be undone."
    }

    private var totalSelectedScreenshots: Int {
        viewModel.groups
            .filter { selectedGroups.contains($0.name) }
            .reduce(0) { $0 + $1.totalCount }
    }

    private var progressDone: Int {
        if case .classifying(let d, _) = viewModel.state { return d }
        return 0
    }

    private var progressTotal: Int {
        if case .classifying(_, let t) = viewModel.state { return t }
        return 0
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .requestingPermission, .loading:
            CenteredLoading(label: "Loading screenshots…")
        case .permissionDenied:
            PermissionDeniedView()
        case .classifying, .ready:
            mainScroll
        }
    }

    private var mainScroll: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryHeader
                if let error = viewModel.lastError {
                    ErrorBanner(message: error) { viewModel.dismissError() }
                }
                if !isSelecting {
                    sortButton
                }

                if !viewModel.groups.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(viewModel.groups) { group in
                            groupCard(for: group)
                        }
                    }
                } else {
                    emptyCard
                }

                if !isSelecting {
                    actionLinks
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, isSelecting ? 100 : 36)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func groupCard(for group: AppGroup) -> some View {
        if isSelecting {
            Button {
                toggleSelection(for: group.name)
            } label: {
                AppGroupCardView(
                    group: group,
                    isSelectable: true,
                    isSelected: selectedGroups.contains(group.name)
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                DetailView(appName: group.name)
            } label: {
                AppGroupCardView(group: group)
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleSelection(for name: String) {
        if selectedGroups.contains(name) {
            selectedGroups.remove(name)
        } else {
            selectedGroups.insert(name)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 0) {
            summaryText
            Spacer(minLength: 8)
            if viewModel.pendingCount > 0 && !viewModel.isClassifying && !isSelecting {
                PendingChip(count: viewModel.pendingCount)
            }
        }
        .padding(.horizontal, 4)
    }

    private var summaryText: Text {
        let groupCount = viewModel.groups.count
        let totalCount = viewModel.totalScreenshots
        let appsLabel = groupCount == 1 ? " app" : " apps"
        let screensLabel = totalCount == 1 ? " screenshot" : " screenshots"

        let count1 = Text("\(groupCount)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.snapAccent)
        let label1 = Text(appsLabel)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color.snapTextMuted)
        let separator = Text(" · ")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color.snapTextSubtle)
        let count2 = Text("\(totalCount)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.snapAccent)
        let label2 = Text(screensLabel)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color.snapTextMuted)

        return count1 + label1 + separator + count2 + label2
    }

    private var sortButton: some View {
        Button {
            showSortScreen = true
            Task {
                let start = Date()
                await viewModel.sort()
                let elapsed = Date().timeIntervalSince(start)
                if elapsed < 0.6 {
                    try? await Task.sleep(nanoseconds: UInt64((0.6 - elapsed) * 1_000_000_000))
                }
                showSortScreen = false
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isClassifying {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                    Text(progressLabel)
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Sort")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.snapAccent)
            )
            .shadow(color: Color.snapAccent.opacity(0.30), radius: 14, x: 0, y: 8)
        }
        .disabled(viewModel.isClassifying)
        .opacity(viewModel.isClassifying ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isClassifying)
    }

    private var progressLabel: String {
        if case .classifying(let done, let total) = viewModel.state {
            return "Sorting \(done) / \(total)…"
        }
        return "Sorting…"
    }

    private var emptyCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.snapTextSubtle)
            Text("No sorted screenshots yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.snapText)
            Text(viewModel.totalScreenshots == 0
                 ? "Take a screenshot, then tap Sort."
                 : "Tap Sort to classify your screenshots.")
                .font(.system(size: 13))
                .foregroundStyle(Color.snapTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .snapCard()
    }

    private var actionLinks: some View {
        HStack(spacing: 10) {
            PillLink(icon: "square.grid.2x2.fill", label: "Apps (\(knownAppsStore.apps.count))") {
                showApps = true
            }
            PillLink(icon: "key.fill", label: "Settings") {
                showSettings = true
            }
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedGroups.isEmpty ? "Select groups" : "\(selectedGroups.count) selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.snapText)
                if !selectedGroups.isEmpty {
                    Text("\(totalSelectedScreenshots) screenshot\(totalSelectedScreenshots == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.snapTextMuted)
                        .monospacedDigit()
                }
            }
            Spacer()
            Button {
                pendingDeleteGroups = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Delete")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selectedGroups.isEmpty ? Color.snapTextSubtle : Color.red)
                )
            }
            .disabled(selectedGroups.isEmpty)
            .animation(.easeInOut(duration: 0.15), value: selectedGroups.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.snapBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

private struct PillLink: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Color.snapTextMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.snapMuted)
            )
            .overlay(
                Capsule().strokeBorder(Color.snapBorder, lineWidth: 1)
            )
        }
    }
}

private struct PendingChip: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.orange)
                .frame(width: 6, height: 6)
            Text("\(count) pending")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.snapMuted)
        )
    }
}

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sorting hit an error")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.snapText)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.snapTextMuted)
                    .lineLimit(4)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.snapTextSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.30), lineWidth: 1)
        )
    }
}

private struct CenteredLoading: View {
    let label: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.snapAccent)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.snapTextMuted)
        }
    }
}

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.snapTextSubtle)
            Text("Photos access required")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.snapText)
            Text("Enable Photos access in Settings so SnapSort can read your screenshots.")
                .multilineTextAlignment(.center)
                .font(.system(size: 13))
                .foregroundStyle(Color.snapTextMuted)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.snapAccent)
                    )
            }
            .padding(.top, 4)
        }
        .padding()
    }
}
