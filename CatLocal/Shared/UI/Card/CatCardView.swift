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
            style: record.cardStyle,
            presentation: presentation
        ) {
            StoredImageView(path: imagePath, contentMode: .fit) {
                ProgressView()
                    .tint(CatLocalTheme.primaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(record.displayName), captured \(record.capturedAt.formatted(date: .abbreviated, time: .omitted))")
        .accessibilityHint(isFocused ? "Drag the card to shift its light" : "Opens the card")
    }

    private var imagePath: String {
        isFocused ? record.cutoutImagePath : record.thumbnailImagePath
    }
}

struct DraftCatCardView: View {
    let image: UIImage
    let sequence: Int
    let name: String
    let note: String
    let style: CardStyle

    var body: some View {
        CatCardSurface(
            sequence: sequence,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "New Local"
                : name,
            date: Date(),
            note: note,
            style: style,
            presentation: .focused
        ) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }
}

enum CatCardPresentation {
    case thumbnail
    case focused
}

private struct CatCardSurface<CatImage: View>: View {
    let sequence: Int
    let name: String
    let date: Date
    let note: String
    let style: CardStyle
    let presentation: CatCardPresentation
    @ViewBuilder let catImage: () -> CatImage

    private var focused: Bool { presentation == .focused }

    var body: some View {
        GeometryReader { proxy in
            let cornerRadius: CGFloat = focused ? 34 : 22
            let outerPadding: CGFloat = focused ? 20 : 11
            let imageStageHeight = proxy.size.height * (focused ? 0.54 : 0.50)

            VStack(alignment: .leading, spacing: focused ? 16 : 9) {
                header

                ZStack {
                    imageStage

                    catImage()
                        .scaledToFit()
                        .frame(
                            maxWidth: proxy.size.width - outerPadding * 2,
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
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: focused ? 3 : 1) {
                Text(name)
                    .font(.system(size: focused ? 31 : 18, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(focused ? .footnote.weight(.medium) : .caption2.weight(.medium))
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            Spacer(minLength: 10)

            Text(sequence.formatted(.number.precision(.integerLength(3))))
                .font(.system(size: focused ? 17 : 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(CatLocalTheme.secondaryText)
                .monospacedDigit()
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
                    .lineLimit(3)
                    .foregroundStyle(note.isEmpty ? CatLocalTheme.secondaryText : CatLocalTheme.primaryText)
            }
        } else {
            HStack(spacing: 8) {
                Circle()
                    .fill(CatLocalTheme.accent(for: style))
                    .frame(width: 5, height: 5)
                Text(style.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(1)
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
            .frame(width: focused ? 34 : 22, height: focused ? 34 : 22)
            .overlay {
                Circle()
                    .fill(CatLocalTheme.accent(for: style).opacity(0.12))
                    .padding(5)
            }
            .padding(focused ? 20 : 11)
            .accessibilityHidden(true)
    }
}
