import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedPage: OnboardingPage = .welcome
    @State private var transitionDirection = OnboardingTransitionDirection.forward
    @State private var forwardFeedbackTrigger = 0
    @State private var backwardFeedbackTrigger = 0
    @State private var completionFeedbackTrigger = 0
    @State private var isCompleting = false
    @Namespace private var actionNamespace

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 0) {
                progressHeader
                onboardingContent
                footer
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.48), trigger: forwardFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: backwardFeedbackTrigger)
        .sensoryFeedback(.success, trigger: completionFeedbackTrigger)
    }

    private var onboardingContent: some View {
        pageStage
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, pageVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
    }

    private var pageStage: some View {
        ZStack {
            OnboardingPageScreen(page: selectedPage)
                .id(selectedPage)
                .transition(pageTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(pageAnimation, value: selectedPage)
    }

    private var footer: some View {
        actionButtons
        .padding(.horizontal, horizontalPadding)
        .padding(.top, footerTopPadding)
        .padding(.bottom, footerBottomPadding)
        .frame(maxWidth: .infinity)
        .animation(actionAnimation, value: selectedPage)
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    progressStepLabel
                    Spacer(minLength: 12)

                    if selectedPage.canSkipToHome {
                        skipButton
                            .transition(.opacity)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    progressStepLabel

                    if selectedPage.canSkipToHome {
                        skipButton
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .transition(.opacity)
                    }
                }
            }

            OnboardingProgressBar(selectedPage: selectedPage)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 8 : 12)
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 8 : 10)
        .frame(maxWidth: .infinity)
        .animation(actionAnimation, value: selectedPage)
    }

    private var progressStepLabel: some View {
        Text("Step \(selectedPage.stepNumber) of \(OnboardingPage.totalCount)")
            .font(CatTypography.finePrint)
            .foregroundStyle(CatLocalTheme.secondaryText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Onboarding step \(selectedPage.stepNumber) of \(OnboardingPage.totalCount)")
            .accessibilityIdentifier("onboarding-step")
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 18 : CatLocalTheme.screenHorizontalPadding
    }

    private var pageVerticalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 4 : 8
    }

    private var footerTopPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 10 : 14
    }

    private var footerBottomPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 10
    }

    @ViewBuilder
    private var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                primaryButton

                if selectedPage.previous != nil {
                    backButton
                        .transition(backButtonTransition)
                }
            }
        } else {
            HStack(spacing: 12) {
                if selectedPage.previous != nil {
                    backButton
                        .transition(backButtonTransition)
                        .frame(width: 116)
                }

                primaryButton
            }
        }
    }

    private var backButton: some View {
        Button {
            guard let previous = selectedPage.previous else { return }
            move(to: previous, direction: .backward)
        } label: {
            Label("Back", systemImage: "chevron.left")
                .font(CatTypography.compactControl)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .catSecondaryActionSurface(cornerRadius: 24, minHeight: 56)
        }
        .buttonStyle(.catTactile)
        .disabled(isCompleting)
        .accessibilityIdentifier("onboarding-back")
    }

    private var primaryButton: some View {
        Button(action: handlePrimaryAction) {
            OnboardingPrimaryActionLabel(
                title: selectedPage.primaryActionTitle,
                systemImage: selectedPage.isFinalPage ? "checkmark" : "arrow.right"
            )
            .catPrimaryActionSurface(role: .action, cornerRadius: 24, isDisabled: isCompleting)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.catTactile)
        .matchedGeometryEffect(id: "onboarding-primary-action", in: actionNamespace)
        .disabled(isCompleting)
        .accessibilityLabel(selectedPage.primaryActionTitle)
        .accessibilityHint(selectedPage.footerNote)
        .accessibilityIdentifier("onboarding-primary-action")
    }

    private var skipButton: some View {
        Button(action: skipToHome) {
            Text("Skip to Home")
                .font(CatTypography.finePrint)
                .foregroundStyle(CatLocalTheme.secondaryText.opacity(0.78))
                .lineLimit(1)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCompleting)
        .accessibilityHint("Ends onboarding. Privacy details remain available in Settings.")
        .accessibilityIdentifier("onboarding-skip-home")
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion: .offset(x: transitionDirection.pageInsertionOffset).combined(with: .opacity),
            removal: .offset(x: transitionDirection.pageRemovalOffset).combined(with: .opacity)
        )
    }

    private var pageAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.26, extraBounce: 0)
    }

    private var actionAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.2, extraBounce: 0)
    }

    private var backButtonTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion: .offset(x: -12).combined(with: .opacity),
            removal: .offset(x: -8).combined(with: .opacity)
        )
    }

    private func handlePrimaryAction() {
        guard !isCompleting else { return }

        guard let nextPage = selectedPage.next else {
            completeAfterFinalFeedback()
            return
        }

        move(to: nextPage, direction: .forward)
    }

    private func move(to page: OnboardingPage, direction: OnboardingTransitionDirection) {
        switch direction {
        case .forward:
            forwardFeedbackTrigger += 1
        case .backward:
            backwardFeedbackTrigger += 1
        }

        transitionDirection = direction

        withAnimation(pageAnimation) {
            selectedPage = page
        }
    }

    private func completeAfterFinalFeedback() {
        guard !isCompleting else { return }

        isCompleting = true
        completionFeedbackTrigger += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            onComplete()
        }
    }

    private func skipToHome() {
        guard !isCompleting else { return }

        isCompleting = true
        onComplete()
    }
}

