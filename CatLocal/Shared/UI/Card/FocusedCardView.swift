import SwiftData
import SwiftUI

struct FocusedCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(CatLocalUserDefaults.hasSeenFocusedCardGlintHintKey) private var hasSeenFocusedCardGlintHint = false

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

            focusedContent
        }
        .navigationTitle(record.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !dynamicTypeSize.isAccessibilitySize {
                lightGuidance
                    .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                    .padding(.bottom, 18)
            }
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
    private var focusedContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityFocusedContent
        } else {
            standardFocusedContent
        }
    }

    private var standardFocusedContent: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            interactiveCard(showsFooter: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
    }

    private var accessibilityFocusedContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                interactiveCard(showsFooter: false)

                FocusedJournalEntryView(record: record)

                lightGuidance
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var focusedCardMaxWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 230 : 326
    }

    @ViewBuilder
    private func interactiveCard(showsFooter: Bool) -> some View {
        if showsFooter {
            liveInteractiveCard(showsFooter: showsFooter)
        } else {
            liveInteractiveCard(showsFooter: showsFooter)
                .dynamicTypeSize(.xxxLarge)
        }
    }

    private func liveInteractiveCard(showsFooter: Bool) -> some View {
        LiveInteractiveCardView(
            width: compactAccessibilityCardSize?.width,
            height: compactAccessibilityCardSize?.height,
            cornerRadius: 34,
            onInteractionChanged: { isInteracting in
                isCardInteracting = isInteracting
                if isInteracting {
                    hasSeenFocusedCardGlintHint = true
                }
            }
        ) { rotateX, rotateY, isInteracting in
            CatCardView(
                record: record,
                presentation: .focused,
                rotateX: rotateX,
                rotateY: rotateY,
                isLightActive: isInteracting,
                showsFooter: showsFooter
            )
        }
        .frame(maxWidth: focusedCardMaxWidth)
        .aspectRatio(0.64, contentMode: .fit)
    }

    private var compactAccessibilityCardSize: CGSize? {
        guard dynamicTypeSize.isAccessibilitySize else { return nil }
        return CGSize(width: focusedCardMaxWidth, height: focusedCardMaxWidth / 0.64)
    }

    private var showsFirstGlintMascot: Bool {
        !hasSeenFocusedCardGlintHint && !reduceMotion && !isCardInteracting
    }

    private var lightGuidance: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                if showsFirstGlintMascot {
                    glintHintMascot(size: 54)
                }

                lightHintPill
            }

            VStack(spacing: 8) {
                if showsFirstGlintMascot {
                    glintHintMascot(size: 62)
                }

                lightHintPill
            }
        }
        .opacity(isCardInteracting && !reduceMotion ? 0 : 1)
        .offset(y: isCardInteracting && !reduceMotion ? 8 : 0)
        .animation(.easeInOut(duration: 0.16), value: isCardInteracting)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2, extraBounce: 0), value: showsFirstGlintMascot)
        .allowsHitTesting(false)
        .accessibilityHidden(isCardInteracting && !reduceMotion)
    }

    private func glintHintMascot(size: CGFloat) -> some View {
        LociMascotView(
            state: .state(for: .glintHint),
            size: size
        )
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .accessibilityHidden(true)
    }

    private var lightHintPill: some View {
        Label {
            Text(reduceMotion ? "Lighting motion is reduced" : "Drag to catch the light")
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: reduceMotion ? "figure.stand" : "gyroscope")
                .imageScale(.medium)
                .accessibilityHidden(true)
        }
        .font(CatTypography.supportingEmphasized)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .center)
        .catAttentionPillSurface(role: .action, cornerRadius: 22)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        .multilineTextAlignment(.center)
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

private struct FocusedJournalEntryView: View {
    let record: CatRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal Entry")
                .font(CatTypography.panelTitle)
                .foregroundStyle(CatLocalTheme.primaryText)

            journalRow(
                title: "Captured",
                icon: "calendar",
                value: record.capturedAt.formatted(date: .abbreviated, time: .omitted)
            )

            journalRow(
                title: "Notes",
                icon: "note.text",
                value: record.note.isEmpty ? "No note yet." : record.note,
                isPlaceholder: record.note.isEmpty
            )

            if let placeName = record.memoryPlaceName {
                journalRow(
                    title: "Memory Place",
                    icon: "mappin.and.ellipse",
                    value: placeName
                )
            } else {
                journalRow(
                    title: "Memory Place",
                    icon: "mappin.and.ellipse",
                    value: "Add when ready.",
                    isPlaceholder: true
                )
            }

            if let placeDetail = record.memoryPlaceDetail {
                journalRow(
                    title: "Place Detail",
                    icon: "text.alignleft",
                    value: placeDetail
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CatLocalTheme.cardSurface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(CatLocalTheme.imageOutline.opacity(0.62), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func journalRow(
        title: String,
        icon: String,
        value: String,
        isPlaceholder: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(CatTypography.supportingEmphasized)
                .imageScale(.medium)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CatTypography.fieldLabel)
                    .foregroundStyle(CatLocalTheme.secondaryText)

                Text(value)
                    .font(CatTypography.body)
                    .foregroundStyle(isPlaceholder ? CatLocalTheme.secondaryText : CatLocalTheme.primaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
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
    let initialFocusedField: FocusedField?

    @State private var nickname: String
    @State private var note: String
    @State private var placeName: String
    @State private var placeDetail: String
    @State private var selectedStyle: CardStyle
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var didApplyInitialFocus = false
    @FocusState private var focusedField: FocusedField?

    init(
        record: CatRecord,
        initialFocusedField: FocusedField? = nil,
        onDeleted: (() -> Void)? = nil
    ) {
        self.record = record
        self.onDeleted = onDeleted
        self.initialFocusedField = initialFocusedField
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
                    Section {
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
                    } header: {
                        editSectionHeader("Card Design")
                    }

                    Section {
                        TextField("Nickname", text: $nickname)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .name)
                    } header: {
                        editSectionHeader("Name the Cat")
                    }

                    Section {
                        TextField("Memory Place", text: $placeName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .location)

                        TextField("Place Detail", text: $placeDetail, axis: .vertical)
                            .lineLimit(1...4)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .location)
                    } header: {
                        editSectionHeader("Catlas")
                    }

                    Section {
                        TextField("A note about this encounter", text: $note, axis: .vertical)
                            .lineLimit(3...7)
                            .focused($focusedField, equals: .notes)
                    } header: {
                        editSectionHeader("Encounter Note")
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
                                .font(CatTypography.control)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .catDestructiveActionSurface(
                                    cornerRadius: 24,
                                    minHeight: 54,
                                    isProminent: true
                                )
                        }
                        .buttonStyle(.catTactile)
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
        .task {
            await applyInitialFocusIfNeeded()
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
                    .fill(CatAttentionRole.info.wash)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CatAttentionRole.info.accent)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text("Typed labels only. No GPS is requested.")
                .font(CatTypography.metadata)
                .foregroundStyle(CatAttentionRole.info.text)
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
                .fill(CatAttentionRole.info.wash)
        )
    }

    private func dismissEditKeyboard() {
        if focusedField != nil {
            focusedField = nil
        }
    }

    private func applyInitialFocusIfNeeded() async {
        guard !didApplyInitialFocus, let initialFocusedField else { return }

        didApplyInitialFocus = true
        try? await Task.sleep(nanoseconds: 320_000_000)
        focusedField = initialFocusedField
    }

    private func editSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(CatTypography.fieldLabel)
            .foregroundStyle(CatLocalTheme.secondaryText)
            .textCase(nil)
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
