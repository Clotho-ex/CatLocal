import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CatRecord]

    @AppStorage(CatLocalUserDefaults.appearanceKey) private var appearance = CatLocalAppearance.system
    @AppStorage(CatLocalUserDefaults.cardMotionEnabledKey) private var cardMotionEnabled = true
    @AppStorage(CatLocalUserDefaults.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(CatLocalUserDefaults.languageKey) private var language = CatLocalLanguage.system

    @State private var storageText = "Calculating..."
    @State private var storageByteCount: Int64?
    @State private var showingDeleteConfirmation = false
    @State private var showingStorageError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                preferencesSection
                storageSection
                informationSection
            }
            .accessibilityIdentifier("settings-list")
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { CatLocalBackground() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .modifier(SettingsNavigationBackgroundModifier())
            .tint(CatLocalTheme.blueAction)
        }
        .id(language)
        .task {
            await refreshStorage()
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            CatDeletionConfirmationSheet(
                title: "Delete every cat?",
                message: "This permanently removes every saved cat from this iPhone.",
                detail: storageDeletionDetail,
                deleteTitle: "Delete All"
            ) {
                showingDeleteConfirmation = false
                Task { await deleteAll() }
            } onCancel: {
                showingDeleteConfirmation = false
            }
        }
        .alert("Could not update storage", isPresented: $showingStorageError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .accessibilityIdentifier("settings-screen")
    }

    private var preferencesSection: some View {
        Section {
            if CatLocalLanguage.shouldOfferEnglishFallback() {
                Button {
                    language = CatLocalLanguage.englishFallbackSelection(from: language)
                } label: {
                    SettingsRowLabel(
                        title: language == .english ? "Use System Language" : "Use English",
                        detail: language == .english
                            ? "Return to your iOS language."
                            : "Switch CatLocal to English.",
                        systemImage: "globe"
                    )
                }
                .accessibilityIdentifier("settings-language-fallback")
            }

            Picker(selection: $appearance) {
                ForEach(CatLocalAppearance.allCases) { option in
                    Text(catLocalKey: option.title).tag(option)
                }
            } label: {
                SettingsRowLabel(
                    title: "Appearance",
                    detail: nil,
                    systemImage: "circle.lefthalf.filled"
                )
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings-appearance-picker")

            Toggle(isOn: $cardMotionEnabled) {
                SettingsRowLabel(
                    title: "Card Motion",
                    detail: "Tilt, foil lighting, and reveal motion.",
                    systemImage: "gyroscope"
                )
            }
            .accessibilityIdentifier("settings-card-motion-toggle")

            Toggle(isOn: $hapticsEnabled) {
                SettingsRowLabel(
                    title: "Haptic Feedback",
                    detail: "Tactile cues for capture, cards, and actions.",
                    systemImage: "waveform"
                )
            }
            .accessibilityIdentifier("settings-haptics-toggle")
        } header: {
            Text("Preferences")
        } footer: {
            Text("iOS Reduce Motion always takes priority over Card Motion.")
        }
    }

    private var storageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 20) {
                StorageSummaryRow(
                    savedCatText: savedCatText(records.count),
                    storageText: storageText,
                    storageRole: storageSizeRole
                )
                .accessibilityIdentifier("settings-storage-summary")

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete All Cats", systemImage: "trash")
                        .font(CatTypography.control)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 14)
                        .catDestructiveActionSurface(
                            cornerRadius: 16,
                            minHeight: 46,
                            isDisabled: records.isEmpty,
                            fillsWidth: dynamicTypeSize.isAccessibilitySize
                        )
                }
                .buttonStyle(.catTactile)
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(records.isEmpty)
                .opacity(records.isEmpty ? 0.45 : 1)
                .accessibilityHint("Permanently removes every stored cat and local image")
                .accessibilityIdentifier("settings-delete-all-cats")
            }
            .padding(.vertical, 8)
        } header: {
            Text("Storage")
        } footer: {
            Text("Sanitized originals, cutouts, and thumbnails stay in CatLocal's private app container. Their folders use iOS file protection until the first unlock after restart, are excluded from backups, and are removed with their cat.")
        }
    }

    private var informationSection: some View {
        Section("Privacy & About") {
            NavigationLink {
                PrivacyReceiptView()
            } label: {
                SettingsRowLabel(
                    title: "Privacy Receipt",
                    detail: "See exactly what stays on-device.",
                    systemImage: "lock.shield.fill"
                )
            }
            .accessibilityIdentifier("settings-privacy-receipt")

            NavigationLink {
                AboutCatLocalView()
            } label: {
                SettingsRowLabel(
                    title: "About CatLocal",
                    detail: "App purpose and version information.",
                    systemImage: "info.circle.fill"
                )
            }
            .accessibilityIdentifier("settings-about-catlocal")
        }
    }

    private var storageDeletionDetail: String {
        "Includes card details, notes, typed Catlas labels, originals, cutouts, and thumbnails."
    }

    private func savedCatText(_ count: Int) -> String {
        CatLocalLocalization.plural("%lld cats saved locally", count: count)
    }

    private var storageSizeRole: CatAttentionRole {
        guard let storageByteCount else { return .neutral }

        switch storageByteCount {
        case 0..<50_000_000:
            return .success
        case 50_000_000..<250_000_000:
            return .info
        case 250_000_000..<1_000_000_000:
            return .warning
        default:
            return .destructive
        }
    }

    private func refreshStorage() async {
        do {
            let bytes = try await CatImageStore.shared.storageSize()
            storageByteCount = bytes
            storageText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } catch {
            storageByteCount = nil
            storageText = "Unavailable".catLocalized
            errorMessage = "\("CatLocal could not measure local storage.".catLocalized) \(error.localizedDescription)"
            showingStorageError = true
        }
    }

    private func deleteAll() async {
        do {
            try await CatImageStore.shared.deleteAll()
            records.forEach(modelContext.delete)
            try modelContext.save()
            await refreshStorage()
        } catch {
            errorMessage = error.localizedDescription
            showingStorageError = true
        }
    }
}

