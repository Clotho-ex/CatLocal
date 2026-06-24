import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CatRecord]

    @State private var storageText = "Calculating..."
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                privacyCard
                storageCard
                aboutCard
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .task {
            await refreshStorage()
        }
        .confirmationDialog(
            "Delete the entire collection?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Cards", role: .destructive) {
                Task { await deleteAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every stored photo, cutout, note, and card will be permanently removed from this iPhone.")
        }
        .alert("Could not update storage", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .accessibilityIdentifier("settings-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Settings")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(2)

            Text("PRIVACY & STORAGE")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(CatLocalTheme.secondaryText)
        }
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("On this iPhone, by design", systemImage: "lock.shield.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(nil)

            VStack(alignment: .leading, spacing: 13) {
                privacyRow(
                    icon: "camera.fill",
                    title: "Photos",
                    detail: "Only captures and imports you choose are stored."
                )
                privacyRow(
                    icon: "brain.head.profile",
                    title: "Recognition",
                    detail: "Apple Vision finds and separates cats entirely on-device."
                )
                privacyRow(
                    icon: "location.slash.fill",
                    title: "Location",
                    detail: "CatLocal does not request GPS or save coordinates. Memory Atlas labels are typed by you."
                )
                privacyRow(
                    icon: "network.slash",
                    title: "Network",
                    detail: "The collection requires no account or upload."
                )
            }
        }
        .padding(18)
        .catPanelSurface()
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                storageSummaryRow
                VStack(alignment: .leading, spacing: 10) {
                    storageSummaryText
                    storageIcon
                }
            }

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Entire Collection", systemImage: "trash")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            .disabled(records.isEmpty)
            .opacity(records.isEmpty ? 0.45 : 1)
            .accessibilityHint("Permanently removes every stored card and local image")
        }
        .padding(18)
        .catPanelSurface()
    }

    private var storageSummaryRow: some View {
        HStack {
            storageSummaryText
            Spacer()
            storageIcon
        }
    }

    private var storageSummaryText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Local storage")
                .font(.headline)
                .foregroundStyle(CatLocalTheme.primaryText)
            Text("\(records.count) cards · \(storageText)")
                .font(.subheadline)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }

    private var storageIcon: some View {
        Image(systemName: "internaldrive.fill")
            .font(.title2)
            .foregroundStyle(CatLocalTheme.blueAction)
            .accessibilityHidden(true)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("About")
                    .font(.headline)
                    .foregroundStyle(CatLocalTheme.primaryText)
                Spacer()
                Text("Version 0.1")
                    .font(.footnote)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }
            Text("A private field journal for the cats you meet. There is no account, public map, advertising identifier, GPS tracking, cloud AI, or model-training upload.")
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
        .padding(18)
        .catPanelSurface()
    }

    private func privacyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CatLocalTheme.warning)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func refreshStorage() async {
        do {
            let bytes = try await CatImageStore.shared.storageSize()
            storageText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } catch {
            storageText = "Unavailable"
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
        }
    }
}