private enum OnboardingTransitionDirection {
    case forward
    case backward

    var pageInsertionOffset: CGFloat {
        switch self {
        case .forward:
            return 34
        case .backward:
            return -34
        }
    }

    var pageRemovalOffset: CGFloat {
        switch self {
        case .forward:
            return -18
        case .backward:
            return 18
        }
    }

}

private enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome
    case privacy
    case firstCard

    var id: String {
        switch self {
        case .welcome:
            return "welcome"
        case .privacy:
            return "privacy"
        case .firstCard:
            return "first-card"
        }
    }

    var stepNumber: Int { rawValue + 1 }
    static var totalCount: Int { allCases.count }
    var isFinalPage: Bool { next == nil }
    var canSkipToHome: Bool { !isFinalPage }
    var next: OnboardingPage? { OnboardingPage(rawValue: rawValue + 1) }
    var previous: OnboardingPage? { OnboardingPage(rawValue: rawValue - 1) }

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to CatLocal"
        case .privacy:
            return "Your furry encounters are safe"
        case .firstCard:
            return "Ready for Your First Local"
        }
    }

    var detail: String {
        switch self {
        case .welcome:
            return "A private place for the cats you meet."
        case .privacy:
            return "Photos stay on this iPhone."
        case .firstCard:
            return "Home opens next.\nTap Camera when you meet a cat, or choose a private photo."
        }
    }

    var detailAccessibilityLabel: String {
        switch self {
        case .firstCard:
            return "Home opens next. Tap Camera when you meet a cat, or choose a private photo."
        case .welcome, .privacy:
            return detail
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .welcome, .privacy:
            return "Continue"
        case .firstCard:
            return "Start Collecting"
        }
    }

    var footerNote: String {
        switch self {
        case .welcome:
            return "Shows how CatLocal turns encounters into a private collection."
        case .privacy:
            return "Explains local privacy before you start collecting."
        case .firstCard:
            return "Finishes onboarding, then Home opens so you can tap Camera or import a private photo."
        }
    }

    var detailOpacity: Double {
        switch self {
        case .welcome:
            return 0.86
        case .privacy:
            return 0.78
        case .firstCard:
            return 0.9
        }
    }

    var detailAccessibilityIdentifier: String? {
        switch self {
        case .welcome:
            return "onboarding-welcome-copy"
        case .privacy, .firstCard:
            return nil
        }
    }

    var privacyCues: [OnboardingPrivacyCue] {
        guard self == .privacy else { return [] }

        return [
            OnboardingPrivacyCue(
                title: "On-device Vision",
                detail: "CatLocal looks for cats here.",
                systemImage: "viewfinder",
                role: .info
            ),
            OnboardingPrivacyCue(
                title: "Location Data Stripped",
                detail: "Saved images are GPS-free.",
                systemImage: "location.slash.fill",
                role: .info
            ),
            OnboardingPrivacyCue(
                title: "No Account or Cloud",
                detail: "Cards save to this iPhone.",
                systemImage: "person.crop.circle.badge.xmark",
                role: .info
            )
        ]
    }
}

