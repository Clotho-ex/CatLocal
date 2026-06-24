import SwiftData
import SwiftUI

struct CollectionView: View {
    @Query(sort: \CatRecord.capturedAt, order: .reverse)
    private var records: [CatRecord]

    @State private var selectedRecord: CatRecord?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if records.isEmpty {
                    emptyState
                } else {
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
            }
            .padding(.horizontal, 22)
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CatLocal")
                        .catEditorialTitle(size: 58)
                        .foregroundStyle(CatLocalTheme.primaryText)

                    Text("YOUR COLLECTION")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(3.2)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .frame(width: 48, height: 48)
                    .catGlass(cornerRadius: 24)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 12) {
                Text(records.count == 1 ? "1 cat" : "\(records.count) cats")
                    .font(.subheadline.weight(.semibold))

                Rectangle()
                    .fill(CatLocalTheme.separator)
                    .frame(width: 2, height: 16)

                Text("Sorted by recent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(CatLocalTheme.primaryText)

            VStack(spacing: 7) {
                Text("Your first local is out there")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)

                Text("Use the camera button to turn a cat encounter into a private card. Nothing leaves this iPhone.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 310)
            }

            Label("No account. No public map. No model training.", systemImage: "lock.shield.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 46)
        .background(CatLocalTheme.elevatedSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
        )
        .accessibilityIdentifier("empty-collection")
    }
}