private struct SettingsNavigationBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbarBackground(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

private struct StorageSummaryRow: View {
    let savedCatText: String
    let storageText: String
    let storageRole: CatAttentionRole

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                StorageSummaryIdentity(savedCatText: savedCatText)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 10)
                StorageSizePill(storageText: storageText, role: storageRole)
            }

            VStack(alignment: .leading, spacing: 12) {
                StorageSummaryIdentity(savedCatText: savedCatText)
                StorageSizePill(storageText: storageText, role: storageRole)
            }
        }
    }
}

private struct StorageSummaryIdentity: View {
    let savedCatText: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(CatAttentionRole.info.accent)
                .frame(width: 40, height: 40)
                .background(CatAttentionRole.info.wash.opacity(0.72), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Local Storage")
                    .font(CatTypography.panelTitle)
                    .foregroundStyle(CatLocalTheme.primaryText)
                Text(savedCatText)
                    .font(CatTypography.supporting)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct StorageSizePill: View {
    let storageText: String
    let role: CatAttentionRole

    var body: some View {
        Text(storageText)
            .font(CatTypography.metadata)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .contentTransition(.numericText())
            .catAttentionPillSurface(role: role, cornerRadius: 17)
            .animation(.smooth(duration: 0.22, extraBounce: 0), value: storageText)
            .animation(.smooth(duration: 0.22, extraBounce: 0), value: role)
            .accessibilityLabel(
                CatLocalLocalization.format("Storage used, %1$@", storageText)
            )
            .accessibilityIdentifier("settings-storage-size")
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let detail: String?
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(catLocalKey: title)
                    .font(CatTypography.body)
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(catLocalKey: detail)
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(CatLocalTheme.blueAction)
                .frame(width: 26)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(-1)
    }
}

private struct PrivacyReceiptView: View {
    var body: some View {
        List {
            Section {
                PrivacyReceiptRow(
                    icon: "camera.fill",
                    title: "Photos",
                    detail: "For each cat, CatLocal retains a sanitized, re-encoded original plus its cutout and thumbnail."
                )
                PrivacyReceiptRow(
                    icon: "brain.head.profile",
                    title: "Recognition",
                    detail: "Apple Vision finds and separates cats entirely on-device."
                )
                PrivacyReceiptRow(
                    icon: "location.slash.fill",
                    title: "Location",
                    detail: "CatLocal does not request GPS or save coordinates. Catlas labels are typed by you."
                )
                PrivacyReceiptRow(
                    icon: "network.slash",
                    title: "Network",
                    detail: "The collection requires no account, upload, cloud AI, or model-training use."
                )
                PrivacyReceiptRow(
                    icon: "lock.doc.fill",
                    title: "Image Storage",
                    detail: "Image folders use iOS file protection until the first unlock after restart, are excluded from backups, and are deleted with their cat."
                )
            } header: {
                Text("On this iPhone")
            } footer: {
                Text("Before storage, CatLocal redraws the selected photo and re-encodes it without source EXIF, GPS, camera/device, or orientation metadata.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { CatLocalBackground() }
        .navigationTitle("Privacy Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("privacy-receipt-screen")
    }
}

private struct PrivacyReceiptRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(CatAttentionRole.success.accent)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(catLocalKey: title)
                    .font(CatTypography.supportingEmphasized)
                    .foregroundStyle(CatLocalTheme.primaryText)
                Text(catLocalKey: detail)
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct AboutCatLocalView: View {
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "Unavailable".catLocalized
    }

    var body: some View {
        List {
            Section {
                Text("A private field journal for the cats you meet. CatLocal turns real encounters into tactile collectible cards using on-device processing and local storage.")
                    .font(CatTypography.body)
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            }

            Section("App Information") {
                LabeledContent("Version", value: versionText)
            }

            Section("Built Without") {
                Text("No account, public map, advertising identifier, GPS tracking, cloud AI, or model-training upload.")
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { CatLocalBackground() }
        .navigationTitle("About CatLocal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