private struct OnboardingPrivacyCue: Identifiable {
    let title: String
    let detail: String
    let systemImage: String
    let role: CatAttentionRole

    var id: String { title }
}

private struct OnboardingPageScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var revealPhase = 0
    @State private var revealGeneration = 0

    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            OnboardingHeroVisual(page: page, didReveal: isRevealed(.hero))
                .opacity(revealOpacity(.hero))
                .offset(y: revealOffset(for: .hero))
                .scaleEffect(revealScale(for: .hero))

            VStack(spacing: titleSpacing) {
                titleContent

                detailCopy
            }
            .opacity(revealOpacity(.copy))
            .offset(y: revealOffset(for: .copy))
            .padding(.top, heroToCopySpacing)

            supportingContent
                .opacity(revealOpacity(.supporting))
                .offset(y: revealOffset(for: .supporting))
                .padding(.top, copyToSupportingSpacing)
        }
        .padding(.top, pageTopInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: reveal)
        .onDisappear {
            revealGeneration += 1
        }
        .onChange(of: reduceMotion) {
            reveal()
        }
    }

    private var pageTopInset: CGFloat {
        guard !dynamicTypeSize.isAccessibilitySize else { return 4 }

        switch page {
        case .welcome:
            return 20
        case .privacy:
            return 16
        case .firstCard:
            return 12
        }
    }

    private var titleSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 9 : 11
    }

    private var heroToCopySpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 24
    }

    private var copyToSupportingSpacing: CGFloat {
        guard !dynamicTypeSize.isAccessibilitySize else { return 12 }

        switch page {
        case .welcome, .privacy:
            return 24
        case .firstCard:
            return 20
        }
    }

    @ViewBuilder
    private var titleContent: some View {
        switch page {
        case .privacy:
            OnboardingPrivacyTitle()
        case .welcome, .firstCard:
            Text(page.title)
                .font(CatTypography.screenTitle)
                .foregroundStyle(CatLocalTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var detailCopy: some View {
        if let identifier = page.detailAccessibilityIdentifier {
            detailText
                .accessibilityIdentifier(identifier)
        } else {
            detailText
        }
    }

    private var detailText: some View {
        Text(page.detail)
            .font(CatTypography.body)
            .foregroundStyle(CatLocalTheme.secondaryText.opacity(page.detailOpacity))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 340)
            .accessibilityLabel(page.detailAccessibilityLabel)
    }

    @ViewBuilder
    private var supportingContent: some View {
        switch page {
        case .welcome:
            OnboardingActivationTrail()
        case .privacy:
            OnboardingPrivacyCueList(cues: page.privacyCues)
        case .firstCard:
            OnboardingFinalPrompt()
        }
    }

    private func reveal() {
        revealGeneration += 1
        let generation = revealGeneration

        if reduceMotion {
            revealPhase = OnboardingRevealSection.supporting.rawValue
            return
        }

        revealPhase = 0

        guard page == .welcome else {
            withAnimation(revealAnimation(duration: 0.34)) {
                revealPhase = OnboardingRevealSection.supporting.rawValue
            }
            return
        }

        scheduleReveal(.hero, after: 0.04, duration: 0.36, generation: generation)
        scheduleReveal(.copy, after: 0.19, duration: 0.32, generation: generation)
        scheduleReveal(.supporting, after: 0.34, duration: 0.3, generation: generation)
    }

    private func scheduleReveal(
        _ section: OnboardingRevealSection,
        after delay: TimeInterval,
        duration: TimeInterval,
        generation: Int
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard generation == revealGeneration, !reduceMotion else { return }

            withAnimation(revealAnimation(duration: duration)) {
                revealPhase = section.rawValue
            }
        }
    }

    private func isRevealed(_ section: OnboardingRevealSection) -> Bool {
        reduceMotion || revealPhase >= section.rawValue
    }

    private func revealOpacity(_ section: OnboardingRevealSection) -> Double {
        isRevealed(section) ? 1 : 0.01
    }

    private func revealOffset(for section: OnboardingRevealSection) -> CGFloat {
        guard !isRevealed(section) else { return 0 }

        switch section {
        case .hero:
            return 14
        case .copy:
            return 10
        case .supporting:
            return 8
        }
    }

    private func revealScale(for section: OnboardingRevealSection) -> CGFloat {
        guard section == .hero, !isRevealed(section) else { return 1 }
        return 0.985
    }

    private func revealAnimation(duration: TimeInterval) -> Animation {
        .smooth(duration: duration, extraBounce: 0)
    }
}

