import SwiftUI

struct FocusedCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let card: CatCard
    let dismiss: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CatLocalTheme.ink.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismiss)

                VStack(spacing: 18) {
                    Spacer(minLength: 32)

                    CatCardView(card: card, presentation: .focused)
                        .frame(maxWidth: min(proxy.size.width - 54, 360))
                        .rotation3DEffect(
                            .degrees(reduceMotion ? 0 : Double(dragOffset.height / -18)),
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.65
                        )
                        .rotation3DEffect(
                            .degrees(reduceMotion ? 0 : Double(dragOffset.width / 18)),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.65
                        )
                        .overlay {
                            if !reduceMotion {
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.45), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .blendMode(.screen)
                                .offset(x: dragOffset.width * 1.8)
                                .mask {
                                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                                }
                                .allowsHitTesting(false)
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard !reduceMotion else { return }
                                    dragOffset = CGSize(
                                        width: max(-90, min(90, value.translation.width)),
                                        height: max(-90, min(90, value.translation.height))
                                    )
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                                        dragOffset = .zero
                                    }
                                }
                        )

                    Label("Drag to catch the light", systemImage: "hand.draw")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CatLocalTheme.forest)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(.thinMaterial, in: Capsule())

                    Button("Close", action: dismiss)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CatLocalTheme.forest)
                        .padding(.vertical, 8)

                    Spacer(minLength: 112)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, dismiss)
    }
}
