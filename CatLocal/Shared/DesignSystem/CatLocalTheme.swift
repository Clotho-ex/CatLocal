import SwiftUI
import UIKit

enum CatLocalTheme {
    static let background = Color(
        light: UIColor(hex: 0xF6F2E8),
        dark: UIColor(hex: 0x101412)
    )
    static let backgroundGlow = Color(
        light: UIColor(hex: 0xFFF8EA),
        dark: UIColor(hex: 0x24312A)
    )
    static let elevatedSurface = Color(
        light: UIColor(hex: 0xECE4D3),
        dark: UIColor(hex: 0x1B241E)
    )
    static let cardSurface = Color(
        light: UIColor(hex: 0xFFFDF7),
        dark: UIColor(hex: 0x202820)
    )
    static let primaryText = Color(
        light: UIColor(hex: 0x1C241F),
        dark: UIColor(hex: 0xF4F0E6)
    )
    static let secondaryText = Color(
        light: UIColor(hex: 0x5D665E),
        dark: UIColor(hex: 0xAEB7AD)
    )
    static let separator = Color(
        light: UIColor(hex: 0x1C241F, alpha: 0.10),
        dark: UIColor(hex: 0xF4F0E6, alpha: 0.13)
    )
    static let imageOutline = Color(
        light: UIColor(hex: 0x1C241F, alpha: 0.13),
        dark: UIColor(hex: 0xF4F0E6, alpha: 0.16)
    )
    static let shadow = Color(
        light: UIColor(hex: 0x1C241F, alpha: 0.16),
        dark: UIColor.black.withAlphaComponent(0.65)
    )
    static let blueAction = Color(
        light: UIColor(hex: 0x2457A6),
        dark: UIColor(hex: 0x82AFFF)
    )
    static let actionWash = Color(
        light: UIColor(hex: 0xE5EDFB),
        dark: UIColor(hex: 0x13243D)
    )
    static let actionStroke = Color(
        light: UIColor(hex: 0x7B99C9),
        dark: UIColor(hex: 0x98BCFF)
    )
    static let actionText = Color(
        light: UIColor(hex: 0x173F78),
        dark: UIColor(hex: 0xC8D9FF)
    )
    static let actionForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x08131D)
    )
    static let warning = Color(
        light: UIColor(hex: 0xA64E2D),
        dark: UIColor(hex: 0xF29A6E)
    )
    static let warningWash = Color(
        light: UIColor(hex: 0xF7E4D9),
        dark: UIColor(hex: 0x3A2118)
    )
    static let warningStroke = Color(
        light: UIColor(hex: 0xCE8A6F),
        dark: UIColor(hex: 0xF7B28D)
    )
    static let warningText = Color(
        light: UIColor(hex: 0x6D321D),
        dark: UIColor(hex: 0xFFD6C4)
    )
    static let warningForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x22110A)
    )
    static let sage = Color(
        light: UIColor(hex: 0xD9E1CF),
        dark: UIColor(hex: 0x1F2A22)
    )
    static let information = Color(
        light: UIColor(hex: 0x2A6F8F),
        dark: UIColor(hex: 0x7DCAE0)
    )
    static let informationWash = Color(
        light: UIColor(hex: 0xE2F1F6),
        dark: UIColor(hex: 0x12313A)
    )
    static let informationStroke = Color(
        light: UIColor(hex: 0x7CB4C6),
        dark: UIColor(hex: 0x9ADBEA)
    )
    static let informationText = Color(
        light: UIColor(hex: 0x175A75),
        dark: UIColor(hex: 0xB9EAF4)
    )
    static let informationForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x061821)
    )
    static let positive = Color(
        light: UIColor(hex: 0x2F7C4F),
        dark: UIColor(hex: 0x91D7A9)
    )
    static let positiveWash = Color(
        light: UIColor(hex: 0xE2F2E8),
        dark: UIColor(hex: 0x142A1D)
    )
    static let positiveStroke = Color(
        light: UIColor(hex: 0x7FB994),
        dark: UIColor(hex: 0xA9E6BB)
    )
    static let positiveText = Color(
        light: UIColor(hex: 0x1F5E39),
        dark: UIColor(hex: 0xC5F1D0)
    )
    static let positiveForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x07190F)
    )
    static let destructive = Color(
        light: UIColor(hex: 0xB3261E),
        dark: UIColor(hex: 0xFFB4AB)
    )
    static let destructiveWash = Color(
        light: UIColor(hex: 0xFCE8E6),
        dark: UIColor(hex: 0x3B1918)
    )
    static let destructiveStroke = Color(
        light: UIColor(hex: 0xD4877E),
        dark: UIColor(hex: 0xFFB4AB)
    )
    static let destructiveText = Color(
        light: UIColor(hex: 0x8C1D18),
        dark: UIColor(hex: 0xFFDAD6)
    )
    static let destructiveForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x230A08)
    )
    static let neutralSymbol = secondaryText
    static let infoSymbol = information
    static let dangerSymbol = destructive
    static let successSymbol = positive
    static let memoryPlaceFill = Color(
        light: UIColor(hex: 0xE1E8D6, alpha: 0.92),
        dark: UIColor(hex: 0x263424, alpha: 0.94)
    )
    static let memoryPlaceStroke = Color(
        light: UIColor(hex: 0x567A46, alpha: 0.30),
        dark: UIColor(hex: 0x91D7A9, alpha: 0.28)
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
        case .sunstamp, .apricot, .gold, .topo, .topoEmber:
            warning
        case .clear, .topoLagoon:
            blueAction
        case .garden, .topoMoss:
            positive
        case .midnight, .prism, .topoDusk:
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
        case .midnight, .topo, .topoEmber, .topoLagoon, .topoMoss, .topoDusk:
            primaryText.opacity(0.92)
        case .prism:
            Color(red: 0.08, green: 0.09, blue: 0.12)
        case .gold:
            Color(red: 0.15, green: 0.11, blue: 0.07)
        }
    }
}

