import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CatRecord]

    @State private var storageText = "Calculating..."
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
                    .padding(.top, 18)
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(CatLocalTheme.infoSymbol)
                    .frame(width: 48, height: 48)
                    .background(CatLocalTheme.elevatedSurface.opacity(0.76), in: Circle())

                Text("On this iPhone, by Design")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

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
                    detail: "CatLocal does not request GPS or save coordinates. Catlas labels are typed by you."
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
                Label("Delete All Cats", systemImage: "trash")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            .disabled(records.isEmpty)
            .opacity(records.isEmpty ? 0.45 : 1)
            .accessibilityHint("Permanently removes every stored cat and local image")
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
            Text("Local Storage")
                .font(.headline)
                .foregroundStyle(CatLocalTheme.primaryText)
            Text("\(catCountText(records.count)) - \(storageText)")
                .font(.subheadline)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }

    private var storageIcon: some View {
        Image(systemName: "internaldrive.fill")
            .font(.title2)
            .foregroundStyle(CatLocalTheme.infoSymbol)
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
                .foregroundStyle(symbolColor(for: icon))
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

    private func symbolColor(for icon: String) -> Color {
        switch icon {
        case "camera.fill", "brain.head.profile":
            CatLocalTheme.infoSymbol
        case "trash":
            CatLocalTheme.dangerSymbol
        default:
            CatLocalTheme.neutralSymbol
        }
    }

    private func catCountText(_ count: Int) -> String {
        count == 1 ? "1 cat" : "\(count) cats"
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
            showingDeleteConfirmation = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
