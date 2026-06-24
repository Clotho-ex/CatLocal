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
            style: record.cardStyle,
            presentation: presentation
        ) {
            StoredImageView(path: imagePath, contentMode: .fit) {
                ProgressView()
                    .tint(CatLocalTheme.primaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isFocused ? "Drag the card to shift its light" : "Double tap to open full gallery view.")
    }

    private var imagePath: String {
        isFocused ? record.cutoutImagePath : record.thumbnailImagePath
    }

    private var accessibilityLabel: String {
        let place = record.memoryPlaceLabel.map { " Memory place, \($0)." } ?? ""
        return "Cat Record, \(record.displayName). ID number \(record.sequence.formatted(.number.precision(.integerLength(3)))). \(record.cardStyle.title) style. Captured \(record.capturedAt.formatted(date: .abbreviated, time: .omitted)).\(place)"
    }
}

struct DraftCatCardView: View {
    let image: UIImage
    let sequence: Int
    let name: String
    let note: String
    let placeName: String
    let placeDetail: String
    let style: CardStyle

    var body: some View {
        CatCardSurface(
            sequence: sequence,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "New Local"
                : name,
            date: Date(),
            note: note,
            placeName: trimmedPlaceName,
            placeDetail: trimmedPlaceDetail,
            style: style,
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
    let style: CardStyle
    let presentation: CatCardPresentation
    @ViewBuilder let catImage: () -> CatImage

    private var focused: Bool { presentation == .focused }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width, 1)
            let cardHeight = max(proxy.size.height, 1)
            let cornerRadius: CGFloat = focused ? 34 : 22
            let outerPadding: CGFloat = focused ? 20 : 11
            let imageStageHeight = max(cardHeight * imageStageRatio, 1)
            let imageMaxWidth = max(cardWidth - outerPadding * 2, 1)

            VStack(alignment: .leading, spacing: focused ? 16 : 9) {
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
            .overlay(alignment: .topTrailing) { styleMark }
            .shadow(
                color: CatLocalTheme.shadow.opacity(focused ? 0.72 : 0.36),
                radius: focused ? 28 : 11,
                y: focused ? 18 : 6
            )
        }
        .aspectRatio(focused ? 0.67 : 0.72, contentMode: .fit)
    }

    private var imageStageRatio: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            focused ? 0.46 : 0.44
        } else {
            focused ? 0.54 : 0.50
        }
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
        }
        .foregroundStyle(CatLocalTheme.primaryText)
    }

    @ViewBuilder
    private var footer: some View {
        if focused {
            VStack(alignment: .leading, spacing: 10) {
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memory")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CatLocalTheme.secondaryText)

                        Text(placeDetail.map { "\(placeName), \($0)" } ?? placeName)
                            .font(.footnote.weight(.medium))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .foregroundStyle(CatLocalTheme.primaryText)
                    }
                    .padding(.top, 2)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(CatLocalTheme.accent(for: style))
                        .frame(width: 5, height: 5)
                    Text(style.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CatLocalTheme.secondaryText)
                        .lineLimit(1)
                }

                if let placeName {
                    Text(placeName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(CatLocalTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
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
        switch style {
        case .archive:
            ZStack {
                CatLocalTheme.paperSurface(for: style)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        CatLocalTheme.sage.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .sunstamp:
            ZStack {
                CatLocalTheme.paperSurface(for: style)
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        CatLocalTheme.warning.opacity(0.10),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 430
                )
            }
        case .clear:
            ZStack {
                CatLocalTheme.paperSurface(for: style)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        CatLocalTheme.blueAction.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var styleMark: some View {
        Circle()
            .stroke(CatLocalTheme.accent(for: style).opacity(0.34), lineWidth: 1)
            .frame(width: focused ? 42 : 30, height: focused ? 42 : 30)
            .overlay {
                Circle()
                    .fill(CatLocalTheme.accent(for: style).opacity(0.12))
                    .padding(focused ? 5 : 4)
                Text(sequence.formatted(.number.precision(.integerLength(3))))
                    .font(.system(size: focused ? 13 : 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            .padding(focused ? 20 : 11)
            .accessibilityHidden(true)
    }
}
