import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct FocusedCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let record: CatRecord
    let onClose: (() -> Void)?
    let onDeleted: (() -> Void)?

    @State private var isEditing = false
    @State private var isCardInteracting = false

    init(
        record: CatRecord,
        onClose: (() -> Void)? = nil,
        onDeleted: (() -> Void)? = nil
    ) {
        self.record = record
        self.onClose = onClose
        self.onDeleted = onDeleted
    }

    var body: some View {
        ZStack {
            CatLocalBackground()
                .overlay(CatLocalTheme.primaryText.opacity(0.05))

            VStack(spacing: 12) {
                Spacer(minLength: 0)

                LiveInteractiveCardView(
                    width: nil,
                    height: nil,
                    cornerRadius: 34,
                    onInteractionChanged: { isInteracting in
                        isCardInteracting = isInteracting
                    }
                ) { rotateX, rotateY, isInteracting in
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

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 8 : 10)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 16)
        }
        .navigationTitle(record.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                shareToolbarAction

                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit")
            }
        }
        .safeAreaInset(edge: .bottom) {
            lightHintPill
                .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 12 : 18)
        }
        .sheet(isPresented: $isEditing) {
            CatRecordEditSheet(record: record) {
                closeDeletedFocusedCat()
            }
                .presentationDetents([.medium, .large])
                .presentationBackground(CatLocalTheme.background)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
        }
        .accessibilityAction(.escape) { closeFocusedCat() }
    }

    @ViewBuilder
    private var shareToolbarAction: some View {
        ShareLink(
            item: CatCardShareItem(record: record),
            preview: SharePreview(record.displayName, image: Image(systemName: "cat.fill"))
        ) {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share")
    }

    private var lightHintPill: some View {
        Label(
            reduceMotion ? "Lighting motion is reduced" : "Drag to catch the light",
            systemImage: reduceMotion ? "figure.stand" : "gyroscope"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(CatLocalTheme.primaryText)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
        .catGlass(cornerRadius: 22)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        .multilineTextAlignment(.center)
        .opacity(isCardInteracting && !reduceMotion ? 0 : 1)
        .offset(y: isCardInteracting && !reduceMotion ? 8 : 0)
        .animation(.easeInOut(duration: 0.16), value: isCardInteracting)
        .allowsHitTesting(false)
        .accessibilityHidden(isCardInteracting && !reduceMotion)
    }

    private func closeFocusedCat() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func closeDeletedFocusedCat() {
        if let onDeleted {
            onDeleted()
        } else {
            closeFocusedCat()
        }
    }
}

private struct CatCardShareItem: Transferable, Sendable {
    let displayName: String
    let sequence: Int
    let capturedAt: Date
    let note: String
    let placeName: String
    let placeDetail: String
    let cardStyle: CardStyle
    let cutoutImagePath: String
    let thumbnailImagePath: String
    let catBoundingBox: CGRect?
    let topoSeed: Int

    init(record: CatRecord) {
        displayName = record.displayName
        sequence = record.sequence
        capturedAt = record.capturedAt
        note = record.note
        placeName = record.memoryPlaceName ?? ""
        placeDetail = record.memoryPlaceDetail ?? ""
        cardStyle = record.cardStyle
        cutoutImagePath = record.cutoutImagePath
        thumbnailImagePath = record.thumbnailImagePath
        catBoundingBox = record.catBoundingBox
        topoSeed = record.id.hashValue
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            try await item.pngData()
        }
    }

    @MainActor
    private func pngData() async throws -> Data {
        let cutoutImage = await resolvedShareImage()
        let renderer = ImageRenderer(
            content: shareCard(cutoutImage: cutoutImage)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 350, height: 547)

        guard let renderedImage = renderer.uiImage,
              let pngData = renderedImage.pngData()
        else {
            throw CatCardShareError.renderFailed
        }

        return pngData
    }

    @MainActor
    private func resolvedShareImage() async -> UIImage {
        for path in [cutoutImagePath, thumbnailImagePath] where !path.isEmpty {
            if let data = try? await CatImageStore.shared.data(at: path),
               let image = UIImage(data: data) {
                return image
            }
        }

        return Self.placeholderShareImage()
    }

    @MainActor
    private func shareCard(cutoutImage: UIImage) -> some View {
        DraftCatCardView(
            image: cutoutImage,
            sequence: sequence,
            name: displayName,
            date: capturedAt,
            note: note,
            placeName: placeName,
            placeDetail: placeDetail,
            cardStyle: cardStyle,
            presentation: .focused,
            showsFooter: true,
            catBoundingBox: catBoundingBox,
            topoSeed: topoSeed
        )
        .frame(width: 350, height: 547)
    }

    @MainActor
    private static func placeholderShareImage() -> UIImage {
        let size = CGSize(width: 900, height: 900)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let configuration = UIImage.SymbolConfiguration(pointSize: 420, weight: .regular)
            let image = UIImage(systemName: "cat.fill", withConfiguration: configuration)?
                .withTintColor(.label, renderingMode: .alwaysOriginal)
            let rect = CGRect(x: 210, y: 210, width: 480, height: 480)
            image?.draw(in: rect)
        }
    }
}

private enum CatCardShareError: Error {
    case renderFailed
}

struct CatRecordEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CatRecord.sequence, order: .forward)
    private var records: [CatRecord]

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
            ZStack(alignment: .topTrailing) {
                CatLocalBackground()
                    .onTapGesture {
                        dismissEditKeyboard()
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
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                dismissEditKeyboard()
                            }
                        )
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
                .safeAreaInset(edge: .top) {
                    Color.clear
                        .frame(height: 46)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)

                editSheetActionButton
                    .padding(.top, 14)
                    .padding(.trailing, CatLocalTheme.screenHorizontalPadding)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("Could not update cat", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            CatDeletionConfirmationSheet(
                title: "Delete this cat?",
                message: "The original photo, cutout, notes, and cat will be removed from this iPhone.",
                deleteTitle: "Delete"
            ) {
                showingDeleteConfirmation = false
                Task { await deleteRecord() }
            } onCancel: {
                showingDeleteConfirmation = false
            }
        }
    }

    private var editSheetActionButton: some View {
        CatSheetActionButton(mode: editSheetActionMode) {
            performEditSheetAction()
        }
        .accessibilityIdentifier("cat-edit-sheet-action")
    }

    private var editSheetActionMode: CatSheetActionButton.Mode {
        hasDraftChanges ? .confirm : .close
    }

    private var hasDraftChanges: Bool {
        trimmedMemoryText(nickname) != record.nickname
            || note != record.note
            || trimmedMemoryText(placeName) != record.placeName
            || trimmedMemoryText(placeDetail) != record.placeDetail
            || selectedStyle != record.cardStyle
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

    private func dismissEditKeyboard() {
        if focusedField != nil {
            focusedField = nil
        }
    }

    private func performEditSheetAction() {
        dismissEditKeyboard()
        guard editSheetActionMode == .confirm else {
            dismiss()
            return
        }

        saveChanges()
    }

    private func saveChanges() {
        dismissEditKeyboard()
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
        let remainingRecords = records.filter { $0.id != record.id }
        do {
            try await CatImageStore.shared.deleteRecord(id: record.id)
            modelContext.delete(record)
            CatRecord.compactSequences(remainingRecords)
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
