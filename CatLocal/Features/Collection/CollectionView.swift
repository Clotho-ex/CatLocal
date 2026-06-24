import SwiftData
import SwiftUI

struct CollectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(sort: \CatRecord.capturedAt, order: .reverse)
    private var records: [CatRecord]

    @State private var selectedRecord: CatRecord?
    @State private var collectionMode: CollectionMode = .cards

    private let onCaptureRequested: (() -> Void)?

    init(onCaptureRequested: (() -> Void)? = nil) {
        self.onCaptureRequested = onCaptureRequested
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
                        cardGrid
                    case .atlas:
                        memoryAtlas
                    }
                }
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(item: $selectedRecord) { record in
            FocusedCardView(record: record)
        }
        .accessibilityIdentifier("collection-screen")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CatLocal")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text("YOUR COLLECTION")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            Spacer()

            CatGlassGroup {
                Image(systemName: records.isEmpty ? "camera.aperture" : "square.grid.2x2")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .catGlass(cornerRadius: 22)
                    .accessibilityHidden(true)
            }
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
        Text(records.isEmpty ? "Ready for your first card" : summaryDetail)
            .font(.subheadline)
            .foregroundStyle(CatLocalTheme.secondaryText)
    }

    private var summaryDetail: String {
        let placedCount = records.filter { $0.memoryPlaceName != nil }.count
        guard placedCount > 0 else { return "Sorted by recent" }
        return "\(placedCount) in Memory Atlas"
    }

    private var modePicker: some View {
        Picker("Collection view", selection: $collectionMode) {
            ForEach(CollectionMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("collection-mode-picker")
    }

    private var cardGrid: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(records) { record in
                Button {
                    selectedRecord = record
                } label: {
                    CatCardView(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var memoryAtlas: some View {
        VStack(alignment: .leading, spacing: 18) {
            atlasIntro

            ForEach(atlasGroups) { group in
                atlasGroup(group)
            }
        }
        .accessibilityIdentifier("memory-atlas")
    }

    private var atlasIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Memory Atlas")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                Spacer()
                Text(atlasSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

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
        let grouped = Dictionary(grouping: records) { record in
            record.atlasGroupTitle
        }

        return grouped.map { title, records in
            MemoryAtlasGroup(
                title: title,
                records: records.sorted { $0.capturedAt > $1.capturedAt },
                isUnplaced: title == "Unplaced"
            )
        }
        .sorted { lhs, rhs in
            if lhs.isUnplaced != rhs.isUnplaced {
                return !lhs.isUnplaced
            }

            return lhs.latestCapture > rhs.latestCapture
        }
    }

    private func atlasGroup(_ group: MemoryAtlasGroup) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(2)
                Spacer()
                Text(group.records.count == 1 ? "1 card" : "\(group.records.count) cards")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            if group.isUnplaced {
                Text("Add a memory place from Edit Card, or while saving a new card.")
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
            selectedRecord = record
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CatLocalTheme.accent(for: record.cardStyle))
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

                    Text("#\(record.sequence.formatted(.number.precision(.integerLength(3)))) - \(record.cardStyle.title) - \(record.capturedAt.formatted(date: .abbreviated, time: .omitted))")
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
        .accessibilityHint("Opens this saved card")
    }

    private func atlasAccessibilityLabel(for record: CatRecord) -> String {
        let place = record.memoryPlaceLabel ?? "Unplaced"
        return "\(record.displayName), \(place), \(record.cardStyle.title) style, card \(record.sequence.formatted(.number.precision(.integerLength(3))))."
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(CatLocalTheme.primaryText)

            VStack(spacing: 7) {
                Text("Meet Your First Local")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.82)

                Text("Capture a cat encounter and keep the card private on this iPhone.")
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
                    privacyPoint(icon: "brain.head.profile", title: "No Model Training")
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    privacyPoint(icon: "person.crop.circle.badge.xmark", title: "No Account")
                    privacyPoint(icon: "map.fill", title: "No Public Map")
                    privacyPoint(icon: "brain.head.profile", title: "No Model Training")
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
        case .cards: "Cards"
        case .atlas: "Atlas"
        }
    }
}

private struct MemoryAtlasGroup: Identifiable {
    let title: String
    let records: [CatRecord]
    let isUnplaced: Bool

    var id: String { title }

    var latestCapture: Date {
        records.map(\.capturedAt).max() ?? .distantPast
    }
}