private enum OnboardingRevealSection: Int {
    case hero = 1
    case copy
    case supporting
}

private struct OnboardingPrivacyTitle: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            titleLayout
        }
        .font(CatTypography.screenTitle)
        .foregroundStyle(CatLocalTheme.primaryText)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your furry encounters are safe")
        .accessibilityIdentifier("onboarding-privacy-title")
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var titleLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 6) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(CatLocalTheme.warning)
                    .rotationEffect(.degrees(-12))
                    .accessibilityHidden(true)

                privacyTitleLine
            }
        } else {
            VStack(spacing: 2) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .lastTextBaseline, spacing: 7) {
                        Text("Your")
                        furryWord
                        Text("encounters")
                    }

                    VStack(spacing: 0) {
                        Text("Your encounters")
                        furryWord
                    }
                }

                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text("are")
                    Text("safe")
                        .foregroundStyle(CatAttentionRole.success.accent)
                }
            }
        }
    }

    private var privacyTitleLine: Text {
        Text("Your furry encounters are ")
            + Text("safe").foregroundStyle(CatAttentionRole.success.accent)
    }

    private var furryWord: some View {
        VStack(spacing: -2) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CatLocalTheme.warning)
                .rotationEffect(.degrees(-12))
                .accessibilityHidden(true)

            Text("furry")
        }
        .alignmentGuide(.lastTextBaseline) { dimensions in
            dimensions[.bottom] - 4
        }
    }
}

private struct OnboardingHeroVisual: View {
    let page: OnboardingPage
    let didReveal: Bool

    var body: some View {
        visual
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var visual: some View {
        switch page {
        case .welcome:
            OnboardingCollectionHero(didReveal: didReveal)
                .accessibilityHidden(true)
        case .privacy:
            OnboardingPrivacyHero(didReveal: didReveal)
        case .firstCard:
            OnboardingFirstCardHero(didReveal: didReveal)
                .accessibilityHidden(true)
        }
    }
}

private struct OnboardingCollectionHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var cardWidth: CGFloat = 152
    @ScaledMetric(relativeTo: .largeTitle) private var cardHeight: CGFloat = 184

    let didReveal: Bool

    var body: some View {
        ZStack {
            archiveCard(rotation: -8, offset: CGSize(width: -46, height: 16), opacity: 0.74)
            archiveCard(rotation: 7, offset: CGSize(width: 46, height: 18), opacity: 0.72)
            frontCard
        }
        .frame(height: dynamicHeroHeight)
        .animation(reduceMotion ? nil : .smooth(duration: 0.48, extraBounce: 0), value: didReveal)
    }

    private var dynamicHeroHeight: CGFloat {
        max(cardHeight + 30, 214)
    }

