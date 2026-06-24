import SwiftUI

enum CatLocalTheme {
    static let background = Color(
        light: UIColor(hex: 0xF2EDE4),
        dark: UIColor(hex: 0x121413)
    )
    static let backgroundGlow = Color(
        light: UIColor(hex: 0xFAF8F5),
        dark: UIColor(hex: 0x1C1E1D)
    )
    static let elevatedSurface = Color(
        light: UIColor(hex: 0xE6DFD3),
        dark: UIColor(hex: 0x1C1E1D)
    )
    static let cardSurface = Color(
        light: UIColor(hex: 0xFAF8F5),
        dark: UIColor(hex: 0x262927)
    )
    static let primaryText = Color(
        light: UIColor(hex: 0x1A2F25),
        dark: UIColor(hex: 0x8FA89B)
    )
    static let secondaryText = Color(
        light: UIColor(hex: 0x6E6A61),
        dark: UIColor(hex: 0x91948F)
    )
    static let separator = Color(
        light: UIColor(hex: 0x1A2F25, alpha: 0.12),
        dark: UIColor(hex: 0x8FA89B, alpha: 0.16)
    )
    static let imageOutline = Color(
        light: UIColor.black.withAlphaComponent(0.10),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let shadow = Color(
        light: UIColor(hex: 0x1A2F25, alpha: 0.16),
        dark: UIColor.black.withAlphaComponent(0.45)
    )
    static let blueAction = Color(
        light: UIColor(red: 0.0, green: 0.32, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.58, blue: 1.0, alpha: 1)
    )
    static let warning = Color(
        light: UIColor(hex: 0xD95B32),
        dark: UIColor(hex: 0xFF7A59)
    )
    static let sage = Color(
        light: UIColor(hex: 0x1A2F25),
        dark: UIColor(hex: 0x8FA89B)
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
                light: UIColor(hex: 0xFAF8F5),
                dark: UIColor(hex: 0x262927)
            )
        case .clear:
            Color(
                light: UIColor(hex: 0xFAF8F5),
                dark: UIColor(hex: 0x262927)
            )
        }
    }

    static let screenHorizontalPadding: CGFloat = 22
    static let largePanelRadius: CGFloat = 32
    static let panelRadius: CGFloat = 26
    static let inputRadius: CGFloat = 16
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
                    CatLocalTheme.warning.opacity(0.055)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

struct CatGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
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
    }

    nonisolated func catPanelSurface(
        cornerRadius: CGFloat = CatLocalTheme.panelRadius,
        fillOpacity: Double = 0.92,
        shadowOpacity: Double = 0.24
    ) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(
                CatLocalTheme.cardSurface.opacity(fillOpacity),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
            .shadow(color: CatLocalTheme.shadow.opacity(shadowOpacity), radius: 16, y: 8)
    }

    nonisolated func catInputSurface() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                CatLocalTheme.elevatedSurface.opacity(0.86),
                in: RoundedRectangle(cornerRadius: CatLocalTheme.inputRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CatLocalTheme.inputRadius, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
    }

    nonisolated func catPrimaryActionSurface(
        cornerRadius: CGFloat = 19,
        isDisabled: Bool = false
    ) -> some View {
        foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                CatLocalTheme.blueAction.opacity(isDisabled ? 0.58 : 1),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

private extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
