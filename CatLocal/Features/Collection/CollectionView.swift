import SwiftUI

struct CollectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCard: CatCard?

    private let cards = CatCard.samples
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            archiveBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(cards) { card in
                            Button {
                                withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(duration: 0.48, bounce: 0.12)) {
                                    selectedCard = card
                                }
                            } label: {
                                CatCardView(card: card, presentation: .thumbnail)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(card.name), \(card.neighborhood)")
                            .accessibilityHint("Opens the card")
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 140)
            }
            .blur(radius: selectedCard == nil ? 0 : 16)
            .scaleEffect(selectedCard == nil ? 1 : 0.98)
            .allowsHitTesting(selectedCard == nil)

            if let selectedCard {
                FocusedCardView(card: selectedCard) {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.4, bounce: 0.08)) {
                        self.selectedCard = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(2)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CatLocal")
                        .font(.system(size: 58, weight: .medium, design: .serif))
                        .tracking(-2.8)
                        .foregroundStyle(CatLocalTheme.forest)

                    Text("YOUR COLLECTION")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .tracking(3.2)
                        .foregroundStyle(CatLocalTheme.ink.opacity(0.8))
                }

                Spacer()

                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CatLocalTheme.forest)
                    .frame(width: 48, height: 48)
                    .background(.thinMaterial, in: Circle())
                    .accessibilityHidden(true)
            }

            HStack(spacing: 12) {
                Text("\(cards.count) cats")
                    .font(.subheadline.weight(.semibold))

                Rectangle()
                    .fill(CatLocalTheme.apricot)
                    .frame(width: 2, height: 16)

                Text("Sorted by recent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var archiveBackground: some View {
        GeometryReader { proxy in
            ZStack {
                CatLocalTheme.limestone

                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width * 0.66, y: -20))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: 80))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: 320))
                    path.addLine(to: CGPoint(x: proxy.size.width * 0.52, y: 20))
                    path.closeSubpath()
                }
                .fill(CatLocalTheme.ink.opacity(0.045))
                .blur(radius: 2)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    CollectionView()
}

