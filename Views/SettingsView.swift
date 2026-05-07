import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @Environment(\.dismiss) private var dismiss

    let isFirstLaunch: Bool
    let vision: VisionService?

    init(isFirstLaunch: Bool, vision: VisionService? = nil) {
        self.isFirstLaunch = isFirstLaunch
        self.vision = vision
    }

    @State private var draftMistralKey: String = ""
    @State private var draftMistralModel: String = ""
    @State private var draftOllamaURL: String = ""
    @State private var draftOllamaModel: String = ""
    @State private var saved = false

    @State private var ollamaTestState: OllamaTestState = .idle

    enum OllamaTestState: Equatable {
        case idle
        case testing
        case success(modelCount: Int)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.snapBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        backendPicker

                        switch configStore.backend {
                        case .mistral:
                            mistralKeyCard
                            mistralModelCard
                        case .ollama:
                            ollamaURLCard
                            ollamaModelCard
                        }

                        saveButton

                        if removeKeyVisible {
                            Button(role: .destructive, action: clear) {
                                Text(removeKeyLabel)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(isFirstLaunch ? "Welcome" : "Settings")
            .navigationBarTitleDisplayMode(.large)
            .tint(.snapAccent)
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
        .onAppear { syncDrafts() }
        .onChange(of: configStore.backend) { _, _ in
            syncDrafts()
            ollamaTestState = .idle
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            SnapSortLogo(size: 64)

            Text(isFirstLaunch ? "Welcome to SnapSort" : "Settings")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.snapText)

            Text("SnapSort uses a vision model to identify which app each screenshot was taken in. Pick a backend to get started.")
                .font(.system(size: 14))
                .foregroundStyle(Color.snapTextMuted)
                .lineSpacing(2)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Backend picker

    private var backendPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Backend")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            VStack(spacing: 10) {
                ForEach(AIBackend.allCases) { backend in
                    BackendRow(
                        backend: backend,
                        isActive: configStore.backend == backend,
                        hasConfig: hasConfig(for: backend)
                    ) {
                        configStore.setBackend(backend)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private func hasConfig(for backend: AIBackend) -> Bool {
        switch backend {
        case .mistral: return configStore.hasMistralKey
        case .ollama:  return configStore.hasOllamaURL
        }
    }

    // MARK: - Mistral cards

    private var mistralKeyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mistral AI API Key")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            SecureField("API key", text: $draftMistralKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.snapText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.snapMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.snapBorder, lineWidth: 1)
                )

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Stored locally on this device. Get a free key at console.mistral.ai.")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.snapTextSubtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private var mistralModelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vision Model")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            mistralModelMenu

            Text("Pixtral 12B is the default. Larger models are more accurate but cost more per request.")
                .font(.system(size: 12))
                .foregroundStyle(Color.snapTextSubtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private var mistralModelMenu: some View {
        Menu {
            ForEach(ConfigStore.availableMistralModels) { option in
                Button {
                    draftMistralModel = option.id
                } label: {
                    menuRow(option: option, isSelected: option.id == effectiveMistralDraftModel)
                }
            }
        } label: {
            menuTrigger(name: currentMistralModelName, subtitle: currentMistralModelTagline)
        }
    }

    // MARK: - Ollama cards

    private var ollamaURLCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ollama Server URL")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            TextField(ConfigStore.defaultOllamaBaseURL, text: $draftOllamaURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.snapText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.snapMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.snapBorder, lineWidth: 1)
                )
                .onChange(of: draftOllamaURL) { _, _ in ollamaTestState = .idle }

            ollamaTestRow

            Text("Run `OLLAMA_HOST=0.0.0.0 ollama serve` on your computer, then point this at its LAN IP, e.g. http://192.168.1.50:11434.")
                .font(.system(size: 12))
                .foregroundStyle(Color.snapTextSubtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private var ollamaTestRow: some View {
        HStack(spacing: 8) {
            Button(action: testOllama) {
                HStack(spacing: 6) {
                    if case .testing = ollamaTestState {
                        ProgressView().controlSize(.mini).tint(Color.snapAccent)
                    } else {
                        Image(systemName: "wifi")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text("Test connection")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.snapAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.snapAccentSoft))
            }
            .disabled({
                if case .testing = ollamaTestState { return true }
                return draftOllamaURL.trimmingCharacters(in: .whitespaces).isEmpty
            }())

            ollamaStatusLabel
        }
    }

    @ViewBuilder
    private var ollamaStatusLabel: some View {
        switch ollamaTestState {
        case .idle:
            EmptyView()
        case .testing:
            Text("Pinging server…")
                .font(.system(size: 12))
                .foregroundStyle(Color.snapTextMuted)
        case .success(let n):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(n == 0 ? "Connected (no models)" : "Connected · \(n) model\(n == 1 ? "" : "s")")
                    .foregroundStyle(Color.snapTextMuted)
            }
            .font(.system(size: 12, weight: .medium))
        case .failure(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .foregroundStyle(Color.snapTextMuted)
                    .lineLimit(2)
            }
            .font(.system(size: 11))
        }
    }

    private var ollamaModelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ollama Model")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            ollamaModelMenu

            customModelField

            Text("Pull the model first on your computer: `ollama pull llama3.2-vision`")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.snapTextSubtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private var ollamaModelMenu: some View {
        Menu {
            ForEach(ConfigStore.suggestedOllamaModels) { option in
                Button {
                    draftOllamaModel = option.id
                } label: {
                    menuRow(option: option, isSelected: option.id == effectiveOllamaDraftModel)
                }
            }
        } label: {
            menuTrigger(name: currentOllamaModelName, subtitle: currentOllamaModelTagline)
        }
    }

    private var customModelField: some View {
        TextField("Or enter a custom tag (e.g. llava:13b)", text: $draftOllamaModel)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(Color.snapText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.snapMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.snapBorder, lineWidth: 1)
            )
    }

    // MARK: - Reusable menu pieces

    private func menuRow(option: ConfigStore.ModelOption, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.name)
                Text(option.id).font(.caption)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }

    private func menuTrigger(name: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.snapText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.snapTextMuted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.snapTextSubtle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.snapMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.snapBorder, lineWidth: 1)
        )
    }

    // MARK: - Save / clear

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: saved ? "checkmark" : "key.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(saved ? "Saved" : "Save")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(canSave ? Color.snapAccent : Color.snapTextSubtle)
            )
            .shadow(
                color: canSave ? Color.snapAccent.opacity(0.25) : .clear,
                radius: 12, x: 0, y: 6
            )
        }
        .disabled(!canSave)
        .animation(.easeInOut(duration: 0.2), value: canSave)
        .animation(.easeInOut(duration: 0.2), value: saved)
    }

    private var canSave: Bool {
        switch configStore.backend {
        case .mistral:
            return !draftMistralKey.trimmingCharacters(in: .whitespaces).isEmpty
        case .ollama:
            return !draftOllamaURL.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var removeKeyVisible: Bool {
        switch configStore.backend {
        case .mistral: return configStore.hasMistralKey
        case .ollama:  return configStore.hasOllamaURL
        }
    }

    private var removeKeyLabel: String {
        switch configStore.backend {
        case .mistral: return "Remove Saved Key"
        case .ollama:  return "Remove Server URL"
        }
    }

    private func save() {
        switch configStore.backend {
        case .mistral:
            configStore.saveMistralKey(draftMistralKey)
            configStore.saveMistralModel(draftMistralModel)
        case .ollama:
            configStore.saveOllamaBaseURL(draftOllamaURL)
            configStore.saveOllamaModel(draftOllamaModel)
        }
        saved = true
        if !isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        }
    }

    private func clear() {
        switch configStore.backend {
        case .mistral:
            configStore.clearMistralKey()
            configStore.saveMistralModel("")
            draftMistralKey = ""
            draftMistralModel = ""
        case .ollama:
            configStore.clearOllamaBaseURL()
            configStore.saveOllamaModel("")
            draftOllamaURL = ""
            draftOllamaModel = ""
        }
        saved = false
    }

    // MARK: - Test connection

    private func testOllama() {
        guard let vision else { return }
        let trimmed = draftOllamaURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Persist the URL so OllamaClient.ping uses it.
        configStore.saveOllamaBaseURL(trimmed)
        ollamaTestState = .testing

        Task {
            do {
                let models = try await vision.availableModels()
                await MainActor.run {
                    ollamaTestState = .success(modelCount: models.count)
                }
            } catch {
                await MainActor.run {
                    ollamaTestState = .failure(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Drafts

    private func syncDrafts() {
        draftMistralKey = configStore.mistralKey ?? ""
        draftMistralModel = configStore.mistralModelOverride ?? ""
        draftOllamaURL = configStore.ollamaBaseURL ?? ""
        draftOllamaModel = configStore.ollamaModelOverride ?? ""
        saved = false
    }

    // MARK: - Resolved drafts

    private var effectiveMistralDraftModel: String {
        let t = draftMistralModel.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? ConfigStore.defaultMistralModel : t
    }

    private var currentMistralModelOption: ConfigStore.ModelOption? {
        ConfigStore.mistralOption(for: effectiveMistralDraftModel)
    }

    private var currentMistralModelName: String {
        currentMistralModelOption?.name ?? effectiveMistralDraftModel
    }

    private var currentMistralModelTagline: String {
        currentMistralModelOption?.tagline ?? "Custom model"
    }

    private var effectiveOllamaDraftModel: String {
        let t = draftOllamaModel.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? ConfigStore.defaultOllamaModel : t
    }

    private var currentOllamaModelOption: ConfigStore.ModelOption? {
        ConfigStore.ollamaOption(for: effectiveOllamaDraftModel)
    }

    private var currentOllamaModelName: String {
        currentOllamaModelOption?.name ?? effectiveOllamaDraftModel
    }

    private var currentOllamaModelTagline: String {
        currentOllamaModelOption?.tagline ?? "Custom tag"
    }
}

// MARK: - Backend row

private struct BackendRow: View {
    let backend: AIBackend
    let isActive: Bool
    let hasConfig: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: backend.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? .white : Color.snapAccent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(isActive ? Color.snapAccent : Color.snapAccentSoft)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(backend.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.snapText)
                    Text(backend.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.snapTextMuted)
                }

                Spacer()

                if hasConfig {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.snapAccent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? Color.snapAccentSoft : Color.snapMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? Color.snapAccent : Color.snapBorder,
                                  lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
