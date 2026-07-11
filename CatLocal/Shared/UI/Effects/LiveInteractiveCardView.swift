import Accessibility
import SwiftUI

/// Areas for Polish: While custom procedural effects like contour-line cards are
/// impressive, they are computationally heavy.
/// The developer correctly mitigates this by restricting complex renders to
/// focused states and utilizing drawingGroup(), but rendering performance on
/// older devices should be continuously monitored.
struct LiveInteractiveCardView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let width: CGFloat?
    let height: CGFloat?
    let maxTiltAngle: CGFloat
    let cornerRadius: CGFloat
    let hapticsEnabled: Bool
    let onInteractionChanged: ((Bool) -> Void)?
    @ViewBuilder let content: (_ rotateX: CGFloat, _ rotateY: CGFloat, _ isInteracting: Bool) -> Content

    @State private var rotateX: CGFloat = 0
    @State private var rotateY: CGFloat = 0
    @State private var spotlightLocation: CGPoint = .zero
    @State private var lightingPosition: LiveInteractiveCardLightingPosition = .center
    @State private var isInteracting = false
    @State private var lastHapticAngle: CGFloat = 0
    @State private var hasHitLimit = false
    @State private var selectionFeedbackTrigger = 0
    @State private var limitFeedbackTrigger = 0

    init(
        width: CGFloat? = 350,
        height: CGFloat? = 220,
        maxTiltAngle: CGFloat = 12,
        cornerRadius: CGFloat = 34,
        hapticsEnabled: Bool = true,
        onInteractionChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder content: @escaping (_ rotateX: CGFloat, _ rotateY: CGFloat, _ isInteracting: Bool) -> Content
    ) {
        self.width = width
        self.height = height
        self.maxTiltAngle = maxTiltAngle
        self.cornerRadius = cornerRadius
        self.hapticsEnabled = hapticsEnabled
        self.onInteractionChanged = onInteractionChanged
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                content(rotateX, rotateY, isInteracting)
                    .frame(width: size.width, height: size.height)

                if !reduceMotion {
                    spotlight(size: size)
                        .opacity(isInteracting ? 1 : 0)
                        .animation(.easeInOut(duration: 0.18), value: isInteracting)
                }
            }
            .frame(width: size.width, height: size.height)
            .compositingGroup()
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : rotateX),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.66
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : rotateY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.66
            )
            .gesture(dragGesture(size: size))
            .accessibilityAdjustableAction { direction in
                adjustLighting(direction: direction, size: size)
            }
            .accessibilityLabel("Card lighting")
            .accessibilityValue(lightingPosition.accessibilityValue)
            .accessibilityHint("Swipe up or down to move the light.")
            .onAppear {
                spotlightLocation = CGPoint(x: size.width / 2, y: size.height / 2)
                lightingPosition = .center
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    resetInteraction(size: size)
                }
            }
            .onChange(of: isInteracting) { _, isInteracting in
                onInteractionChanged?(isInteracting)
            }
            .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1), trigger: limitFeedbackTrigger)
        }
        .frame(width: width, height: height)
    }

    private func spotlight(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0.18),
                        .cyan.opacity(0.05),
                        .clear
                    ]),
                    center: UnitPoint(
                        x: spotlightLocation.x / max(size.width, 1),
                        y: spotlightLocation.y / max(size.height, 1)
                    ),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.55
                )
            )
            .blendMode(.screen)
            .compositingGroup()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !reduceMotion else { return }

                let tilt = LiveInteractiveCardMath.tilt(
                    for: value.location,
                    in: size,
                    maxTiltAngle: maxTiltAngle
                )
                spotlightLocation = tilt.location
                lightingPosition = LiveInteractiveCardLightingPosition(
                    locationX: tilt.location.x,
                    width: size.width
                )
                let hapticMagnitude = abs(tilt.rotateX) + abs(tilt.rotateY)
                if hapticsEnabled, abs(hapticMagnitude - lastHapticAngle) > 2.5 {
                    selectionFeedbackTrigger += 1
                    lastHapticAngle = hapticMagnitude
                }

                withAnimation(.easeInOut(duration: 0.16)) {
                    isInteracting = true
                }

                if hapticsEnabled && tilt.isAtLimit && !hasHitLimit {
                    limitFeedbackTrigger += 1
                    hasHitLimit = true
                } else if !tilt.isAtLimit {
                    hasHitLimit = false
                }

                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.65)) {
                    rotateX = tilt.rotateX
                    rotateY = tilt.rotateY
                }
            }
            .onEnded { _ in
                hasHitLimit = false
                lastHapticAngle = 0
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    rotateX = 0
                    rotateY = 0
                    spotlightLocation = CGPoint(x: size.width / 2, y: size.height / 2)
                    lightingPosition = .center
                    isInteracting = false
                }
            }
    }

    private func resetInteraction(size: CGSize) {
        hasHitLimit = false
        isInteracting = false
        lastHapticAngle = 0
        rotateX = 0
        rotateY = 0
        spotlightLocation = CGPoint(x: size.width / 2, y: size.height / 2)
        lightingPosition = .center
    }

    private func adjustLighting(direction: AccessibilityAdjustmentDirection, size: CGSize) {
        guard !reduceMotion else { return }

        let nextPosition: LiveInteractiveCardLightingPosition?
        switch direction {
        case .increment:
            nextPosition = lightingPosition.movingRight()
        case .decrement:
            nextPosition = lightingPosition.movingLeft()
        @unknown default:
            nextPosition = nil
        }
        guard let nextPosition else { return }

        let tilt = LiveInteractiveCardMath.tilt(
            for: CGPoint(x: nextPosition.locationX(in: size.width), y: size.height / 2),
            in: size,
            maxTiltAngle: maxTiltAngle
        )
        spotlightLocation = tilt.location
        lightingPosition = nextPosition
        withAnimation(.easeInOut(duration: 0.16)) {
            isInteracting = true
        }

        if hapticsEnabled && tilt.isAtLimit {
            limitFeedbackTrigger += 1
        }

        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.65)) {
            rotateX = tilt.rotateX
            rotateY = tilt.rotateY
        }

        AccessibilityNotification.Announcement(nextPosition.accessibilityValue).post()
    }
}

