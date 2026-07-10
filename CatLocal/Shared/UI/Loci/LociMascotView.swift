import SwiftUI

struct LociMascotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loopPhase = false
    @State private var impulsePhase = false

    let state: LociMascotState
    var size: CGFloat = 160
    var accessibilityLabel: String?

    init(
        state: LociMascotState,
        size: CGFloat = 160,
        accessibilityLabel: String? = nil
    ) {
        self.state = state
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    init(
        pose: LociPose,
        size: CGFloat = 160,
        motion: LociMascotAnimation = .none,
        title: String = "",
        subtitle: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.state = LociMascotState(
            pose: pose,
            motion: motion,
            title: title,
            subtitle: subtitle
        )
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    init(
        pose: LociPose,
        size: CGFloat = 160,
        animation: LociMascotAnimation,
        accessibilityLabel: String? = nil
    ) {
        self.init(
            pose: pose,
            size: size,
            motion: animation,
            accessibilityLabel: accessibilityLabel
        )
    }

    var body: some View {
        ZStack {
            mascotImage
                .id(state.pose)
                .transition(poseTransition)
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .offset(x: xOffset, y: yOffset)
        .rotationEffect(.degrees(rotationDegrees))
        .animation(poseAnimation, value: state.pose)
        .onAppear(perform: restartMotion)
        .onDisappear(perform: stopMotion)
        .onChange(of: state.pose) {
            restartMotion()
        }
        .onChange(of: state.motion) {
            restartMotion()
        }
        .onChange(of: reduceMotion) {
            restartMotion()
        }
    }

    private var mascotImage: some View {
        Image(state.pose.rawValue)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFit()
            .accessibilityLabel(Text(accessibilityLabel ?? ""))
            .accessibilityHidden(accessibilityLabel == nil)
    }

    private var poseAnimation: Animation? {
        if reduceMotion {
            return .easeInOut(duration: 0.16)
        }

        return .smooth(duration: 0.24, extraBounce: 0)
    }

    private var poseTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .scale(scale: 1.02).combined(with: .opacity)
        )
    }

    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }

        switch state.motion {
        case .none:
            return 1
        case .idle:
            return loopPhase ? 1.01 : 0.995
        case .thinking:
            return loopPhase ? 1.006 : 1
        case .successPop:
            return impulsePhase ? 1.08 : 1
        case .errorTilt:
            return impulsePhase ? 1.015 : 1
        }
    }

    private var xOffset: CGFloat {
        guard !reduceMotion else { return 0 }

        switch state.motion {
        case .errorTilt:
            return impulsePhase ? -2 : 0
        case .none, .idle, .thinking, .successPop:
            return 0
        }
    }

    private var yOffset: CGFloat {
        guard !reduceMotion else { return 0 }

        switch state.motion {
        case .idle:
            return loopPhase ? -3 : 2
        case .thinking:
            return loopPhase ? -2 : 1
        case .successPop:
            return impulsePhase ? -3 : 0
        case .none, .errorTilt:
            return 0
        }
    }

    private var rotationDegrees: Double {
        guard !reduceMotion else { return 0 }

        switch state.motion {
        case .thinking:
            return loopPhase ? -2 : 1.5
        case .errorTilt:
            return impulsePhase ? -4 : 0
        case .none, .idle, .successPop:
            return 0
        }
    }

    private func restartMotion() {
        stopMotion()
        guard !reduceMotion else { return }

        switch state.motion {
        case .idle:
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                loopPhase = true
            }
        case .thinking:
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                loopPhase = true
            }
        case .successPop:
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                impulsePhase = true
            }
            settleImpulse(after: 0.2, animation: .smooth(duration: 0.3, extraBounce: 0))
        case .errorTilt:
            withAnimation(.easeInOut(duration: 0.18)) {
                impulsePhase = true
            }
            settleImpulse(after: 0.18, animation: .smooth(duration: 0.24, extraBounce: 0))
        case .none:
            break
        }
    }

    private func stopMotion() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            loopPhase = false
            impulsePhase = false
        }
    }

    private func settleImpulse(after delay: TimeInterval, animation: Animation) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !reduceMotion else { return }
            withAnimation(animation) {
                impulsePhase = false
            }
        }
    }
}
