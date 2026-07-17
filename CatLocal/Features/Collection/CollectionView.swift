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
    @State private var editingIntent: CatRecordEditIntent = .card
    @State private var removalRecord: CatRecord?
    @State private var selectedAtlasRoute: AtlasRoute?
    @AppStorage(CatLocalUserDefaults.homeViewKey) private var collectionMode = CatLocalHomeView.cards
    @AppStorage(CatLocalUserDefaults.sortOrderKey) private var sortOption = CatLocalSortOrder.number
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
                            collectionModeStage
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
        .sheet(item: $editingRecord, onDismiss: {
            editingIntent = .card
        }) { record in
            CatRecordEditSheet(
                record: record,
                initialFocusedField: editingIntent.initialFocusedField
            )
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
                title: "Delete selected cards?",
                message: "The selected originals, cutouts, notes, and records will be removed from this iPhone.",
                deleteTitle: bulkDeleteTitle,
                isDeleting: isBulkDeleting
            ) {
                Task { await removeSelectedRecords() }
            } onCancel: {
                guard !isBulkDeleting else { return }
                showingBulkDeleteConfirmation = false
            }
        }
        .alert("Could not delete card", isPresented: .constant(errorMessage != nil)) {
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
        .animation(selectionModeAnimation, value: isSelectionMode)
        .catSensoryFeedback(.success, trigger: collectionCountDelightTrigger)
        .catSensoryFeedback(.selection, trigger: collectionModeDelightTrigger)
        .catSensoryFeedback(.selection, trigger: collectionSelectionFeedbackTrigger)
        .catSensoryFeedback(.success, trigger: collectionDeletionFeedbackTrigger)
        .catSensoryFeedback(.selection, trigger: sortDelightTrigger)
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

    private var collectionModeAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24, extraBounce: 0)
    }

    private var selectionModeAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.22, extraBounce: 0)
    }

    private var selectionModeLabelTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 8)),
            removal: .opacity.combined(with: .offset(x: -8))
        )
    }

    private var headerSortTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 8)),
            removal: .opacity.combined(with: .offset(x: 8))
        )
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

            Text("A private field journal for the cats you meet.")
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
        if collectionMode == .catlas && !records.isEmpty {
            return atlasPlaceCountText
        }
        return savedCountText(records.count)
    }

    private var summaryIconName: String {
        collectionMode == .catlas ? "mappin.and.ellipse" : "pawprint.fill"
    }

    private var summaryAccent: Color {
        collectionMode == .catlas ? CatAttentionRole.info.accent : CatAttentionRole.success.accent
    }

    private var summaryDelightTrigger: Int {
        collectionCountDelightTrigger + collectionModeDelightTrigger
    }

    private var modePicker: some View {
        Picker("Home view", selection: collectionModeSelection) {
            ForEach(CatLocalHomeView.allCases) { mode in
                Text(catLocalKey: mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("collection-mode-picker")
    }

    private var collectionModeSelection: Binding<CatLocalHomeView> {
        Binding(
            get: { collectionMode },
            set: { mode in
                setCollectionMode(mode)
            }
        )
    }

    private var collectionModeStage: some View {
        ZStack(alignment: .topLeading) {
            switch collectionMode {
            case .cards:
                catGridSection
                    .id(CatLocalHomeView.cards)
                    .transition(collectionModeTransition(for: .cards))
            case .catlas:
                catlas
                    .id(CatLocalHomeView.catlas)
                    .transition(collectionModeTransition(for: .catlas))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
        .animation(collectionModeAnimation, value: collectionMode)
    }

    private func collectionModeTransition(for mode: CatLocalHomeView) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        switch mode {
        case .cards:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .catlas:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private var catGridSection: some View {
        let visibleRecords = sortedRecords

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: isSelectionMode ? "Select Cards" : "Archive")

            if isSelectionMode {
                Text("Select cards to delete from this iPhone.")
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
                    openCardEditor(for: record)
                }
            } label: {
                Label("Edit Card", systemImage: "pencil")
            }

            if record.memoryPlaceName == nil {
                Button {
                    deferContextMenuAction {
                        openMemoryPlaceEditor(for: record)
                    }
                } label: {
                    Label("Add Memory Place", systemImage: "mappin.and.ellipse")
                }
            }

            Button(role: .destructive) {
                deferContextMenuAction {
                    removalRecord = record
                }
            } label: {
                Label("Delete Card", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("collection-card-\(record.sequence)")
        .accessibilityHint(
            isSelectionMode
                ? "Double tap to select or deselect this card".catLocalized
                : "Double tap to open this card".catLocalized
        )
        .accessibilityValue(selectionAccessibilityValue(isSelected: isSelected))
        .accessibilityAddTraits(isSelectionMode && isSelected ? .isSelected : [])
    }

    private var catlas: some View {
        let groups = atlasGroups
        let placedGroups = groups.filter { !$0.isUnplaced }
        let unplacedGroups = groups.filter(\.isUnplaced)

        return VStack(alignment: .leading, spacing: 18) {
            atlasIntro

            ForEach(placedGroups) { group in
                atlasGroup(group)
            }

            if !unplacedGroups.isEmpty {
                if !placedGroups.isEmpty {
                    unplacedDivider
                }

                ForEach(unplacedGroups) { group in
                    atlasGroup(group)
                }
            }
        }
        .animation(sortAnimation, value: groups.map(\.id))
        .accessibilityIdentifier("catlas")
    }

    private var unplacedDivider: some View {
        HStack(alignment: .center, spacing: 10) {
            Rectangle()
                .fill(CatLocalTheme.separator.opacity(0.78))
                .frame(height: 1)

            Text("Unplaced for now")
                .font(CatTypography.badge)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Rectangle()
                .fill(CatLocalTheme.separator.opacity(0.78))
                .frame(height: 1)
        }
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 6 : 2)
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 2 : 0)
        .accessibilityElement(children: .combine)
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
            "Add a Memory Place to build Catlas.".catLocalized
        default:
            CatLocalLocalization.plural("%lld places typed by you.", count: atlasPlaceCount)
        }
    }

    private var atlasPlaceCount: Int {
        Set(records.compactMap(\.memoryPlaceName)).count
    }

    private var atlasPlaceCountText: String {
        CatLocalLocalization.plural("%lld places", count: atlasPlaceCount)
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
            openAtlasGroup(group)
        } label: {
            AtlasFolderButton(
                group: group,
                countText: catCountText(group.records.count),
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
                    cardGridHeaderActions
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        sectionTitle(title)
                        Spacer(minLength: 10)
                        cardGridHeaderActions
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(title)
                        cardGridHeaderActions
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(catLocalKey: title)
            .font(CatTypography.sectionTitle)
            .foregroundStyle(CatLocalTheme.primaryText)
            .lineLimit(nil)
    }

    private func atlasRouteHeader(_ route: AtlasRoute, recordCount: Int) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    atlasRouteSummary(recordCount: recordCount)
                    cardGridHeaderActions
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        atlasRouteSummary(recordCount: recordCount)
                        Spacer(minLength: 10)
                        cardGridHeaderActions
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        atlasRouteSummary(recordCount: recordCount)
                        cardGridHeaderActions
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func atlasRouteSummary(recordCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(catCountText(recordCount))
                .font(CatTypography.supportingEmphasized)
                .foregroundStyle(CatLocalTheme.primaryText)
        }
    }

    private var sortMenu: some View {
        Menu {
            sortPicker(title: "Sort places")
        } label: {
            headerActionLabel(title: "Sort", systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Sort places")
        .accessibilityValue(
            CatLocalLocalization.format(
                "Sorted by %1$@",
                CatLocalLocalization.string(sortOption.title)
            )
        )
        .accessibilityHint("Sorts Catlas places")
    }

    private var cardGridHeaderActions: some View {
        HStack(alignment: .center, spacing: 8) {
            if !isSelectionMode {
                cardGridSortMenu
                    .transition(headerSortTransition)
            }

            selectionModeButton
        }
        .animation(selectionModeAnimation, value: isSelectionMode)
        .accessibilityElement(children: .contain)
    }

    private var cardGridSortMenu: some View {
        Menu {
            sortPicker(title: "Sort saved cards")
        } label: {
            headerActionLabel(title: "Sort", systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Sort saved cards")
        .accessibilityValue(
            CatLocalLocalization.format(
                "Sorted by %1$@",
                CatLocalLocalization.string(sortOption.title)
            )
        )
        .accessibilityHint("Changes the card order")
    }

    private var selectionModeButton: some View {
        Button {
            if isSelectionMode {
                endSelectionMode()
            } else {
                beginSelectionMode()
            }
        } label: {
            selectionModeButtonLabel
        }
        .buttonStyle(.catTactile)
        .accessibilityIdentifier("collection-selection-toggle")
        .accessibilityLabel(
            isSelectionMode
                ? "Done selecting cards".catLocalized
                : "Select cards for deletion".catLocalized
        )
        .accessibilityValue(isSelectionMode ? selectedSelectionText : "")
        .accessibilityHint(
            isSelectionMode
                ? "Leaves selection mode".catLocalized
                : "Shows selection controls before deleting cards".catLocalized
        )
    }

    private var selectionModeButtonLabel: some View {
        ZStack {
            selectionControlLabel(title: "Select", systemImage: "checkmark.circle")
                .hidden()
                .accessibilityHidden(true)

            selectionControlLabel(title: "Done", systemImage: "checkmark.circle.fill")
                .hidden()
                .accessibilityHidden(true)

            selectionControlLabel(
                title: isSelectionMode ? "Done" : "Select",
                systemImage: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle"
            )
            .id(isSelectionMode)
            .transition(selectionModeLabelTransition)
        }
        .clipped()
    }

    private func headerActionLabel(title: String, systemImage: String) -> some View {
        selectionControlLabel(title: title, systemImage: systemImage)
    }

    private func selectionControlLabel(title: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text(catLocalKey: title)
                .font(CatTypography.compactControl)
        }
        .foregroundStyle(CatLocalTheme.secondaryText)
        .padding(.horizontal, 6)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func sortPicker(title: String) -> some View {
        Picker(title, selection: sortSelection) {
            ForEach(CatLocalSortOrder.allCases) { option in
                Label {
                    Text(catLocalKey: option.title)
                } icon: {
                    Image(systemName: option.systemImage)
                }
                .tag(option)
            }
        }
    }

    private var sortSelection: Binding<CatLocalSortOrder> {
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
            .catGlass(cornerRadius: 26, legacyRole: .groupedAction)
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
            .accessibilityIdentifier("collection-selection-status")
    }

    private var bulkDeleteButton: some View {
        Button {
            guard !selectedRecordIDs.isEmpty, !isBulkDeleting else { return }
            showingBulkDeleteConfirmation = true
        } label: {
            Label {
                Text(catLocalKey: isBulkDeleting ? "Deleting" : "Delete")
            } icon: {
                Image(systemName: "trash.fill")
            }
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
        .accessibilityIdentifier("collection-delete-selected")
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
            return "Choose cards to delete".catLocalized
        }
        return CatLocalLocalization.plural("%lld cards selected", count: selectedRecordIDs.count)
    }

    private var bulkDeleteTitle: String {
        CatLocalLocalization.plural("Delete %lld Cards", count: selectedRecordIDs.count)
    }

    private var removalErrorMessage: String {
        guard let errorMessage else { return "" }
        return "\("The card was not deleted. Please try again.".catLocalized)\n\n\(errorMessage)"
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
        withAnimation(collectionModeAnimation) {
            selectedAtlasRoute = nil
            collectionMode = .cards
        }
        endSelectionMode()
    }

    private func setCollectionMode(_ mode: CatLocalHomeView) {
        guard mode != collectionMode else { return }
        withAnimation(collectionModeAnimation) {
            collectionMode = mode
        }
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
        withAnimation(selectionModeAnimation) {
            isSelectionMode = true
            selectedRecordIDs.removeAll()
        }
        collectionSelectionFeedbackTrigger += 1
    }

    private func beginSelection(with record: CatRecord) {
        withAnimation(selectionModeAnimation) {
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
        withAnimation(selectionModeAnimation) {
            isSelectionMode = false
            selectedRecordIDs.removeAll()
        }
    }

    private func selectionContextTitle(isSelected: Bool) -> String {
        if isSelectionMode {
            return isSelected
                ? "Remove from Selection".catLocalized
                : "Add to Selection".catLocalized
        }
        return "Select Card".catLocalized
    }

    private func selectionAccessibilityValue(isSelected: Bool) -> String {
        guard isSelectionMode else { return "" }
        return isSelected ? "Selected for deletion".catLocalized : "Not selected".catLocalized
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

    private func openCardEditor(for record: CatRecord) {
        editingIntent = .card
        editingRecord = record
    }

    private func openMemoryPlaceEditor(for record: CatRecord) {
        editingIntent = .memoryPlace
        editingRecord = record
        collectionSelectionFeedbackTrigger += 1
    }

    private func openAtlasGroup(_ group: MemoryAtlasGroup) {
        withAnimation(focusTransitionAnimation) {
            collectionSelectionFeedbackTrigger += 1
            selectedAtlasRoute = AtlasRoute(group: group)
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
        CatLocalLocalization.plural("%lld cats", count: count)
    }

    private func savedCountText(_ count: Int) -> String {
        CatLocalLocalization.plural("%lld saved cards", count: count)
    }

    private var emptyState: some View {
        LociStateView(
            context: .emptyCollection,
            showsCard: true,
            mascotSize: dynamicTypeSize.isAccessibilitySize ? 112 : 120,
            cardWidth: dynamicTypeSize.isAccessibilitySize ? 126 : 136,
            buttonTitle: onCaptureRequested == nil ? nil : "Capture or Import",
            buttonAction: onCaptureRequested
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 22)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 30 : 36)
        .accessibilityIdentifier("empty-collection")
    }
}

private struct AtlasFolderButton: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let group: MemoryAtlasGroup
    let countText: String
    let isHighlighted: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(spacing: 0) {
            folderHeader
                .padding(12)

            Rectangle()
                .fill(CatLocalTheme.separator.opacity(0.72))
                .frame(height: 1)
                .padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(visibleRecords) { record in
                    AtlasCatRecordRow(record: record)

                    if record.id != visibleRecords.last?.id {
                        Rectangle()
                            .fill(CatLocalTheme.separator.opacity(0.56))
                            .frame(height: 1)
                            .padding(.leading, 96)
                    }
                }

                if hiddenRecordCount > 0 {
                    moreCatsRow
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { shape.fill(groupBackground) }
        .overlay { shape.stroke(groupOutline, lineWidth: isHighlighted ? 1.35 : 1) }
        .clipShape(shape)
        .contentShape(shape)
    }

    private var visibleRecords: [CatRecord] {
        Array(group.records.prefix(3))
    }

    private var hiddenRecordCount: Int {
        max(group.records.count - visibleRecords.count, 0)
    }

    private var groupBackground: Color {
        if isHighlighted {
            return CatAttentionRole.success.wash.opacity(0.30)
        }
        return group.isUnplaced
            ? CatLocalTheme.elevatedSurface.opacity(0.70)
            : CatLocalTheme.cardSurface.opacity(0.88)
    }

    private var groupOutline: Color {
        isHighlighted
            ? CatAttentionRole.success.stroke.opacity(0.62)
            : CatLocalTheme.imageOutline.opacity(0.46)
    }

    private var folderHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: group.isUnplaced ? "tray" : "mappin.and.ellipse")
                        .font(CatTypography.metadata.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(group.isUnplaced ? CatLocalTheme.secondaryText : CatAttentionRole.info.accent)
                        .accessibilityHidden(true)

                    Text(catLocalKey: group.displayTitle)
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

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(CatTypography.metadata)
                .imageScale(.small)
                .foregroundStyle(CatLocalTheme.secondaryText.opacity(0.72))
                .frame(width: 22, height: 44)
                .accessibilityHidden(true)
        }
    }

    private var moreCatsRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis")
                .font(CatTypography.metadata.weight(.semibold))
                .frame(width: 24, height: 24)
                .background(CatLocalTheme.elevatedSurface, in: Circle())
                .accessibilityHidden(true)

            Text(CatLocalLocalization.plural("%lld more cats", count: hiddenRecordCount))
                .font(CatTypography.metadata)
                .foregroundStyle(CatLocalTheme.secondaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
    }
}

private struct AtlasCatRecordRow: View {
    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 72

    let record: CatRecord

    var body: some View {
        HStack(spacing: 12) {
            catImage

            VStack(alignment: .leading, spacing: 4) {
                Text(record.displayName)
                    .font(CatTypography.supportingEmphasized)
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(2)

                Text(record.capturedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(CatTypography.finePrint)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(record.sequence.formatted())
                .font(CatTypography.sequence(focused: false))
                .monospacedDigit()
                .foregroundStyle(CatLocalTheme.primaryText)
                .frame(width: 28, height: 28)
                .background(CatLocalTheme.elevatedSurface, in: Circle())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            CatLocalLocalization.format(
                "%1$@, cat number %2$lld, captured %3$@.",
                record.displayName,
                Int64(record.sequence),
                record.capturedAt.formatted(date: .abbreviated, time: .omitted)
            )
        )
        .accessibilityIdentifier("catlas-cat-row-\(record.displayName)")
    }

    private var resolvedThumbnailSize: CGFloat {
        min(thumbnailSize, 92)
    }

    private var catImage: some View {
        StoredImageView(path: record.thumbnailImagePath, contentMode: .fit) {
            Image(systemName: "cat.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(6)
        .frame(width: resolvedThumbnailSize, height: resolvedThumbnailSize)
        .background(CatLocalTheme.elevatedSurface.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(CatLocalTheme.imageOutline.opacity(0.44), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private enum CardGridContext {
    case collection
    case catlas

    var showsThumbnailPlaceFooter: Bool {
        self == .collection
    }
}

private enum CatRecordEditIntent {
    case card
    case memoryPlace

    var initialFocusedField: CatRecordEditSheet.FocusedField? {
        switch self {
        case .card:
            nil
        case .memoryPlace:
            .location
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
        isUnplaced ? "Unplaced" : title
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
