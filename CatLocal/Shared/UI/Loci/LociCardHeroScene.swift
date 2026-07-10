import SwiftUI

struct LociCardHeroScene: View {
    let state: LociMascotState
    var mascotSize: CGFloat = 120
    var cardWidth: CGFloat = 136
    var spacing: CGFloat = 12

    init(
        context: LociContext,
        mascotSize: CGFloat = 120,
        cardWidth: CGFloat = 136,
        spacing: CGFloat = 12
    ) {
        self.state = LociMascotState.state(for: context)
        self.mascotSize = mascotSize
        self.cardWidth = cardWidth
        self.spacing = spacing
    }

    init(
        state: LociMascotState,
        mascotSize: CGFloat = 120,
        cardWidth: CGFloat = 136,
        spacing: CGFloat = 12
    ) {
        self.state = state
        self.mascotSize = mascotSize
        self.cardWidth = cardWidth
        self.spacing = spacing
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .accessibilityHidden(true)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            mascot
            skeletonCard
        }
    }

    private var verticalLayout: some View {
        VStack(spacing: 14) {
            mascot
            skeletonCard
        }
    }

    private var mascot: some View {
        LociMascotView(
            state: state,
            size: mascotSize
        )
    }

    private var skeletonCard: some View {
        CatLocalCardSkeletonView(showsShimmer: false)
            .frame(width: cardWidth)
    }
}
