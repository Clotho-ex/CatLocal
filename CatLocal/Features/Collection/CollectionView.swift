import SwiftData
import SwiftUI
import UIKit

struct CollectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CatRecord.sequence, order: .forward)
    private var records: [CatRecord]

    @Namespace private var cardTransitionNamespace

    @State private var selectedRecord: CatRecord?
    @State private var editingRecord: CatRecord?
    @State private var removalRecord: CatRecord?
    @State private var selectedAtlasRoute: AtlasRoute?
    @State private var collectionMode: CollectionMode = .cards
    @State private var sortOption: CatSortOption = .number
    @State private var isSelectionMode = false
    @State private var selectedRecordIDs = Set<UUID>()
    @State private var deletingRecordID: UUID?
    @State private var showingBulkDeleteConfirmation = false
    @State private var isBulkDeleting = false
    @State private var suppressFocusedZoomTransition = false
    @State private var errorMessage: String?

    private let onCaptureRequested: (() -> Void)?
    private let homeReselectionID: Int
    private let selectedTab: AppTab

    init(
        onCaptureRequested: (() -> Void)? = nil,
        homeReselectionID: Int = 0,
        selectedTab: AppTab = .home
    ) {
        self.onCaptureRequested = onCaptureRequested
        self.homeReselectionID = homeReselectionID
        self.selectedTab = selectedTab
    }

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 18)]
        } else {
            [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CatLocalBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        header

                        if records.isEmpty {
                            emptyState
                        } else {
                            collectionSummary
                            modePicker

                            switch collectionMode {
                            case .cards:
                                catGridSection
                            case .atlas:
                                catlas
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 18)
                    .padding(.bottom, scrollBottomPadding)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(item: $selectedRecord) { record in
                FocusedCardView(
                    record: record,
                    onClose: {
                        closeFocusedRecord()
                    },
                    onDeleted: {
                        closeFocusedRecordAfterDeletion()
                    }
                )
                .modifier(
                    FocusedCardZoomTransition(
                        recordID: record.id,
                        namespace: cardTransitionNamespace,
                        isEnabled: !suppressFocusedZoomTransition
                    )
                )
            }
            .navigationDestination(item: $selectedAtlasRoute) { route in
                atlasFilteredGrid(route)
            }
        }
        .sheet(item: $editingRecord) { record in
            CatRecordEditSheet(record: record)
                .presentationBackground(CatLocalTheme.background)
        }
        .sheet(item: $removalRecord) { record in
            CatDeletionConfirmationSheet(
                title: "Delete this cat?",
                message: "The original photo, cutout, notes, and cat record will be removed from this iPhone.",
                deleteTitle: "Delete",
                isDeleting: deletingRecordID == record.id
            ) {
                Task { await remove(record: record) }
            } onCancel: {
                guard deletingRecordID != record.id else { return }
                if removalRecord?.id == record.id {
                    removalRecord = nil
                }
            }
        }
        .sheet(isPresented: $showingBulkDeleteConfirmation) {
            CatDeletionConfirmationSheet(
                title: "Delete selected cats?",
                message: "The selected originals, cutouts, notes, and cat records will be removed from this iPhone.",
                deleteTitle: bulkDeleteTitle,
                isDeleting: isBulkDeleting
            ) {
                Task { await removeSelectedRecords() }
            } onCancel: {
                guard !isBulkDeleting else { return }
                showingBulkDeleteConfirmation = false
            }
        }
        .alert("Could not delete cat", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(removalErrorMessage)
        }
        .onChange(of: homeReselectionID) {
            navigateHomeToCats()
        }
        .onChange(of: selectedTab) { _, tab in
            guard tab != .home else { return }
            if selectedRecord != nil {
                closeFocusedRecord()
            }
            selectedAtlasRoute = nil
            endSelectionMode()
        }
        .onChange(of: records.map(\.id)) { _, recordIDs in
            reconcileSelection(with: recordIDs)
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode {
                selectionActionBar
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(hidesTabBar ? .hidden : .visible, for: .tabBar)
        .animation(.snappy(duration: 0.24), value: hidesTabBar)
        .accessibilityIdentifier("collection-screen")
    }

    private var hidesTabBar: Bool {
        isSelectionMode || selectedRecord != nil
    }

    private var focusTransitionAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.84)
    }

    private var sortAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.28)
    }

    private var horizontalPadding: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 20
        }
        return horizontalSizeClass == .regular ? 28 : CatLocalTheme.screenHorizontalPadding
    }

    private var contentSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 28 : 24
    }

    private var gridRowSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 22 : 18
    }

    private var scrollBottomPadding: CGFloat {
        guard isSelectionMode else { return 140 }
        return dynamicTypeSize.isAccessibilitySize ? 230 : 170
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CatLocal")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)

            Text("A private home for the cats you meet.")
                .font(.callout)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }

    private var collectionSummary: some View {
        Text(summaryCountLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CatLocalTheme.primaryText)
    }

    private var summaryCountLabel: String {
        if collectionMode == .atlas && !records.isEmpty {
            return atlasPlaceCountText
        }
        return catCountText(records.count)
    }

    private var modePicker: some View {
        Picker("Home view", selection: $collectionMode) {
            ForEach(CollectionMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("collection-mode-picker")
    }

    private var catGridSection: some View {
        let visibleRecords = sortedRecords

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: isSelectionMode ? "Select Cats" : "Cats")

            if isSelectionMode {
                Text("Tap cards to choose what to delete.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
                    .transition(.opacity)
            }

            LazyVGrid(columns: columns, spacing: gridRowSpacing) {
                ForEach(visibleRecords) { record in
                    catGridCard(record, context: .collection)
                }
            }
            .animation(sortAnimation, value: visibleRecords.map(\.id))
        }
    }

    private func catGridCard(
        _ record: CatRecord,
        context: CardGridContext = .collection
    ) -> some View {
        let isSelected = selectedRecordIDs.contains(record.id)

        return Button {
            if isSelectionMode {
                toggleSelection(for: record)
            } else {
                selectedRecord = record
            }
        } label: {
            CatCardView(
                record: record,
                showsThumbnailPlaceFooter: context.showsThumbnailPlaceFooter
            )
                .frame(maxWidth: .infinity)
                .aspectRatio(0.72, contentMode: .fit)
                .overlay {
                    homeCardQuietingOverlay
                }
                .overlay {
                    selectionStroke(isSelected: isSelected)
                }
                .overlay(alignment: .topTrailing) {
                    selectionBadge(isSelected: isSelected)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .matchedTransitionSource(id: record.id, in: cardTransitionNamespace) { configuration in
                    configuration
                        .background(.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.72, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipped()
        .contextMenu {
            Button {
                deferContextMenuAction {
                    if isSelectionMode {
                        toggleSelection(for: record)
                    } else {
                        beginSelection(with: record)
                    }
                }
            } label: {
                Label(
                    selectionContextTitle(isSelected: isSelected),
                    systemImage: isSelected ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }

            Button {
                deferContextMenuAction {
                    editingRecord = record
                }
            } label: {
                Label("Edit Cat", systemImage: "pencil")
            }

            Button(role: .destructive) {
                deferContextMenuAction {
                    removalRecord = record
                }
            } label: {
                Label("Delete Cat", systemImage: "trash")
            }
        }
        .accessibilityHint(isSelectionMode ? "Double tap to select or deselect this cat" : "Double tap to open this cat")
        .accessibilityValue(selectionAccessibilityValue(isSelected: isSelected))
    }

    private var catlas: some View {
        let groups = atlasGroups

        return VStack(alignment: .leading, spacing: 18) {
            atlasIntro

            ForEach(groups) { group in
                atlasGroup(group)
            }
        }
        .animation(sortAnimation, value: groups.map(\.id))
        .accessibilityIdentifier("catlas")
    }

    private func atlasFilteredGrid(_ route: AtlasRoute) -> some View {
        let routeRecords = atlasRecords(for: route)

        return ZStack {
            CatLocalBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 24 : 20) {
                    atlasRouteHeader(route, recordCount: routeRecords.count)

                    LazyVGrid(columns: columns, spacing: gridRowSpacing) {
                        ForEach(routeRecords) { record in
                            catGridCard(record, context: .catlas)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, scrollBottomPadding)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func atlasRecords(for route: AtlasRoute) -> [CatRecord] {
        sort(records.filter { record in
            record.atlasGroupTitle == route.id
        })
    }

    private var atlasIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Places")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                Spacer()
                sortMenu
            }

            Text("Places you type yourself. No GPS or public map.")
                .font(.footnote)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
        .padding(.top, 2)
    }

    private var atlasPlaceCount: Int {
        Set(records.compactMap(\.memoryPlaceName)).count
    }

    private var atlasPlaceCountText: String {
        switch atlasPlaceCount {
        case 0:
            "No places yet"
        case 1:
            "1 place"
        default:
            "\(atlasPlaceCount) places"
        }
    }

    private var atlasGroups: [MemoryAtlasGroup] {
        let grouped = Dictionary(grouping: sortedRecords) { record in
            record.atlasGroupTitle
        }

        return grouped.map { title, records in
            MemoryAtlasGroup(
                title: title,
                records: sort(records),
                isUnplaced: title == "Unplaced"
            )
        }
        .sorted { lhs, rhs in
            if lhs.isUnplaced != rhs.isUnplaced {
                return !lhs.isUnplaced
            }

            switch sortOption {
            case .number:
                return lhs.firstSequence < rhs.firstSequence
            case .place:
                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            case .alphabetical:
                return lhs.firstDisplayName.localizedCaseInsensitiveCompare(rhs.firstDisplayName) == .orderedAscending
            }
        }
    }

    private func atlasGroup(_ group: MemoryAtlasGroup) -> some View {
        Button {
            withAnimation(focusTransitionAnimation) {
                selectedAtlasRoute = AtlasRoute(group: group)
            }
        } label: {
            AtlasFolderButton(
                group: group,
                countText: catCountText(group.records.count),
                unplacedText: group.isUnplaced
                    ? "Add a memory place in Edit Cat."
                    : nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.displayTitle), \(catCountText(group.records.count))")
        .accessibilityHint("Opens a filtered Catlas grid")
    }

    private func sectionHeader(title: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle(title)
                    cardGridOrganizeMenu
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        sectionTitle(title)
                        Spacer(minLength: 10)
                        cardGridOrganizeMenu
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(title)
                        cardGridOrganizeMenu
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(CatLocalTheme.primaryText)
            .lineLimit(nil)
    }

    private func atlasRouteHeader(_ route: AtlasRoute, recordCount: Int) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    atlasRouteSummary(route, recordCount: recordCount)
                    cardGridOrganizeMenu
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        atlasRouteSummary(route, recordCount: recordCount)
                        Spacer(minLength: 10)
                        cardGridOrganizeMenu
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        atlasRouteSummary(route, recordCount: recordCount)
                        cardGridOrganizeMenu
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func atlasRouteSummary(_ route: AtlasRoute, recordCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(catCountText(recordCount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)

            if route.isUnplaced {
                Text("Add a memory place in Edit Cat.")
                    .font(.footnote)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            sortPicker
        } label: {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
                    .accessibilityHidden(true)

                Text(sortOption.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(CatLocalTheme.secondaryText)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort cats")
        .accessibilityValue(sortOption.title)
    }

    private var cardGridOrganizeMenu: some View {
        Menu {
            sortPicker

            Divider()

            Button {
                if isSelectionMode {
                    endSelectionMode()
                } else {
                    beginSelectionMode()
                }
            } label: {
                Label(
                    isSelectionMode ? "Done Selecting" : "Select for Deletion",
                    systemImage: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
        } label: {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
                    .accessibilityHidden(true)

                Text("Organize")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(CatLocalTheme.secondaryText)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Organize cats")
        .accessibilityValue(isSelectionMode ? "Selection active" : "Sorted by \(sortOption.title)")
        .accessibilityHint("Sort cats or choose cats to delete")
    }

    private var sortPicker: some View {
        Picker("Sort cats", selection: sortSelection) {
            ForEach(CatSortOption.allCases) { option in
                Label(option.title, systemImage: option.systemImage).tag(option)
            }
        }
    }

    private var sortSelection: Binding<CatSortOption> {
        Binding(
            get: { sortOption },
            set: { option in
                withAnimation(sortAnimation) {
                    sortOption = option
                }
            }
        )
    }

    private var selectionActionBar: some View {
        CatGlassGroup(spacing: 12) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            selectionCancelButton
                            selectionStatus
                            Spacer(minLength: 0)
                        }

                        bulkDeleteButton
                    }
                } else {
                    HStack(spacing: 12) {
                        selectionCancelButton
                        selectionStatus
                        bulkDeleteButton
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(CatLocalTheme.cardSurface.opacity(0.66))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline.opacity(0.72), lineWidth: 1)
            )
            .catGlass(cornerRadius: 26)
            .shadow(color: CatLocalTheme.shadow.opacity(0.12), radius: 8, y: 4)
            .accessibilityElement(children: .contain)
        }
    }

    private var selectionCancelButton: some View {
        Button {
            endSelectionMode()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel selection")
    }

    private var selectionStatus: some View {
        Text(selectedSelectionText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CatLocalTheme.primaryText)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.78)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bulkDeleteButton: some View {
        Button {
            guard !selectedRecordIDs.isEmpty, !isBulkDeleting else { return }
            showingBulkDeleteConfirmation = true
        } label: {
            Label(isBulkDeleting ? "Deleting" : "Delete", systemImage: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CatLocalTheme.background)
                .padding(.horizontal, 16)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .frame(minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(selectedRecordIDs.isEmpty ? CatLocalTheme.secondaryText.opacity(0.36) : CatLocalTheme.warning)
                )
                .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selectedRecordIDs.isEmpty || isBulkDeleting)
        .accessibilityLabel(bulkDeleteTitle)
    }

    private var sortedRecords: [CatRecord] {
        sort(records)
    }

    private func sort(_ records: [CatRecord]) -> [CatRecord] {
        records.sorted { lhs, rhs in
            switch sortOption {
            case .number:
                lhs.sequence < rhs.sequence
            case .place:
                placeSortKey(for: lhs) < placeSortKey(for: rhs)
            case .alphabetical:
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    private func placeSortKey(for record: CatRecord) -> String {
        if let place = record.memoryPlaceName {
            return "0-\(place.localizedLowercase)-\(record.displayName.localizedLowercase)"
        }
        return "1-\(record.displayName.localizedLowercase)"
    }

    private var selectedSelectionText: String {
        if selectedRecordIDs.isEmpty {
            return "Choose cats to delete"
        }
        return selectedRecordIDs.count == 1 ? "1 selected" : "\(selectedRecordIDs.count) selected"
    }

    private var bulkDeleteTitle: String {
        selectedRecordIDs.count == 1 ? "Delete 1 Cat" : "Delete \(selectedRecordIDs.count) Cats"
    }

    private var removalErrorMessage: String {
        guard let errorMessage else { return "" }
        return "The cat was not deleted. Please try again.\n\n\(errorMessage)"
    }

    private var homeCardQuietingOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CatLocalTheme.cardSurface.opacity(0.10),
                    .clear,
                    CatLocalTheme.background.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CatLocalTheme.imageOutline.opacity(0.58), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func selectionStroke(isSelected: Bool) -> some View {
        if isSelectionMode {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? CatLocalTheme.blueAction : CatLocalTheme.imageOutline.opacity(0.58),
                    lineWidth: isSelected ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isSelected ? CatLocalTheme.blueAction.opacity(0.07) : .clear)
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func selectionBadge(isSelected: Bool) -> some View {
        if isSelectionMode {
            ZStack {
                Circle()
                    .fill(isSelected ? CatLocalTheme.blueAction : CatLocalTheme.cardSurface.opacity(0.90))

                Circle()
                    .stroke(
                        isSelected ? CatLocalTheme.blueAction : CatLocalTheme.secondaryText.opacity(0.62),
                        lineWidth: isSelected ? 0 : 1.8
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 25, height: 25)
            .shadow(color: CatLocalTheme.shadow.opacity(0.14), radius: 4, y: 2)
            .padding(.top, 11)
            .padding(.trailing, 11)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func closeFocusedRecord() {
        selectedRecord = nil
    }

    private func closeFocusedRecordAfterDeletion() {
        suppressFocusedZoomTransition = true
        DispatchQueue.main.async {
            selectedRecord = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                suppressFocusedZoomTransition = false
            }
        }
    }

    private func navigateHomeToCats() {
        selectedRecord = nil
        withAnimation(focusTransitionAnimation) {
            selectedAtlasRoute = nil
            collectionMode = .cards
        }
        endSelectionMode()
    }

    private func beginSelectionMode() {
        withAnimation(.snappy(duration: 0.22)) {
            isSelectionMode = true
            selectedRecordIDs.removeAll()
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func beginSelection(with record: CatRecord) {
        withAnimation(.snappy(duration: 0.22)) {
            isSelectionMode = true
            selectedRecordIDs = [record.id]
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func toggleSelection(for record: CatRecord) {
        withAnimation(.snappy(duration: 0.18)) {
            if selectedRecordIDs.contains(record.id) {
                selectedRecordIDs.remove(record.id)
            } else {
                selectedRecordIDs.insert(record.id)
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func endSelectionMode() {
        guard isSelectionMode || !selectedRecordIDs.isEmpty else { return }
        withAnimation(.snappy(duration: 0.22)) {
            isSelectionMode = false
            selectedRecordIDs.removeAll()
        }
    }

    private func selectionContextTitle(isSelected: Bool) -> String {
        if isSelectionMode {
            return isSelected ? "Remove from Selection" : "Add to Selection"
        }
        return "Select for Deletion"
    }

    private func selectionAccessibilityValue(isSelected: Bool) -> String {
        guard isSelectionMode else { return "" }
        return isSelected ? "Selected for deletion" : "Not selected"
    }

    private func reconcileSelection(with recordIDs: [UUID]) {
        let availableIDs = Set(recordIDs)
        let reconciledSelection = selectedRecordIDs.intersection(availableIDs)
        guard reconciledSelection != selectedRecordIDs else { return }

        selectedRecordIDs = reconciledSelection
        if records.isEmpty || selectedRecordIDs.isEmpty && !isSelectionMode {
            endSelectionMode()
        }
    }

    private func deferContextMenuAction(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }

    private func remove(record: CatRecord) async {
        guard deletingRecordID == nil else { return }
        let remainingRecords = records.filter { $0.id != record.id }
        deletingRecordID = record.id
        defer {
            if deletingRecordID == record.id {
                deletingRecordID = nil
            }
        }

        do {
            try await CatImageStore.shared.deleteRecord(id: record.id)
            modelContext.delete(record)
            CatRecord.compactSequences(remainingRecords)
            try modelContext.save()
            if selectedRecord?.id == record.id {
                selectedRecord = nil
            }
            selectedRecordIDs.remove(record.id)
            if selectedRecordIDs.isEmpty && isSelectionMode {
                endSelectionMode()
            }
            removalRecord = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeSelectedRecords() async {
        guard !isBulkDeleting else { return }
        let selectedIDs = selectedRecordIDs
        let selectedRecords = records.filter { selectedIDs.contains($0.id) }
        let remainingRecords = records.filter { !selectedIDs.contains($0.id) }
        guard !selectedRecords.isEmpty else {
            endSelectionMode()
            return
        }

        isBulkDeleting = true
        defer {
            isBulkDeleting = false
        }

        do {
            for record in selectedRecords {
                try await CatImageStore.shared.deleteRecord(id: record.id)
            }

            for record in selectedRecords {
                modelContext.delete(record)
            }

            CatRecord.compactSequences(remainingRecords)
            try modelContext.save()
            showingBulkDeleteConfirmation = false
            endSelectionMode()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func catCountText(_ count: Int) -> String {
        count == 1 ? "1 cat" : "\(count) cats"
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "cat.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(CatLocalTheme.primaryText)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text("Meet Your First Cat")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)

                Text("Capture a cat encounter and keep it private on this iPhone.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 300)
            }

            if let onCaptureRequested {
                Button {
                    onCaptureRequested()
                } label: {
                    Label("Capture or Import", systemImage: "camera.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .catSingleActionPillSurface()
                }
                .buttonStyle(.plain)
                .accessibilityHint("Starts the private capture and photo import flow")
            }

            privacyPoints
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 22)
        .padding(.vertical, 46)
        .accessibilityIdentifier("empty-collection")
    }

    @ViewBuilder
    private var privacyPoints: some View {
        CatGlassGroup(spacing: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    privacyPoint(icon: "person.crop.circle.badge.xmark", title: "No Account")
                    privacyPoint(icon: "map.fill", title: "No Public Map")
                    privacyPoint(icon: "brain.head.profile", title: "No AI Training")
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    privacyPoint(icon: "person.crop.circle.badge.xmark", title: "No Account")
                    privacyPoint(icon: "map.fill", title: "No Public Map")
                    privacyPoint(icon: "brain.head.profile", title: "No AI Training")
                }
            }
        }
    }

    private func privacyPoint(icon: String, title: String) -> some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .frame(width: 28, height: 28)
                .catGlass(cornerRadius: 14)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct AtlasFolderButton: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let group: MemoryAtlasGroup
    let countText: String
    let unplacedText: String?

    var body: some View {
        let bodyShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 10) {
            folderLayout
            unplacedGuidance
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CatLocalTheme.chalk.opacity(0.56), in: bodyShape)
        .overlay {
            bodyShape
                .stroke(CatLocalTheme.imageOutline.opacity(0.76), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var folderLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    folderText
                    Spacer(minLength: 8)
                    chevron
                }

                AtlasArchivePreview(records: group.records)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    AtlasArchivePreview(records: group.records)
                    folderText
                    Spacer(minLength: 8)
                    chevron
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        folderText
                        Spacer(minLength: 8)
                        chevron
                    }

                    AtlasArchivePreview(records: group.records)
                }
            }
        }
    }

    private var folderText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.displayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CatLocalTheme.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

            Text(countText)
                .font(.caption.weight(.medium))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .imageScale(.small)
            .foregroundStyle(CatLocalTheme.secondaryText.opacity(0.74))
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var unplacedGuidance: some View {
        if let unplacedText {
            Text(unplacedText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }
}

private struct AtlasArchivePreview: View {
    let records: [CatRecord]

    var body: some View {
        let previewRecords = Array(records.prefix(Self.maxVisibleThumbnails))

        return ZStack(alignment: .leading) {
            ForEach(Array(previewRecords.enumerated()), id: \.element.id) { index, record in
                AtlasArchiveThumbnail(record: record)
                    .offset(x: CGFloat(index) * Self.thumbnailOffset)
                    .zIndex(Double(index))
            }

            if remainingCount > 0 {
                AtlasArchiveRemainder(count: remainingCount)
                    .offset(x: CGFloat(previewRecords.count) * Self.thumbnailOffset)
                    .zIndex(Double(previewRecords.count))
            }
        }
        .frame(width: Self.previewWidth, height: Self.thumbnailSize, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(thumbnailSummary)
    }

    private static let maxVisibleThumbnails = 3
    private static let thumbnailSize: CGFloat = 48
    private static let thumbnailOffset: CGFloat = 18
    private static let previewWidth: CGFloat = thumbnailSize + thumbnailOffset * CGFloat(maxVisibleThumbnails)

    private var remainingCount: Int {
        max(records.count - Self.maxVisibleThumbnails, 0)
    }

    private var thumbnailSummary: String {
        records.count == 1 ? "1 cat thumbnail" : "\(records.count) cat thumbnails"
    }
}

private struct AtlasArchiveRemainder: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(CatLocalTheme.primaryText)
            .frame(width: 48, height: 48)
            .background(
                CatLocalTheme.elevatedSurface.opacity(0.82),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

private struct AtlasArchiveThumbnail: View {
    let record: CatRecord

    var body: some View {
        StoredImageView(path: record.thumbnailImagePath, contentMode: .fill) {
            Image(systemName: "cat.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CatLocalTheme.elevatedSurface.opacity(0.72))
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(CatLocalTheme.cardSurface.opacity(0.92), lineWidth: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(CatLocalTheme.imageOutline.opacity(0.72), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private enum CollectionMode: String, CaseIterable, Identifiable {
    case cards
    case atlas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cards: "Cats"
        case .atlas: "Catlas"
        }
    }
}

private enum CardGridContext {
    case collection
    case catlas

    var showsThumbnailPlaceFooter: Bool {
        self == .collection
    }
}

private enum CatSortOption: String, CaseIterable, Identifiable {
    case number
    case place
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .number: "Number"
        case .place: "Place"
        case .alphabetical: "A-Z"
        }
    }

    var systemImage: String {
        switch self {
        case .number: "number"
        case .place: "mappin.and.ellipse"
        case .alphabetical: "textformat.abc"
        }
    }
}

private struct AtlasRoute: Identifiable, Hashable {
    let id: String
    let title: String
    let isUnplaced: Bool

    init(group: MemoryAtlasGroup) {
        id = group.id
        title = group.displayTitle
        isUnplaced = group.isUnplaced
    }

    static func == (lhs: AtlasRoute, rhs: AtlasRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct FocusedCardZoomTransition: ViewModifier {
    let recordID: UUID
    let namespace: Namespace.ID
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.navigationTransition(.zoom(sourceID: recordID, in: namespace))
        } else {
            content
        }
    }
}

private struct MemoryAtlasGroup: Identifiable {
    let title: String
    let records: [CatRecord]
    let isUnplaced: Bool

    var id: String { title }

    var displayTitle: String {
        isUnplaced ? "Unplaced cats" : title
    }

    var firstSequence: Int {
        records.map(\.sequence).min() ?? Int.max
    }

    var firstDisplayName: String {
        records.map(\.displayName).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.first ?? displayTitle
    }
}
