import SwiftUI

enum CatLocalTheme {
    static let background = Color(
        light: UIColor(red: 0.957, green: 0.969, blue: 0.957, alpha: 1),
        dark: UIColor(red: 0.043, green: 0.047, blue: 0.063, alpha: 1)
    )
    static let backgroundGlow = Color(
        light: UIColor.white,
        dark: UIColor(red: 0.122, green: 0.157, blue: 0.200, alpha: 1)
    )
    static let elevatedSurface = Color(
        light: UIColor(red: 0.910, green: 0.937, blue: 0.914, alpha: 1),
        dark: UIColor(red: 0.122, green: 0.157, blue: 0.200, alpha: 1)
    )
    static let cardSurface = Color(
        light: UIColor.white,
        dark: UIColor(red: 0.122, green: 0.157, blue: 0.200, alpha: 1)
    )
    static let primaryText = Color(
        light: UIColor(red: 0.102, green: 0.184, blue: 0.145, alpha: 1),
        dark: UIColor.white
    )
    static let secondaryText = Color(
        light: UIColor(red: 0.439, green: 0.518, blue: 0.478, alpha: 1),
        dark: UIColor(red: 0.600, green: 0.651, blue: 0.710, alpha: 1)
    )
    static let separator = Color(
        light: UIColor(red: 0.102, green: 0.184, blue: 0.145, alpha: 0.08),
        dark: UIColor.white.withAlphaComponent(0.12)
    )
    static let imageOutline = Color(
        light: UIColor(red: 0.102, green: 0.184, blue: 0.145, alpha: 0.10),
        dark: UIColor.white.withAlphaComponent(0.12)
    )
    static let shadow = Color(
        light: UIColor(red: 0.102, green: 0.184, blue: 0.145, alpha: 0.12),
        dark: UIColor.black.withAlphaComponent(0.60)
    )
    static let blueAction = Color(
        light: UIColor(red: 0.173, green: 0.333, blue: 0.271, alpha: 1),
        dark: UIColor(red: 0.271, green: 0.635, blue: 0.620, alpha: 1)
    )
    static let warning = Color(
        light: UIColor(red: 0.898, green: 0.451, blue: 0.333, alpha: 1),
        dark: UIColor(red: 1.0, green: 0.533, blue: 0.400, alpha: 1)
    )
    static let sage = Color(
        light: UIColor(red: 0.855, green: 0.890, blue: 0.855, alpha: 1),
        dark: UIColor(red: 0.071, green: 0.090, blue: 0.110, alpha: 1)
    )
    static let information = Color(
        light: UIColor(hex: 0x2F6F5E),
        dark: UIColor(hex: 0x8EC8B5)
    )
    static let positive = Color(
        light: UIColor(hex: 0x2F7C4F),
        dark: UIColor(hex: 0x91D7A9)
    )
    static let neutralSymbol = secondaryText
    static let infoSymbol = information
    static let dangerSymbol = warning
    static let successSymbol = positive
    static let memoryPlaceFill = Color(
        light: UIColor(hex: 0xDCE7DB, alpha: 0.88),
        dark: UIColor(hex: 0x203329, alpha: 0.92)
    )
    static let memoryPlaceStroke = Color(
        light: UIColor(hex: 0x2F6F5E, alpha: 0.22),
        dark: UIColor(hex: 0x8EC8B5, alpha: 0.24)
    )

    static let limestone = background
    static let chalk = elevatedSurface
    static let forest = primaryText
    static let ink = primaryText
    static let apricot = warning
    static let cobalt = blueAction

    static let screenHorizontalPadding: CGFloat = 22
    static let largePanelRadius: CGFloat = 32
    static let panelRadius: CGFloat = 26
    static let inputRadius: CGFloat = 16

    static func accent(for style: CardStyle) -> Color {
        switch style {
        case .archive:
            sage
        case .sunstamp, .apricot, .gold, .topo:
            warning
        case .clear:
            blueAction
        case .garden:
            positive
        case .midnight, .prism:
            primaryText
        }
    }

    static func paperSurface(for style: CardStyle) -> Color {
        switch style {
        case .archive, .sunstamp, .clear:
            cardSurface
        case .apricot:
            elevatedSurface
        case .garden:
            memoryPlaceFill
        case .midnight, .topo:
            primaryText.opacity(0.92)
        case .prism:
            Color(red: 0.08, green: 0.09, blue: 0.12)
        case .gold:
            Color(red: 0.15, green: 0.11, blue: 0.07)
        }
    }
}

extension UIColor {
    var optimalTextColor: Color {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return CatLocalTheme.primaryText
        }

        let luminance = (red * 0.299) + (green * 0.587) + (blue * 0.114)
        return luminance > 0.5 ? CatLocalTheme.primaryText : .white
    }
}

extension Color {
    var optimalTextColor: Color {
        UIColor(self).optimalTextColor
    }
}

struct CatLocalBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            CatLocalTheme.background

            RadialGradient(
                colors: [
                    CatLocalTheme.backgroundGlow.opacity(colorScheme == .dark ? 0.72 : 0.54),
                    CatLocalTheme.background.opacity(0)
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 460
            )

            RadialGradient(
                colors: [
                    CatLocalTheme.warning.opacity(colorScheme == .dark ? 0.16 : 0.11),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    CatLocalTheme.blueAction.opacity(colorScheme == .dark ? 0.22 : 0.14),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 520
            )

            LinearGradient(
                colors: [
                    CatLocalTheme.sage.opacity(colorScheme == .dark ? 0.20 : 0.26),
                    .clear,
                    CatLocalTheme.elevatedSurface.opacity(colorScheme == .dark ? 0.18 : 0.30)
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
        foregroundStyle(
            Color(
                light: UIColor.white,
                dark: UIColor(hex: 0x121413)
            )
            .opacity(isDisabled ? 0.72 : 1)
        )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                LinearGradient(
                    colors: [
                        CatLocalTheme.primaryText.opacity(isDisabled ? 0.42 : 0.9),
                        CatLocalTheme.sage.opacity(isDisabled ? 0.32 : 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
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
