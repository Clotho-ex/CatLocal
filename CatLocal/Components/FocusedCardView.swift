import SwiftData
import SwiftUI

struct FocusedCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let record: CatRecord

    @StateObject private var motion = MotionTiltModel()
    @State private var dragOffset: CGSize = .zero
    @State private var nickname: String
    @State private var note: String
    @State private var style: CardStyle
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    init(record: CatRecord) {
        self.record = record
        _nickname = State(initialValue: record.nickname)
        _note = State(initialValue: record.note)
        _style = State(initialValue: record.cardStyle)
    }

    var body: some View {
        ZStack {
            CatLocalBackground()
                .overlay(CatLocalTheme.ink.opacity(0.09))

            VStack(spacing: 16) {
                topBar

                Spacer(minLength: 0)

                CatCardView(record: record, presentation: .focused)
                    .frame(maxWidth: 365)
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : tiltY * -7),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.66
                    )
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : tiltX * 8),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.66
                    )
                    .overlay {
                        if !reduceMotion {
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.46), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .blendMode(.screen)
                            .offset(x: tiltX * 90, y: tiltY * 65)
                            .mask(RoundedRectangle(cornerRadius: 34, style: .continuous))
                            .allowsHitTesting(false)
                        }
                    }
                    .gesture(cardDrag)

                Label(
                    reduceMotion ? "Lighting motion is reduced" : "Drag or tilt to catch the light",
                    systemImage: reduceMotion ? "figure.stand" : "gyroscope"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CatLocalTheme.forest)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .catGlass(cornerRadius: 22)

                Spacer(minLength: 84)
            }
            .padding(.horizontal, 22)
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
        .task {
            guard !reduceMotion else { return }
            motion.start()
        }
        .onDisappear { motion.stop() }
        .accessibilityAction(.escape) { dismiss() }
    }

    private var topBar: some View {
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
                    .frame(height: 46)
                    .catGlass(cornerRadius: 23, interactive: true)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(CatLocalTheme.forest)
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

    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !reduceMotion else { return }
                dragOffset = CGSize(
                    width: max(-90, min(90, value.translation.width)),
                    height: max(-90, min(90, value.translation.height))
                )
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.42, bounce: 0.18)) {
                    dragOffset = .zero
                }
            }
    }

    private var tiltX: Double {
        Double(dragOffset.width / 90) + motion.x * 0.42
    }

    private var tiltY: Double {
        Double(dragOffset.height / 90) + motion.y * 0.32
    }

    private func saveChanges() {
        record.nickname = nickname
        record.note = note
        record.cardStyle = style
        do {
            try modelContext.save()
            isEditing = false
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
