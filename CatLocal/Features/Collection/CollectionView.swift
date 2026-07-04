import SwiftData
import SwiftUI

struct CollectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CatRecord.sequence, order: .forward)
    private var records: [CatRecord]

    @Namespace private var cardTransitionNamespace

    @State private var selectedRecord: CatRecord?
    @State private var selectedAtlasRecord: CatRecord?
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
    @State private var isFocusedCardTabBarHidden = false
    @State private var collectionCountDelightTrigger = 0
    @State private var collectionModeDelightTrigger = 0
    @State private var collectionSelectionFeedbackTrigger = 0
    @State private var collectionDeletionFeedbackTrigger = 0
    @State private var sortDelightTrigger = 0
    @State private var recentlyAddedRecordID: UUID?
    @State private var recentlyUpdatedAtlasGroupID: String?
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
            if activeFocusedRecordID != nil {
                closeFocusedRecord()
            }
            selectedAtlasRoute = nil
            endSelectionMode()
        }
        .onChange(of: collectionMode) { oldMode, newMode in
            guard oldMode != newMode else { return }
            collectionModeDelightTrigger += 1
        }
        .onChange(of: selectedAtlasRoute?.id) { _, routeID in
            if routeID == nil {
                selectedAtlasRecord = nil
            }
        }
        .onChange(of: activeFocusedRecordID) { _, recordID in
            if let recordID {
                scheduleFocusedTabBarHide(for: recordID)
            } else {
                scheduleFocusedTabBarReveal()
            }
        }
        .onChange(of: records.map(\.id)) { oldRecordIDs, recordIDs in
            let addedRecordID = recordIDs.first { !oldRecordIDs.contains($0) }
            let didAddRecord = recordIDs.count > oldRecordIDs.count && addedRecordID != nil
            reconcileSelection(with: recordIDs)
            if didAddRecord, let addedRecordID {
                collectionCountDelightTrigger += 1
                markRecentlyAddedRecord(addedRecordID)
            }
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
        .animation(.snappy(duration: 0.24), value: isSelectionMode)
        .sensoryFeedback(.success, trigger: collectionCountDelightTrigger)
        .sensoryFeedback(.selection, trigger: collectionModeDelightTrigger)
        .sensoryFeedback(.selection, trigger: collectionSelectionFeedbackTrigger)
        .sensoryFeedback(.success, trigger: collectionDeletionFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: sortDelightTrigger)
        .accessibilityIdentifier("collection-screen")
    }

    private var hidesTabBar: Bool {
        isSelectionMode || isFocusedCardTabBarHidden
    }

    private var activeFocusedRecordID: UUID? {
        selectedRecord?.id ?? selectedAtlasRecord?.id
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
        guard isSelectionMode else {
            return dynamicTypeSize.isAccessibilitySize ? 320 : 140
        }
        return dynamicTypeSize.isAccessibilitySize ? 230 : 170
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CatLocal")
                .font(CatTypography.screenTitle)
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)

            Text("A private home for the cats you meet.")
                .font(CatTypography.screenSubtitle)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }

    private var collectionSummary: some View {
        HStack(spacing: 7) {
            Image(systemName: summaryIconName)
                .font(CatTypography.metadata)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(summaryAccent)
                .symbolEffect(.bounce, value: summaryDelightTrigger)
                .accessibilityHidden(true)

            Text(summaryCountLabel)
                .contentTransition(.numericText())
        }
        .font(CatTypography.supportingEmphasized)
        .foregroundStyle(CatLocalTheme.primaryText)
        .animation(.smooth(duration: 0.22, extraBounce: 0), value: summaryCountLabel)
    }

    private var summaryCountLabel: String {
        if collectionMode == .atlas && !records.isEmpty {
            return atlasPlaceCountText
        }
        return catCountText(records.count)
    }

    private var summaryIconName: String {
        collectionMode == .atlas ? "mappin.and.ellipse" : "pawprint.fill"
    }

    private var summaryAccent: Color {
        collectionMode == .atlas ? CatAttentionRole.info.accent : CatAttentionRole.success.accent
    }

    private var summaryDelightTrigger: Int {
        collectionCountDelightTrigger + collectionModeDelightTrigger
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
                    .font(CatTypography.metadata)
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
        let isFreshlyAdded = recentlyAddedRecordID == record.id

        return Button {
            if isSelectionMode {
                toggleSelection(for: record)
            } else {
                openFocusedRecord(record, context: context)
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
                    newCardArrivalGlow(isVisible: isFreshlyAdded)
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
        .scaleEffect(isFreshlyAdded && !reduceMotion ? 1.012 : 1)
        .animation(.smooth(duration: 0.28, extraBounce: 0), value: isFreshlyAdded)
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
        .navigationDestination(item: $selectedAtlasRecord) { record in
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
                    .font(CatTypography.sectionTitle)
                    .foregroundStyle(CatLocalTheme.primaryText)
                Spacer()
                sortMenu
            }

            Text(atlasIntroText)
                .contentTransition(.numericText())
                .font(CatTypography.metadata)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
        .padding(.top, 2)
    }

    private var atlasIntroText: String {
        switch atlasPlaceCount {
        case 0:
            "Add a Memory Place from Edit to build Catlas. No GPS or public map."
        case 1:
            "1 private place typed by you. No GPS or public map."
        default:
            "\(atlasPlaceCount) private places typed by you. No GPS or public map."
        }
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
                collectionSelectionFeedbackTrigger += 1
                selectedAtlasRoute = AtlasRoute(group: group)
            }
        } label: {
            AtlasFolderButton(
                group: group,
                countText: catCountText(group.records.count),
                unplacedText: group.isUnplaced
                    ? "No memory place yet."
                    : nil,
                isHighlighted: recentlyUpdatedAtlasGroupID == group.id
            )
        }
        .buttonStyle(.catTactile)
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
            .font(CatTypography.sectionTitle)
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
                .font(CatTypography.supportingEmphasized)
                .foregroundStyle(CatLocalTheme.primaryText)

            if route.isUnplaced {
                Text("No memory place yet.")
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            sortPicker
        } label: {
            organizeMenuLabel(title: "Organize")
        }
        .accessibilityLabel("Organize places")
        .accessibilityValue("Sorted by \(sortOption.title)")
        .accessibilityHint("Sorts Catlas places")
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
                    isSelectionMode ? "Done Selecting" : "Bulk Delete...",
                    systemImage: isSelectionMode ? "checkmark.circle.fill" : "trash.circle"
                )
            }
        } label: {
            organizeMenuLabel(title: "Organize")
        }
        .accessibilityLabel("Organize cats")
        .accessibilityValue(isSelectionMode ? "Selection active" : "Sorted by \(sortOption.title)")
        .accessibilityHint("Sort cats or enter bulk delete mode")
    }

    private func organizeMenuLabel(title: String) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 17, weight: .semibold))
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text(title)
                .font(CatTypography.compactControl)
        }
        .foregroundStyle(CatLocalTheme.secondaryText)
        .padding(.horizontal, 6)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
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
                guard sortOption != option else { return }
                withAnimation(sortAnimation) {
                    sortOption = option
                }
                sortDelightTrigger += 1
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
        .buttonStyle(.catTactile)
        .accessibilityLabel("Cancel selection")
    }

    private var selectionStatus: some View {
        Text(selectedSelectionText)
            .font(CatTypography.supportingEmphasized)
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
                .font(CatTypography.compactControl)
                .padding(.horizontal, 16)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .catDestructiveActionSurface(
                    cornerRadius: 17,
                    minHeight: 46,
                    isProminent: true,
                    isDisabled: selectedRecordIDs.isEmpty
                )
        }
        .buttonStyle(.catTactile)
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
    private func newCardArrivalGlow(isVisible: Bool) -> some View {
        if isVisible {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CatAttentionRole.success.wash.opacity(0.30),
                                CatAttentionRole.success.wash.opacity(0.08),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(CatAttentionRole.success.stroke.opacity(0.74), lineWidth: 1.4)
                    .shadow(color: CatAttentionRole.success.accent.opacity(0.14), radius: 9, y: 3)
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func selectionStroke(isSelected: Bool) -> some View {
        if isSelectionMode {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? CatAttentionRole.action.accent : CatLocalTheme.imageOutline.opacity(0.58),
                    lineWidth: isSelected ? 2 : 1
                )
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isSelected ? CatAttentionRole.action.wash.opacity(0.72) : .clear)
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
                    .fill(isSelected ? CatAttentionRole.action.accent : CatLocalTheme.cardSurface.opacity(0.90))

                Circle()
                    .stroke(
                        isSelected ? CatAttentionRole.action.accent : CatLocalTheme.secondaryText.opacity(0.62),
                        lineWidth: isSelected ? 0 : 1.8
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(CatTypography.finePrint.weight(.bold))
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
        selectedAtlasRecord = nil
    }

    private func closeFocusedRecordAfterDeletion() {
        suppressFocusedZoomTransition = true
        DispatchQueue.main.async {
            selectedRecord = nil
            selectedAtlasRecord = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                suppressFocusedZoomTransition = false
            }
        }
    }

    private func navigateHomeToCats() {
        selectedRecord = nil
        selectedAtlasRecord = nil
        isFocusedCardTabBarHidden = false
        withAnimation(focusTransitionAnimation) {
            selectedAtlasRoute = nil
            collectionMode = .cards
        }
        endSelectionMode()
    }

    private func scheduleFocusedTabBarHide(for recordID: UUID) {
        Task { @MainActor in
            // Let the native zoom capture the Catlas thumbnail before the tab bar changes layout.
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard activeFocusedRecordID == recordID else { return }
            isFocusedCardTabBarHidden = true
        }
    }

    private func scheduleFocusedTabBarReveal() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard activeFocusedRecordID == nil else { return }
            isFocusedCardTabBarHidden = false
        }
    }

    private func openFocusedRecord(_ record: CatRecord, context: CardGridContext) {
        switch context {
        case .collection:
            selectedRecord = record
        case .catlas:
            selectedAtlasRecord = record
        }
    }

    private func beginSelectionMode() {
        withAnimation(.snappy(duration: 0.22)) {
            isSelectionMode = true
            selectedRecordIDs.removeAll()
        }
        collectionSelectionFeedbackTrigger += 1
    }

    private func beginSelection(with record: CatRecord) {
        withAnimation(.snappy(duration: 0.22)) {
            isSelectionMode = true
            selectedRecordIDs = [record.id]
        }
        collectionSelectionFeedbackTrigger += 1
    }

    private func toggleSelection(for record: CatRecord) {
        withAnimation(.snappy(duration: 0.18)) {
            if selectedRecordIDs.contains(record.id) {
                selectedRecordIDs.remove(record.id)
            } else {
                selectedRecordIDs.insert(record.id)
            }
        }
        collectionSelectionFeedbackTrigger += 1
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
        return "Select for Bulk Delete"
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

    private func markRecentlyAddedRecord(_ recordID: UUID) {
        let groupID = records.first { $0.id == recordID }?.atlasGroupTitle
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.28, extraBounce: 0)) {
            recentlyAddedRecordID = recordID
            recentlyUpdatedAtlasGroupID = groupID
        }

        Task { @MainActor [recordID] in
            try? await Task.sleep(nanoseconds: 1_450_000_000)
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.30, extraBounce: 0)) {
                if recentlyAddedRecordID == recordID {
                    recentlyAddedRecordID = nil
                    recentlyUpdatedAtlasGroupID = nil
                }
            }
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
            if selectedRecord?.id == record.id || selectedAtlasRecord?.id == record.id {
                selectedRecord = nil
                selectedAtlasRecord = nil
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
            collectionDeletionFeedbackTrigger += 1
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
                    .font(CatTypography.pageTitle)
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)

                Text("Capture a cat encounter and keep it private on this iPhone.")
                    .font(CatTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 300)
            }

            if let onCaptureRequested {
                Button {
                    onCaptureRequested()
                } label: {
                    Label("Capture or Import", systemImage: "camera.fill")
                        .font(CatTypography.control)
                        .frame(maxWidth: .infinity)
                        .catPrimaryActionSurface(role: .action, cornerRadius: 28)
                }
                .buttonStyle(.catTactile)
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
                    privacyPoint(icon: "person.crop.circle.badge.xmark", title: "No Account", role: .info)
                    privacyPoint(icon: "map.fill", title: "No Public Map", role: .success)
                    privacyPoint(icon: "brain.head.profile", title: "No Model Training", role: .success)
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    privacyPoint(icon: "person.crop.circle.badge.xmark", title: "No Account", role: .info)
                    privacyPoint(icon: "map.fill", title: "No Public Map", role: .success)
                    privacyPoint(icon: "brain.head.profile", title: "No Model Training", role: .success)
                }
            }
        }
    }

    private func privacyPoint(icon: String, title: String, role: CatAttentionRole) -> some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(role.accent)
                .frame(width: 30, height: 30)

            Text(title)
                .font(CatTypography.badge)
                .foregroundStyle(role.text)
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
    let isHighlighted: Bool

    var body: some View {
        let bodyShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 9) {
            folderLayout
            unplacedGuidance
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            folderBackground(in: bodyShape)
        }
        .overlay { rowOutline(bodyShape) }
        .overlay(alignment: .topLeading) {
            folderLip
        }
        .shadow(color: CatLocalTheme.shadow.opacity(rowShadowOpacity), radius: 7, y: 3)
        .contentShape(Rectangle())
    }

    private var baseGroupBackground: Color {
        group.isUnplaced ? CatLocalTheme.elevatedSurface.opacity(0.74) : CatLocalTheme.cardSurface.opacity(0.78)
    }

    private var rowShadowOpacity: Double {
        if isHighlighted {
            return 0.11
        }
        return group.isUnplaced ? 0.09 : 0.07
    }

    @ViewBuilder
    private func folderBackground(in shape: RoundedRectangle) -> some View {
        shape
            .fill(baseGroupBackground)

        if !group.isUnplaced {
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            CatAttentionRole.info.wash.opacity(isHighlighted ? 0.28 : 0.10),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }

        if isHighlighted {
            shape
                .fill(CatAttentionRole.success.wash.opacity(0.22))
        }
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: group.isUnplaced ? "tray" : "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(group.isUnplaced ? CatLocalTheme.secondaryText : CatAttentionRole.info.accent)
                    .accessibilityHidden(true)

                Text(group.displayTitle)
                    .font(CatTypography.supportingEmphasized)
                    .foregroundStyle(CatLocalTheme.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }

            Text(countText)
                .font(CatTypography.finePrint)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .contentTransition(.numericText())
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(CatTypography.metadata)
            .imageScale(.small)
            .foregroundStyle(CatLocalTheme.secondaryText.opacity(0.72))
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var unplacedGuidance: some View {
        if let unplacedText {
            Text(unplacedText)
                .font(CatTypography.metadata)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }

    private var folderLip: some View {
        Capsule(style: .continuous)
            .fill(
                (group.isUnplaced ? CatLocalTheme.secondaryText : CatAttentionRole.info.accent)
                    .opacity(isHighlighted ? 0.42 : 0.22)
            )
            .frame(width: 44, height: 3)
            .padding(.leading, 18)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func rowOutline(_ shape: RoundedRectangle) -> some View {
        shape.stroke(
            rowOutlineColor,
            lineWidth: isHighlighted ? 1.35 : 1
        )
    }

    private var rowOutlineColor: Color {
        if isHighlighted {
            return CatAttentionRole.success.stroke.opacity(0.62)
        }
        return group.isUnplaced
            ? CatLocalTheme.imageOutline.opacity(0.52)
            : CatLocalTheme.imageOutline.opacity(0.46)
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
            .font(CatTypography.badge)
            .foregroundStyle(CatLocalTheme.primaryText)
            .frame(width: 48, height: 48)
            .background(
                CatLocalTheme.elevatedSurface.opacity(0.82),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
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
                .background(CatLocalTheme.elevatedSurface.opacity(0.88))
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(CatLocalTheme.cardSurface.opacity(0.92), lineWidth: 2)
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
