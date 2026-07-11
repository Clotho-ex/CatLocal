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
            catBoundingBox: record.catBoundingBox,
            topoSeed: record.id.hashValue
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
        .accessibilityHint(presentation == .focused ? "Drag the cat to shift its light" : "Double tap to open focused cat view.")
    }

    private var imagePath: String {
        usesCutoutImage ? record.cutoutImagePath : record.thumbnailImagePath
    }

    private var accessibilityLabel: String {
        let note = record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " Note saved."
        let place = if presentation == .thumbnail, showsThumbnailPlaceFooter {
            record.memoryPlaceLabel.map { " Memory Place, \($0)." } ?? " No Memory Place yet."
        } else {
            showsThumbnailPlaceFooter ? record.memoryPlaceLabel.map { " Memory Place, \($0)." } ?? "" : ""
        }

        return "Cat, \(record.displayName). Cat number \(record.sequence.formatted()). Captured \(record.capturedAt.formatted(date: .abbreviated, time: .omitted)).\(place)\(note)"
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
    var topoSeed: Int = 0
    var appliesStickerEffect = false
    var stickerMotionIntensity: CGFloat?

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
            catBoundingBox: catBoundingBox,
            topoSeed: topoSeed
        ) {
            draftCatImage
        }
    }

    @ViewBuilder
    private var draftCatImage: some View {
        if appliesStickerEffect, stickerMotionIntensity != nil {
            StickerCutoutView(
                image: image,
                appliesMotion: true
            )
        } else if appliesStickerEffect {
            StickerCutoutView(
                image: image,
                appliesMotion: false
            )
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
    let catBoundingBox: CGRect?
    let topoSeed: Int
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
                                .frame(
                                    maxWidth: imageMaxWidth,
                                    maxHeight: imageStageHeight * 0.96,
                                    alignment: .center
                                )
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: imageStageHeight)

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
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
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

                    Text(note.isEmpty ? "No Note Yet." : note)
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

            Text(title)
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

            Text(title)
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
                parts.append("Memory Place, \(placeName), \(placeDetail)")
            } else {
                parts.append("Memory Place, \(placeName)")
            }
        } else {
            parts.append("No Memory Place yet")
        }

        if hasNote {
            parts.append("Note saved")
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
            thumbnailStyleHintSurface
        }
    }

    private var standardSurface: some View {
        ZStack {
            LinearGradient(
                colors: palette.surfaceColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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

            if cardStyle.isLightEffect {
                lightEffectThumbnailLayer
                    .opacity(0.62)
            }

            thumbnailStyleGlint
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
        CardMaterialPatternShape(style: cardStyle, seed: positiveSeed)
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
        CardMaterialPatternShape(style: cardStyle, seed: positiveSeed)
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
            LinearGradient(
                colors: palette.surfaceColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            lightEffectAura
            lightEffectBand
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

    private var lightEffectThumbnailLayer: some View {
        ZStack {
            lightEffectAura

            lightEffectBand
                .opacity(0.58)
        }
        .accessibilityHidden(true)
    }

    private var topoSurface: some View {
        ZStack {
            LinearGradient(
                colors: palette.surfaceColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if presentation == .thumbnail {
                topoThumbnailLayer
            } else {
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
    }

    private var topoThumbnailLayer: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                TopoContourShape(index: index, total: 6, seed: positiveSeed)
                    .stroke(
                        LinearGradient(
                            colors: [
                                topoLineColors.first?.opacity(0.42) ?? Color.white.opacity(0.36),
                                palette.accent.opacity(0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .opacity(0.58)
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
                    angle: .degrees(Double(topoSeed % 180) + Double(effectiveRotateX - effectiveRotateY) * 2.6)
                )
                .scaleEffect(1.75)
                .blur(radius: presentation == .thumbnail ? 3 : 1.5)
                .blendMode(.hardLight)
                .opacity(0.64)
            }
            .overlay {
                TopoContourLayer(
                    seed: positiveSeed + topoVariant * 97,
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
        abs(topoSeed == Int.min ? 0 : topoSeed)
    }

    private func clampedUnit(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
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
    let seed: Int

    func path(in rect: CGRect) -> Path {
        switch style {
        case .pineShadow:
            pineShadowPath(in: rect)
        case .cedarShade:
            cedarShadePath(in: rect)
        case .fernTrace:
            fernTracePath(in: rect)
        case .mossVeil:
            mossVeilPath(in: rect)
        default:
            Path()
        }
    }

    private func pineShadowPath(in rect: CGRect) -> Path {
        var path = Path()
        let stems = 9

        for index in 0..<stems {
            let progress = CGFloat(index) / CGFloat(max(stems - 1, 1))
            let baseX = rect.minX + rect.width * (-0.04 + progress * 1.10)
            let baseY = rect.maxY + rect.height * 0.08
            let tipX = baseX + rect.width * (-0.12 + CGFloat((seed + index * 5) % 9) * 0.028)
            let tipY = rect.minY + rect.height * (0.10 + CGFloat((seed + index * 3) % 6) * 0.045)

            path.move(to: CGPoint(x: baseX, y: baseY))
            path.addLine(to: CGPoint(x: tipX, y: tipY))

            for leaf in 0..<3 {
                let leafProgress = CGFloat(leaf + 1) / 4
                let anchorX = baseX + (tipX - baseX) * leafProgress
                let anchorY = baseY + (tipY - baseY) * leafProgress
                let reach = rect.width * (0.05 + CGFloat(leaf) * 0.014)
                let rise = rect.height * (0.04 + CGFloat(leaf) * 0.010)

                path.move(to: CGPoint(x: anchorX, y: anchorY))
                path.addQuadCurve(
                    to: CGPoint(x: anchorX + reach, y: anchorY - rise),
                    control: CGPoint(x: anchorX + reach * 0.34, y: anchorY - rise * 1.24)
                )

                path.move(to: CGPoint(x: anchorX, y: anchorY))
                path.addQuadCurve(
                    to: CGPoint(x: anchorX - reach * 0.72, y: anchorY - rise * 0.78),
                    control: CGPoint(x: anchorX - reach * 0.20, y: anchorY - rise * 1.12)
                )
            }
        }

        return path
    }

    private func cedarShadePath(in rect: CGRect) -> Path {
        var path = Path()
        let branches = 8

        for index in 0..<branches {
            let progress = CGFloat(index) / CGFloat(max(branches - 1, 1))
            let start = CGPoint(
                x: rect.minX + rect.width * (0.08 + progress * 0.82),
                y: rect.maxY + rect.height * 0.06
            )
            let end = CGPoint(
                x: start.x + rect.width * (-0.18 + CGFloat((seed + index * 7) % 13) * 0.025),
                y: rect.minY + rect.height * (0.04 + CGFloat(index % 4) * 0.05)
            )

            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x - rect.width * 0.10, y: rect.midY * 1.08),
                control2: CGPoint(x: end.x + rect.width * 0.08, y: rect.midY * 0.54)
            )

            for needle in 0..<4 {
                let needleProgress = CGFloat(needle + 1) / 5
                let anchor = CGPoint(
                    x: start.x + (end.x - start.x) * needleProgress,
                    y: start.y + (end.y - start.y) * needleProgress
                )
                let reach = rect.width * (0.036 + CGFloat(needle) * 0.006)
                path.move(to: anchor)
                path.addLine(to: CGPoint(x: anchor.x + reach, y: anchor.y - rect.height * 0.026))
                path.move(to: anchor)
                path.addLine(to: CGPoint(x: anchor.x - reach * 0.74, y: anchor.y - rect.height * 0.020))
            }
        }

        return path
    }

    private func fernTracePath(in rect: CGRect) -> Path {
        var path = Path()
        let stemStart = CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY + rect.height * 0.02)
        let stemEnd = CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.08)

        path.move(to: stemStart)
        path.addCurve(
            to: stemEnd,
            control1: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.midY * 1.14),
            control2: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.midY * 0.50)
        )

        for leaflet in 0..<12 {
            let progress = CGFloat(leaflet + 1) / 13
            let anchor = CGPoint(
                x: stemStart.x + (stemEnd.x - stemStart.x) * progress,
                y: stemStart.y + (stemEnd.y - stemStart.y) * progress
            )
            let side: CGFloat = leaflet % 2 == 0 ? 1 : -1
            let length = rect.width * (0.08 + CGFloat((seed + leaflet) % 4) * 0.008)
            let lift = rect.height * (0.036 + CGFloat(leaflet % 3) * 0.008)

            path.move(to: anchor)
            path.addQuadCurve(
                to: CGPoint(x: anchor.x + side * length, y: anchor.y - lift),
                control: CGPoint(x: anchor.x + side * length * 0.42, y: anchor.y - lift * 1.32)
            )
        }

        return path
    }

    private func mossVeilPath(in rect: CGRect) -> Path {
        var path = Path()
        let pockets = 13

        for index in 0..<pockets {
            let seedX = CGFloat((seed + index * 17) % 97) / 97
            let seedY = CGFloat((seed + index * 29) % 89) / 89
            let width = rect.width * (0.08 + CGFloat(index % 4) * 0.018)
            let height = width * (0.46 + CGFloat((seed + index) % 3) * 0.14)
            let origin = CGPoint(
                x: rect.minX + rect.width * (0.06 + seedX * 0.84),
                y: rect.minY + rect.height * (0.10 + seedY * 0.74)
            )

            path.addEllipse(
                in: CGRect(
                    x: origin.x - width / 2,
                    y: origin.y - height / 2,
                    width: width,
                    height: height
                )
            )

            if index % 3 == 0 {
                path.move(to: CGPoint(x: origin.x - width * 0.62, y: origin.y))
                path.addQuadCurve(
                    to: CGPoint(x: origin.x + width * 0.62, y: origin.y - height * 0.12),
                    control: CGPoint(x: origin.x, y: origin.y - height * 0.78)
                )
            }
        }

        return path
    }
}

private struct TopoContourLayer: View {
    let seed: Int
    let lineCount: Int
    let lineWidth: CGFloat
    let gradient: LinearGradient

    var body: some View {
        ZStack {
            ForEach(0..<lineCount, id: \.self) { index in
                TopoContourShape(index: index, total: lineCount, seed: seed)
                    .stroke(
                        gradient,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

private struct TopoContourShape: Shape {
    let index: Int
    let total: Int
    let seed: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(
            x: rect.midX + seedOffset(axis: 0, scale: rect.width * 0.08),
            y: rect.midY + seedOffset(axis: 1, scale: rect.height * 0.08)
        )
        let maximumRadius = min(rect.width, rect.height) * 0.62
        let progress = CGFloat(index + 1) / CGFloat(total + 2)
        let baseRadius = maximumRadius * progress
        let seedPhase = Double(seed % 997) * 0.017
        var path = Path()

        for angleDegrees in stride(from: 0.0, through: 360.0, by: 5.0) {
            let angle = angleDegrees * .pi / 180
            let contourIndex = Double(index)
            let waveA = sin(angle * 3.0 + contourIndex * 0.47 + seedPhase)
            let waveB = cos(angle * 5.0 - contourIndex * 0.31 + seedPhase * 0.7)
            let waveC = sin(angle * 2.0 + contourIndex * 1.09 - seedPhase * 0.4)
            let distortion = CGFloat(waveA * 7.5 + waveB * 4.8 + waveC * 3.2)
            let radius = max(baseRadius + distortion, 5)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if angleDegrees == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func seedOffset(axis: Int, scale: CGFloat) -> CGFloat {
        let value = ((seed / max(axis + 1, 1)) % 31) - 15
        return CGFloat(value) / 15 * scale
    }
}

struct CardStylePicker<Preview: View>: View {
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
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
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

                Text("\(CardStyle.orderedCases.count) in \(CardStyleFamily.allCases.count) families")
                    .font(CatTypography.finePrint)
                    .foregroundStyle(CatLocalTheme.secondaryText)
            }

            familySelector

            HStack(alignment: .firstTextBaseline) {
                Text(selectedFamily.title)
                    .font(CatTypography.control)
                    .foregroundStyle(CatLocalTheme.primaryText)

                Spacer(minLength: 12)

                Text("\(selectedFamily.styles.count) styles")
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
        .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
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
        .accessibilityLabel("Card style families")
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

                Text(style.title)
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
        .accessibilityLabel("Recommended, \(style.title)")
        .accessibilityHint("Selects this card design")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func familyButton(_ family: CardStyleFamily) -> some View {
        let isSelected = family == selectedFamily

        return Button {
            selectFamily(family)
        } label: {
            Text(family.title)
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
        .accessibilityLabel("\(family.title) styles")
        .accessibilityHint("Shows \(family.styles.count) styles")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func selectRecommendedStyle(_ style: CardStyle) {
        withAnimation(.snappy(duration: 0.24)) {
            selectedFamily = style.family
            selectedStyle = style
        }
        selectionFeedbackTrigger += 1
    }

    private func selectFamily(_ family: CardStyleFamily) {
        guard family != selectedFamily else { return }
        withAnimation(.snappy(duration: 0.24)) {
            selectedFamily = family
            selectedStyle = family.recommendedStyle
        }
        selectionFeedbackTrigger += 1
    }
}

struct CardStyleCarousel<Preview: View>: View {
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
                withAnimation(.snappy(duration: 0.24)) {
                    centeredItemID = centeredItemID(for: style)
                }
            }
            .onChange(of: orderedStyles) { _, _ in
                centeredItemID = centeredItemID(for: selectedStyle)
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
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

                Text(style.title)
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
        .accessibilityLabel("Design \(style.displayIndex + 1), \(style.title) card design")
        .accessibilityHint("Selects this card design")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func selectStyle(_ style: CardStyle) {
        withAnimation(.snappy(duration: 0.24)) {
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
        }
    }

    private var archiveMaterialSwatchOverlay: some View {
        let variant = style.archiveMaterialVariantIndex

        return ZStack {
            archiveMaterialSwatchWash

            CardMaterialPatternShape(style: style, seed: 23 + variant * 47)
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
                seed: 17 + variant * 53,
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
