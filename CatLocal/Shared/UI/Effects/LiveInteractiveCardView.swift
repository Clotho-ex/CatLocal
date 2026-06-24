import SwiftUI
import UIKit

struct LiveInteractiveCardView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let width: CGFloat?
    let height: CGFloat?
    let maxTiltAngle: CGFloat
    let cornerRadius: CGFloat
    let hapticsEnabled: Bool
    @ViewBuilder let content: () -> Content

    @State private var rotateX: CGFloat = 0
    @State private var rotateY: CGFloat = 0
    @State private var spotlightLocation: CGPoint = .zero
    @State private var hasHitLimit = false

    init(
        width: CGFloat? = 350,
        height: CGFloat? = 220,
        maxTiltAngle: CGFloat = 12,
        cornerRadius: CGFloat = 34,
        hapticsEnabled: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.width = width
        self.height = height
        self.maxTiltAngle = maxTiltAngle
        self.cornerRadius = cornerRadius
        self.hapticsEnabled = hapticsEnabled
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                content()
                    .frame(width: size.width, height: size.height)

                if !reduceMotion {
                    spotlight(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
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
            .onAppear {
                spotlightLocation = CGPoint(x: size.width / 2, y: size.height / 2)
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    resetInteraction(size: size)
                }
            }
        }
        .frame(width: width, height: height)
    }

    private func spotlight(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0.22),
                        CatLocalTheme.blueAction.opacity(0.08),
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

                if hapticsEnabled && tilt.isAtLimit && !hasHitLimit {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
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
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    rotateX = 0
                    rotateY = 0
                    spotlightLocation = CGPoint(x: size.width / 2, y: size.height / 2)
                }
            }
    }

    private func resetInteraction(size: CGSize) {
        hasHitLimit = false
        rotateX = 0
        rotateY = 0
        spotlightLocation = CGPoint(x: size.width / 2, y: size.height / 2)
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

        LiveInteractiveCardView {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(CatLocalTheme.elevatedSurface)
                .overlay {
                    Text("CatLocal")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                }
        }
    }
}