enum LiveInteractiveCardLightingPosition: Int, CaseIterable, Sendable {
    case left = -1
    case center = 0
    case right = 1

    var accessibilityValue: String {
        switch self {
        case .left:
            "Light left"
        case .center:
            "Light centered"
        case .right:
            "Light right"
        }
    }

    init(locationX: CGFloat, width: CGFloat) {
        guard width > 0 else {
            self = .center
            return
        }

        let normalizedX = min(max(locationX / width, 0), 1)
        if normalizedX < 1 / 3 {
            self = .left
        } else if normalizedX > 2 / 3 {
            self = .right
        } else {
            self = .center
        }
    }

    func movingLeft() -> Self? {
        Self(rawValue: rawValue - 1)
    }

    func movingRight() -> Self? {
        Self(rawValue: rawValue + 1)
    }

    func locationX(in width: CGFloat) -> CGFloat {
        switch self {
        case .left:
            0
        case .center:
            width / 2
        case .right:
            width
        }
    }
}

struct LiveInteractiveCardTilt: Equatable {
    let location: CGPoint
    let rotateX: CGFloat
    let rotateY: CGFloat
    let isAtLimit: Bool
}

enum LiveInteractiveCardMath {
    static func tilt(
        for location: CGPoint,
        in size: CGSize,
        maxTiltAngle: CGFloat
    ) -> LiveInteractiveCardTilt {
        guard size.width > 0, size.height > 0 else {
            return LiveInteractiveCardTilt(
                location: .zero,
                rotateX: 0,
                rotateY: 0,
                isAtLimit: false
            )
        }

        let boundedLocation = CGPoint(
            x: min(max(location.x, 0), size.width),
            y: min(max(location.y, 0), size.height)
        )
        let percentX = (boundedLocation.y / size.height) - 0.5
        let percentY = (boundedLocation.x / size.width) - 0.5

        let rawRotateX = -percentX * (maxTiltAngle * 2.5)
        let rawRotateY = percentY * (maxTiltAngle * 2.5)
        let clampedX = min(max(rawRotateX, -maxTiltAngle), maxTiltAngle)
        let clampedY = min(max(rawRotateY, -maxTiltAngle), maxTiltAngle)
        let isAtLimit = abs(clampedX) == maxTiltAngle || abs(clampedY) == maxTiltAngle

        return LiveInteractiveCardTilt(
            location: boundedLocation,
            rotateX: clampedX,
            rotateY: clampedY,
            isAtLimit: isAtLimit
        )
    }
}

#Preview {
    ZStack {
        CatLocalBackground()

        LiveInteractiveCardView { _, _, _ in
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(CatLocalTheme.elevatedSurface)
                .overlay {
                    Text("CatLocal")
                        .font(CatTypography.screenTitle)
                        .foregroundStyle(CatLocalTheme.primaryText)
                }
        }
    }
}