    private func archiveCard(rotation: Double, offset: CGSize, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(CatLocalTheme.cardSurface.opacity(opacity))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline.opacity(0.3), lineWidth: 1)
            )
            .frame(width: cardWidth * 0.88, height: cardHeight * 0.92)
            .rotationEffect(.degrees(didReveal && !reduceMotion ? rotation : rotation * 0.5))
            .offset(
                x: didReveal && !reduceMotion ? offset.width : offset.width * 0.55,
                y: didReveal && !reduceMotion ? offset.height : offset.height * 0.65
            )
            .shadow(color: CatLocalTheme.shadow.opacity(0.08), radius: 8, y: 4)
    }

    private var frontCard: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        CatLocalTheme.cardSurface.opacity(0.98),
                        CatLocalTheme.actionWash.opacity(0.56)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(CatLocalTheme.actionStroke.opacity(0.42), lineWidth: 1)
            )
            .overlay {
                VStack(spacing: 11) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(CatAttentionRole.action.accent)
                        .frame(width: 58, height: 58)
                        .background(CatAttentionRole.action.wash, in: Circle())

                    Text("Local Card")
                        .font(CatTypography.bodyEmphasized)
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text("Saved here")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .shadow(color: CatLocalTheme.shadow.opacity(0.13), radius: 12, y: 6)
            .frame(width: cardWidth, height: cardHeight)
            .scaleEffect(didReveal && !reduceMotion ? 1 : 0.985)
    }
}

private struct OnboardingPrivacyHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var mascotSize: CGFloat = 92
    @State private var backlightBreathes = false

    let didReveal: Bool

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                lociBacklight

                Circle()
                    .fill(CatAttentionRole.info.wash.opacity(0.9))
                    .frame(width: mascotRingSize, height: mascotRingSize)
                    .overlay(
                        Circle()
                            .stroke(CatAttentionRole.info.stroke.opacity(0.42), lineWidth: 1)
                    )

                LociMascotView(
                    state: .state(for: .privacyEducation),
                    size: mascotSize
                )
                .scaleEffect(didReveal ? 1 : 0.97)
            }
            .accessibilityHidden(true)

            Label {
                Text("On this iPhone, by design")
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CatAttentionRole.success.accent)
            }
            .font(CatTypography.supportingEmphasized)
            .foregroundStyle(CatLocalTheme.primaryText)
            .labelStyle(.titleAndIcon)
            .padding(.leading, 13)
            .padding(.trailing, 14)
            .frame(minHeight: 38)
            .background(
                LinearGradient(
                    colors: [
                        CatLocalTheme.cardSurface.opacity(0.94),
                        CatAttentionRole.success.wash.opacity(0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(CatAttentionRole.success.stroke.opacity(0.52), lineWidth: 1)
            )
            .shadow(color: CatAttentionRole.success.accent.opacity(0.08), radius: 7, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("onboarding-privacy-pill")
        }
        .frame(height: 214)
        .onAppear {
            backlightBreathes = !reduceMotion
        }
        .onChange(of: reduceMotion) {
            backlightBreathes = !reduceMotion
        }
        .onDisappear {
            backlightBreathes = false
        }
    }

    private var mascotRingSize: CGFloat {
        mascotSize * 1.32
    }

    private var lociBacklight: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            CatAttentionRole.success.accent.opacity(0.24),
                            CatAttentionRole.info.wash.opacity(0.42),
                            CatAttentionRole.info.wash.opacity(0)
                        ],
                        center: .center,
                        startRadius: mascotRingSize * 0.08,
                        endRadius: mascotRingSize * 0.86
                    )
                )
                .frame(width: mascotRingSize * 1.58, height: mascotRingSize * 1.58)
                .blur(radius: 22)
                .scaleEffect(reduceMotion ? 1 : (backlightBreathes ? 1.05 : 0.98))
                .opacity(backlightOpacity)

            Circle()
                .fill(CatLocalTheme.backgroundGlow.opacity(0.78))
                .frame(width: mascotRingSize * 1.06, height: mascotRingSize * 1.06)
                .blur(radius: 20)
                .offset(x: -3, y: -5)
                .opacity(didReveal ? 0.5 : 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(
            reduceMotion ? nil : .smooth(duration: 2.8, extraBounce: 0).repeatForever(autoreverses: true),
            value: backlightBreathes
        )
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.2, extraBounce: 0),
            value: didReveal
        )
    }

    private var backlightOpacity: Double {
        guard didReveal else { return 0 }
        guard !reduceMotion else { return 0.72 }
        return backlightBreathes ? 0.84 : 0.68
    }
}

