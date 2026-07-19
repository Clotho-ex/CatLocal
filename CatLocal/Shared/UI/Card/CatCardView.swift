import SwiftUI
import UIKit

struct CatCardView: View {
    let record: CatRecord
    var presentation: CatCardPresentation = .thumbnail
    var cardStyle: CardStyle?
    var rotateX: CGFloat = 0
    var rotateY: CGFloat = 0
    var isLightActive: Bool = false
    var showsFooter: Bool = true
    var showsThumbnailPlaceFooter: Bool = true
    var showsSurfaceShadow: Bool = true

    private var usesCutoutImage: Bool {
        presentation == .focused || presentation == .stylePreview
    }
    private var resolvedCardStyle: CardStyle { cardStyle ?? record.cardStyle }

    var body: some View {
        CatCardSurface(
            sequence: record.sequence,
            name: record.displayName,
            date: record.capturedAt,
            note: record.note,
            placeName: record.memoryPlaceName,
            placeDetail: record.memoryPlaceDetail,
            cardStyle: resolvedCardStyle,
            presentation: presentation,
            rotateX: rotateX,
            rotateY: rotateY,
            isLightActive: isLightActive,
            showsFooter: showsFooter,
            showsThumbnailPlaceFooter: showsThumbnailPlaceFooter,
            showsSurfaceShadow: showsSurfaceShadow,
            catBoundingBox: record.catBoundingBox,
            patternSeed: CatCardPatternSeed.forSequence(record.sequence)
        ) {
            StoredImageView(path: imagePath, contentMode: .fit) {
                if presentation == .stylePreview {
                    Image(systemName: "cat.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(CardStylePalette(style: resolvedCardStyle).accent.opacity(0.48))
                } else {
                    ProgressView()
                        .tint(CatLocalTheme.primaryText)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(
            presentation == .focused
                ? "Drag the cat to shift its light".catLocalized
                : "Double tap to open focused cat view.".catLocalized
        )
    }

    private var imagePath: String {
        usesCutoutImage ? record.cutoutImagePath : record.thumbnailImagePath
    }

    private var accessibilityLabel: String {
        var parts = [
            CatLocalLocalization.format(
                "Cat, %1$@. Cat number %2$lld. Captured %3$@.",
                record.displayName,
                Int64(record.sequence),
                record.capturedAt.formatted(date: .abbreviated, time: .omitted)
            ),
        ]

        if presentation == .thumbnail, showsThumbnailPlaceFooter {
            parts.append(
                record.memoryPlaceLabel.map {
                    CatLocalLocalization.format("Memory Place, %1$@", $0)
                } ?? "No Memory Place yet.".catLocalized
            )
        } else if showsThumbnailPlaceFooter, let label = record.memoryPlaceLabel {
            parts.append(CatLocalLocalization.format("Memory Place, %1$@", label))
        }

        if !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Note saved.".catLocalized)
        }

        return parts.joined(separator: " ")
    }
}

struct DraftCatCardView: View {
    let image: UIImage
    let sequence: Int
    let name: String
    var date: Date = Date()
    let note: String
    let placeName: String
    let placeDetail: String
    var cardStyle: CardStyle = .archive
    var presentation: CatCardPresentation = .focused
    var rotateX: CGFloat = 0
    var rotateY: CGFloat = 0
    var isLightActive: Bool = false
    var showsFooter: Bool = true
    var showsThumbnailPlaceFooter: Bool = true
    var catBoundingBox: CGRect?
    var patternSeed: Int = 0
    var showsSurfaceShadow: Bool = true
    var appliesStickerEffect = false
    var stickerMotionIntensity: CGFloat?
    var catOpacity: Double = 1
    var outlineMask: CGImage?
    var imageStageCoordinateSpaceName: String?
    var onImageStageFrameChange: ((CGRect) -> Void)?

    var body: some View {
        CatCardSurface(
            sequence: sequence,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "New Cat"
                : name,
            date: date,
            note: note,
            placeName: trimmedPlaceName,
            placeDetail: trimmedPlaceDetail,
            cardStyle: cardStyle,
            presentation: presentation,
            rotateX: rotateX,
            rotateY: rotateY,
            isLightActive: isLightActive,
            showsFooter: showsFooter,
            showsThumbnailPlaceFooter: showsThumbnailPlaceFooter,
            showsSurfaceShadow: showsSurfaceShadow,
            catBoundingBox: catBoundingBox,
            patternSeed: patternSeed,
            catOpacity: catOpacity,
            imageStageCoordinateSpaceName: imageStageCoordinateSpaceName,
            onImageStageFrameChange: onImageStageFrameChange
        ) {
            draftCatImage
        }
    }

    @ViewBuilder
    private var draftCatImage: some View {
        if appliesStickerEffect, let outlineMask {
            ZStack {
                Image(decorative: outlineMask, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFit()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .compositingGroup()
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    private var trimmedPlaceName: String? {
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedPlaceDetail: String? {
        let trimmed = placeDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum CatCardPresentation {
    case thumbnail
    case focused
    case stylePreview
}

enum CatCardPatternSeed {
    static func forSequence(_ sequence: Int) -> Int {
        sequence
    }
}

enum CatCardLightEffectMath {
    static func progress(
        rotateX: CGFloat,
        rotateY: CGFloat,
        maxTiltAngle: CGFloat = 12,
        deadZone: CGFloat = 0.10
    ) -> CGFloat {
        guard maxTiltAngle > 0 else { return 0 }

        let normalizedTilt = min(max(max(abs(rotateX), abs(rotateY)) / maxTiltAngle, 0), 1)
        let clampedDeadZone = min(max(deadZone, 0), 0.99)
        guard normalizedTilt > clampedDeadZone else { return 0 }

        let value = (normalizedTilt - clampedDeadZone) / (1 - clampedDeadZone)
        return value * value * (3 - 2 * value)
    }
}

struct CatCardEffectPresentationPolicy {
    let showsStandardAura: Bool
    let showsStandardSheen: Bool
    let showsFamilyAura: Bool
    let showsLightBand: Bool
    let showsGenericGlint: Bool
    let illustrativeLightProgress: CGFloat

    init(style: CardStyle, presentation: CatCardPresentation) {
        let isLightStyle = style.isLightEffect
        let isLightThumbnail = isLightStyle && presentation == .thumbnail

        showsStandardAura = !isLightStyle
        showsStandardSheen = !isLightStyle
        showsFamilyAura = isLightStyle && !isLightThumbnail
        showsLightBand = isLightStyle && !isLightThumbnail
        showsGenericGlint = presentation == .thumbnail && !isLightStyle
        illustrativeLightProgress = isLightStyle && presentation == .stylePreview ? 0.55 : 0
    }
}

private struct CatCardSurface<CatImage: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let sequence: Int
    let name: String
    let date: Date
    let note: String
    let placeName: String?
    let placeDetail: String?
    let cardStyle: CardStyle
    let presentation: CatCardPresentation
    let rotateX: CGFloat
    let rotateY: CGFloat
    let isLightActive: Bool
    let showsFooter: Bool
    let showsThumbnailPlaceFooter: Bool
    let showsSurfaceShadow: Bool
    let catBoundingBox: CGRect?
    let patternSeed: Int
    var catOpacity: Double = 1
    var imageStageCoordinateSpaceName: String?
    var onImageStageFrameChange: ((CGRect) -> Void)?
    @ViewBuilder let catImage: () -> CatImage

    private var focused: Bool { presentation == .focused }
    private var thumbnail: Bool { presentation == .thumbnail }
    private var stylePreview: Bool { presentation == .stylePreview }
    private var effectiveRotateX: CGFloat { focused ? rotateX : 0 }
    private var effectiveRotateY: CGFloat { focused ? rotateY : 0 }
    private var foilLightOpacity: Double {
        if focused {
            return isLightActive ? 1 : 0
        }
        return thumbnail ? 0.14 : 1
    }
    private var premiumFoilOpacity: Double {
        if focused {
            return isLightActive ? 1 : 0.42
        }
        return thumbnail ? 0.16 : 0.92
    }
    private var palette: CardStylePalette { CardStylePalette(style: cardStyle) }
    private var effectPolicy: CatCardEffectPresentationPolicy {
        CatCardEffectPresentationPolicy(style: cardStyle, presentation: presentation)
    }

    private var primaryContentColor: Color {
        palette.primaryContent
    }

    private var secondaryContentColor: Color {
        palette.secondaryContent
    }

    private var metadataContentColor: Color {
        palette.metadataContent
    }

    private var separatorColor: Color {
        palette.separator
    }

    private var medallionFill: Color {
        palette.medallionFill
    }

    private var pillFill: Color {
        palette.pillFill
    }

    private var pillStroke: Color {
        palette.pillStroke
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width, 1)
            let cardHeight = max(proxy.size.height, 1)
            let cornerRadius: CGFloat = focused ? 34 : (stylePreview ? 24 : 22)
            let outerPadding: CGFloat = focused ? 16 : (stylePreview ? 12 : 11)
            let imageStageHeight = max(cardHeight * imageStageRatio, 1)
            let imageMaxWidth = max(cardWidth - outerPadding * 2, 1)
            let previewImageHeight = max(cardHeight - outerPadding * 2, 1)

            Group {
                if stylePreview {
                    ZStack {
                        imageStage

                        catImage()
                            .scaledToFit()
                            .opacity(catOpacity)
                            .frame(
                                maxWidth: imageMaxWidth,
                                maxHeight: previewImageHeight,
                                alignment: .center
                            )
                            .accessibilityHidden(true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: focused ? 12 : 9) {
                        header

                        ZStack {
                            imageStage

                            catImage()
                                .scaledToFit()
                                .opacity(catOpacity)
                                .frame(
                                    maxWidth: imageMaxWidth,
                                    maxHeight: imageStageHeight * 0.96,
                                    alignment: .center
                                )
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: imageStageHeight)
                        .overlay {
                            CatCardImageStageReporter(
                                coordinateSpaceName: imageStageCoordinateSpaceName,
                                onFrameChange: onImageStageFrameChange
                            )
                                .frame(
                                    maxWidth: imageMaxWidth,
                                    maxHeight: imageStageHeight * 0.96
                                )
                        }

                        if showsFooter {
                            footer
                        } else if focused {
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(outerPadding)
            .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
            .shadow(
                color: showsSurfaceShadow ? shadowColor : .clear,
                radius: shadowRadius,
                y: shadowOffset
            )
        }
        .aspectRatio(cardAspectRatio, contentMode: .fit)
    }

    private var cardAspectRatio: CGFloat {
        switch presentation {
        case .focused:
            0.64
        case .stylePreview:
            0.64
        case .thumbnail:
            0.72
        }
    }

    private var shadowColor: Color {
        CatLocalTheme.shadow.opacity(focused ? 0.72 : (thumbnail ? 0.16 : 0.36))
    }

    private var shadowRadius: CGFloat {
        focused ? 22 : (thumbnail ? 8 : 11)
    }

    private var shadowOffset: CGFloat {
        focused ? 14 : (thumbnail ? 4 : 6)
    }

    private var imageStageRatio: CGFloat {
        if stylePreview {
            return 1
        }

        if focused, !showsFooter {
            return dynamicTypeSize.isAccessibilitySize ? 0.66 : 0.62
        }

        if focused, showsFooter, hasFocusedTextContent {
            return dynamicTypeSize.isAccessibilitySize ? 0.32 : 0.42
        }

        return if dynamicTypeSize.isAccessibilitySize {
            focused ? 0.43 : 0.47
        } else {
            focused ? 0.49 : 0.54
        }
    }

    private var hasFocusedTextContent: Bool {
        hasNote || placeName != nil || placeDetail != nil
    }

    private var hasNote: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: focused ? 3 : 1) {
                Text(name)
                    .font(CatTypography.cardTitle(focused: focused))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.7)

                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(CatTypography.cardDate(focused: focused))
                    .foregroundStyle(metadataContentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 10)

            sequenceMedallion
        }
        .foregroundStyle(primaryContentColor)
    }

    @ViewBuilder
    private var footer: some View {
        if focused {
            VStack(alignment: .leading, spacing: 12) {
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 4) {
                    metadataHeading(title: "Notes", icon: "note.text")

                    Text(note.isEmpty ? "No note yet.".catLocalized : note)
                        .font(CatTypography.body)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                        .foregroundStyle(note.isEmpty ? secondaryContentColor : primaryContentColor)
                }

                if let placeName {
                    focusedPlaceDetails(placeName: placeName, placeDetail: placeDetail)
                }
            }
        } else {
            if showsThumbnailPlaceFooter {
                thumbnailMetadataFooter
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var sequenceMedallion: some View {
        Text(sequence.formatted())
            .font(CatTypography.sequence(focused: focused))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .foregroundStyle(primaryContentColor)
            .frame(width: focused ? 32 : 27, height: focused ? 32 : 27)
            .background(
                medallionFill,
                in: Circle()
            )
            .overlay(
                Circle()
                    .stroke(separatorColor.opacity(0.9), lineWidth: 1)
            )
            .shadow(
                color: CatLocalTheme.shadow.opacity(focused ? 0.14 : 0.08),
                radius: focused ? 5 : 3,
                y: focused ? 3 : 2
            )
            .accessibilityHidden(true)
    }

    private func focusedPlaceDetails(placeName: String, placeDetail: String?) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            placeDetailRow(
                title: "Memory Place",
                icon: "mappin.and.ellipse",
                value: placeName
            )

            if let placeDetail {
                placeDetailRow(
                    title: "Place Detail",
                    icon: "text.alignleft",
                    value: placeDetail
                )
            }
        }
    }

    private func placeDetailRow(title: String, icon: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataHeading(title: title, icon: icon)

            Text(value)
                .font(CatTypography.body)
                .foregroundStyle(primaryContentColor)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func metadataHeading(title: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .font(CatTypography.supportingEmphasized)
                .imageScale(.medium)
                .symbolRenderingMode(.monochrome)
                .frame(width: 20, height: 19, alignment: .center)
                .accessibilityHidden(true)

            Text(catLocalKey: title)
                .font(CatTypography.supportingEmphasized)
        }
        .foregroundStyle(metadataContentColor)
    }

    private var thumbnailMetadataFooter: some View {
        let isPlaced = placeName != nil
        let title = placeName ?? "Unplaced for now"
        let symbolName = isPlaced ? "mappin.and.ellipse" : "tray"

        return HStack(alignment: .center, spacing: 6) {
            Image(systemName: symbolName)
                .font(CatTypography.cardPlace(focused: false))
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(catLocalKey: title)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasNote {
                Image(systemName: "note.text")
                    .font(CatTypography.finePrint)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
        }
        .font(CatTypography.cardPlace(focused: false))
        .foregroundStyle(isPlaced ? primaryContentColor : secondaryContentColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(isPlaced ? pillFill : separatorColor.opacity(0.18))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isPlaced ? pillStroke : separatorColor.opacity(0.62), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(thumbnailMetadataAccessibilityLabel)
    }

    private var thumbnailMetadataAccessibilityLabel: String {
        var parts: [String] = []

        if let placeName {
            if let placeDetail {
                parts.append(
                    CatLocalLocalization.format("Memory Place, %1$@, %2$@", placeName, placeDetail)
                )
            } else {
                parts.append(CatLocalLocalization.format("Memory Place, %1$@", placeName))
            }
        } else {
            parts.append("No Memory Place yet.".catLocalized)
        }

        if hasNote {
            parts.append("Note saved.".catLocalized)
        }

        return parts.joined(separator: ". ")
    }

    private var imageStage: some View {
        RoundedRectangle(cornerRadius: focused ? 26 : (stylePreview ? 18 : 16), style: .continuous)
            .fill(palette.imageStageFill.opacity(focused ? 0.72 : (stylePreview ? 0.42 : 0.56)))
            .overlay(
                RoundedRectangle(cornerRadius: focused ? 26 : (stylePreview ? 18 : 16), style: .continuous)
                    .stroke(palette.imageStageStroke, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var surface: some View {
        if thumbnail {
            thumbnailSurface
        } else if cardStyle.isTopographic {
            topoSurface
        } else if cardStyle.isArchiveMaterial {
            archiveMaterialSurface
        } else if cardStyle.isLightEffect {
            lightEffectSurface
        } else {
            switch cardStyle {
            case .prism:
                prismSurface
            case .gold:
                goldSurface
            default:
                standardSurface
            }
        }
    }

    private var thumbnailSurface: some View {
        ZStack {
            standardSurface

            if effectPolicy.showsGenericGlint {
                thumbnailStyleHintSurface
            }
        }
    }

    private var standardSurface: some View {
        ZStack {
            baseSurface

            if effectPolicy.showsStandardAura {
                RadialGradient(
                    colors: [
                        palette.accent.opacity(focused ? 0.34 : (thumbnail ? 0.11 : 0.25)),
                        palette.secondaryAccent.opacity(focused ? 0.16 : (thumbnail ? 0.05 : 0.10)),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: focused ? 260 : (thumbnail ? 120 : 150)
                )
            }

            if effectPolicy.showsStandardSheen {
                LinearGradient(
                    colors: [
                        palette.sheen.opacity(focused ? 0.28 : (thumbnail ? 0.07 : 0.20)),
                        palette.secondaryAccent.opacity(focused ? 0.18 : (thumbnail ? 0.05 : 0.12))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var baseSurface: some View {
        LinearGradient(
            colors: palette.surfaceColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var thumbnailStyleHintSurface: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [
                    palette.accent.opacity(0.16),
                    palette.secondaryAccent.opacity(0.08),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 130
            )

            if cardStyle.isTopographic {
                topoThumbnailLayer
                    .opacity(0.48)
            }

            if cardStyle.isArchiveMaterial {
                archiveMaterialThumbnailLayer
                    .opacity(0.54)
            }

            if effectPolicy.showsGenericGlint {
                thumbnailStyleGlint
            }
        }
        .blendMode(.softLight)
        .accessibilityHidden(true)
    }

    private var thumbnailStyleGlint: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.sheen.opacity(0.48),
                        palette.accent.opacity(0.34),
                        palette.secondaryAccent.opacity(0.18)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 34, height: 5)
            .padding(.top, 12)
            .padding(.trailing, 12)
            .opacity(0.38)
    }

    private var prismSurface: some View {
        ZStack {
            LinearGradient(
                colors: palette.surfaceColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            AngularGradient(
                colors: prismColors,
                center: prismCenter,
                angle: .degrees(Double(effectiveRotateY - effectiveRotateX) * 2.4)
            )
            .opacity(0.74 * premiumFoilOpacity)
            .blendMode(.hardLight)
            .animation(.easeInOut(duration: 0.18), value: premiumFoilOpacity)

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.42),
                    Color.purple.opacity(0.16),
                    .clear
                ],
                center: foilHotspot,
                startRadius: 0,
                endRadius: 210
            )
            .opacity(0.72 * premiumFoilOpacity)
            .blendMode(.screen)
            .animation(.easeInOut(duration: 0.18), value: premiumFoilOpacity)
        }
    }

    private var goldSurface: some View {
        ZStack {
            LinearGradient(
                colors: palette.surfaceColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color(red: 0.34, green: 0.18, blue: 0.05).opacity(0.86),
                    Color(red: 1.0, green: 0.76, blue: 0.22),
                    Color(red: 1.0, green: 0.94, blue: 0.58),
                    Color(red: 0.74, green: 0.42, blue: 0.08),
                    Color(red: 0.24, green: 0.13, blue: 0.04).opacity(0.82)
                ],
                startPoint: goldStartPoint,
                endPoint: goldEndPoint
            )
            .opacity(0.82 * premiumFoilOpacity)
            .blendMode(.hardLight)
            .animation(.easeInOut(duration: 0.18), value: premiumFoilOpacity)

            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.50),
                    .clear
                ],
                center: foilHotspot,
                startRadius: 0,
                endRadius: 170
            )
            .opacity(0.46 * premiumFoilOpacity)
            .blendMode(.screen)
            .animation(.easeInOut(duration: 0.18), value: premiumFoilOpacity)
        }
    }

    private var archiveMaterialSurface: some View {
        ZStack {
            standardSurface
            archiveMaterialWash
            archiveMaterialPatternLayer
            archiveMaterialLightBand
        }
    }

    @ViewBuilder
    private var archiveMaterialWash: some View {
        switch cardStyle {
        case .pineShadow, .cedarShade, .fernTrace, .mossVeil:
            ZStack {
                RadialGradient(
                    colors: [
                        palette.accent.opacity(archiveMaterialAccentOpacity),
                        palette.secondaryAccent.opacity(0.18),
                        .clear
                    ],
                    center: archiveMaterialLightCenter,
                    startRadius: 10,
                    endRadius: 260
                )

                LinearGradient(
                    colors: [
                        .black.opacity(archiveMaterialShadowOpacity),
                        .clear,
                        palette.sheen.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .blendMode(.screen)
        default:
            EmptyView()
        }
    }

    private var archiveMaterialPatternLayer: some View {
        CardMaterialPatternShape(style: cardStyle, patternSeed: positiveSeed)
            .stroke(
                archiveMaterialPatternGradient,
                style: StrokeStyle(
                    lineWidth: focused ? 1.15 : 0.9,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .opacity(focused ? 0.76 : 0.64)
            .blendMode(archiveMaterialPatternBlendMode)
            .accessibilityHidden(true)
    }

    private var archiveMaterialThumbnailLayer: some View {
        CardMaterialPatternShape(style: cardStyle, patternSeed: positiveSeed)
            .stroke(
                LinearGradient(
                    colors: [
                        palette.primaryContent.opacity(0.36),
                        palette.sheen.opacity(0.38),
                        palette.accent.opacity(0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 0.68, lineCap: .round, lineJoin: .round)
            )
            .blendMode(archiveMaterialPatternBlendMode)
            .accessibilityHidden(true)
    }

    private var archiveMaterialLightBand: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        palette.sheen.opacity(focused ? 0.28 : 0.18),
                        palette.accent.opacity(focused ? 0.16 : 0.10),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: focused ? 92 : 68)
            .rotationEffect(.degrees(archiveMaterialLightAngle))
            .offset(x: effectiveRotateY * 0.9, y: -effectiveRotateX * 0.65)
            .opacity(focused ? 0.72 : 0.54)
            .blendMode(.screen)
            .accessibilityHidden(true)
    }

    private var lightEffectSurface: some View {
        ZStack {
            baseSurface

            if effectPolicy.showsFamilyAura {
                lightEffectAura
                    .opacity(lightEffectProgress)
                    .animation(.easeOut(duration: 0.20), value: lightEffectProgress)
            }

            if effectPolicy.showsLightBand {
                lightEffectBand
                    .opacity(lightEffectProgress)
                    .animation(.easeOut(duration: 0.20), value: lightEffectProgress)
            }
        }
    }

    @ViewBuilder
    private var lightEffectAura: some View {
        switch cardStyle {
        case .cobaltHalo:
            ZStack {
                RadialGradient(
                    colors: [
                        palette.accent.opacity(0.68),
                        palette.secondaryAccent.opacity(0.24),
                        .clear
                    ],
                    center: lightEffectCenter,
                    startRadius: 0,
                    endRadius: focused ? 260 : 180
                )
                .blendMode(.screen)

                AngularGradient(
                    colors: [
                        Color.cyan.opacity(0.60),
                        Color.blue.opacity(0.22),
                        .clear,
                        Color.mint.opacity(0.30),
                        Color.cyan.opacity(0.60)
                    ],
                    center: lightEffectCenter,
                    angle: .degrees(Double(effectiveRotateY - effectiveRotateX) * 1.7)
                )
                .opacity(focused ? 0.66 : 0.48)
                .blendMode(.plusLighter)
            }
        case .apricotBeam:
            ZStack {
                RadialGradient(
                    colors: [
                        palette.sheen.opacity(0.72),
                        palette.accent.opacity(0.26),
                        .clear
                    ],
                    center: lightEffectCenter,
                    startRadius: 0,
                    endRadius: focused ? 220 : 150
                )
                .blendMode(.screen)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.44),
                        palette.accent.opacity(0.30),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            }
        case .auroraPool:
            AngularGradient(
                colors: [
                    Color(red: 0.32, green: 0.88, blue: 0.72),
                    Color(red: 0.36, green: 0.46, blue: 1.0),
                    Color(red: 0.95, green: 0.36, blue: 0.78),
                    Color(red: 0.96, green: 0.78, blue: 0.36),
                    Color(red: 0.32, green: 0.88, blue: 0.72)
                ],
                center: lightEffectCenter,
                angle: .degrees(Double(effectiveRotateY - effectiveRotateX) * 2.2 + 24)
            )
            .opacity(focused ? 0.58 : 0.42)
            .blendMode(.hardLight)
        default:
            EmptyView()
        }
    }

    private var lightEffectBand: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        palette.sheen.opacity(focused ? 0.42 : 0.28),
                        palette.accent.opacity(focused ? 0.24 : 0.14),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: lightEffectBandWidth)
            .rotationEffect(.degrees(lightEffectBandAngle))
            .offset(x: effectiveRotateY * 1.05, y: -effectiveRotateX * 0.70)
            .opacity(focused ? 0.78 : 0.56)
            .blendMode(.screen)
            .accessibilityHidden(true)
    }

    private var topoSurface: some View {
        ZStack {
            LinearGradient(
                colors: palette.surfaceColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            topoStaticLayer

            topoFoilLayer
                .mask {
                    RadialGradient(
                        colors: [
                            .white,
                            .white.opacity(0.4),
                            .clear
                        ],
                        center: topoMaskCenter,
                        startRadius: 0,
                        endRadius: 180
                    )
                }
                .blendMode(.plusLighter)
                .opacity(foilLightOpacity)
                .animation(.easeInOut(duration: 0.18), value: foilLightOpacity)
        }
    }

    private var topoThumbnailLayer: some View {
        TopoContourLayer(
            patternSeed: positiveSeed + topoVariant * 97,
            lineCount: 8,
            lineWidth: 0.7,
            gradient: LinearGradient(
                colors: [
                    topoLineColors.first?.opacity(0.42) ?? Color.white.opacity(0.36),
                    palette.accent.opacity(0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .opacity(0.58)
        .blendMode(.softLight)
        .accessibilityHidden(true)
    }

    private var topoStaticLayer: some View {
        TopoContourLayer(
            patternSeed: positiveSeed + topoVariant * 97,
            lineCount: topoLineCount,
            lineWidth: max(topoLineWidth * 0.76, 0.72),
            gradient: LinearGradient(
                colors: [
                    topoLineColors.first?.opacity(0.48) ?? Color.white.opacity(0.42),
                    palette.accent.opacity(0.34),
                    palette.secondaryAccent.opacity(0.26)
                ],
                startPoint: topoStartPoint,
                endPoint: topoEndPoint
            )
        )
        .opacity(stylePreview ? 0.68 : 0.46)
        .blendMode(.softLight)
        .accessibilityHidden(true)
    }

    private var topoFoilLayer: some View {
        Rectangle()
            .fill(
                AngularGradient(
                    colors: topoColors,
                    center: topoMaskCenter,
                    angle: topoAngle
                )
            )
            .overlay {
                LinearGradient(
                    colors: Array(topoColors.reversed()),
                    startPoint: topoStartPoint,
                    endPoint: topoEndPoint
                )
                .blendMode(.overlay)
            }
            .overlay {
                AngularGradient(
                    colors: topoSecondaryColors,
                    center: .center,
                    angle: .degrees(Double(patternSeed % 180) + Double(effectiveRotateX - effectiveRotateY) * 2.6)
                )
                .scaleEffect(1.75)
                .blur(radius: presentation == .thumbnail ? 3 : 1.5)
                .blendMode(.hardLight)
                .opacity(0.64)
            }
            .overlay {
                TopoContourLayer(
                    patternSeed: positiveSeed + topoVariant * 97,
                    lineCount: topoLineCount,
                    lineWidth: topoLineWidth,
                    gradient: LinearGradient(
                        colors: topoLineColors,
                        startPoint: topoStartPoint,
                        endPoint: topoEndPoint
                    )
                )
                .opacity(presentation == .thumbnail ? 0.7 : 0.92)
                .blendMode(.plusLighter)
            }
    }

    private var prismColors: [Color] {
        [
            .cyan,
            Color(red: 1.0, green: 0.0, blue: 0.82),
            .yellow,
            .blue,
            .purple,
            .cyan
        ]
    }

    private var prismCenter: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.5 + effectiveRotateY / 32),
            y: clampedUnit(0.5 - effectiveRotateX / 32)
        )
    }

    private var goldStartPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.08 + effectiveRotateY / 28),
            y: clampedUnit(0.12 + effectiveRotateX / 34)
        )
    }

    private var goldEndPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.92 + effectiveRotateY / 28),
            y: clampedUnit(0.88 + effectiveRotateX / 34)
        )
    }

    private var foilHotspot: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.5 + effectiveRotateY / 30),
            y: clampedUnit(0.5 - effectiveRotateX / 30)
        )
    }

    private var archiveMaterialStartPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.12 + CGFloat(cardStyle.archiveMaterialVariantIndex) * 0.06 + effectiveRotateY / 38),
            y: clampedUnit(0.08 + effectiveRotateX / 44)
        )
    }

    private var archiveMaterialEndPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.92 - CGFloat(cardStyle.archiveMaterialVariantIndex) * 0.04 + effectiveRotateY / 38),
            y: clampedUnit(0.88 + effectiveRotateX / 44)
        )
    }

    private var archiveMaterialLightCenter: UnitPoint {
        switch cardStyle {
        case .cedarShade:
            UnitPoint(
                x: clampedUnit(0.72 + effectiveRotateY / 38),
                y: clampedUnit(0.26 - effectiveRotateX / 38)
            )
        case .fernTrace:
            UnitPoint(
                x: clampedUnit(0.34 + effectiveRotateY / 38),
                y: clampedUnit(0.30 - effectiveRotateX / 38)
            )
        case .mossVeil:
            UnitPoint(
                x: clampedUnit(0.54 + effectiveRotateY / 38),
                y: clampedUnit(0.60 - effectiveRotateX / 38)
            )
        default:
            UnitPoint(
                x: clampedUnit(0.62 + effectiveRotateY / 38),
                y: clampedUnit(0.34 - effectiveRotateX / 38)
            )
        }
    }

    private var archiveMaterialLightAngle: Double {
        switch cardStyle {
        case .pineShadow:
            -42
        case .cedarShade:
            -28
        case .fernTrace:
            32
        case .mossVeil:
            -8
        default:
            -18
        }
    }

    private var archiveMaterialAccentOpacity: Double {
        switch cardStyle {
        case .cedarShade:
            0.34
        case .fernTrace:
            0.26
        case .mossVeil:
            0.38
        default:
            0.30
        }
    }

    private var archiveMaterialShadowOpacity: Double {
        switch cardStyle {
        case .fernTrace:
            0.24
        case .mossVeil:
            0.28
        default:
            0.34
        }
    }

    private var archiveMaterialPatternGradient: LinearGradient {
        LinearGradient(
            colors: [
                palette.primaryContent.opacity(0.42),
                palette.sheen.opacity(0.62),
                palette.accent.opacity(0.46)
            ],
            startPoint: archiveMaterialStartPoint,
            endPoint: archiveMaterialEndPoint
        )
    }

    private var archiveMaterialPatternBlendMode: BlendMode {
        switch cardStyle {
        case .pineShadow, .cedarShade, .fernTrace, .mossVeil:
            .screen
        default:
            .softLight
        }
    }

    private var lightEffectCenter: UnitPoint {
        switch cardStyle {
        case .cobaltHalo:
            UnitPoint(
                x: clampedUnit(0.66 + effectiveRotateY / 34),
                y: clampedUnit(0.30 - effectiveRotateX / 34)
            )
        case .apricotBeam:
            UnitPoint(
                x: clampedUnit(0.26 + effectiveRotateY / 36),
                y: clampedUnit(0.22 - effectiveRotateX / 36)
            )
        case .auroraPool:
            UnitPoint(
                x: clampedUnit(0.48 + effectiveRotateY / 32),
                y: clampedUnit(0.52 - effectiveRotateX / 32)
            )
        default:
            .center
        }
    }

    private var lightEffectBandAngle: Double {
        switch cardStyle {
        case .cobaltHalo:
            -16
        case .apricotBeam:
            24
        case .auroraPool:
            -34
        default:
            -18
        }
    }

    private var lightEffectBandWidth: CGFloat {
        switch cardStyle {
        case .apricotBeam:
            focused ? 114 : 82
        case .auroraPool:
            focused ? 92 : 70
        default:
            focused ? 78 : 60
        }
    }

    private var lightEffectProgress: CGFloat {
        switch presentation {
        case .thumbnail:
            0
        case .stylePreview:
            effectPolicy.illustrativeLightProgress
        case .focused:
            isLightActive
                ? CatCardLightEffectMath.progress(rotateX: effectiveRotateX, rotateY: effectiveRotateY)
                : 0
        }
    }

    private var topoMaskCenter: UnitPoint {
        let base = topoBaseCenter
        return UnitPoint(
            x: clampedUnit(base.x + effectiveRotateY / 24),
            y: clampedUnit(base.y + (-effectiveRotateX / 24))
        )
    }

    private var topoColors: [Color] {
        let palettes = topoPalettes
        let palette = palettes[positiveSeed % palettes.count]
        let rotation = positiveSeed % palette.count
        return Array(palette[rotation...]) + Array(palette[..<rotation]) + [palette[rotation]]
    }

    private var topoSecondaryColors: [Color] {
        [
            Color.white.opacity(0.78),
            topoColors[positiveSeed % max(topoColors.count, 1)].opacity(0.42),
            .clear,
            Color.white.opacity(0.55)
        ]
    }

    private var topoLineColors: [Color] {
        [
            .white.opacity(0.92),
            topoColors[(positiveSeed + 1) % max(topoColors.count, 1)].opacity(0.88),
            .white.opacity(0.72)
        ]
    }

    private var topoAngle: Angle {
        .degrees(Double((positiveSeed + topoVariant * 41) % 360) + Double(effectiveRotateY - effectiveRotateX) * topoTiltResponse)
    }

    private var topoStartPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(topoStartBase.x + CGFloat((positiveSeed % 17)) / 72 + effectiveRotateY / 36),
            y: clampedUnit(topoStartBase.y + effectiveRotateX / 42)
        )
    }

    private var topoEndPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(topoEndBase.x - CGFloat((positiveSeed % 13)) / 82 + effectiveRotateY / 36),
            y: clampedUnit(topoEndBase.y + effectiveRotateX / 42)
        )
    }

    private var topoVariant: Int {
        cardStyle.topographicVariantIndex
    }

    private var topoLineCount: Int {
        let base = presentation == .thumbnail ? 9 : 15
        return base + min(topoVariant, 4) * (presentation == .thumbnail ? 1 : 2)
    }

    private var topoLineWidth: CGFloat {
        let base: CGFloat = presentation == .thumbnail ? 0.8 : 1.12
        return base + CGFloat(topoVariant % 3) * 0.08
    }

    private var topoTiltResponse: Double {
        2.7 + Double(topoVariant) * 0.18
    }

    private var topoBaseCenter: UnitPoint {
        switch cardStyle {
        case .topoEmber:
            UnitPoint(x: 0.66, y: 0.36)
        case .topoLagoon:
            UnitPoint(x: 0.36, y: 0.42)
        case .topoMoss:
            UnitPoint(x: 0.58, y: 0.64)
        case .topoDusk:
            UnitPoint(x: 0.44, y: 0.30)
        default:
            UnitPoint(x: 0.5, y: 0.5)
        }
    }

    private var topoStartBase: UnitPoint {
        switch cardStyle {
        case .topoEmber:
            UnitPoint(x: 0.04, y: 0.18)
        case .topoLagoon:
            UnitPoint(x: 0.20, y: 0.04)
        case .topoMoss:
            UnitPoint(x: 0.10, y: 0.46)
        case .topoDusk:
            UnitPoint(x: 0.24, y: 0.10)
        default:
            UnitPoint(x: 0.12, y: 0.10)
        }
    }

    private var topoEndBase: UnitPoint {
        switch cardStyle {
        case .topoEmber:
            UnitPoint(x: 0.96, y: 0.82)
        case .topoLagoon:
            UnitPoint(x: 0.82, y: 0.96)
        case .topoMoss:
            UnitPoint(x: 0.88, y: 0.72)
        case .topoDusk:
            UnitPoint(x: 0.92, y: 0.90)
        default:
            UnitPoint(x: 0.88, y: 0.92)
        }
    }

    private var topoPalettes: [[Color]] {
        switch cardStyle {
        case .topoEmber:
            [
                [.orange, .yellow, Color(red: 1.0, green: 0.35, blue: 0.24), .pink],
                [Color(red: 1.0, green: 0.84, blue: 0.32), .orange, Color(red: 0.96, green: 0.18, blue: 0.18), .mint],
                [Color(red: 0.92, green: 0.24, blue: 0.14), Color(red: 1.0, green: 0.72, blue: 0.20), .teal, .pink]
            ]
        case .topoLagoon:
            [
                [.cyan, .mint, Color(red: 0.16, green: 0.54, blue: 1.0), .yellow],
                [Color(red: 0.28, green: 0.90, blue: 0.78), .blue, .cyan, Color(red: 0.92, green: 1.0, blue: 0.60)],
                [.teal, Color(red: 0.36, green: 0.66, blue: 1.0), .mint, .white]
            ]
        case .topoMoss:
            [
                [.green, Color(red: 0.86, green: 0.92, blue: 0.34), .mint, .orange],
                [Color(red: 0.44, green: 0.76, blue: 0.28), Color(red: 1.0, green: 0.78, blue: 0.24), .teal, Color(red: 0.82, green: 1.0, blue: 0.58)],
                [Color(red: 0.22, green: 0.58, blue: 0.30), .yellow, .mint, Color(red: 0.92, green: 0.58, blue: 0.24)]
            ]
        case .topoDusk:
            [
                [Color(red: 0.64, green: 0.52, blue: 1.0), .cyan, Color(red: 1.0, green: 0.42, blue: 0.70), .yellow],
                [.blue, Color(red: 0.86, green: 0.44, blue: 1.0), .mint, Color(red: 1.0, green: 0.72, blue: 0.36)],
                [Color(red: 0.42, green: 0.36, blue: 1.0), .pink, .cyan, .white]
            ]
        default:
            [
                [.red, .yellow, .green, .pink],
                [.cyan, .yellow, .mint, .orange],
                [.pink, .green, .yellow, .blue],
                [.orange, .teal, .yellow, .red]
            ]
        }
    }

    private var positiveSeed: Int {
        abs(patternSeed == Int.min ? 0 : patternSeed)
    }

    private func clampedUnit(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

private struct CatCardImageStageReporter: View {
    let coordinateSpaceName: String?
    let onFrameChange: ((CGRect) -> Void)?

    var body: some View {
        Color.clear
            .onGeometryChange(for: CGRect.self) { geometry in
                guard let coordinateSpaceName else { return .zero }
                return geometry.frame(in: .named(coordinateSpaceName))
            } action: { frame in
                guard frame.width > 0, frame.height > 0 else { return }
                onFrameChange?(frame)
            }
    }
}

private struct CardStylePalette {
    let surfaceColors: [Color]
    let accent: Color
    let secondaryAccent: Color
    let sheen: Color
    let primaryContent: Color
    let secondaryContent: Color
    let metadataContent: Color
    let separator: Color
    let medallionFill: Color
    let pillFill: Color
    let pillStroke: Color
    let imageStageFill: Color
    let imageStageStroke: Color

    init(style: CardStyle) {
        switch style {
        case .archive:
            surfaceColors = [
                Color(red: 0.96, green: 0.90, blue: 0.78),
                Color(red: 0.86, green: 0.76, blue: 0.58),
                Color(red: 0.98, green: 0.94, blue: 0.84)
            ]
            accent = Color(red: 0.55, green: 0.34, blue: 0.17)
            secondaryAccent = Color(red: 0.36, green: 0.24, blue: 0.13)
            sheen = Color(red: 1.0, green: 0.96, blue: 0.86)
            primaryContent = Color(red: 0.24, green: 0.16, blue: 0.08)
        case .sunstamp:
            surfaceColors = [
                Color(red: 1.0, green: 0.94, blue: 0.62),
                Color(red: 1.0, green: 0.77, blue: 0.25),
                Color(red: 1.0, green: 0.96, blue: 0.78)
            ]
            accent = Color(red: 1.0, green: 0.63, blue: 0.10)
            secondaryAccent = Color(red: 0.96, green: 0.32, blue: 0.18)
            sheen = Color(red: 1.0, green: 0.98, blue: 0.78)
            primaryContent = Color(red: 0.34, green: 0.19, blue: 0.03)
        case .clear:
            surfaceColors = [
                Color(red: 0.98, green: 1.0, blue: 1.0),
                Color(red: 0.80, green: 0.95, blue: 1.0),
                Color(red: 0.93, green: 0.99, blue: 1.0)
            ]
            accent = Color(red: 0.18, green: 0.68, blue: 0.92)
            secondaryAccent = Color(red: 0.52, green: 0.88, blue: 1.0)
            sheen = Color.white
            primaryContent = Color(red: 0.05, green: 0.23, blue: 0.34)
        case .garden:
            surfaceColors = [
                Color(red: 0.61, green: 0.78, blue: 0.49),
                Color(red: 0.23, green: 0.47, blue: 0.27),
                Color(red: 0.80, green: 0.89, blue: 0.65)
            ]
            accent = Color(red: 0.94, green: 0.82, blue: 0.30)
            secondaryAccent = Color(red: 0.14, green: 0.34, blue: 0.19)
            sheen = Color(red: 0.90, green: 1.0, blue: 0.70)
            primaryContent = Color(red: 0.06, green: 0.20, blue: 0.11)
        case .midnight:
            surfaceColors = [
                Color(red: 0.05, green: 0.09, blue: 0.20),
                Color(red: 0.02, green: 0.04, blue: 0.12),
                Color(red: 0.08, green: 0.18, blue: 0.36)
            ]
            accent = Color(red: 0.24, green: 0.54, blue: 1.0)
            secondaryAccent = Color(red: 0.48, green: 0.76, blue: 1.0)
            sheen = Color(red: 0.72, green: 0.88, blue: 1.0)
            primaryContent = .white
        case .apricot:
            surfaceColors = [
                Color(red: 1.0, green: 0.72, blue: 0.52),
                Color(red: 0.96, green: 0.42, blue: 0.31),
                Color(red: 1.0, green: 0.86, blue: 0.68)
            ]
            accent = Color(red: 0.88, green: 0.28, blue: 0.18)
            secondaryAccent = Color(red: 1.0, green: 0.58, blue: 0.40)
            sheen = Color(red: 1.0, green: 0.92, blue: 0.78)
            primaryContent = Color(red: 0.35, green: 0.12, blue: 0.07)
        case .prism:
            surfaceColors = [
                Color(red: 0.05, green: 0.04, blue: 0.18),
                Color(red: 0.10, green: 0.08, blue: 0.30),
                Color(red: 0.02, green: 0.03, blue: 0.12)
            ]
            accent = Color(red: 0.40, green: 0.95, blue: 1.0)
            secondaryAccent = Color(red: 1.0, green: 0.16, blue: 0.84)
            sheen = Color(red: 0.70, green: 0.82, blue: 1.0)
            primaryContent = .white
        case .gold:
            surfaceColors = [
                Color(red: 0.24, green: 0.13, blue: 0.04),
                Color(red: 0.55, green: 0.34, blue: 0.08),
                Color(red: 0.16, green: 0.08, blue: 0.03)
            ]
            accent = Color(red: 1.0, green: 0.77, blue: 0.23)
            secondaryAccent = Color(red: 0.77, green: 0.45, blue: 0.10)
            sheen = Color(red: 1.0, green: 0.94, blue: 0.60)
            primaryContent = .white
        case .topo:
            surfaceColors = [
                Color(red: 0.05, green: 0.07, blue: 0.12),
                Color(red: 0.08, green: 0.13, blue: 0.17),
                Color(red: 0.03, green: 0.05, blue: 0.08)
            ]
            accent = Color(red: 0.98, green: 0.64, blue: 0.16)
            secondaryAccent = Color(red: 0.28, green: 0.82, blue: 0.76)
            sheen = Color(red: 1.0, green: 0.84, blue: 0.36)
            primaryContent = .white
        case .topoEmber:
            surfaceColors = [
                Color(red: 0.16, green: 0.06, blue: 0.04),
                Color(red: 0.45, green: 0.13, blue: 0.08),
                Color(red: 0.09, green: 0.04, blue: 0.03)
            ]
            accent = Color(red: 1.0, green: 0.55, blue: 0.18)
            secondaryAccent = Color(red: 0.98, green: 0.22, blue: 0.24)
            sheen = Color(red: 1.0, green: 0.84, blue: 0.42)
            primaryContent = .white
        case .topoLagoon:
            surfaceColors = [
                Color(red: 0.02, green: 0.10, blue: 0.15),
                Color(red: 0.03, green: 0.24, blue: 0.29),
                Color(red: 0.01, green: 0.06, blue: 0.11)
            ]
            accent = Color(red: 0.24, green: 0.88, blue: 0.86)
            secondaryAccent = Color(red: 0.25, green: 0.52, blue: 1.0)
            sheen = Color(red: 0.78, green: 1.0, blue: 0.86)
            primaryContent = .white
        case .topoMoss:
            surfaceColors = [
                Color(red: 0.05, green: 0.13, blue: 0.08),
                Color(red: 0.16, green: 0.30, blue: 0.15),
                Color(red: 0.03, green: 0.08, blue: 0.05)
            ]
            accent = Color(red: 0.78, green: 0.92, blue: 0.30)
            secondaryAccent = Color(red: 0.34, green: 0.72, blue: 0.40)
            sheen = Color(red: 0.92, green: 1.0, blue: 0.62)
            primaryContent = .white
        case .topoDusk:
            surfaceColors = [
                Color(red: 0.04, green: 0.04, blue: 0.15),
                Color(red: 0.15, green: 0.08, blue: 0.24),
                Color(red: 0.03, green: 0.02, blue: 0.09)
            ]
            accent = Color(red: 0.70, green: 0.58, blue: 1.0)
            secondaryAccent = Color(red: 1.0, green: 0.38, blue: 0.66)
            sheen = Color(red: 0.70, green: 0.92, blue: 1.0)
            primaryContent = .white
        case .pineShadow:
            surfaceColors = [
                Color(red: 0.04, green: 0.13, blue: 0.10),
                Color(red: 0.13, green: 0.30, blue: 0.22),
                Color(red: 0.03, green: 0.09, blue: 0.07)
            ]
            accent = Color(red: 0.64, green: 0.82, blue: 0.35)
            secondaryAccent = Color(red: 0.26, green: 0.62, blue: 0.46)
            sheen = Color(red: 0.78, green: 0.96, blue: 0.62)
            primaryContent = .white
        case .cedarShade:
            surfaceColors = [
                Color(red: 0.05, green: 0.11, blue: 0.08),
                Color(red: 0.18, green: 0.25, blue: 0.14),
                Color(red: 0.07, green: 0.07, blue: 0.05)
            ]
            accent = Color(red: 0.72, green: 0.78, blue: 0.40)
            secondaryAccent = Color(red: 0.32, green: 0.58, blue: 0.36)
            sheen = Color(red: 0.86, green: 0.94, blue: 0.62)
            primaryContent = .white
        case .fernTrace:
            surfaceColors = [
                Color(red: 0.02, green: 0.12, blue: 0.12),
                Color(red: 0.06, green: 0.28, blue: 0.22),
                Color(red: 0.02, green: 0.08, blue: 0.08)
            ]
            accent = Color(red: 0.36, green: 0.86, blue: 0.62)
            secondaryAccent = Color(red: 0.22, green: 0.62, blue: 0.76)
            sheen = Color(red: 0.70, green: 1.0, blue: 0.78)
            primaryContent = .white
        case .mossVeil:
            surfaceColors = [
                Color(red: 0.08, green: 0.13, blue: 0.07),
                Color(red: 0.24, green: 0.32, blue: 0.18),
                Color(red: 0.05, green: 0.08, blue: 0.04)
            ]
            accent = Color(red: 0.84, green: 0.86, blue: 0.46)
            secondaryAccent = Color(red: 0.52, green: 0.68, blue: 0.38)
            sheen = Color(red: 0.96, green: 1.0, blue: 0.70)
            primaryContent = .white
        case .cobaltHalo:
            surfaceColors = [
                Color(red: 0.02, green: 0.06, blue: 0.14),
                Color(red: 0.03, green: 0.18, blue: 0.28),
                Color(red: 0.01, green: 0.03, blue: 0.09)
            ]
            accent = Color(red: 0.22, green: 0.80, blue: 1.0)
            secondaryAccent = Color(red: 0.36, green: 0.50, blue: 1.0)
            sheen = Color(red: 0.70, green: 0.94, blue: 1.0)
            primaryContent = .white
        case .apricotBeam:
            surfaceColors = [
                Color(red: 0.95, green: 0.64, blue: 0.38),
                Color(red: 0.56, green: 0.22, blue: 0.16),
                Color(red: 1.0, green: 0.83, blue: 0.56)
            ]
            accent = Color(red: 1.0, green: 0.54, blue: 0.22)
            secondaryAccent = Color(red: 0.90, green: 0.24, blue: 0.20)
            sheen = Color(red: 1.0, green: 0.92, blue: 0.68)
            primaryContent = Color(red: 0.25, green: 0.08, blue: 0.05)
        case .auroraPool:
            surfaceColors = [
                Color(red: 0.04, green: 0.05, blue: 0.14),
                Color(red: 0.04, green: 0.16, blue: 0.18),
                Color(red: 0.10, green: 0.06, blue: 0.22)
            ]
            accent = Color(red: 0.30, green: 0.88, blue: 0.74)
            secondaryAccent = Color(red: 0.86, green: 0.34, blue: 0.86)
            sheen = Color(red: 0.68, green: 0.92, blue: 1.0)
            primaryContent = .white
        }

        secondaryContent = primaryContent.opacity(0.82)
        metadataContent = primaryContent.opacity(0.88)
        separator = primaryContent.opacity(0.24)
        medallionFill = primaryContent.opacity(0.14)
        pillFill = primaryContent.opacity(0.13)
        pillStroke = primaryContent.opacity(0.24)
        imageStageFill = sheen.opacity(0.42)
        imageStageStroke = primaryContent.opacity(0.14)
    }
}

private struct CardMaterialPatternShape: Shape {
    let style: CardStyle
    let patternSeed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for command in CatCardBotanicalPattern.commands(style: style, patternSeed: patternSeed) {
            switch command {
            case let .move(point):
                path.move(to: scaled(point, in: rect))
            case let .line(point):
                path.addLine(to: scaled(point, in: rect))
            case let .quad(end, control):
                path.addQuadCurve(to: scaled(end, in: rect), control: scaled(control, in: rect))
            case let .curve(end, control1, control2):
                path.addCurve(
                    to: scaled(end, in: rect),
                    control1: scaled(control1, in: rect),
                    control2: scaled(control2, in: rect)
                )
            case .close:
                path.closeSubpath()
            }
        }

        return path
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}

enum CatCardBotanicalCommand {
    case move(CGPoint)
    case line(CGPoint)
    case quad(end: CGPoint, control: CGPoint)
    case curve(end: CGPoint, control1: CGPoint, control2: CGPoint)
    case close

    var points: [CGPoint] {
        switch self {
        case let .move(point), let .line(point):
            [point]
        case let .quad(end, control):
            [end, control]
        case let .curve(end, control1, control2):
            [end, control1, control2]
        case .close:
            []
        }
    }
}

enum CatCardBotanicalPattern {
    static func signature(style: CardStyle, patternSeed: Int) -> [Int] {
        commands(style: style, patternSeed: patternSeed).flatMap { command in
            let marker: Int
            switch command {
            case .move: marker = 1
            case .line: marker = 2
            case .quad: marker = 3
            case .curve: marker = 4
            case .close: marker = 5
            }

            return [marker] + command.points.flatMap { point in
                [Int((point.x * 10_000).rounded()), Int((point.y * 10_000).rounded())]
            }
        }
    }

    static func normalizedBounds(style: CardStyle, patternSeed: Int) -> CGRect {
        let points = commands(style: style, patternSeed: patternSeed).flatMap(\.points)
        guard let first = points.first else { return .null }

        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { bounds, point in
            bounds.union(CGRect(origin: point, size: .zero))
        }
    }

    static func commands(style: CardStyle, patternSeed: Int) -> [CatCardBotanicalCommand] {
        switch style {
        case .pineShadow:
            pineCommands(patternSeed: patternSeed)
        case .cedarShade:
            cedarCommands(patternSeed: patternSeed)
        case .fernTrace:
            fernCommands(patternSeed: patternSeed)
        case .mossVeil:
            mossCommands(patternSeed: patternSeed)
        default:
            []
        }
    }

    private static func pineCommands(patternSeed: Int) -> [CatCardBotanicalCommand] {
        var random = CatCardPatternRandom(patternSeed: patternSeed, salt: 0x5049_4E45)
        var commands: [CatCardBotanicalCommand] = []

        for trunk in 0..<6 {
            let progress = CGFloat(trunk) / 5
            let base = CGPoint(
                x: -0.08 + progress * 1.16 + random.centered(0.035),
                y: 1.06 + random.centered(0.035)
            )
            let tip = CGPoint(
                x: base.x + 0.13 + random.nextUnit() * 0.10,
                y: -0.06 + random.nextUnit() * 0.18
            )
            commands += [
                .move(base),
                .curve(
                    end: tip,
                    control1: CGPoint(x: base.x + 0.02, y: 0.76),
                    control2: CGPoint(x: tip.x - 0.08, y: 0.26)
                )
            ]

            for needle in 1...6 {
                let needleProgress = CGFloat(needle) / 7
                let anchor = interpolate(base, tip, progress: needleProgress)
                let reach = 0.115 * (1 - needleProgress) + 0.028
                let rise = 0.024 + random.nextUnit() * 0.018
                commands += [
                    .move(anchor),
                    .quad(
                        end: CGPoint(x: anchor.x + reach, y: anchor.y - rise),
                        control: CGPoint(x: anchor.x + reach * 0.42, y: anchor.y - rise * 1.45)
                    ),
                    .move(anchor),
                    .quad(
                        end: CGPoint(x: anchor.x - reach * 0.82, y: anchor.y - rise * 0.72),
                        control: CGPoint(x: anchor.x - reach * 0.34, y: anchor.y - rise * 1.28)
                    )
                ]
            }
        }

        return commands
    }

    private static func cedarCommands(patternSeed: Int) -> [CatCardBotanicalCommand] {
        var random = CatCardPatternRandom(patternSeed: patternSeed, salt: 0x4345_4441)
        var commands: [CatCardBotanicalCommand] = []

        for bough in 0..<5 {
            let progress = CGFloat(bough) / 4
            let start = CGPoint(x: -0.10, y: 0.01 + progress * 0.88 + random.centered(0.025))
            let end = CGPoint(x: 1.10, y: 0.10 + progress * 0.82 + random.centered(0.035))
            commands += [
                .move(start),
                .curve(
                    end: end,
                    control1: CGPoint(x: 0.20, y: start.y + 0.16 + random.centered(0.04)),
                    control2: CGPoint(x: 0.72, y: end.y - 0.18 + random.centered(0.04))
                )
            ]

            for cluster in 1...7 {
                let clusterProgress = CGFloat(cluster) / 8
                let anchor = interpolate(start, end, progress: clusterProgress)
                let length = 0.054 - clusterProgress * 0.018 + random.nextUnit() * 0.012
                commands += [
                    .move(anchor),
                    .line(CGPoint(x: anchor.x - length * 0.45, y: anchor.y - length)),
                    .move(anchor),
                    .line(CGPoint(x: anchor.x + length * 0.72, y: anchor.y - length * 0.74)),
                    .move(anchor),
                    .line(CGPoint(x: anchor.x + length * 0.88, y: anchor.y + length * 0.46))
                ]
            }
        }

        return commands
    }

    private static func fernCommands(patternSeed: Int) -> [CatCardBotanicalCommand] {
        var random = CatCardPatternRandom(patternSeed: patternSeed, salt: 0x4645_524E)
        var commands: [CatCardBotanicalCommand] = []
        let bases: [CGFloat] = [0.10, 0.48, 0.86]
        let tips: [CGFloat] = [-0.08, 0.52, 1.08]

        for frond in 0..<3 {
            let base = CGPoint(x: bases[frond] + random.centered(0.03), y: 1.08)
            let tip = CGPoint(x: tips[frond] + random.centered(0.04), y: 0.01 + random.nextUnit() * 0.08)
            let direction: CGFloat = frond == 0 ? -1 : (frond == 2 ? 1 : 0.2)
            commands += [
                .move(base),
                .curve(
                    end: tip,
                    control1: CGPoint(x: base.x + direction * 0.12, y: 0.72),
                    control2: CGPoint(x: tip.x - direction * 0.16, y: 0.30)
                )
            ]

            for leaflet in 1...8 {
                let leafletProgress = CGFloat(leaflet) / 9
                let anchor = interpolate(base, tip, progress: leafletProgress)
                let taper = 0.13 * (1 - leafletProgress) + 0.035
                let lift = 0.026 + random.nextUnit() * 0.022
                commands += [
                    .move(anchor),
                    .quad(
                        end: CGPoint(x: anchor.x + taper, y: anchor.y - lift),
                        control: CGPoint(x: anchor.x + taper * 0.48, y: anchor.y - lift * 1.55)
                    ),
                    .move(anchor),
                    .quad(
                        end: CGPoint(x: anchor.x - taper, y: anchor.y - lift * 0.86),
                        control: CGPoint(x: anchor.x - taper * 0.48, y: anchor.y - lift * 1.42)
                    )
                ]
            }
        }

        return commands
    }

    private static func mossCommands(patternSeed: Int) -> [CatCardBotanicalCommand] {
        var random = CatCardPatternRandom(patternSeed: patternSeed, salt: 0x4D4F_5353)
        let centers = [
            CGPoint(x: -0.02, y: 0.18),
            CGPoint(x: 0.28, y: 0.38),
            CGPoint(x: 0.72, y: 0.18),
            CGPoint(x: 1.02, y: 0.55),
            CGPoint(x: 0.68, y: 0.84),
            CGPoint(x: 0.18, y: 0.88)
        ].map { point in
            CGPoint(x: point.x + random.centered(0.045), y: point.y + random.centered(0.045))
        }

        var commands: [CatCardBotanicalCommand] = []

        for (clusterIndex, center) in centers.enumerated() {
            let radiusX = 0.17 + random.nextUnit() * 0.09
            let radiusY = 0.12 + random.nextUnit() * 0.08
            let lobeCount = 8
            var lobes: [CGPoint] = []

            for lobe in 0..<lobeCount {
                let angle = CGFloat(lobe) / CGFloat(lobeCount) * .pi * 2
                let radialJitter = 0.82 + random.nextUnit() * 0.32
                lobes.append(
                    CGPoint(
                        x: center.x + cos(angle) * radiusX * radialJitter,
                        y: center.y + sin(angle) * radiusY * radialJitter
                    )
                )
            }

            commands.append(.move(lobes[0]))
            for lobe in 1..<lobeCount {
                let previous = lobes[lobe - 1]
                let next = lobes[lobe]
                commands.append(
                    .quad(
                        end: next,
                        control: CGPoint(
                            x: (previous.x + next.x) * 0.5 + (previous.x - center.x) * 0.18,
                            y: (previous.y + next.y) * 0.5 + (previous.y - center.y) * 0.18
                        )
                    )
                )
            }
            commands.append(
                .quad(
                    end: lobes[0],
                    control: CGPoint(
                        x: (lobes[lobeCount - 1].x + lobes[0].x) * 0.5 + random.centered(0.04),
                        y: (lobes[lobeCount - 1].y + lobes[0].y) * 0.5 + random.centered(0.04)
                    )
                )
            )
            commands.append(.close)

            for filament in 0..<3 {
                let angle = (CGFloat(filament) / 3 + CGFloat(clusterIndex) * 0.11) * .pi * 2
                let end = CGPoint(
                    x: center.x + cos(angle) * radiusX * 0.82,
                    y: center.y + sin(angle) * radiusY * 0.82
                )
                commands += [
                    .move(center),
                    .curve(
                        end: end,
                        control1: CGPoint(
                            x: center.x + cos(angle - 0.55) * radiusX * 0.42,
                            y: center.y + sin(angle - 0.55) * radiusY * 0.42
                        ),
                        control2: CGPoint(
                            x: center.x + cos(angle + 0.42) * radiusX * 0.66,
                            y: center.y + sin(angle + 0.42) * radiusY * 0.66
                        )
                    )
                ]
            }
        }

        for index in 1..<centers.count {
            let start = centers[index - 1]
            let end = centers[index]
            commands += [
                .move(start),
                .curve(
                    end: end,
                    control1: CGPoint(
                        x: start.x + (end.x - start.x) * 0.34 + random.centered(0.05),
                        y: start.y + random.centered(0.12)
                    ),
                    control2: CGPoint(
                        x: start.x + (end.x - start.x) * 0.72 + random.centered(0.05),
                        y: end.y + random.centered(0.12)
                    )
                )
            ]
        }

        return commands
    }

    private static func interpolate(_ start: CGPoint, _ end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }
}

struct CatCardPatternRandom {
    private var state: UInt64

    init(patternSeed: Int, salt: UInt64) {
        state = Self.mix(UInt64(bitPattern: Int64(patternSeed)) ^ salt)
    }

    mutating func nextUnit() -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        let value = Self.mix(state) >> 11
        return CGFloat(Double(value) / 9_007_199_254_740_992)
    }

    mutating func centered(_ magnitude: CGFloat) -> CGFloat {
        (nextUnit() - 0.5) * magnitude * 2
    }

    static func unit(patternSeed: Int, salt: UInt64) -> CGFloat {
        var random = CatCardPatternRandom(patternSeed: patternSeed, salt: salt)
        return random.nextUnit()
    }

    private static func mix(_ input: UInt64) -> UInt64 {
        var value = input
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

private struct TopoContourLayer: View {
    let patternSeed: Int
    let lineCount: Int
    let lineWidth: CGFloat
    let gradient: LinearGradient

    var body: some View {
        TopoContourShape(lineCount: lineCount, patternSeed: patternSeed)
            .stroke(
                gradient,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

private struct TopoContourShape: Shape {
    let lineCount: Int
    let patternSeed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard lineCount > 0 else { return path }

        for index in 0..<lineCount {
            let points = CatCardContourMath.samplePoints(
                index: index,
                total: lineCount,
                patternSeed: patternSeed,
                in: rect
            )
            guard let first = points.first else { continue }

            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }

        return path
    }
}

enum CatCardContourMath {
    static func samplePoints(
        index: Int,
        total: Int,
        patternSeed: Int,
        in rect: CGRect
    ) -> [CGPoint] {
        guard rect.width > 0, rect.height > 0, total > 0 else { return [] }

        let center = CGPoint(
            x: rect.midX + (CatCardPatternRandom.unit(patternSeed: patternSeed, salt: 0xC011) - 0.5) * rect.width * 0.16,
            y: rect.midY + (CatCardPatternRandom.unit(patternSeed: patternSeed, salt: 0xC012) - 0.5) * rect.height * 0.16
        )
        let denominator = CGFloat(max(total - 1, 1))
        let contourProgress = min(max(CGFloat(index) / denominator, 0), 1)
        let maximumRadius = hypot(
            max(abs(rect.minX - center.x), abs(rect.maxX - center.x)),
            max(abs(rect.minY - center.y), abs(rect.maxY - center.y))
        ) * 1.03
        let contourScale = 0.06 + contourProgress * 0.94
        let baseRadius = maximumRadius * contourScale
        let phase = Double(CatCardPatternRandom.unit(patternSeed: patternSeed, salt: 0xC013)) * .pi * 2
        let contourIndex = Double(index)
        let distortionScale = min(rect.width, rect.height) / 400

        return stride(from: 0.0, through: 360.0, by: 4.0).map { angleDegrees in
            let angle = angleDegrees * .pi / 180
            let directionX = CGFloat(cos(angle))
            let directionY = CGFloat(sin(angle))
            let waveA = sin(angle * 3 + contourIndex * 0.47 + phase)
            let waveB = cos(angle * 5 - contourIndex * 0.31 + phase * 0.7)
            let waveC = sin(angle * 2 + contourIndex * 1.09 - phase * 0.4)
            let distortion = CGFloat(waveA * 7.5 + waveB * 4.8 + waveC * 3.2)
                * distortionScale
            let radius = max(baseRadius + distortion, min(rect.width, rect.height) * 0.025)

            return CGPoint(
                x: center.x + directionX * radius,
                y: center.y + directionY * radius
            )
        }
    }
}

struct CardStylePicker<Preview: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedStyle: CardStyle
    let itemWidth: CGFloat
    let previewAspectRatio: CGFloat
    let itemPadding: CGFloat
    let itemCornerRadius: CGFloat
    let itemSpacing: CGFloat
    let titleMinHeight: CGFloat
    @State private var selectedFamily: CardStyleFamily
    @State private var selectionFeedbackTrigger = 0

    @ViewBuilder let preview: (_ style: CardStyle) -> Preview

    init(
        selectedStyle: Binding<CardStyle>,
        itemWidth: CGFloat = 184,
        previewAspectRatio: CGFloat = 0.64,
        itemPadding: CGFloat = 8,
        itemCornerRadius: CGFloat = 28,
        itemSpacing: CGFloat = 14,
        titleMinHeight: CGFloat = 34,
        @ViewBuilder preview: @escaping (_ style: CardStyle) -> Preview
    ) {
        _selectedStyle = selectedStyle
        self.itemWidth = itemWidth
        self.previewAspectRatio = previewAspectRatio
        self.itemPadding = itemPadding
        self.itemCornerRadius = itemCornerRadius
        self.itemSpacing = itemSpacing
        self.titleMinHeight = titleMinHeight
        _selectedFamily = State(initialValue: selectedStyle.wrappedValue.family)
        self.preview = preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recommended")
                .font(CatTypography.badge)
                .foregroundStyle(CatLocalTheme.secondaryText)

            LazyVGrid(
                columns: recommendedColumns,
                spacing: 8
            ) {
                ForEach(CardStyleFamily.recommendedStyles) { style in
                    recommendedStyleButton(style)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("All styles")
                    .font(CatTypography.badge)
                    .foregroundStyle(CatLocalTheme.primaryText)

                Spacer(minLength: 12)

                Text(
                    CatLocalLocalization.cardStyleSummary(
                        styleCount: CardStyle.orderedCases.count,
                        familyCount: CardStyleFamily.allCases.count
                    )
                )
                    .font(CatTypography.finePrint)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            familySelector

            HStack(alignment: .firstTextBaseline) {
                Text(catLocalKey: selectedFamily.title)
                    .font(CatTypography.control)
                    .foregroundStyle(CatLocalTheme.primaryText)

                Spacer(minLength: 12)

                Text(CatLocalLocalization.plural("%lld styles", count: selectedFamily.styles.count))
                    .font(CatTypography.finePrint)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            CardStyleCarousel(
                selectedStyle: $selectedStyle,
                styles: selectedFamily.styles,
                showsTitle: false,
                itemWidth: itemWidth,
                previewAspectRatio: previewAspectRatio,
                itemPadding: itemPadding,
                itemCornerRadius: itemCornerRadius,
                itemSpacing: itemSpacing,
                titleMinHeight: titleMinHeight,
                preview: preview
            )
        }
        .onChange(of: selectedStyle) { _, style in
            guard style.family != selectedFamily else { return }
            selectedFamily = style.family
        }
        .catSensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
    }

    private var recommendedColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 8)]
        } else {
            [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
        }
    }

    private var familySelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(CardStyleFamily.allCases) { family in
                    familyButton(family)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card style families".catLocalized)
    }

    private func recommendedStyleButton(_ style: CardStyle) -> some View {
        let isSelected = style == selectedStyle
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return Button {
            selectRecommendedStyle(style)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    preview(style)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1.55, contentMode: .fit)
                .clipped()

                Text(catLocalKey: style.title)
                    .font(CatTypography.badge)
                    .foregroundStyle(isSelected ? CatAttentionRole.action.text : CatLocalTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background {
                shape.fill(isSelected ? CatAttentionRole.action.wash : CatLocalTheme.cardSurface.opacity(0.44))
            }
            .overlay {
                shape.stroke(isSelected ? CatAttentionRole.action.stroke : CatLocalTheme.separator, lineWidth: 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recommended-card-style-\(style.rawValue)")
        .accessibilityLabel(
            CatLocalLocalization.format(
                "Recommended, %1$@",
                CatLocalLocalization.string(style.title)
            )
        )
        .accessibilityHint("Selects this card design".catLocalized)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func familyButton(_ family: CardStyleFamily) -> some View {
        let isSelected = family == selectedFamily

        return Button {
            selectFamily(family)
        } label: {
            Text(catLocalKey: family.title)
                .font(CatTypography.badge)
                .foregroundStyle(isSelected ? CatAttentionRole.action.text : CatLocalTheme.secondaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? CatAttentionRole.action.wash : Color.clear)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isSelected ? CatAttentionRole.action.stroke : CatLocalTheme.separator, lineWidth: 1)
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("card-style-family-\(family.rawValue)")
        .accessibilityLabel(
            CatLocalLocalization.format(
                "%1$@ styles",
                CatLocalLocalization.string(family.title)
            )
        )
        .accessibilityHint(
            CatLocalLocalization.plural("Shows %lld styles", count: family.styles.count)
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func selectRecommendedStyle(_ style: CardStyle) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            selectedFamily = style.family
            selectedStyle = style
        }
        selectionFeedbackTrigger += 1
    }

    private func selectFamily(_ family: CardStyleFamily) {
        guard family != selectedFamily else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            selectedFamily = family
            selectedStyle = family.recommendedStyle
        }
        selectionFeedbackTrigger += 1
    }
}

struct CardStyleCarousel<Preview: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedStyle: CardStyle
    let styles: [CardStyle]
    let showsTitle: Bool
    let itemWidth: CGFloat
    let previewAspectRatio: CGFloat
    let itemPadding: CGFloat
    let itemCornerRadius: CGFloat
    let itemSpacing: CGFloat
    let titleMinHeight: CGFloat
    @State private var centeredItemID: Int?
    @State private var hapticStyle: CardStyle?
    @State private var selectionFeedbackTrigger = 0

    @ViewBuilder let preview: (_ style: CardStyle) -> Preview

    init(
        selectedStyle: Binding<CardStyle>,
        styles: [CardStyle] = CardStyle.orderedCases,
        showsTitle: Bool = true,
        itemWidth: CGFloat = 184,
        previewAspectRatio: CGFloat = 0.64,
        itemPadding: CGFloat = 8,
        itemCornerRadius: CGFloat = 28,
        itemSpacing: CGFloat = 14,
        titleMinHeight: CGFloat = 34,
        @ViewBuilder preview: @escaping (_ style: CardStyle) -> Preview
    ) {
        _selectedStyle = selectedStyle
        self.styles = styles
        self.showsTitle = showsTitle
        self.itemWidth = itemWidth
        self.previewAspectRatio = previewAspectRatio
        self.itemPadding = itemPadding
        self.itemCornerRadius = itemCornerRadius
        self.itemSpacing = itemSpacing
        self.titleMinHeight = titleMinHeight
        self.preview = preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text("Card design")
                    .font(CatTypography.badge)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: itemSpacing) {
                    ForEach(carouselItems) { item in
                        styleOption(item.style)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredItemID)
            .onAppear {
                centeredItemID = centeredItemID(for: selectedStyle)
            }
            .onChange(of: centeredItemID) { _, itemID in
                guard let itemID, let item = carouselItems.first(where: { $0.id == itemID }) else { return }
                if item.style != selectedStyle {
                    selectedStyle = item.style
                    playSelectionHaptic(for: item.style)
                }
                recenterIfNeeded(item)
            }
            .onChange(of: selectedStyle) { _, style in
                guard orderedStyles.contains(style) else { return }
                guard currentCenteredStyle != style else { return }
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                    centeredItemID = centeredItemID(for: style)
                }
            }
            .onChange(of: orderedStyles) { _, _ in
                centeredItemID = centeredItemID(for: selectedStyle)
            }
        }
        .catSensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
    }

    private var styleCount: Int {
        orderedStyles.count
    }

    private var orderedStyles: [CardStyle] {
        styles
    }

    private var carouselCycleCount: Int {
        7
    }

    private var centerCycle: Int {
        carouselCycleCount / 2
    }

    private var carouselItems: [CarouselStyleItem] {
        guard styleCount > 0 else { return [] }
        return (0..<(styleCount * carouselCycleCount)).map { index in
            CarouselStyleItem(
                id: index,
                style: orderedStyles[index % styleCount],
                cycle: index / styleCount
            )
        }
    }

    private var currentCenteredStyle: CardStyle? {
        guard let centeredItemID else { return nil }
        return carouselItems.first(where: { $0.id == centeredItemID })?.style
    }

    private func centeredItemID(for style: CardStyle) -> Int {
        let styleIndex = orderedStyles.firstIndex(of: style) ?? 0
        return centerCycle * styleCount + styleIndex
    }

    private func recenterIfNeeded(_ item: CarouselStyleItem) {
        guard item.cycle <= 1 || item.cycle >= carouselCycleCount - 2 else { return }
        let targetID = centeredItemID(for: item.style)
        guard centeredItemID != targetID else { return }

        Task { @MainActor in
            centeredItemID = targetID
        }
    }

    private func styleOption(_ style: CardStyle) -> some View {
        let isSelected = style == selectedStyle
        let shape = RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous)

        return Button {
            selectStyle(style)
        } label: {
            VStack(spacing: 9) {
                preview(style)
                    .aspectRatio(previewAspectRatio, contentMode: .fit)
                    .allowsHitTesting(false)

                Text(catLocalKey: style.title)
                    .font(CatTypography.badge)
                    .foregroundStyle(isSelected ? CatAttentionRole.action.text : CatLocalTheme.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: titleMinHeight, alignment: .center)
            }
            .frame(width: itemWidth)
            .padding(itemPadding)
            .background {
                shape
                    .fill(isSelected ? CatAttentionRole.action.wash : CatLocalTheme.cardSurface.opacity(0.36))
            }
            .overlay {
                shape
                    .stroke(isSelected ? CatAttentionRole.action.stroke : Color.clear, lineWidth: 1)
            }
            .scaleEffect(isSelected ? 1 : 0.96)
            .contentShape(RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            CatLocalLocalization.format(
                "Design %1$lld, %2$@ card design",
                Int64(style.displayIndex + 1),
                CatLocalLocalization.string(style.title)
            )
        )
        .accessibilityHint("Selects this card design".catLocalized)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func selectStyle(_ style: CardStyle) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            selectedStyle = style
            centeredItemID = centeredItemID(for: style)
        }
        playSelectionHaptic(for: style)
    }

    private func playSelectionHaptic(for style: CardStyle) {
        guard hapticStyle != style else { return }
        hapticStyle = style
        selectionFeedbackTrigger += 1
    }
}

struct CardStyleSwatch: View {
    let style: CardStyle
    private var palette: CardStylePalette { CardStylePalette(style: style) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        ZStack {
            LinearGradient(
                colors: palette.surfaceColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            swatchOverlay

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(contentColor.opacity(0.72))
                        .frame(width: 52, height: 6)

                    Spacer()

                    Circle()
                        .fill(contentColor.opacity(0.16))
                        .frame(width: 20, height: 20)
                        .overlay {
                            Text("\(style.displayIndex + 1)")
                                .font(CatTypography.finePrint.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(contentColor)
                        }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(contentColor.opacity(0.72))
                        .frame(width: 58, height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(contentColor.opacity(0.26))
                        .frame(width: 42, height: 5)
                }
            }
            .padding(13)
        }
        .clipShape(shape)
        .overlay(shape.stroke(palette.imageStageStroke, lineWidth: 1))
    }

    @ViewBuilder
    private var swatchOverlay: some View {
        switch style {
        case .archive:
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.26),
                    palette.secondaryAccent.opacity(0.10),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunstamp:
            RadialGradient(
                colors: [
                    palette.accent.opacity(0.58),
                    palette.secondaryAccent.opacity(0.26),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 92
            )
        case .clear:
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.24),
                    Color.white.opacity(0.22),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .garden:
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.24),
                    palette.secondaryAccent.opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnight:
            LinearGradient(
                colors: [
                    palette.sheen.opacity(0.18),
                    palette.accent.opacity(0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .apricot:
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.30),
                    palette.sheen.opacity(0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .prism:
            AngularGradient(
                colors: [.cyan, .pink, .yellow, .blue, .purple, .cyan],
                center: .center
            )
            .opacity(0.88)
            .blendMode(.hardLight)
        case .gold:
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.26, blue: 0.08),
                    Color(red: 1.0, green: 0.74, blue: 0.23),
                    Color.white.opacity(0.86),
                    Color(red: 0.49, green: 0.28, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.82)
            .blendMode(.hardLight)
        case .topo, .topoEmber, .topoLagoon, .topoMoss, .topoDusk:
            topographicSwatchOverlay
        case .pineShadow, .cedarShade, .fernTrace, .mossVeil:
            archiveMaterialSwatchOverlay
        case .cobaltHalo, .apricotBeam, .auroraPool:
            lightEffectSwatchOverlay
                .opacity(0.55)
        }
    }

    private var archiveMaterialSwatchOverlay: some View {
        let variant = style.archiveMaterialVariantIndex

        return ZStack {
            archiveMaterialSwatchWash

            CardMaterialPatternShape(style: style, patternSeed: 23 + variant * 47)
                .stroke(
                    LinearGradient(
                        colors: [
                            contentColor.opacity(0.42),
                            palette.sheen.opacity(0.66),
                            palette.accent.opacity(0.50)
                        ],
                        startPoint: archiveMaterialSwatchStartPoint,
                        endPoint: archiveMaterialSwatchEndPoint
                    ),
                    style: StrokeStyle(
                        lineWidth: 0.86,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .blendMode(.screen)
                .opacity(0.82)

            LinearGradient(
                colors: [
                    .clear,
                    palette.sheen.opacity(0.30),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 34)
            .rotationEffect(.degrees(archiveMaterialSwatchAngle))
            .blendMode(.screen)
            .opacity(0.74)
        }
    }

    @ViewBuilder
    private var archiveMaterialSwatchWash: some View {
        switch style {
        case .pineShadow:
            RadialGradient(
                colors: [
                    palette.accent.opacity(0.28),
                    palette.secondaryAccent.opacity(0.18),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 120
            )
            .blendMode(.screen)
        case .cedarShade:
            RadialGradient(
                colors: [
                    palette.accent.opacity(0.34),
                    palette.secondaryAccent.opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 118
            )
            .blendMode(.screen)
        case .fernTrace:
            RadialGradient(
                colors: [
                    palette.sheen.opacity(0.30),
                    palette.accent.opacity(0.20),
                    .clear
                ],
                center: .leading,
                startRadius: 0,
                endRadius: 116
            )
            .blendMode(.screen)
        case .mossVeil:
            RadialGradient(
                colors: [
                    palette.accent.opacity(0.36),
                    palette.secondaryAccent.opacity(0.18),
                    .clear
                ],
                center: UnitPoint(x: 0.52, y: 0.62),
                startRadius: 0,
                endRadius: 128
            )
            .blendMode(.screen)
        default:
            EmptyView()
        }
    }

    private var archiveMaterialSwatchStartPoint: UnitPoint {
        switch style {
        case .pineShadow:
            .topTrailing
        case .cedarShade:
            .top
        case .fernTrace:
            .leading
        case .mossVeil:
            .topLeading
        default:
            .topLeading
        }
    }

    private var archiveMaterialSwatchEndPoint: UnitPoint {
        switch style {
        case .pineShadow:
            .bottomLeading
        case .cedarShade:
            .bottomTrailing
        case .fernTrace:
            .trailing
        case .mossVeil:
            .bottom
        default:
            .bottomTrailing
        }
    }

    private var archiveMaterialSwatchAngle: Double {
        switch style {
        case .pineShadow:
            -42
        case .cedarShade:
            -28
        case .fernTrace:
            32
        case .mossVeil:
            -8
        default:
            -18
        }
    }

    private var lightEffectSwatchOverlay: some View {
        let variant = style.lightEffectVariantIndex

        return ZStack {
            RadialGradient(
                colors: [
                    palette.accent.opacity(style == .apricotBeam ? 0.48 : 0.58),
                    palette.secondaryAccent.opacity(0.22),
                    .clear
                ],
                center: lightEffectSwatchCenter,
                startRadius: 0,
                endRadius: 108
            )
            .blendMode(.screen)

            AngularGradient(
                colors: lightEffectSwatchColors,
                center: lightEffectSwatchCenter,
                angle: .degrees(Double(variant * 34))
            )
            .opacity(style == .apricotBeam ? 0.36 : 0.54)
            .blendMode(.hardLight)

            LinearGradient(
                colors: [
                    .clear,
                    palette.sheen.opacity(0.36),
                    palette.accent.opacity(0.24),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: style == .apricotBeam ? 42 : 34)
            .rotationEffect(.degrees(lightEffectSwatchAngle))
            .blendMode(.screen)
            .opacity(0.80)
        }
    }

    private var lightEffectSwatchColors: [Color] {
        switch style {
        case .cobaltHalo:
            [.cyan, palette.accent, palette.secondaryAccent, .mint, .cyan]
        case .apricotBeam:
            [palette.sheen, palette.accent, palette.secondaryAccent, Color.white.opacity(0.82), palette.sheen]
        case .auroraPool:
            [.mint, .blue, .pink, .yellow, .mint]
        default:
            [palette.accent, palette.secondaryAccent, palette.sheen, palette.accent]
        }
    }

    private var lightEffectSwatchCenter: UnitPoint {
        switch style {
        case .cobaltHalo:
            UnitPoint(x: 0.66, y: 0.30)
        case .apricotBeam:
            UnitPoint(x: 0.24, y: 0.22)
        case .auroraPool:
            UnitPoint(x: 0.50, y: 0.52)
        default:
            .center
        }
    }

    private var lightEffectSwatchAngle: Double {
        switch style {
        case .cobaltHalo:
            -16
        case .apricotBeam:
            24
        case .auroraPool:
            -34
        default:
            -18
        }
    }

    private var topographicSwatchOverlay: some View {
        let variant = style.topographicVariantIndex

        return ZStack {
            AngularGradient(
                colors: topographicSwatchColors,
                center: topographicSwatchCenter,
                angle: .degrees(Double(variant * 22))
            )
            .opacity(0.52)
            .blendMode(.plusLighter)

            LinearGradient(
                colors: [
                    palette.sheen.opacity(0.30),
                    .clear,
                    palette.secondaryAccent.opacity(0.24)
                ],
                startPoint: topographicSwatchStartPoint,
                endPoint: topographicSwatchEndPoint
            )
            .blendMode(.screen)

            TopoContourLayer(
                patternSeed: 17 + variant * 53,
                lineCount: 8 + min(variant, 4),
                lineWidth: 0.8 + CGFloat(variant % 3) * 0.08,
                gradient: LinearGradient(
                    colors: [
                        Color.white.opacity(0.74),
                        palette.sheen.opacity(0.66),
                        palette.accent.opacity(0.58)
                    ],
                    startPoint: topographicSwatchStartPoint,
                    endPoint: topographicSwatchEndPoint
                )
            )
            .opacity(0.76)
            .blendMode(.plusLighter)
        }
    }

    private var topographicSwatchColors: [Color] {
        switch style {
        case .topoEmber:
            [.orange, palette.sheen, palette.secondaryAccent, .pink, .orange]
        case .topoLagoon:
            [.cyan, palette.accent, .mint, palette.secondaryAccent, .cyan]
        case .topoMoss:
            [.green, palette.accent, .yellow, palette.secondaryAccent, .green]
        case .topoDusk:
            [palette.accent, .cyan, palette.secondaryAccent, palette.sheen, palette.accent]
        default:
            [.orange, .teal, .yellow, .pink, .orange]
        }
    }

    private var topographicSwatchCenter: UnitPoint {
        switch style {
        case .topoEmber:
            UnitPoint(x: 0.68, y: 0.34)
        case .topoLagoon:
            UnitPoint(x: 0.36, y: 0.42)
        case .topoMoss:
            UnitPoint(x: 0.58, y: 0.66)
        case .topoDusk:
            UnitPoint(x: 0.42, y: 0.28)
        default:
            .center
        }
    }

    private var topographicSwatchStartPoint: UnitPoint {
        switch style {
        case .topoLagoon:
            .top
        case .topoMoss:
            .leading
        default:
            .topLeading
        }
    }

    private var topographicSwatchEndPoint: UnitPoint {
        switch style {
        case .topoLagoon:
            .bottomTrailing
        case .topoMoss:
            .trailing
        default:
            .bottomTrailing
        }
    }

    private var contentColor: Color {
        palette.primaryContent
    }
}

private struct CarouselStyleItem: Identifiable {
    let id: Int
    let style: CardStyle
    let cycle: Int
}
