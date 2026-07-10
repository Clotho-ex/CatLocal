import SwiftUI

struct LociStateView: View {
    let state: LociMascotState

    var showsCard = false
    var mascotSize: CGFloat = 120
    var cardWidth: CGFloat = 136
    var buttonTitle: String?
    var buttonSystemImage = "camera.fill"
    var buttonAction: (() -> Void)?

    init(
        context: LociContext,
        showsCard: Bool = false,
        mascotSize: CGFloat = 120,
        cardWidth: CGFloat = 136,
        title: String? = nil,
        subtitle: String? = nil,
        buttonTitle: String? = nil,
        buttonSystemImage: String = "camera.fill",
        buttonAction: (() -> Void)? = nil
    ) {
        var state = LociMascotState.state(for: context)
        if let title {
            state.title = title
        }
        if let subtitle {
            state.subtitle = subtitle
        }
        self.state = state
        self.showsCard = showsCard
        self.mascotSize = mascotSize
        self.cardWidth = cardWidth
        self.buttonTitle = buttonTitle
        self.buttonSystemImage = buttonSystemImage
        self.buttonAction = buttonAction
    }

    init(
        state: LociMascotState,
        showsCard: Bool = false,
        mascotSize: CGFloat = 120,
        cardWidth: CGFloat = 136,
        buttonTitle: String? = nil,
        buttonSystemImage: String = "camera.fill",
        buttonAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.showsCard = showsCard
        self.mascotSize = mascotSize
        self.cardWidth = cardWidth
        self.buttonTitle = buttonTitle
        self.buttonSystemImage = buttonSystemImage
        self.buttonAction = buttonAction
    }

    private var buttonRole: CatAttentionRole {
        state.context?.role ?? .action
    }

    var body: some View {
        VStack(spacing: 18) {
            if showsCard {
                LociCardHeroScene(
                    state: state,
                    mascotSize: mascotSize,
                    cardWidth: cardWidth,
                    spacing: 12
                )
            } else {
                LociMascotView(
                    state: state,
                    size: mascotSize
                )
            }

            LociStateText(title: state.title, subtitle: state.subtitle)

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Label(buttonTitle, systemImage: buttonSystemImage)
                        .font(CatTypography.control)
                        .frame(maxWidth: .infinity)
                        .catPrimaryActionSurface(role: buttonRole, cornerRadius: 28)
                }
                .buttonStyle(.catTactile)
                .accessibilityHint("Starts the private capture and photo import flow")
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct LociStateText: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(CatTypography.pageTitle)
                .foregroundStyle(CatLocalTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(CatTypography.body)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
    }
}