private struct OnboardingFirstCardHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var stageWidth: CGFloat = 258

    let didReveal: Bool

    var body: some View {
        ZStack {
            sourcePhoto
                .rotationEffect(.degrees(didReveal && !reduceMotion ? -7 : -3))
                .offset(x: didReveal && !reduceMotion ? -74 : -52, y: didReveal && !reduceMotion ? -24 : -12)

            savedCard
                .rotationEffect(.degrees(didReveal && !reduceMotion ? 6 : 2))
                .offset(x: didReveal && !reduceMotion ? 54 : 34, y: didReveal && !reduceMotion ? 20 : 12)

            liftedSubject
                .scaleEffect(didReveal && !reduceMotion ? 1 : 0.94)
                .offset(y: didReveal && !reduceMotion ? -4 : 10)
        }
        .frame(width: effectiveStageWidth, height: dynamicTypeSize.isAccessibilitySize ? 176 : 204)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .smooth(duration: 0.42, extraBounce: 0), value: didReveal)
    }

    private var effectiveStageWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 228 : stageWidth
    }

    private var sourcePhoto: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(CatLocalTheme.cardSurface.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline.opacity(0.42), lineWidth: 1)
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(CatAttentionRole.action.accent)

                    Text("Photo")
                        .font(CatTypography.finePrint)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
            }
            .frame(width: effectiveStageWidth * 0.44, height: dynamicTypeSize.isAccessibilitySize ? 108 : 126)
            .shadow(color: CatLocalTheme.shadow.opacity(0.08), radius: 8, y: 4)
    }

    private var savedCard: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        CatLocalTheme.cardSurface.opacity(0.98),
                        CatAttentionRole.success.wash.opacity(0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(CatAttentionRole.success.stroke.opacity(0.42), lineWidth: 1)
            )
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Card")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.primaryText)

                    Text("Saved to Home")
                        .font(CatTypography.finePrint)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .padding(13)
            }
            .frame(width: effectiveStageWidth * 0.54, height: dynamicTypeSize.isAccessibilitySize ? 130 : 150)
            .shadow(color: CatLocalTheme.shadow.opacity(0.13), radius: 12, y: 6)
    }

    private var liftedSubject: some View {
        ZStack {
            Circle()
                .fill(CatAttentionRole.action.wash.opacity(0.9))
                .frame(width: 86, height: 86)
                .blur(radius: 10)
                .opacity(0.82)

            Circle()
                .fill(CatLocalTheme.cardSurface.opacity(0.94))
                .frame(width: 76, height: 76)
                .overlay(
                    Circle()
                        .stroke(CatAttentionRole.action.stroke.opacity(0.46), lineWidth: 1)
                )

            Image(systemName: "pawprint.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CatAttentionRole.action.accent)

            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(CatAttentionRole.success.accent)
                .offset(x: 30, y: -28)
        }
        .shadow(color: CatLocalTheme.shadow.opacity(0.1), radius: 9, y: 4)
    }
}

private struct OnboardingTrailItem: Identifiable {
    let title: String
    let detail: String?
    let systemImage: String
    let role: CatAttentionRole

    init(
        title: String,
        detail: String? = nil,
        systemImage: String,
        role: CatAttentionRole
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.role = role
    }

    var id: String { title }
}

private struct OnboardingActivationTrail: View {
    private let items = [
        OnboardingTrailItem(
            title: "Capture or Import",
            detail: "Camera or private photo",
            systemImage: "camera.viewfinder",
            role: .action
        ),
        OnboardingTrailItem(
            title: "Lift On Device",
            detail: "Looking for cats, then lifting the subject",
            systemImage: "viewfinder",
            role: .info
        ),
        OnboardingTrailItem(
            title: "Make It Yours",
            detail: "Choose a design, notes, and typed place",
            systemImage: "rectangle.stack.fill",
            role: .success
        )
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(items) { item in
                OnboardingProcessStepRow(item: item)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capture or Import. Lift On Device. Make It Yours.")
    }
}

private struct OnboardingProcessStepRow: View {
    let item: OnboardingTrailItem

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.role.accent)
                .frame(width: 40, height: 40)
                .background(item.role.wash.opacity(0.86), in: Circle())
                .accessibilityHidden(true)

