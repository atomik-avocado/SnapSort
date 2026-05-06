import SwiftUI

@main
struct SnapSortApp: App {
    @StateObject private var configStore: ConfigStore
    @StateObject private var knownAppsStore: KnownAppsStore
    @StateObject private var viewModel: ScreenshotsViewModel
    private let visionService: VisionService

    init() {
        let config = ConfigStore()
        let known = KnownAppsStore()
        let cache = ClassificationCache()
        let mistral = MistralClient(config: config)
        let vision = VisionService(mistral: mistral)
        let library = PhotoLibraryService()
        let coordinator = ClassificationCoordinator(
            vision: vision,
            cache: cache,
            library: library
        )
        let vm = ScreenshotsViewModel(
            library: library,
            coordinator: coordinator,
            cache: cache,
            knownApps: known
        )
        _configStore = StateObject(wrappedValue: config)
        _knownAppsStore = StateObject(wrappedValue: known)
        _viewModel = StateObject(wrappedValue: vm)
        self.visionService = vision
    }

    var body: some Scene {
        WindowGroup {
            RootView(vision: visionService)
                .environmentObject(configStore)
                .environmentObject(knownAppsStore)
                .environmentObject(viewModel)
                .tint(.snapAccent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @EnvironmentObject private var knownAppsStore: KnownAppsStore

    let vision: VisionService

    var body: some View {
        Group {
            if !configStore.hasAPIKey {
                SettingsView(isFirstLaunch: true)
            } else if !knownAppsStore.hasCompletedSetup {
                AppDetectionView(vision: vision, knownAppsStore: knownAppsStore)
            } else {
                DashboardView(vision: vision)
            }
        }
    }
}
