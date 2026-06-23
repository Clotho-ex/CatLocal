import SwiftUI

enum CatCardPresentation {
    case thumbnail
    case focused
}

struct CatCardView: View {
    let card: CatCard
    let presentation: CatCardPresentation

    private var isFocused: Bool {
        presentation == .focused
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                cardSurface

                Image(card.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height * (isFocused ? 0.63 : 0.66)
                    )
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, CatLocalTheme.chalk.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: proxy.size.height * 0.18)
                    }
                    .padding(.top, proxy.size.height * 0.16)

                VStack(alignment: .leading, spacing: isFocused ? 3 : 1) {
                    Text(card.sequence.formatted(.number.precision(.integerLength(3))))
                        .font(.system(size: isFocused ? 28 : 18, weight: .medium, design: .serif))
                    Text(card.name)
                        .font(.system(size: isFocused ? 36 : 23, weight: .medium, design: .serif))
                        .lineLimit(1)
                }
                .foregroundStyle(CatLocalTheme.forest)
                .padding(isFocused ? 24 : 14)

                VStack(alignment: .leading, spacing: isFocused ? 12 : 5) {
                    Text(card.neighborhood)
                        .font(isFocused ? .headline : .caption.weight(.semibold))

                    Text(card.date, format: .dateTime.month(.abbreviated).day())
                        .font(isFocused ? .subheadline : .caption2)
                        .foregroundStyle(.secondary)

                    if isFocused {
                        Divider()
                            .overlay(CatLocalTheme.ink.opacity(0.25))

                        Text("NOTES")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.8)
                            .foregroundStyle(CatLocalTheme.apricot)

                        Text(card.note)
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .italic()
                            .lineSpacing(3)
                    }
                }
                .foregroundStyle(CatLocalTheme.ink)
                .padding(isFocused ? 24 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                Rectangle()
                    .fill(CatLocalTheme.accent(card.accent))
                    .frame(width: isFocused ? 9 : 6)
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: isFocused ? 34 : 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: isFocused ? 34 : 22, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(
                color: CatLocalTheme.ink.opacity(isFocused ? 0.22 : 0.1),
                radius: isFocused ? 28 : 10,
                y: isFocused ? 18 : 6
            )
        }
        .aspectRatio(isFocused ? 0.66 : 0.7, contentMode: .fit)
    }

    private var cardSurface: some View {
        ZStack {
            CatLocalTheme.chalk

            LinearGradient(
                colors: [
                    .white.opacity(0.1),
                    CatLocalTheme.accent(card.accent).opacity(0.08),
                    .white.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

