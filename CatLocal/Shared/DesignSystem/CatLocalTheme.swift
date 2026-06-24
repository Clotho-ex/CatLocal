import SwiftUI

enum CatLocalTheme {
    static let background = Color(
        light: UIColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1),
        dark: UIColor(red: 0.055, green: 0.058, blue: 0.052, alpha: 1)
    )
    static let backgroundGlow = Color(
        light: UIColor(red: 1.0, green: 0.985, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.16, blue: 0.15, alpha: 1)
    )
    static let elevatedSurface = Color(
        light: UIColor(red: 0.985, green: 0.975, blue: 0.945, alpha: 1),
        dark: UIColor(red: 0.125, green: 0.13, blue: 0.12, alpha: 1)
    )
    static let cardSurface = Color(
        light: UIColor(red: 0.975, green: 0.963, blue: 0.925, alpha: 1),
        dark: UIColor(red: 0.165, green: 0.168, blue: 0.155, alpha: 1)
    )
    static let primaryText = Color(
        light: UIColor(red: 0.06, green: 0.08, blue: 0.065, alpha: 1),
        dark: UIColor(red: 0.93, green: 0.91, blue: 0.86, alpha: 1)
    )
    static let secondaryText = Color(
        light: UIColor(red: 0.35, green: 0.37, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.67, blue: 0.62, alpha: 1)
    )
    static let separator = Color(
        light: UIColor(red: 0.06, green: 0.08, blue: 0.065, alpha: 0.12),
        dark: UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 0.14)
    )
    static let imageOutline = Color(
        light: UIColor.black.withAlphaComponent(0.10),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let shadow = Color(
        light: UIColor(red: 0.05, green: 0.08, blue: 0.06, alpha: 0.18),
        dark: UIColor.black.withAlphaComponent(0.45)
    )
    static let blueAction = Color(
        light: UIColor(red: 0.0, green: 0.32, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.58, blue: 1.0, alpha: 1)
    )
    static let warning = Color(
        light: UIColor(red: 0.82, green: 0.32, blue: 0.10, alpha: 1),
        dark: UIColor(red: 1.0, green: 0.55, blue: 0.28, alpha: 1)
    )
    static let sage = Color(
        light: UIColor(red: 0.47, green: 0.55, blue: 0.48, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.65, blue: 0.56, alpha: 1)
    )

    static let limestone = background
    static let chalk = elevatedSurface
    static let forest = primaryText
    static let ink = primaryText
    static let apricot = warning
    static let cobalt = blueAction

    static func accent(for style: CardStyle) -> Color {
        switch style {
        case .archive: secondaryText
        case .sunstamp: warning
        case .clear: blueAction
        }
    }

    static func paperSurface(for style: CardStyle) -> Color {
        switch style {
        case .archive:
            cardSurface
        case .sunstamp:
            Color(
                light: UIColor(red: 0.98, green: 0.94, blue: 0.86, alpha: 1),
                dark: UIColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1)
            )
        case .clear:
            Color(
                light: UIColor(red: 0.93, green: 0.96, blue: 0.96, alpha: 1),
                dark: UIColor(red: 0.12, green: 0.16, blue: 0.17, alpha: 1)
            )
        }
    }
}

struct CatLocalBackground: View {
    var body: some View {
        ZStack {
            CatLocalTheme.background

            RadialGradient(
                colors: [
                    CatLocalTheme.backgroundGlow.opacity(0.82),
                    CatLocalTheme.background.opacity(0)
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 520
            )

            LinearGradient(
                colors: [
                    CatLocalTheme.sage.opacity(0.10),
                    .clear,
                    CatLocalTheme.blueAction.opacity(0.055)
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
                    .overlay(shape.stroke(CatLocalTheme.imageOutline, lineWidth: 1))
                    .shadow(color: CatLocalTheme.shadow.opacity(0.55), radius: 18, y: 8)
            }
        }
    }
}

extension View {
    nonisolated func catGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(CatGlassModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    nonisolated func catEditorialTitle(size: CGFloat) -> some View {
        font(.system(size: size, weight: .semibold))
            .tracking(-size * 0.045)
    }
}

extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
