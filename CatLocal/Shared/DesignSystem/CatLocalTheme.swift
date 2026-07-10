import SwiftUI
import UIKit

enum CatLocalTheme {
    static let background = Color(
        light: UIColor(hex: 0xDCEAE5),
        dark: UIColor(hex: 0x061210)
    )
    static let backgroundGlow = Color(
        light: UIColor(hex: 0xF8FFFC),
        dark: UIColor(hex: 0x103B35)
    )
    static let elevatedSurface = Color(
        light: UIColor(hex: 0xCBDDD6),
        dark: UIColor(hex: 0x142C27)
    )
    static let cardSurface = Color(
        light: UIColor(hex: 0xFEFFFB),
        dark: UIColor(hex: 0x1C352F)
    )
    static let primaryText = Color(
        light: UIColor(hex: 0x12211E),
        dark: UIColor(hex: 0xF4FFF7)
    )
    static let secondaryText = Color(
        light: UIColor(hex: 0x3F5750),
        dark: UIColor(hex: 0xBCD1CA)
    )
    static let separator = Color(
        light: UIColor(hex: 0x12211E, alpha: 0.16),
        dark: UIColor(hex: 0xF4FFF7, alpha: 0.18)
    )
    static let imageOutline = Color(
        light: UIColor(hex: 0x12211E, alpha: 0.22),
        dark: UIColor(hex: 0xF4FFF7, alpha: 0.24)
    )
    static let shadow = Color(
        light: UIColor(hex: 0x12211E, alpha: 0.22),
        dark: UIColor.black.withAlphaComponent(0.78)
    )
    static let blueAction = Color(
        light: UIColor(hex: 0x005F68),
        dark: UIColor(hex: 0x84E0DC)
    )
    static let actionWash = Color(
        light: UIColor(hex: 0xD3EAEC),
        dark: UIColor(hex: 0x0D3D3C)
    )
    static let actionStroke = Color(
        light: UIColor(hex: 0x4FAAB0),
        dark: UIColor(hex: 0x91EAE6)
    )
    static let actionText = Color(
        light: UIColor(hex: 0x004E56),
        dark: UIColor(hex: 0xC6F6F3)
    )
    static let actionForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x021616)
    )
    static let warning = Color(
        light: UIColor(hex: 0x93440F),
        dark: UIColor(hex: 0xF2AF6D)
    )
    static let warningWash = Color(
        light: UIColor(hex: 0xF1DDCD),
        dark: UIColor(hex: 0x3B230F)
    )
    static let warningStroke = Color(
        light: UIColor(hex: 0xC9844C),
        dark: UIColor(hex: 0xFFC78B)
    )
    static let warningText = Color(
        light: UIColor(hex: 0x633006),
        dark: UIColor(hex: 0xFFE2C2)
    )
    static let warningForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x241002)
    )
    static let sage = Color(
        light: UIColor(hex: 0xBBD4CC),
        dark: UIColor(hex: 0x233C35)
    )
    static let information = Color(
        light: UIColor(hex: 0x3458A6),
        dark: UIColor(hex: 0xB7C8FF)
    )
    static let informationWash = Color(
        light: UIColor(hex: 0xDFE7FA),
        dark: UIColor(hex: 0x172241)
    )
    static let informationStroke = Color(
        light: UIColor(hex: 0x7F96D0),
        dark: UIColor(hex: 0xC2D0FF)
    )
    static let informationText = Color(
        light: UIColor(hex: 0x24498F),
        dark: UIColor(hex: 0xE0E8FF)
    )
    static let informationForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x07111F)
    )
    static let positive = Color(
        light: UIColor(hex: 0x236F45),
        dark: UIColor(hex: 0xA5E4B0)
    )
    static let positiveWash = Color(
        light: UIColor(hex: 0xD8EEE2),
        dark: UIColor(hex: 0x12301F)
    )
    static let positiveStroke = Color(
        light: UIColor(hex: 0x6EAE86),
        dark: UIColor(hex: 0xB7F0C0)
    )
    static let positiveText = Color(
        light: UIColor(hex: 0x184F31),
        dark: UIColor(hex: 0xD8F8DD)
    )
    static let positiveForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x071A0C)
    )
    static let destructive = Color(
        light: UIColor(hex: 0xA51C34),
        dark: UIColor(hex: 0xFFB2C0)
    )
    static let destructiveWash = Color(
        light: UIColor(hex: 0xF9E3E8),
        dark: UIColor(hex: 0x3D151E)
    )
    static let destructiveStroke = Color(
        light: UIColor(hex: 0xC96F82),
        dark: UIColor(hex: 0xFFB2C0)
    )
    static let destructiveText = Color(
        light: UIColor(hex: 0x781025),
        dark: UIColor(hex: 0xFFD9DF)
    )
    static let destructiveForeground = Color(
        light: UIColor.white,
        dark: UIColor(hex: 0x26070D)
    )
    static let neutralSymbol = secondaryText
    static let infoSymbol = information
    static let dangerSymbol = destructive
    static let successSymbol = positive
    static let memoryPlaceFill = Color(
        light: UIColor(hex: 0xCEE5D7, alpha: 0.94),
        dark: UIColor(hex: 0x1A3A29, alpha: 0.96)
    )
    static let memoryPlaceStroke = Color(
        light: UIColor(hex: 0x236F45, alpha: 0.34),
        dark: UIColor(hex: 0xA5E4B0, alpha: 0.34)
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
        case .clear, .topoLagoon, .cobaltHalo:
            blueAction
        case .garden, .topoMoss, .pineShadow, .cedarShade, .fernTrace, .mossVeil:
            positive
        case .midnight, .prism, .topoDusk, .auroraPool:
            primaryText
        case .apricotBeam:
            warning
        }
    }

    static func paperSurface(for style: CardStyle) -> Color {
        switch style {
        case .archive, .sunstamp, .clear:
            cardSurface
        case .apricot:
            elevatedSurface
        case .garden, .pineShadow, .cedarShade, .fernTrace, .mossVeil:
            memoryPlaceFill
        case .midnight, .topo, .topoEmber, .topoLagoon, .topoMoss, .topoDusk, .cobaltHalo, .auroraPool:
            primaryText.opacity(0.92)
        case .prism:
            Color(red: 0.08, green: 0.09, blue: 0.12)
        case .gold:
            Color(red: 0.15, green: 0.11, blue: 0.07)
        case .apricotBeam:
            warningWash
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
    let detail: String?
    let deleteTitle: String
    let isDeleting: Bool
    let onDelete: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String,
        detail: String? = nil,
        deleteTitle: String = "Delete",
        isDeleting: Bool = false,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.detail = detail
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
        VStack(alignment: .leading, spacing: 20) {
            sheetHeader
            consequenceSummary
            actionButtons
        }
    }

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            deleteIcon

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(CatTypography.momentTitle)
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(CatTypography.supporting)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var consequenceSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This cannot be undone.")
                .font(CatTypography.fieldLabel)
                .foregroundStyle(CatAttentionRole.destructive.text)

            if let detail {
                Text(detail)
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CatAttentionRole.destructive.wash.opacity(0.64), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CatAttentionRole.destructive.stroke.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var deleteIcon: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(CatAttentionRole.destructive.accent)
            .frame(width: 42, height: 42)
            .background(CatAttentionRole.destructive.wash.opacity(0.82), in: Circle())
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
        if dynamicTypeSize.isAccessibilitySize {
            return [.medium, .large]
        }

        return detail == nil ? [.height(300)] : [.height(348)]
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
                            .regular.tint(CatLocalTheme.cardSurface.opacity(0.16)).interactive(),
                            in: .rect(cornerRadius: cornerRadius)
                        )
                } else {
                    content
                        .glassEffect(
                            .regular.tint(CatLocalTheme.cardSurface.opacity(0.16)),
                            in: .rect(cornerRadius: cornerRadius)
                        )
                }
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        .overlay(shape.stroke(CatLocalTheme.imageOutline.opacity(0.72), lineWidth: 1))
        .shadow(color: CatLocalTheme.shadow.opacity(0.16), radius: 7, y: 3)
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
        fillOpacity: Double = 0.94,
        shadowOpacity: Double = 0.13
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return frame(maxWidth: .infinity, alignment: .leading)
            .background(
                CatLocalTheme.cardSurface.opacity(fillOpacity),
                in: shape
            )
            .overlay(
                shape.stroke(CatLocalTheme.imageOutline.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: CatLocalTheme.shadow.opacity(shadowOpacity), radius: 10, y: 4)
    }

    nonisolated func catInputSurface() -> some View {
        font(CatTypography.body)
            .foregroundStyle(CatLocalTheme.primaryText)
            .tint(CatAttentionRole.action.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                CatLocalTheme.cardSurface.opacity(0.98),
                in: RoundedRectangle(cornerRadius: CatLocalTheme.inputRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CatLocalTheme.inputRadius, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline.opacity(0.86), lineWidth: 1)
            )
            .shadow(color: CatLocalTheme.shadow.opacity(0.11), radius: 7, y: 2)
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
            .background(CatLocalTheme.cardSurface.opacity(isDisabled ? 0.56 : 0.94), in: shape)
            .overlay(
                shape.stroke(CatLocalTheme.imageOutline.opacity(isDisabled ? 0.44 : 0.76), lineWidth: 1)
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
