import SwiftUI

struct CatLocalCardSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme

    var showsShimmer = false

    var body: some View {
        GeometryReader { proxy in
            let tone = CatLocalSkeletonTone.scheme(colorScheme)
            let width = proxy.size.width
            let padding = max(16, width * 0.105)
            let cornerRadius = max(24, width * 0.17)
            let imageCornerRadius = max(18, width * 0.13)

            VStack(spacing: 0) {
                SkeletonCardHeader(width: width, showsShimmer: showsShimmer)

                Spacer(minLength: width * 0.09)

                SkeletonCardImagePlaceholder(
                    cornerRadius: imageCornerRadius,
                    showsShimmer: showsShimmer
                )

                Spacer(minLength: width * 0.10)

                SkeletonCardFooter(width: width, showsShimmer: showsShimmer)

                Spacer(minLength: 0)
            }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tone.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tone.cardStroke, lineWidth: 1)
            }
            .shadow(color: CatLocalTheme.shadow.opacity(0.14), radius: 14, x: 0, y: 8)
        }
        .aspectRatio(0.68, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct CatLocalSkeletonTone {
    let cardFill: Color
    let cardStroke: Color
    let imageFill: Color
    let catFill: Color
    let shapeFill: Color
    let shimmerFill: Color
    let imageShimmerOpacity: Double

    static func scheme(_ colorScheme: ColorScheme) -> CatLocalSkeletonTone {
        switch colorScheme {
        case .dark:
            return CatLocalSkeletonTone(
                cardFill: CatLocalTheme.cardSurface.opacity(0.98),
                cardStroke: CatLocalTheme.imageOutline.opacity(0.86),
                imageFill: CatLocalTheme.positiveWash.opacity(0.78),
                catFill: CatLocalTheme.positiveStroke.opacity(0.42),
                shapeFill: CatLocalTheme.secondaryText.opacity(0.36),
                shimmerFill: CatLocalTheme.primaryText.opacity(0.30),
                imageShimmerOpacity: 0.42
            )
        default:
            return CatLocalSkeletonTone(
                cardFill: CatLocalTheme.cardSurface,
                cardStroke: CatLocalTheme.imageOutline.opacity(0.65),
                imageFill: CatLocalTheme.sage.opacity(0.24),
                catFill: CatLocalTheme.sage.opacity(0.44),
                shapeFill: CatLocalTheme.sage.opacity(0.42),
                shimmerFill: .white.opacity(0.28),
                imageShimmerOpacity: 0.34
            )
        }
    }
}

private struct SkeletonCardHeader: View {
    let width: CGFloat
    let showsShimmer: Bool

    var body: some View {
        HStack(alignment: .center) {
            SkeletonCapsule(
                width: width * 0.30,
                height: max(8, width * 0.045),
                showsShimmer: showsShimmer
            )

            Spacer()

            SkeletonCircle(size: width * 0.14, showsShimmer: showsShimmer)
        }
    }
}

private struct SkeletonCardImagePlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let showsShimmer: Bool

    var body: some View {
        let tone = CatLocalSkeletonTone.scheme(colorScheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(tone.imageFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                CatHeadPlaceholder()
                    .foregroundStyle(tone.catFill)
                    .padding(44)
            }
            .overlay {
                if showsShimmer {
                    SkeletonShape(shape: shape, showsShimmer: true)
                        .opacity(tone.imageShimmerOpacity)
                }
            }
            .compositingGroup()
    }
}

private struct SkeletonCardFooter: View {
    let width: CGFloat
    let showsShimmer: Bool

    var body: some View {
        SkeletonCapsule(
            width: width * 0.42,
            height: max(8, width * 0.045),
            showsShimmer: showsShimmer
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SkeletonCapsule: View {
    let width: CGFloat
    let height: CGFloat
    let showsShimmer: Bool

    var body: some View {
        SkeletonShape(shape: Capsule(), showsShimmer: showsShimmer)
            .frame(width: width, height: height)
    }
}

private struct SkeletonCircle: View {
    let size: CGFloat
    let showsShimmer: Bool

    var body: some View {
        SkeletonShape(shape: Circle(), showsShimmer: showsShimmer)
            .frame(width: size, height: size)
    }
}

private struct SkeletonShape<S: Shape>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerX: CGFloat = -1.2

    let shape: S
    let showsShimmer: Bool

    var body: some View {
        let tone = CatLocalSkeletonTone.scheme(colorScheme)

        shape
            .fill(tone.shapeFill)
            .overlay {
                if showsShimmer && !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                .clear,
                                tone.shimmerFill,
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.7)
                        .offset(x: shimmerX * proxy.size.width)
                    }
                    .mask(shape)
                    .onAppear {
                        shimmerX = 1.6
                    }
                    .animation(
                        .linear(duration: 1.6).repeatForever(autoreverses: false),
                        value: shimmerX
                    )
                }
            }
    }
}

private struct CatHeadPlaceholder: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                Triangle()
                    .frame(width: size * 0.32, height: size * 0.34)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -size * 0.22, y: -size * 0.17)

                Triangle()
                    .frame(width: size * 0.32, height: size * 0.34)
                    .rotationEffect(.degrees(18))
                    .offset(x: size * 0.22, y: -size * 0.17)

                Circle()
                    .frame(width: size * 0.68, height: size * 0.68)
                    .offset(y: size * 0.06)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
