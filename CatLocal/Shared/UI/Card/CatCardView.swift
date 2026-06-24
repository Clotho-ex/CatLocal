import SwiftUI

struct CatCardView: View {
    let record: CatRecord
    var presentation: CatCardPresentation = .thumbnail

    private var isFocused: Bool { presentation == .focused }

    var body: some View {
        CatCardSurface(
            sequence: record.sequence,
            name: record.displayName,
            date: record.capturedAt,
            note: record.note,
            placeName: record.memoryPlaceName,
            placeDetail: record.memoryPlaceDetail,
            presentation: presentation
        ) {
            StoredImageView(path: imagePath, contentMode: .fit) {
                ProgressView()
                    .tint(CatLocalTheme.primaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isFocused ? "Drag the cat to shift its light" : "Double tap to open focused cat view.")
    }

    private var imagePath: String {
        isFocused ? record.cutoutImagePath : record.thumbnailImagePath
    }

    private var accessibilityLabel: String {
        let place = record.memoryPlaceLabel.map { " Memory Place, \($0)." } ?? ""
        return "Cat, \(record.displayName). Cat number \(record.sequence.formatted()). Captured \(record.capturedAt.formatted(date: .abbreviated, time: .omitted)).\(place)"
    }
}

struct DraftCatCardView: View {
    let image: UIImage
    let sequence: Int
    let name: String
    let note: String
    let placeName: String
    let placeDetail: String

    var body: some View {
        CatCardSurface(
            sequence: sequence,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "New Cat"
                : name,
            date: Date(),
            note: note,
            placeName: trimmedPlaceName,
            placeDetail: trimmedPlaceDetail,
            presentation: .focused
        ) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    private var trimmedPlaceName: String? {
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedPlaceDetail: String? {
        let trimmed = placeDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum CatCardPresentation {
    case thumbnail
    case focused
}

private struct CatCardSurface<CatImage: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let sequence: Int
    let name: String
    let date: Date
    let note: String
    let placeName: String?
    let placeDetail: String?
    let presentation: CatCardPresentation
    @ViewBuilder let catImage: () -> CatImage

    private var focused: Bool { presentation == .focused }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width, 1)
            let cardHeight = max(proxy.size.height, 1)
            let cornerRadius: CGFloat = focused ? 34 : 22
            let outerPadding: CGFloat = focused ? 18 : 11
            let imageStageHeight = max(cardHeight * imageStageRatio, 1)
            let imageMaxWidth = max(cardWidth - outerPadding * 2, 1)

            VStack(alignment: .leading, spacing: focused ? 14 : 9) {
                header

                ZStack {
                    imageStage

                    catImage()
                        .scaledToFit()
                        .frame(
                            maxWidth: imageMaxWidth,
                            maxHeight: imageStageHeight * 0.96,
                            alignment: .center
                        )
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .frame(height: imageStageHeight)

                footer
            }
            .padding(outerPadding)
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
            .shadow(
                color: CatLocalTheme.shadow.opacity(focused ? 0.72 : 0.36),
                radius: focused ? 28 : 11,
                y: focused ? 18 : 6
            )
        }
        .aspectRatio(focused ? 0.64 : 0.72, contentMode: .fit)
    }

    private var imageStageRatio: CGFloat {
        if focused, hasFocusedTextContent {
            return dynamicTypeSize.isAccessibilitySize ? 0.32 : 0.42
        }

        return if dynamicTypeSize.isAccessibilitySize {
            focused ? 0.43 : 0.47
        } else {
            focused ? 0.49 : 0.54
        }
    }

    private var hasFocusedTextContent: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || placeName != nil || placeDetail != nil
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: focused ? 3 : 1) {
                Text(name)
                    .font(focused ? .title.weight(.semibold) : .headline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.7)

                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(focused ? .footnote.weight(.medium) : .caption2.weight(.medium))
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            Spacer(minLength: 10)

            sequenceMedallion
        }
        .foregroundStyle(CatLocalTheme.primaryText)
    }

    @ViewBuilder
    private var footer: some View {
        if focused {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(CatLocalTheme.separator)
                    .frame(height: 1)

                Text("Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.secondaryText)

                Text(note.isEmpty ? "No note yet." : note)
                    .font(.body)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                    .foregroundStyle(note.isEmpty ? CatLocalTheme.secondaryText : CatLocalTheme.primaryText)

                if let placeName {
                    focusedPlaceDetails(placeName: placeName, placeDetail: placeDetail)
                        .padding(.top, 1)
                }
            }
        } else {
            if let placeName {
                memoryPlacePill(placeName)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var sequenceMedallion: some View {
        Text(sequence.formatted())
            .font(.system(size: focused ? 16 : 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .foregroundStyle(CatLocalTheme.primaryText)
            .frame(width: focused ? 34 : 27, height: focused ? 34 : 27)
        .background(
            CatLocalTheme.elevatedSurface.opacity(0.74),
            in: Circle()
        )
        .overlay(
            Circle()
                .stroke(CatLocalTheme.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(
            color: CatLocalTheme.shadow.opacity(focused ? 0.14 : 0.08),
            radius: focused ? 7 : 3,
            y: focused ? 4 : 2
        )
        .accessibilityHidden(true)
    }

    private func focusedPlaceDetails(placeName: String, placeDetail: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            placeDetailRow(
                title: "Memory Place",
                icon: "mappin.and.ellipse",
                value: placeName
            )

            if let placeDetail {
                placeDetailRow(
                    title: "Place detail",
                    icon: "text.alignleft",
                    value: placeDetail
                )
            }
        }
    }

    private func placeDetailRow(title: String, icon: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CatLocalTheme.secondaryText)

            Text(value)
                .font(.body)
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        }
        .accessibilityElement(children: .combine)
    }

    private func memoryPlacePill(_ placeName: String) -> some View {
        Label {
            Text(placeName)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(0.76)
        } icon: {
            Image(systemName: "mappin.and.ellipse")
                .font(.caption.weight(.bold))
        }
        .font(focused ? .footnote.weight(.semibold) : .caption2.weight(.semibold))
        .foregroundStyle(CatLocalTheme.primaryText)
        .padding(.horizontal, focused ? 12 : 9)
        .padding(.vertical, focused ? 8 : 6)
        .background(
            CatLocalTheme.memoryPlaceFill,
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(CatLocalTheme.memoryPlaceStroke, lineWidth: 1)
        )
        .accessibilityLabel("Memory Place, \(placeName)")
    }

    private var imageStage: some View {
        RoundedRectangle(cornerRadius: focused ? 26 : 16, style: .continuous)
            .fill(CatLocalTheme.elevatedSurface.opacity(focused ? 0.62 : 0.48))
            .overlay(
                RoundedRectangle(cornerRadius: focused ? 26 : 16, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var surface: some View {
        ZStack {
            CatLocalTheme.cardSurface
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    CatLocalTheme.sage.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
