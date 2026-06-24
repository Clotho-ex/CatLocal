import SwiftData
import SwiftUI

struct FocusedCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let record: CatRecord

    @State private var nickname: String
    @State private var note: String
    @State private var placeName: String
    @State private var placeDetail: String
    @State private var style: CardStyle
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    init(record: CatRecord) {
        self.record = record
        _nickname = State(initialValue: record.nickname)
        _note = State(initialValue: record.note)
        _placeName = State(initialValue: record.placeName)
        _placeDetail = State(initialValue: record.placeDetail)
        _style = State(initialValue: record.cardStyle)
    }

    var body: some View {
        ZStack {
            CatLocalBackground()
                .overlay(CatLocalTheme.primaryText.opacity(0.05))

            VStack(spacing: 16) {
                topBar

                Spacer(minLength: 0)

                LiveInteractiveCardView(width: nil, height: nil, cornerRadius: 34) {
                    CatCardView(record: record, presentation: .focused)
                }
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 335 : 365)
                    .aspectRatio(0.67, contentMode: .fit)

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

                Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 44 : 84)
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.top, 12)
        }
        .sheet(isPresented: $isEditing) {
            editSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
        }
        .confirmationDialog(
            "Delete this card?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Card", role: .destructive) {
                Task { await deleteRecord() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original photo, cutout, notes, and card will be removed from this iPhone.")
        }
        .alert("Could not update card", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .accessibilityAction(.escape) { dismiss() }
    }

    private var topBar: some View {
        CatGlassGroup(spacing: 18) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 46, height: 46)
                        .catGlass(cornerRadius: 23, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close card")

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

    private var editSheet: some View {
        NavigationStack {
            ZStack {
                CatLocalBackground()

                Form {
                    Section("Card") {
                        TextField("Nickname", text: $nickname)
                            .textInputAutocapitalization(.words)

                        TextField("A note about this encounter", text: $note, axis: .vertical)
                            .lineLimit(3...7)
                    }

                    Section("Memory Atlas") {
                        TextField("Memory place", text: $placeName)
                            .textInputAutocapitalization(.words)

                        TextField("Place detail", text: $placeDetail, axis: .vertical)
                            .lineLimit(1...4)
                            .textInputAutocapitalization(.sentences)

                        Text("Manual label only. CatLocal does not request GPS or save coordinates.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Design") {
                        Picker("Card style", selection: $style) {
                            ForEach(CardStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Button("Delete Card", role: .destructive) {
                            isEditing = false
                            showingDeleteConfirmation = true
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        nickname = record.nickname
                        note = record.note
                        placeName = record.placeName
                        placeDetail = record.placeDetail
                        style = record.cardStyle
                        isEditing = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        record.nickname = nickname
        record.note = note
        record.placeName = trimmedMemoryText(placeName)
        record.placeDetail = trimmedMemoryText(placeDetail)
        record.cardStyle = style
        do {
            try modelContext.save()
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func trimmedMemoryText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deleteRecord() async {
        do {
            try await CatImageStore.shared.deleteRecord(id: record.id)
            modelContext.delete(record)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
