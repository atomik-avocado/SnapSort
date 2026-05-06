import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @Environment(\.dismiss) private var dismiss

    let isFirstLaunch: Bool

    @State private var draftKey: String = ""
    @State private var draftModel: String = ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.snapBg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        keyCard
                        modelCard
                        saveButton

                        if configStore.hasAPIKey {
                            Button(role: .destructive, action: clear) {
                                Text("Remove Saved Key")
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
        .onAppear {
            draftKey = configStore.apiKey ?? ""
            draftModel = configStore.modelOverride ?? ""
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            SnapSortLogo(size: 64)

            Text(isFirstLaunch ? "Welcome to SnapSort" : "Settings")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.snapText)

            Text("SnapSort uses Mistral AI's Pixtral vision model to identify which app each screenshot was taken in. Add your API key to get started.")
                .font(.system(size: 14))
                .foregroundStyle(Color.snapTextMuted)
                .lineSpacing(2)
        }
        .padding(.bottom, 4)
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mistral AI API Key")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            SecureField("API key", text: $draftKey)
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

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vision Model")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.snapTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            modelMenu

            Text("Pixtral 12B is the default. Larger models are more accurate but cost more per request.")
                .font(.system(size: 12))
                .foregroundStyle(Color.snapTextSubtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .snapCard()
    }

    private var modelMenu: some View {
        Menu {
            ForEach(ConfigStore.availableModels) { option in
                Button {
                    draftModel = option.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.name)
                            Text(option.id)
                                .font(.caption)
                        }
                        Spacer()
                        if option.id == effectiveDraftModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentModelName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.snapText)
                    Text(currentModelTagline)
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
    }

    private var effectiveDraftModel: String {
        let trimmed = draftModel.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? ConfigStore.defaultModel : trimmed
    }

    private var currentModelOption: ConfigStore.ModelOption? {
        ConfigStore.option(for: effectiveDraftModel)
    }

    private var currentModelName: String {
        currentModelOption?.name ?? effectiveDraftModel
    }

    private var currentModelTagline: String {
        currentModelOption?.tagline ?? "Custom model"
    }

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
        !draftKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        configStore.saveKey(draftKey)
        configStore.saveModel(draftModel)
        saved = true
        if !isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        }
    }

    private func clear() {
        configStore.clearKey()
        configStore.saveModel("")
        draftKey = ""
        draftModel = ""
        saved = false
    }
}
