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
                    .tint(CatLocalTheme.forest)
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
            ZStack {
                surface

                decorativeMark

                catImage()
                    .frame(
                        width: proxy.size.width * (focused ? 0.77 : 0.82),
                        height: proxy.size.height * (focused ? 0.58 : 0.56)
                    )
                    .offset(
                        x: focused ? proxy.size.width * 0.08 : proxy.size.width * 0.05,
                        y: focused ? proxy.size.height * 0.03 : proxy.size.height * 0.06
                    )

                VStack(alignment: .leading, spacing: focused ? 5 : 2) {
                    Text(sequence.formatted(.number.precision(.integerLength(3))))
                        .font(.system(size: focused ? 29 : 17, weight: .medium, design: .serif))
                    Text(name)
                        .font(.system(size: focused ? 36 : 22, weight: .medium, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .foregroundStyle(CatLocalTheme.forest)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(focused ? 24 : 14)

                VStack(alignment: .leading, spacing: focused ? 10 : 4) {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(focused ? .subheadline.weight(.medium) : .caption2.weight(.medium))
                        .foregroundStyle(CatLocalTheme.ink.opacity(0.72))

                    if focused {
                        Rectangle()
                            .fill(CatLocalTheme.ink.opacity(0.18))
                            .frame(height: 1)

                        Text("NOTES")
                            .font(.caption2.weight(.bold))
                            .tracking(1.8)
                            .foregroundStyle(CatLocalTheme.accent(for: style))

                        Text(note.isEmpty ? "No note yet." : note)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .italic()
                            .lineLimit(3)
                            .foregroundStyle(CatLocalTheme.ink.opacity(note.isEmpty ? 0.45 : 0.9))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(focused ? 24 : 14)

                Rectangle()
                    .fill(CatLocalTheme.accent(for: style))
                    .frame(width: focused ? 9 : 6)
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: focused ? 34 : 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: focused ? 34 : 22, style: .continuous)
                    .stroke(.white.opacity(0.78), lineWidth: 1)
            )
            .shadow(
                color: CatLocalTheme.ink.opacity(focused ? 0.22 : 0.11),
                radius: focused ? 30 : 12,
                y: focused ? 19 : 7
            )
        }
        .aspectRatio(focused ? 0.67 : 0.72, contentMode: .fit)
    }

    @ViewBuilder
    private var surface: some View {
        switch style {
        case .archive:
            ZStack {
                CatLocalTheme.chalk
                LinearGradient(
                    colors: [.white.opacity(0.28), CatLocalTheme.sage.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .sunstamp:
            ZStack {
                Color(red: 0.98, green: 0.93, blue: 0.82)
                RadialGradient(
                    colors: [Color.white.opacity(0.68), CatLocalTheme.apricot.opacity(0.15)],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 430
                )
            }
        case .clear:
            ZStack {
                Color(red: 0.91, green: 0.95, blue: 0.95)
                LinearGradient(
                    colors: [.white.opacity(0.58), CatLocalTheme.cobalt.opacity(0.11)],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var decorativeMark: some View {
        Image(systemName: style == .sunstamp ? "sun.max" : style == .clear ? "sparkles" : "seal")
            .font(.system(size: focused ? 32 : 18, weight: .light))
            .foregroundStyle(CatLocalTheme.accent(for: style).opacity(0.72))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(focused ? 24 : 14)
    }
}
