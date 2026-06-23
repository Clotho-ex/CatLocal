import SwiftUI

enum CatLocalTheme {
    static let limestone = Color(red: 0.95, green: 0.93, blue: 0.88)
    static let chalk = Color(red: 0.985, green: 0.975, blue: 0.94)
    static let forest = Color(red: 0.045, green: 0.16, blue: 0.105)
    static let ink = Color(red: 0.105, green: 0.11, blue: 0.10)
    static let apricot = Color(red: 0.91, green: 0.36, blue: 0.12)
    static let cobalt = Color(red: 0.16, green: 0.36, blue: 0.66)
    static let sage = Color(red: 0.47, green: 0.55, blue: 0.48)

    static func accent(for style: CardStyle) -> Color {
        switch style {
        case .archive: forest
        case .sunstamp: apricot
        case .clear: cobalt
        }
    }
}

struct CatLocalBackground: View {
    var body: some View {
        ZStack {
            CatLocalTheme.limestone

            RadialGradient(
                colors: [
                    .white.opacity(0.82),
                    CatLocalTheme.limestone.opacity(0)
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 520
            )

            LinearGradient(
                colors: [
                    CatLocalTheme.sage.opacity(0.10),
                    .clear,
                    CatLocalTheme.apricot.opacity(0.055)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

private struct CatGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if #available(iOS 26.0, *) {
                if interactive {
                    content
                        .glassEffect(
                            .regular.tint(.white.opacity(0.08)).interactive(),
                            in: .rect(cornerRadius: cornerRadius)
                        )
                } else {
                    content
                        .glassEffect(
                            .regular.tint(.white.opacity(0.08)),
                            in: .rect(cornerRadius: cornerRadius)
                        )
                }
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.stroke(.white.opacity(0.56), lineWidth: 1))
                    .shadow(color: CatLocalTheme.ink.opacity(0.09), radius: 18, y: 8)
            }
        }
    }
}

extension View {
    nonisolated func catGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(CatGlassModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    nonisolated func catEditorialTitle(size: CGFloat) -> some View {
        font(.system(size: size, weight: .medium, design: .serif))
            .tracking(-size * 0.045)
    }
}
