import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CatRecord]

    @State private var storageText = "Calculating..."
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var didOptimizeExistingStorage = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CatLocal")
                        .catEditorialTitle(size: 54)
                        .foregroundStyle(CatLocalTheme.primaryText)
                    Text("PRIVACY & STORAGE")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }

                privacyCard
                storageCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)
                    Text("CatLocal is a private field journal for the cats you meet. There is no account, public map, advertising identifier, location collection, cloud AI, or model-training upload.")
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(CatLocalTheme.elevatedSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                Text("Version 0.1")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .task {
            await optimizeExistingStorageIfNeeded()
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

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("On this iPhone, by design", systemImage: "lock.shield.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)

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
                detail: "CatLocal does not request or store your location."
            )
            privacyRow(
                icon: "network.slash",
                title: "Network",
                detail: "The collection requires no account or upload."
            )
        }
        .padding(20)
        .background(CatLocalTheme.elevatedSurface.opacity(0.84), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
        )
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Local storage")
                        .font(.headline)
                    Text("\(records.count) cards · \(storageText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "internaldrive.fill")
                    .font(.title2)
                    .foregroundStyle(CatLocalTheme.blueAction)
            }

            Button("Delete Entire Collection", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .disabled(records.isEmpty)
        }
        .padding(20)
        .catGlass(cornerRadius: 28)
    }

    private func privacyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CatLocalTheme.warning)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func refreshStorage() async {
        do {
            let bytes = try await CatImageStore.shared.storageSize()
            storageText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } catch {
            storageText = "Unavailable"
        }
    }

    private func optimizeExistingStorageIfNeeded() async {
        guard !didOptimizeExistingStorage else { return }
        didOptimizeExistingStorage = true

        let references = records.map {
            StoredCatImageReferences(
                id: $0.id,
                originalPath: $0.originalImagePath,
                cutoutPath: $0.cutoutImagePath
            )
        }
        await CatImageStore.shared.optimizeExisting(records: references)
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