enum CatAttentionRole: Equatable {
    case action
    case info
    case success
    case warning
    case destructive
    case neutral

    var accent: Color {
        switch self {
        case .action:
            CatLocalTheme.blueAction
        case .info:
            CatLocalTheme.information
        case .success:
            CatLocalTheme.positive
        case .warning:
            CatLocalTheme.warning
        case .destructive:
            CatLocalTheme.destructive
        case .neutral:
            CatLocalTheme.secondaryText
        }
    }

    var wash: Color {
        switch self {
        case .action:
            CatLocalTheme.actionWash
        case .info:
            CatLocalTheme.informationWash
        case .success:
            CatLocalTheme.positiveWash
        case .warning:
            CatLocalTheme.warningWash
        case .destructive:
            CatLocalTheme.destructiveWash
        case .neutral:
            CatLocalTheme.elevatedSurface
        }
    }

    var stroke: Color {
        switch self {
        case .action:
            CatLocalTheme.actionStroke
        case .info:
            CatLocalTheme.informationStroke
        case .success:
            CatLocalTheme.positiveStroke
        case .warning:
            CatLocalTheme.warningStroke
        case .destructive:
            CatLocalTheme.destructiveStroke
        case .neutral:
            CatLocalTheme.imageOutline
        }
    }

    var text: Color {
        switch self {
        case .action:
            CatLocalTheme.actionText
        case .info:
            CatLocalTheme.informationText
        case .success:
            CatLocalTheme.positiveText
        case .warning:
            CatLocalTheme.warningText
        case .destructive:
            CatLocalTheme.destructiveText
        case .neutral:
            CatLocalTheme.secondaryText
        }
    }

    var strongForeground: Color {
        switch self {
        case .action:
            CatLocalTheme.actionForeground
        case .info:
            CatLocalTheme.informationForeground
        case .success:
            CatLocalTheme.positiveForeground
        case .warning:
            CatLocalTheme.warningForeground
        case .destructive:
            CatLocalTheme.destructiveForeground
        case .neutral:
            CatLocalTheme.primaryText
        }
    }
}

enum CatTypography {
    static let screenTitle: Font = .largeTitle.weight(.semibold)
    static let screenSubtitle: Font = .callout
    static let pageTitle: Font = .title2.weight(.semibold)
    static let momentTitle: Font = .title3.weight(.semibold)
    static let panelTitle: Font = .headline.weight(.semibold)
    static let sectionTitle: Font = .headline.weight(.semibold)
    static let body: Font = .body
    static let bodyEmphasized: Font = .body.weight(.medium)
    static let supporting: Font = .subheadline
    static let supportingEmphasized: Font = .subheadline.weight(.semibold)
    static let metadata: Font = .footnote.weight(.medium)
    static let fieldLabel: Font = .footnote.weight(.semibold)
    static let control: Font = .headline.weight(.semibold)
    static let compactControl: Font = .subheadline.weight(.semibold)
    static let badge: Font = .caption.weight(.semibold)
    static let finePrint: Font = .caption2.weight(.medium)

    static func cardTitle(focused: Bool) -> Font {
        focused ? .title.weight(.semibold) : .headline.weight(.semibold)
    }

