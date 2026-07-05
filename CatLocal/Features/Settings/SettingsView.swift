import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CatRecord]

    @State private var storageText = "Calculating..."
    @State private var storageByteCount: Int64?
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CatLocalBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        privacyCard
                        storageCard
                        aboutCard
                    }
                    .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            await refreshStorage()
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            CatDeletionConfirmationSheet(
                title: "Delete every cat?",
                message: "Every stored photo, cutout, note, and cat will be permanently removed from this iPhone.",
                deleteTitle: "Delete All"
            ) {
                showingDeleteConfirmation = false
                Task { await deleteAll() }
            } onCancel: {
                showingDeleteConfirmation = false
            }
        }
        .alert("Could not update storage", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .accessibilityIdentifier("settings-screen")
    }

    private var privacyCard: some View {
        VStack(alignment: .center, spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CatAttentionRole.info.accent)
                    .catAttentionIconSurface(role: .info, size: 40)
                    .accessibilityHidden(true)

                Text("On this iPhone, by Design")
                    .font(CatTypography.panelTitle)
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 20) {
                privacyRow(
                    icon: "camera.fill",
                    title: "Photos",
                    detail: "Only captures and imports you choose are stored.",
                    role: .info
                )
                privacyRow(
                    icon: "brain.head.profile",
                    title: "Recognition",
                    detail: "Apple Vision finds and separates cats entirely on-device.",
                    role: .info
                )
                privacyRow(
                    icon: "location.slash.fill",
                    title: "Location",
                    detail: "CatLocal does not request GPS or save coordinates. Catlas labels are typed by you.",
                    role: .success
                )
                privacyRow(
                    icon: "network.slash",
                    title: "Network",
                    detail: "The collection requires no account or upload.",
                    role: .success
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .catPanelSurface()
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    storageIcon
                    storageSummaryText
                    Spacer(minLength: 10)
                    storageSizePill
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 14) {
                        storageIcon
                        storageSummaryText
                    }
                    storageSizePill
                }
            }

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
                        fillsWidth: false
                    )
            }
            .buttonStyle(.catTactile)
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(records.isEmpty)
            .opacity(records.isEmpty ? 0.45 : 1)
            .accessibilityHint("Permanently removes every stored cat and local image")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .catPanelSurface()
    }

    private var storageSummaryText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Local Storage")
                .font(CatTypography.panelTitle)
                .foregroundStyle(CatLocalTheme.primaryText)
            Text(catCountText(records.count))
                .font(CatTypography.supporting)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }

    private var storageIcon: some View {
        Image(systemName: "internaldrive.fill")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(CatAttentionRole.info.accent)
            .symbolEffect(.pulse, value: reduceMotion ? "" : storageText)
            .frame(width: 40, height: 40)
            .background(CatAttentionRole.info.wash.opacity(0.72), in: Circle())
            .accessibilityHidden(true)
    }

    private var storageSizePill: some View {
        Text(storageText)
            .font(CatTypography.metadata)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .contentTransition(.numericText())
            .catAttentionPillSurface(role: storageSizeRole, cornerRadius: 17)
            .animation(.smooth(duration: 0.22, extraBounce: 0), value: storageText)
            .animation(.smooth(duration: 0.22, extraBounce: 0), value: storageSizeRole)
            .accessibilityLabel("Local storage size, \(storageText)")
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("About")
                    .font(CatTypography.panelTitle)
                    .foregroundStyle(CatLocalTheme.primaryText)
                Spacer()
                Text("Version 0.1")
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }
            Text("A private field journal for the cats you meet. There is no account, public map, advertising identifier, GPS tracking, cloud AI, or model-training upload.")
                .font(CatTypography.body)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
        .padding(20)
        .catPanelSurface()
    }

    private func privacyRow(icon: String, title: String, detail: String, role: CatAttentionRole) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(role.accent)
                .frame(width: 34, height: 34)
                .background(role.wash.opacity(0.68), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(CatTypography.supportingEmphasized)
                    .foregroundStyle(CatLocalTheme.primaryText)
                Text(detail)
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func catCountText(_ count: Int) -> String {
        count == 1 ? "1 Cat" : "\(count) Cats"
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
            errorMessage = nil
        } catch {
            storageByteCount = nil
            storageText = "Unavailable"
            errorMessage = "CatLocal could not measure local storage. \(error.localizedDescription)"
        }
    }

    private func deleteAll() async {
        do {
            try await CatImageStore.shared.deleteAll()
            records.forEach(modelContext.delete)
            try modelContext.save()
            await refreshStorage()
            showingDeleteConfirmation = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
