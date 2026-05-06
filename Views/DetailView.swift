import SwiftUI
import Photos

struct DetailView: View {
    @EnvironmentObject private var viewModel: ScreenshotsViewModel
    let appName: String

    @State private var presentedItem: ScreenshotItem?

    // Select mode
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var pendingDeleteBatch = false

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.snapBg.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.screenshots(for: appName)) { item in
                        thumbnailTile(for: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, isSelecting ? 100 : 32)
            }
            .scrollIndicators(.hidden)

            if isSelecting {
                selectionToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSelecting)
        .navigationTitle(appName)
        .navigationBarTitleDisplayMode(.large)
        .tint(.snapAccent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.screenshots(for: appName).isEmpty {
                    Button(isSelecting ? "Done" : "Select") {
                        if isSelecting { exitSelectionMode() } else { isSelecting = true }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.snapAccent)
                }
            }
        }
        .fullScreenCover(item: $presentedItem) { item in
            FullScreenImageView(item: item)
        }
        .alert(
            deleteAlertTitle,
            isPresented: $pendingDeleteBatch
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    let ids = selectedIDs
                    let toDelete = viewModel.screenshots(for: appName).filter { ids.contains($0.id) }
                    await viewModel.deleteScreenshots(toDelete)
                    exitSelectionMode()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected screenshots will be removed from your Photos library. This can't be undone.")
        }
    }

    private var deleteAlertTitle: String {
        let n = selectedIDs.count
        return n == 1 ? "Delete 1 screenshot?" : "Delete \(n) screenshots?"
    }

    private func exitSelectionMode() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    @ViewBuilder
    private func thumbnailTile(for item: ScreenshotItem) -> some View {
        GridThumbnail(
            item: item,
            isSelectable: isSelecting,
            isSelected: selectedIDs.contains(item.id)
        )
        .onTapGesture {
            if isSelecting {
                toggle(item)
            } else {
                presentedItem = item
            }
        }
        .contextMenu {
            if !isSelecting {
                Button {
                    isSelecting = true
                    selectedIDs.insert(item.id)
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
                Button(role: .destructive) {
                    Task { await viewModel.deleteScreenshot(item) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func toggle(_ item: ScreenshotItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedIDs.isEmpty ? "Select screenshots" : "\(selectedIDs.count) selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.snapText)
            }
            Spacer()
            Button {
                pendingDeleteBatch = true
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
                    Capsule().fill(selectedIDs.isEmpty ? Color.snapTextSubtle : Color.red)
                )
            }
            .disabled(selectedIDs.isEmpty)
            .animation(.easeInOut(duration: 0.15), value: selectedIDs.isEmpty)
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

private struct GridThumbnail: View {
    let item: ScreenshotItem
    let isSelectable: Bool
    let isSelected: Bool

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.snapMuted
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width * 1.4)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.snapAccent : Color.snapBorder,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                .opacity(isSelectable && !isSelected ? 0.85 : 1.0)

                if isSelectable {
                    SelectionCheckmark(isSelected: isSelected)
                        .padding(8)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .task(id: item.id) {
                let loader = PhotoLibraryService()
                let target = CGSize(
                    width: geo.size.width * 3,
                    height: geo.size.width * 3 * 1.4
                )
                let img = await loader.loadThumbnail(for: item.asset, targetSize: target)
                await MainActor.run { self.image = img }
            }
        }
        .aspectRatio(1.0 / 1.4, contentMode: .fit)
    }
}