    static func cardDate(focused: Bool) -> Font {
        focused ? .footnote.weight(.medium) : .caption2.weight(.medium)
    }

    static func cardFooter(focused: Bool) -> Font {
        focused ? .body : .caption.weight(.medium)
    }

    static func cardPlace(focused: Bool) -> Font {
        focused ? .footnote.weight(.semibold) : .caption2.weight(.semibold)
    }

    static func sequence(focused: Bool) -> Font {
        .system(focused ? .callout : .caption, design: .rounded, weight: .semibold)
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

struct CatTactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.982 : 1)
            .brightness(configuration.isPressed ? -0.018 : 0)
            .animation(.smooth(duration: 0.14, extraBounce: 0), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CatTactileButtonStyle {
    static var catTactile: CatTactileButtonStyle { CatTactileButtonStyle() }
}

@MainActor
struct CatSheetActionButton: View {
    enum Mode: Equatable {
        case close
        case confirm
    }

    let mode: Mode
    let isLoading: Bool
    let action: () -> Void

    init(mode: Mode, isLoading: Bool = false, action: @escaping () -> Void) {
        self.mode = mode
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(mode.iconColor)
                    .frame(width: 30, height: 30)
                    .opacity(isLoading ? 0 : 1)
                    .contentTransition(.symbolEffect(.replace))

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(CatLocalTheme.blueAction)
                }
            }
            .catSingleActionIconSurface()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.catTactile)
        .contentShape(Circle())
        .disabled(isLoading)
        .accessibilityLabel(mode.accessibilityLabel)
        .animation(.snappy(duration: 0.18, extraBounce: 0), value: mode)
        .animation(.snappy(duration: 0.18, extraBounce: 0), value: isLoading)
    }
}

struct CatDeletionConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let message: String
    let deleteTitle: String
    let isDeleting: Bool
    let onDelete: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String,
        deleteTitle: String = "Delete",
        isDeleting: Bool = false,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.deleteTitle = deleteTitle
        self.isDeleting = isDeleting
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            CatLocalBackground()

            ScrollView {
                sheetContent
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents(presentationDetents)
        .presentationDragIndicator(.visible)
        .presentationBackground(CatLocalTheme.background)
        .interactiveDismissDisabled(isDeleting)
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                deleteIcon

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(CatTypography.panelTitle)
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(CatTypography.supporting)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            actionButtons
        }
    }

    private var deleteIcon: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(CatAttentionRole.destructive.strongForeground)
            .frame(width: 44, height: 44)
            .background(CatAttentionRole.destructive.accent, in: Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                cancelButton
                deleteButton
            }
        } else {
            HStack(spacing: 12) {
                cancelButton
                deleteButton
            }
        }
    }

    private var cancelButton: some View {
        Button {
            guard !isDeleting else { return }
            onCancel()
            dismiss()
        } label: {
            Text("Cancel")
                .font(CatTypography.control)
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)
                .frame(maxWidth: .infinity)
                .catSingleActionPillSurface()
        }
        .buttonStyle(.catTactile)
        .disabled(isDeleting)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            guard !isDeleting else { return }
            onDelete()
        } label: {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(CatAttentionRole.destructive.strongForeground)
                        .accessibilityHidden(true)
                }

                Text(isDeleting ? "Deleting" : deleteTitle)
                    .font(CatTypography.control)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)
            }
            .foregroundStyle(CatAttentionRole.destructive.strongForeground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, 12)
            .background(CatAttentionRole.destructive.accent.opacity(isDeleting ? 0.74 : 1), in: Capsule(style: .continuous))
        }
        .buttonStyle(.catTactile)
        .disabled(isDeleting)
        .accessibilityLabel(isDeleting ? "Deleting" : deleteTitle)
    }

    private var presentationDetents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.medium, .large] : [.height(232)]
    }
}

private extension CatSheetActionButton.Mode {
    var symbolName: String {
        switch self {
        case .close:
            "xmark"
        case .confirm:
            "checkmark"
        }
    }

