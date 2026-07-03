import SwiftUI

struct CardMintingSuccessView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var isCustomizationDone: Bool

    let cornerRadius: CGFloat
    let showsCustomizationPanel: Bool
    let onHome: () -> Void
    let onKeepEditing: () -> Void
    @ViewBuilder let card: (_ sheen: CardMintingSheenOverlay) -> Content

    @State private var cardSettled = false
    @State private var badgeVisible = false
    @State private var buttonsVisible = false
    @State private var sheenVisible = false
    @State private var sheenTravelled = false
    @State private var hapticTrigger = 0

    init(
        isCustomizationDone: Binding<Bool>,
        cornerRadius: CGFloat = 34,
        showsCustomizationPanel: Bool = true,
        onHome: @escaping () -> Void,
        onKeepEditing: @escaping () -> Void,
        @ViewBuilder card: @escaping (_ sheen: CardMintingSheenOverlay) -> Content
    ) {
        _isCustomizationDone = isCustomizationDone
        self.cornerRadius = cornerRadius
        self.showsCustomizationPanel = showsCustomizationPanel
        self.onHome = onHome
        self.onKeepEditing = onKeepEditing
        self.card = card
    }

    var body: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 18) {
                Spacer(minLength: 44)

                mintedCard

                savedBadge

                Spacer(minLength: 116)
            }
            .padding(.horizontal, 24)

            VStack {
                Spacer()
                actionButtons
            }

            if showsCustomizationPanel && !isCustomizationDone {
                VStack {
                    Spacer()
                    customizationPanel
                }
            }
        }
        .task(id: isCustomizationDone) {
            await runMintingSequence()
        }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    private var mintedCard: some View {
        card(
            CardMintingSheenOverlay(
                isVisible: !reduceMotion && sheenVisible,
                hasTravelled: sheenTravelled
            )
        )
            .scaleEffect(cardSettled || reduceMotion ? 1 : 0.965)
            .offset(y: cardSettled || reduceMotion ? 0 : 18)
            .opacity(cardSettled || reduceMotion ? 1 : 0)
            .frame(maxWidth: 390)
            .animation(.smooth(duration: 0.52, extraBounce: 0), value: cardSettled)
            .accessibilityElement(children: .contain)
    }

    private var savedBadge: some View {
        let badgeFill = Color(red: 0.86, green: 0.96, blue: 0.90)
        let badgeBorder = Color(red: 0.09, green: 0.39, blue: 0.24)
        let badgeText = Color(red: 0.04, green: 0.24, blue: 0.15)
        let checkmarkFill = Color(red: 0.11, green: 0.48, blue: 0.30)

        return HStack(spacing: 8) {
            ZStack {
                Image(systemName: "seal.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(checkmarkFill)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -0.5)
            }
            .frame(width: 24, height: 24)
            .symbolEffect(.bounce, value: hapticTrigger)
            .accessibilityHidden(true)

            Text("Saved Successfully")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(badgeText)
        .padding(.horizontal, 14)
        .frame(minHeight: 38)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(badgeFill.opacity(0.72))
                }
        }
        .overlay(
            Capsule(style: .continuous)
                .stroke(badgeBorder.opacity(0.72), lineWidth: 1)
        )
        .opacity(badgeVisible ? 1 : 0)
        .scaleEffect(badgeVisible || reduceMotion ? 1 : 0.94)
        .offset(y: badgeVisible || reduceMotion ? 0 : 8)
        .animation(.snappy(duration: 0.34, extraBounce: 0), value: badgeVisible)
        .accessibilityLabel("Saved successfully")
        .accessibilityHidden(!badgeVisible)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onHome()
            } label: {
                Label("Home", systemImage: "house.fill")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .catGlass(cornerRadius: 26, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("card-minting-home")

            Button {
                onKeepEditing()
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .catGlass(cornerRadius: 26, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("card-minting-edit")
        }
        .foregroundStyle(CatLocalTheme.primaryText)
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
        .opacity(buttonsVisible || reduceMotion ? 1 : 0)
        .offset(y: buttonsVisible || reduceMotion ? 0 : 12)
        .allowsHitTesting(buttonsVisible || reduceMotion)
        .animation(.smooth(duration: 0.28, extraBounce: 0), value: buttonsVisible)
    }

    private var customizationPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(CatLocalTheme.separator)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Customize")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                Text("Choose the finishing details for this card.")
                    .font(.subheadline)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            Button {
                isCustomizationDone = true
            } label: {
                Text("Done")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(CatLocalTheme.blueAction)
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @MainActor
    private func runMintingSequence() async {
        guard isCustomizationDone else {
            resetMintingState()
            return
        }

        resetMintingState()

        guard !reduceMotion else {
            cardSettled = true
            badgeVisible = true
            buttonsVisible = true
            hapticTrigger += 1
            try? await Task.sleep(for: .milliseconds(2_000))
            guard !Task.isCancelled else { return }
            hideSavedBadge()
            return
        }

        try? await Task.sleep(for: .milliseconds(80))
        hapticTrigger += 1

        withAnimation(.smooth(duration: 0.52, extraBounce: 0)) {
            cardSettled = true
        }

        try? await Task.sleep(for: .milliseconds(130))
        sheenVisible = true
        sheenTravelled = false

        try? await Task.sleep(for: .milliseconds(20))
        withAnimation(.easeOut(duration: 0.86)) {
            sheenTravelled = true
        }

        try? await Task.sleep(for: .milliseconds(270))
        withAnimation(.snappy(duration: 0.34, extraBounce: 0)) {
            badgeVisible = true
        }

        try? await Task.sleep(for: .milliseconds(190))
        withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
            buttonsVisible = true
        }

        try? await Task.sleep(for: .milliseconds(520))
        sheenVisible = false

        try? await Task.sleep(for: .milliseconds(1_290))
        guard !Task.isCancelled else { return }
        hideSavedBadge()
    }

    private func resetMintingState() {
        cardSettled = false
        badgeVisible = false
        buttonsVisible = false
        sheenVisible = false
        sheenTravelled = false
    }

    private func hideSavedBadge() {
        guard badgeVisible else { return }
        if reduceMotion {
            badgeVisible = false
        } else {
            withAnimation(.easeOut(duration: 0.22)) {
                badgeVisible = false
            }
        }
    }
}

#Preview("Card Minting Success") {
    CardMintingSuccessView(
        isCustomizationDone: .constant(true),
        onHome: {},
        onKeepEditing: {}
    ) { sheen in
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        CatLocalTheme.primaryText,
                        CatLocalTheme.warning,
                        CatLocalTheme.blueAction
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "cat.fill")
                    .font(.system(size: 112, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .overlay {
                if sheen.isVisible {
                    sheen
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                }
            }
            .aspectRatio(0.64, contentMode: .fit)
    }
}

struct CardMintingSheenOverlay: View {
    let isVisible: Bool
    let hasTravelled: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            if isVisible {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.36),
                        Color.white.opacity(0.05),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: width * 0.34)
                .frame(maxHeight: .infinity)
                .rotationEffect(.degrees(17))
                .offset(x: hasTravelled ? width * 1.52 : -width * 0.72)
                .blendMode(.screen)
                .animation(.easeOut(duration: 0.86), value: hasTravelled)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
