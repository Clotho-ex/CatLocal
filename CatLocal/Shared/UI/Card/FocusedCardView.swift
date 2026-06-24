import SwiftData
import SwiftUI

struct FocusedCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let record: CatRecord
    let onClose: (() -> Void)?

    @State private var isEditing = false

    init(record: CatRecord, onClose: (() -> Void)? = nil) {
        self.record = record
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            CatLocalBackground()
                .overlay(CatLocalTheme.primaryText.opacity(0.05))

            VStack(spacing: 12) {
                topBar

                Spacer(minLength: 0)

                LiveInteractiveCardView(width: nil, height: nil, cornerRadius: 34) {
                    CatCardView(record: record, presentation: .focused)
                }
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 350 : 390)
                    .aspectRatio(0.64, contentMode: .fit)

                Label(
                    reduceMotion ? "Lighting motion is reduced" : "Drag to catch the light",
                    systemImage: reduceMotion ? "figure.stand" : "gyroscope"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CatLocalTheme.primaryText)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .catGlass(cornerRadius: 22)
                .lineLimit(2)
                .multilineTextAlignment(.center)

                Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 24 : 48)
            }
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 8 : 10)
            .padding(.top, 12)
        }
        .sheet(isPresented: $isEditing) {
            CatRecordEditSheet(record: record) {
                closeFocusedCat()
            }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
        }
        .accessibilityAction(.escape) { closeFocusedCat() }
    }

    private var topBar: some View {
        CatGlassGroup(spacing: 18) {
            HStack {
                Button {
                    closeFocusedCat()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 46, height: 46)
                        .catGlass(cornerRadius: 23, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close cat")

                Spacer()

                Button {
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .catGlass(cornerRadius: 23, interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(CatLocalTheme.primaryText)
    }

    private func closeFocusedCat() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

struct CatRecordEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let record: CatRecord
    let onDeleted: (() -> Void)?

    @State private var nickname: String
    @State private var note: String
    @State private var placeName: String
    @State private var placeDetail: String
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    init(record: CatRecord, onDeleted: (() -> Void)? = nil) {
        self.record = record
        self.onDeleted = onDeleted
        _nickname = State(initialValue: record.nickname)
        _note = State(initialValue: record.note)
        _placeName = State(initialValue: record.placeName)
        _placeDetail = State(initialValue: record.placeDetail)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CatLocalBackground()

                Form {
                    Section("Cat") {
                        TextField("Nickname", text: $nickname)
                            .textInputAutocapitalization(.words)

                        TextField("A note about this encounter", text: $note, axis: .vertical)
                            .lineLimit(3...7)
                    }

                    Section("Catlas") {
                        TextField("Memory Place", text: $placeName)
                            .textInputAutocapitalization(.words)

                        TextField("Place detail", text: $placeDetail, axis: .vertical)
                            .lineLimit(1...4)
                            .textInputAutocapitalization(.sentences)

                        Text("Manual label only. CatLocal does not request GPS or save coordinates.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button("Delete Cat", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Cat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
        }
        .confirmationDialog(
            "Delete this cat?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Cat", role: .destructive) {
                Task { await deleteRecord() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original photo, cutout, notes, and cat will be removed from this iPhone.")
        }
        .alert("Could not update cat", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveChanges() {
        record.nickname = trimmedMemoryText(nickname)
        record.note = note
        record.placeName = trimmedMemoryText(placeName)
        record.placeDetail = trimmedMemoryText(placeDetail)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRecord() async {
        do {
            try await CatImageStore.shared.deleteRecord(id: record.id)
            modelContext.delete(record)
            try modelContext.save()
            dismiss()
            onDeleted?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func trimmedMemoryText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
