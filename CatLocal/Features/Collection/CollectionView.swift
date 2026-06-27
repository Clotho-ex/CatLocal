import SwiftData
import SwiftUI

struct CollectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CatRecord.sequence, order: .forward)
    private var records: [CatRecord]

    @Namespace private var cardTransitionNamespace

    @State private var selectedRecord: CatRecord?
    @State private var editingRecord: CatRecord?
    @State private var removalRecord: CatRecord?
    @State private var collectionMode: CollectionMode = .cards
    @State private var sortOption: CatSortOption = .number
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
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        collectionSummary

                        if records.isEmpty {
                            emptyState
                        } else {
                            modePicker

                            switch collectionMode {
                            case .cards:
                                catGridSection
                            case .atlas:
                                catlas
                            }
                        }
                    }
                    .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(item: $selectedRecord) { record in
                FocusedCardView(record: record) {
                    closeFocusedRecord()
                }
                .navigationTransition(.zoom(sourceID: record.id, in: cardTransitionNamespace))
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .sheet(item: $editingRecord) { record in
            CatRecordEditSheet(record: record)
                .presentationBackground(CatLocalTheme.background)
        }
        .confirmationDialog(
            "Remove this cat?",
            isPresented: removalConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Remove Cat", role: .destructive) {
                guard let removalRecord else { return }
                Task { await remove(record: removalRecord) }
            }
            Button("Cancel", role: .cancel) {
                removalRecord = nil
            }
        } message: {
            Text("The original photo, cutout, notes, and cat will be removed from this iPhone.")
        }
        .alert("Could not remove cat", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: homeReselectionID) {
            guard selectedRecord != nil else { return }
            closeFocusedRecord()
        }
        .onChange(of: selectedTab) { _, tab in
            guard tab != .home, selectedRecord != nil else { return }
            closeFocusedRecord()
        }
        .accessibilityIdentifier("collection-screen")
    }

    private var focusTransitionAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.84)
    }

    private var sortAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.28)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CatLocal")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text("A private home for the cats you meet.")
                .font(.subheadline)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
    }

    private var collectionSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                summaryCount

                Rectangle()
                    .fill(CatLocalTheme.separator)
                    .frame(width: 2, height: 16)

                summarySort
            }

            VStack(alignment: .leading, spacing: 4) {
                summaryCount
                summarySort
            }
        }
    }

    private var summaryCount: some View {
        Text(records.count == 1 ? "1 cat" : "\(records.count) cats")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CatLocalTheme.primaryText)
    }

    private var summarySort: some View {
        Text(records.isEmpty ? "Ready for your first cat" : summaryDetail)
            .font(.subheadline)
            .foregroundStyle(CatLocalTheme.secondaryText)
    }

    private var summaryDetail: String {
        let placedCount = records.filter { $0.memoryPlaceName != nil }.count
        guard placedCount > 0 else { return "Sorted by \(sortOption.summaryLabel)" }
        return "\(placedCount) in Catlas"
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
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Cats")

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(sortedRecords) { record in
                    catGridCard(record)
                }
            }
            .animation(sortAnimation, value: sortedRecords.map(\.id))
        }
    }

    private func catGridCard(_ record: CatRecord) -> some View {
        Button {
            withAnimation(focusTransitionAnimation) {
                selectedRecord = record
            }
        } label: {
            CatCardView(record: record)
                .frame(maxWidth: .infinity)
                .aspectRatio(0.72, contentMode: .fit)
                .overlay {
                    homeCardQuietingOverlay
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .matchedTransitionSource(id: record.id, in: cardTransitionNamespace) { configuration in
                    configuration
                        .background(.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: CatLocalTheme.shadow.opacity(0.18), radius: 14, y: 7)
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.72, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipped()
        .contextMenu {
            Button {
                editingRecord = record
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                removalRecord = record
            } label: {
                Label("Remove Cat", systemImage: "trash")
            }
        }
    }

    private var catlas: some View {
        VStack(alignment: .leading, spacing: 18) {
            atlasIntro

            ForEach(atlasGroups) { group in
                atlasGroup(group)
            }
        }
        .animation(sortAnimation, value: atlasGroups.map(\.id))
        .accessibilityIdentifier("catlas")
    }

    private var atlasIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Catlas")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                Spacer()
                sortMenu
            }

            Text(atlasSummary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(2)

            Text("A private index of the places you type yourself. No GPS, coordinates, or public map.")
                .font(.subheadline)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .lineLimit(nil)
        }
        .padding(18)
        .catPanelSurface(fillOpacity: 0.86, shadowOpacity: 0.14)
    }

    private var atlasSummary: String {
        let placedCount = records.filter { $0.memoryPlaceName != nil }.count
        return placedCount == 1 ? "1 placed" : "\(placedCount) placed"
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
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.displayTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(2)
                Spacer()
                Text(catCountText(group.records.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            if group.isUnplaced {
                Text("\(unplacedCountText(group.records.count)). Add a memory place while saving a new cat or from Edit Cat.")
                    .font(.footnote)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
            }

            VStack(spacing: 0) {
                ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                    atlasRow(record)

                    if index < group.records.count - 1 {
                        Rectangle()
                            .fill(CatLocalTheme.separator)
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(18)
        .catPanelSurface(fillOpacity: 0.82, shadowOpacity: 0.10)
        .accessibilityElement(children: .contain)
    }

    private func atlasRow(_ record: CatRecord) -> some View {
        Button {
            withAnimation(focusTransitionAnimation) {
                selectedRecord = record
            }
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CatLocalTheme.infoSymbol)
                    .frame(width: 28, height: 28)
                    .background(
                        CatLocalTheme.elevatedSurface.opacity(0.72),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .lineLimit(2)

                    Text("Cat \(record.sequence.formatted()) - \(record.capturedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                        .lineLimit(2)

                    if let detail = record.memoryPlaceDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(atlasAccessibilityLabel(for: record))
        .accessibilityHint("Opens this saved cat")
    }

    private func atlasAccessibilityLabel(for record: CatRecord) -> String {
        let place = record.memoryPlaceLabel ?? "Unplaced"
        return "\(record.displayName), \(place), cat \(record.sequence.formatted())."
    }

    private func sectionHeader(title: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
            Spacer()
            sortMenu
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort cats", selection: sortSelection) {
                ForEach(CatSortOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Label(sortOption.title, systemImage: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("Sort cats")
        .accessibilityValue(sortOption.title)
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

    private var removalConfirmationBinding: Binding<Bool> {
        Binding(
            get: { removalRecord != nil },
            set: { isPresented in
                if !isPresented {
                    removalRecord = nil
                }
            }
        )
    }

    private var homeCardQuietingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CatLocalTheme.background.opacity(0.34), lineWidth: 5)
                .blur(radius: 2.2)
                .padding(2)

            LinearGradient(
                colors: [
                    CatLocalTheme.background.opacity(0.16),
                    .clear,
                    CatLocalTheme.background.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CatLocalTheme.imageOutline.opacity(0.8), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    private func closeFocusedRecord() {
        withAnimation(focusTransitionAnimation) {
            selectedRecord = nil
        }
    }

    private func remove(record: CatRecord) async {
        do {
            try await CatImageStore.shared.deleteRecord(id: record.id)
            modelContext.delete(record)
            try modelContext.save()
            if selectedRecord?.id == record.id {
                selectedRecord = nil
            }
            removalRecord = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func catCountText(_ count: Int) -> String {
        count == 1 ? "1 cat" : "\(count) cats"
    }

    private func unplacedCountText(_ count: Int) -> String {
        count == 1 ? "1 unplaced cat" : "\(count) unplaced cats"
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(CatLocalTheme.primaryText)

            VStack(spacing: 7) {
                Text("Meet Your First Cat")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.82)

                Text("Capture a cat encounter and keep it private on this iPhone.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300)
            }

            if let onCaptureRequested {
                Button {
                    onCaptureRequested()
                } label: {
                    Label("Open Camera", systemImage: "camera.fill")
                        .font(.headline)
                        .catPrimaryActionSurface()
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
        .background(
            CatLocalTheme.elevatedSurface.opacity(0.82),
            in: RoundedRectangle(cornerRadius: CatLocalTheme.largePanelRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CatLocalTheme.largePanelRadius, style: .continuous)
                .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
        )
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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

    var summaryLabel: String {
        switch self {
        case .number: "number"
        case .place: "place"
        case .alphabetical: "name"
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

private struct MemoryAtlasGroup: Identifiable {
    let title: String
    let records: [CatRecord]
    let isUnplaced: Bool

    var id: String { title }

    var displayTitle: String {
        isUnplaced ? "Unplaced cats" : title
    }

    var latestCapture: Date {
        records.map(\.capturedAt).max() ?? .distantPast
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
