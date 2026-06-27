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

                LiveInteractiveCardView(width: nil, height: nil, cornerRadius: 34) { rotateX, rotateY, isInteracting in
                    CatCardView(
                        record: record,
                        presentation: .focused,
                        rotateX: rotateX,
                        rotateY: rotateY,
                        isLightActive: isInteracting
                    )
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
                .presentationBackground(CatLocalTheme.background)
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

    enum FocusedField {
        case name
        case location
        case notes
    }

    let record: CatRecord
    let onDeleted: (() -> Void)?

    @State private var nickname: String
    @State private var note: String
    @State private var placeName: String
    @State private var placeDetail: String
    @State private var selectedStyle: CardStyle
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: FocusedField?

    init(record: CatRecord, onDeleted: (() -> Void)? = nil) {
        self.record = record
        self.onDeleted = onDeleted
        _nickname = State(initialValue: record.nickname)
        _note = State(initialValue: record.note)
        _placeName = State(initialValue: record.placeName)
        _placeDetail = State(initialValue: record.placeDetail)
        _selectedStyle = State(initialValue: record.cardStyle)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CatLocalBackground()
                    .onTapGesture {
                        if focusedField != nil {
                            focusedField = nil
                        }
                    }

                Form {
                    Section("Card Design") {
                        CardStyleCarousel(
                            selectedStyle: $selectedStyle,
                            showsTitle: false,
                            itemWidth: 154,
                            previewAspectRatio: 1.28,
                            itemPadding: 6,
                            itemCornerRadius: 22,
                            itemSpacing: 12,
                            titleMinHeight: 20
                        ) { style in
                            CardStyleSwatch(style: style)
                        }
                        .listRowInsets(EdgeInsets(top: 14, leading: 12, bottom: 16, trailing: 12))
                    }

                    Section("Name the Cat") {
                        TextField("Nickname", text: $nickname)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .name)
                    }

                    Section("Catlas") {
                        TextField("Memory Place", text: $placeName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .location)

                        TextField("Place Detail", text: $placeDetail, axis: .vertical)
                            .lineLimit(1...4)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .location)
                    }

                    Section {
                        TextField("A note about this encounter", text: $note, axis: .vertical)
                            .lineLimit(3...7)
                            .focused($focusedField, equals: .notes)
                    } header: {
                        Text("Encounter Note")
                    }

                    Section {
                        catlasPrivacyNote
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)

                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Cat")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 13)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.red)
                                )
                                .shadow(color: Color.red.opacity(0.24), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Deletes this cat and its local images from this iPhone")
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 20, trailing: 16))
                    .listRowBackground(Color.clear)
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

    private var catlasPrivacyNote: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(CatLocalTheme.warning.opacity(0.28))

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text("Manual label only. CatLocal does not request GPS or save coordinates.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textCase(nil)
        .background(
            Capsule(style: .continuous)
                .fill(CatLocalTheme.warning.opacity(0.22))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(CatLocalTheme.warning.opacity(0.55), lineWidth: 1)
        )
    }

    private func saveChanges() {
        record.nickname = trimmedMemoryText(nickname)
        record.note = note
        record.placeName = trimmedMemoryText(placeName)
        record.placeDetail = trimmedMemoryText(placeDetail)
        record.cardStyle = selectedStyle
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
