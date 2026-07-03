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
        light: UIColor(hex: 0x687169),
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
    static let warning = Color(
        light: UIColor(hex: 0xA64E2D),
        dark: UIColor(hex: 0xF29A6E)
    )
    static let sage = Color(
        light: UIColor(hex: 0xD9E1CF),
        dark: UIColor(hex: 0x1F2A22)
    )
    static let information = Color(
        light: UIColor(hex: 0x2A6F8F),
        dark: UIColor(hex: 0x7DCAE0)
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
        .buttonStyle(.plain)
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
                    .padding(22)
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
        VStack(alignment: .leading, spacing: 18) {
            deleteIcon

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.body)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionButtons
        }
    }

    private var deleteIcon: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(CatLocalTheme.background)
            .frame(width: 52, height: 52)
            .background(CatLocalTheme.warning, in: Circle())
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
                .font(.headline.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)
                .frame(maxWidth: .infinity)
                .catSingleActionPillSurface()
        }
        .buttonStyle(.plain)
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
                        .tint(CatLocalTheme.background)
                        .accessibilityHidden(true)
                }

                Text(isDeleting ? "Deleting" : deleteTitle)
                    .font(.headline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)
            }
            .foregroundStyle(CatLocalTheme.background)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, 12)
            .background(CatLocalTheme.warning.opacity(isDeleting ? 0.74 : 1), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .accessibilityLabel(isDeleting ? "Deleting" : deleteTitle)
    }

    private var presentationDetents: Set<PresentationDetent> {
        dynamicTypeSize.isAccessibilitySize ? [.medium, .large] : [.height(324)]
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