    var iconColor: Color {
        switch self {
        case .close:
            CatLocalTheme.primaryText
        case .confirm:
            CatLocalTheme.cobalt
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .close:
            "Close"
        case .confirm:
            "Done"
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
                    .shadow(color: CatLocalTheme.shadow.opacity(0.22), radius: 8, y: 3)
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
        fillOpacity: Double = 0.86,
        shadowOpacity: Double = 0.10
    ) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(
                CatLocalTheme.cardSurface.opacity(fillOpacity),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .shadow(color: CatLocalTheme.shadow.opacity(shadowOpacity), radius: 12, y: 5)
    }

    nonisolated func catInputSurface() -> some View {
        font(CatTypography.body)
            .foregroundStyle(CatLocalTheme.primaryText)
            .tint(CatAttentionRole.action.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                CatLocalTheme.cardSurface.opacity(0.94),
                in: RoundedRectangle(cornerRadius: CatLocalTheme.inputRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CatLocalTheme.inputRadius, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
            .shadow(color: CatLocalTheme.shadow.opacity(0.08), radius: 8, y: 3)
    }

    nonisolated func catSingleActionIconSurface() -> some View {
        frame(width: 56, height: 56)
            .catGlass(cornerRadius: 28, interactive: true)
    }

    nonisolated func catSingleActionPillSurface() -> some View {
        lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 18)
            .frame(minHeight: 56)
            .catGlass(cornerRadius: 28, interactive: true)
            .contentShape(Capsule(style: .continuous))
    }

    nonisolated func catAttentionPillSurface(
        role: CatAttentionRole,
        cornerRadius: CGFloat = 18
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .foregroundStyle(role.text)
            .background(role.wash, in: shape)
            .contentShape(shape)
    }

    nonisolated func catStrongAttentionPillSurface(
        role: CatAttentionRole,
        cornerRadius: CGFloat = 18,
        minHeight: CGFloat = 38
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .foregroundStyle(role.strongForeground)
            .background(role.accent, in: shape)
            .contentShape(shape)
    }

    nonisolated func catAttentionIconSurface(
        role: CatAttentionRole,
        size: CGFloat = 34
    ) -> some View {
        frame(width: size, height: size)
            .background(role.wash.opacity(0.72), in: Circle())
    }

    nonisolated func catPrimaryActionSurface(
        role: CatAttentionRole = .action,
        cornerRadius: CGFloat = 19,
        isDisabled: Bool = false
    ) -> some View {
        foregroundStyle(
            isDisabled ? CatLocalTheme.secondaryText : role.strongForeground
        )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                LinearGradient(
                    colors: [
                        isDisabled ? CatLocalTheme.elevatedSurface : role.accent,
                        isDisabled ? CatLocalTheme.elevatedSurface.opacity(0.72) : role.accent.opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }

    nonisolated func catCommitActionSurface(
        role: CatAttentionRole = .action,
        cornerRadius: CGFloat = 24,
        minHeight: CGFloat = 64,
        isDisabled: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return foregroundStyle(isDisabled ? CatLocalTheme.secondaryText : CatLocalTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .background(
                LinearGradient(
                    colors: [
                        isDisabled ? CatLocalTheme.elevatedSurface.opacity(0.58) : role.wash.opacity(0.96),
                        isDisabled ? CatLocalTheme.elevatedSurface.opacity(0.44) : CatLocalTheme.cardSurface.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: shape
            )
            .overlay(
                shape.stroke(
                    isDisabled ? CatLocalTheme.imageOutline.opacity(0.32) : role.stroke.opacity(0.48),
                    lineWidth: 1
                )
            )
            .shadow(
                color: isDisabled ? .clear : role.accent.opacity(0.12),
                radius: 9,
                x: 0,
                y: 3
            )
            .contentShape(shape)
    }

    nonisolated func catSecondaryActionSurface(
        cornerRadius: CGFloat = 24,
        minHeight: CGFloat = 52,
        isDisabled: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return foregroundStyle(isDisabled ? CatLocalTheme.secondaryText : CatLocalTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .background(CatLocalTheme.cardSurface.opacity(isDisabled ? 0.48 : 0.84), in: shape)
            .overlay(
                shape.stroke(CatLocalTheme.imageOutline.opacity(isDisabled ? 0.36 : 0.58), lineWidth: 1)
            )
            .contentShape(shape)
    }

    nonisolated func catDestructiveActionSurface(
        cornerRadius: CGFloat = 18,
        minHeight: CGFloat = 48,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        fillsWidth: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fill = isDisabled
            ? CatLocalTheme.elevatedSurface.opacity(0.58)
            : (isProminent ? CatAttentionRole.destructive.accent : CatAttentionRole.destructive.wash.opacity(0.9))
        let foreground = isDisabled
            ? CatLocalTheme.secondaryText
            : (isProminent ? CatAttentionRole.destructive.strongForeground : CatAttentionRole.destructive.text)

        return foregroundStyle(foreground)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: minHeight)
            .background(fill, in: shape)
            .overlay(
                shape.stroke(
                    isProminent || isDisabled ? Color.clear : CatAttentionRole.destructive.stroke.opacity(0.55),
                    lineWidth: 1
                )
            )
            .contentShape(shape)
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