            Text(item.title)
                .font(CatTypography.metadata)
                .foregroundStyle(CatLocalTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([item.title, item.detail].compactMap { $0 }.joined(separator: ". "))
    }
}

private struct OnboardingPrivacyCueList: View {
    let cues: [OnboardingPrivacyCue]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(cues) { cue in
                OnboardingPrivacyCueRow(cue: cue)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("onboarding-privacy-cues")
    }
}

private struct OnboardingPrivacyCueRow: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 16

    let cue: OnboardingPrivacyCue

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: cue.systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(cue.role.accent)
                .frame(width: 40, height: 40)
                .background(cue.role.wash, in: Circle())
                .accessibilityHidden(true)

            Text(cue.title)
                .font(CatTypography.metadata)
                .foregroundStyle(CatLocalTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cue.title). \(cue.detail)")
    }
}

private struct OnboardingFinalPrompt: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let traits = [
        OnboardingTrailItem(
            title: "Lifted cutout",
            detail: "On-device lift",
            systemImage: "scissors",
            role: .action
        ),
        OnboardingTrailItem(
            title: "Card details",
            detail: "Design, notes, place",
            systemImage: "rectangle.stack.fill",
            role: .info
        )
    ]

    var body: some View {
        VStack(spacing: 14) {
            Text("Your first card keeps the lifted cutout, design, notes, and typed place together.")
                .font(CatTypography.supporting)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)

            anatomyRail
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding-first-card-anatomy")
    }

    @ViewBuilder
    private var anatomyRail: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(traits) { trait in
                    OnboardingCardDetailItem(item: trait, layout: .row)
                }
            }
        } else {
            HStack(spacing: 9) {
                ForEach(traits) { trait in
                    OnboardingCardDetailItem(item: trait, layout: .tile)
                }
            }
        }
    }
}

private enum OnboardingCardDetailLayout: Equatable {
    case row
    case tile
}

private struct OnboardingCardDetailItem: View {
    let item: OnboardingTrailItem
    let layout: OnboardingCardDetailLayout

    var body: some View {
        Group {
            switch layout {
            case .row:
                rowContent
            case .tile:
                tileContent
            }
        }
        .padding(.horizontal, layout == .tile ? 10 : 12)
        .padding(.vertical, layout == .tile ? 11 : 10)
        .background(CatLocalTheme.cardSurface.opacity(0.66), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(item.role.stroke.opacity(0.34), lineWidth: 1)
        )
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 8) {
            icon
            textStack(alignment: .leading, detailAlignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tileContent: some View {
        VStack(spacing: 7) {
            icon
            textStack(alignment: .center, detailAlignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .center)
    }

    private var icon: some View {
        Image(systemName: item.systemImage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(item.role.accent)
            .frame(width: 28, height: 28)
            .background(item.role.wash.opacity(0.82), in: Circle())
            .accessibilityHidden(true)
    }

    private func textStack(alignment: HorizontalAlignment, detailAlignment: TextAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(item.title)
                .font(CatTypography.metadata)
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(detailAlignment)

            if let detail = item.detail {
                Text(detail)
                    .font(CatTypography.finePrint)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(detailAlignment)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let selectedPage: OnboardingPage

    var body: some View {
        GeometryReader { geometry in
            Capsule(style: .continuous)
                .fill(CatLocalTheme.separator.opacity(0.72))
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(CatAttentionRole.action.accent)
                        .frame(width: geometry.size.width * progressFraction)
                }
        }
        .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2, extraBounce: 0), value: selectedPage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding step \(selectedPage.stepNumber) of \(OnboardingPage.totalCount)")
        .accessibilityIdentifier("onboarding-progress")
    }

    private var progressFraction: CGFloat {
        CGFloat(selectedPage.stepNumber) / CGFloat(OnboardingPage.totalCount)
    }
}

private struct OnboardingPrimaryActionLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let systemImage: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title)
                    .font(CatTypography.control)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10) {
                    Text(title)
                        .font(CatTypography.control)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)

                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.22, extraBounce: 0), value: systemImage)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

#Preview {
    OnboardingView {}
}
