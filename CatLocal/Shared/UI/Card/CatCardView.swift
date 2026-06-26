import SwiftUI
import UIKit

struct CatCardView: View {
    let record: CatRecord
    var presentation: CatCardPresentation = .thumbnail
    var cardStyle: CardStyle?
    var rotateX: CGFloat = 0
    var rotateY: CGFloat = 0
    var isLightActive: Bool = false

    private var usesCutoutImage: Bool { presentation == .focused || presentation == .stylePreview }
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
            catBoundingBox: record.catBoundingBox,
            topoSeed: record.id.hashValue
        ) {
            StoredImageView(path: imagePath, contentMode: .fit) {
                if presentation == .stylePreview {
                    Image(systemName: "cat.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(CatLocalTheme.accent(for: resolvedCardStyle).opacity(0.38))
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
        let place = record.memoryPlaceLabel.map { " Memory Place, \($0)." } ?? ""
        return "Cat, \(record.displayName). Cat number \(record.sequence.formatted()). Captured \(record.capturedAt.formatted(date: .abbreviated, time: .omitted)).\(place)"
    }
}

struct DraftCatCardView: View {
    let image: UIImage
    let sequence: Int
    let name: String
    let note: String
    let placeName: String
    let placeDetail: String
    var cardStyle: CardStyle = .archive
    var presentation: CatCardPresentation = .focused
    var rotateX: CGFloat = 0
    var rotateY: CGFloat = 0
    var isLightActive: Bool = false
    var catBoundingBox: CGRect?
    var topoSeed: Int = 0

    var body: some View {
        CatCardSurface(
            sequence: sequence,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "New Cat"
                : name,
            date: Date(),
            note: note,
            placeName: trimmedPlaceName,
            placeDetail: trimmedPlaceDetail,
            cardStyle: cardStyle,
            presentation: presentation,
            rotateX: rotateX,
            rotateY: rotateY,
            isLightActive: isLightActive,
            catBoundingBox: catBoundingBox,
            topoSeed: topoSeed
        ) {
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
    @Environment(\.colorScheme) private var colorScheme
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
    let catBoundingBox: CGRect?
    let topoSeed: Int
    @ViewBuilder let catImage: () -> CatImage

    private var focused: Bool { presentation == .focused }
    private var stylePreview: Bool { presentation == .stylePreview }
    private var effectiveRotateX: CGFloat { focused ? rotateX : 0 }
    private var effectiveRotateY: CGFloat { focused ? rotateY : 0 }
    private var foilLightOpacity: Double { focused ? (isLightActive ? 1 : 0) : 1 }
    private var needsFoilContrast: Bool {
        cardStyle == .midnight || cardStyle == .prism || cardStyle == .gold || cardStyle == .topo
    }
    private var usesPermanentDarkFoilSurface: Bool {
        cardStyle == .prism || cardStyle == .gold || cardStyle == .topo
    }

    private var primaryContentColor: Color {
        guard needsFoilContrast else { return CatLocalTheme.primaryText }
        if usesPermanentDarkFoilSurface {
            return .white
        }
        return colorScheme == .dark ? CatLocalTheme.background : CatLocalTheme.cardSurface
    }

    private var secondaryContentColor: Color {
        needsFoilContrast ? primaryContentColor.opacity(0.72) : CatLocalTheme.secondaryText
    }

    private var separatorColor: Color {
        needsFoilContrast ? primaryContentColor.opacity(0.26) : CatLocalTheme.separator
    }

    private var medallionFill: Color {
        needsFoilContrast ? primaryContentColor.opacity(0.14) : CatLocalTheme.elevatedSurface.opacity(0.74)
    }

    private var pillFill: Color {
        needsFoilContrast ? primaryContentColor.opacity(0.14) : CatLocalTheme.memoryPlaceFill
    }

    private var pillStroke: Color {
        needsFoilContrast ? primaryContentColor.opacity(0.24) : CatLocalTheme.memoryPlaceStroke
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width, 1)
            let cardHeight = max(proxy.size.height, 1)
            let cornerRadius: CGFloat = focused ? 34 : (stylePreview ? 24 : 22)
            let outerPadding: CGFloat = focused ? 18 : (stylePreview ? 12 : 11)
            let imageStageHeight = max(cardHeight * imageStageRatio, 1)
            let imageMaxWidth = max(cardWidth - outerPadding * 2, 1)
            let previewImageHeight = max(cardHeight - outerPadding * 2, 1)
            let previewCatOffset = catImageOffset(cardWidth: imageMaxWidth, cardHeight: previewImageHeight)
            let focusedCatOffset = catImageOffset(cardWidth: imageMaxWidth, cardHeight: imageStageHeight)

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
                            .offset(x: previewCatOffset.width, y: previewCatOffset.height)
                            .accessibilityHidden(true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: focused ? 14 : 9) {
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
                                .offset(x: focusedCatOffset.width, y: focusedCatOffset.height)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: imageStageHeight)

                        footer
                    }
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
                color: CatLocalTheme.shadow.opacity(focused ? 0.72 : 0.36),
                radius: focused ? 28 : 11,
                y: focused ? 18 : 6
            )
        }
        .aspectRatio(focused || stylePreview ? 0.64 : 0.72, contentMode: .fit)
    }

    private var imageStageRatio: CGFloat {
        if stylePreview {
            return 1
        }

        if focused, hasFocusedTextContent {
            return dynamicTypeSize.isAccessibilitySize ? 0.32 : 0.42
        }

        return if dynamicTypeSize.isAccessibilitySize {
            focused ? 0.43 : 0.47
        } else {
            focused ? 0.49 : 0.54
        }
    }

    private var hasFocusedTextContent: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || placeName != nil || placeDetail != nil
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: focused ? 3 : 1) {
                Text(name)
                    .font(focused ? .title.weight(.semibold) : .headline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.7)

                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .font(focused ? .footnote.weight(.medium) : .caption2.weight(.medium))
                    .foregroundStyle(secondaryContentColor)
            }

            Spacer(minLength: 10)

            sequenceMedallion
        }
        .foregroundStyle(primaryContentColor)
    }

    @ViewBuilder
    private var footer: some View {
        if focused {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 1)

                Text("Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryContentColor)

                Text(note.isEmpty ? "No note yet." : note)
                    .font(.body)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                    .foregroundStyle(note.isEmpty ? secondaryContentColor : primaryContentColor)

                if let placeName {
                    focusedPlaceDetails(placeName: placeName, placeDetail: placeDetail)
                        .padding(.top, 1)
                }
            }
        } else {
            if let placeName {
                memoryPlacePill(placeName)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var sequenceMedallion: some View {
        Text(sequence.formatted())
            .font(.system(size: focused ? 16 : 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .foregroundStyle(primaryContentColor)
            .frame(width: focused ? 34 : 27, height: focused ? 34 : 27)
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
            radius: focused ? 7 : 3,
            y: focused ? 4 : 2
        )
        .accessibilityHidden(true)
    }

    private func focusedPlaceDetails(placeName: String, placeDetail: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            placeDetailRow(
                title: "Memory Place",
                icon: "mappin.and.ellipse",
                value: placeName
            )

            if let placeDetail {
                placeDetailRow(
                    title: "Place detail",
                    icon: "text.alignleft",
                    value: placeDetail
                )
            }
        }
    }

    private func placeDetailRow(title: String, icon: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryContentColor)

            Text(value)
                .font(.body)
                .foregroundStyle(primaryContentColor)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        }
        .accessibilityElement(children: .combine)
    }

    private func memoryPlacePill(_ placeName: String) -> some View {
        Label {
            Text(placeName)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(0.76)
        } icon: {
            Image(systemName: "mappin.and.ellipse")
                .font(.caption.weight(.bold))
        }
        .font(focused ? .footnote.weight(.semibold) : .caption2.weight(.semibold))
        .foregroundStyle(primaryContentColor)
        .padding(.horizontal, focused ? 12 : 9)
        .padding(.vertical, focused ? 8 : 6)
        .background(
            pillFill,
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(pillStroke, lineWidth: 1)
        )
        .accessibilityLabel("Memory Place, \(placeName)")
    }

    private var imageStage: some View {
        RoundedRectangle(cornerRadius: focused ? 26 : (stylePreview ? 18 : 16), style: .continuous)
            .fill(CatLocalTheme.elevatedSurface.opacity(focused ? 0.62 : (stylePreview ? 0.3 : 0.48)))
            .overlay(
                RoundedRectangle(cornerRadius: focused ? 26 : (stylePreview ? 18 : 16), style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var surface: some View {
        switch cardStyle {
        case .prism:
            prismSurface
        case .gold:
            goldSurface
        case .topo:
            topoSurface
        default:
            standardSurface
        }
    }

    private var standardSurface: some View {
        ZStack {
            CatLocalTheme.paperSurface(for: cardStyle)

            LinearGradient(
                colors: [
                    Color.white.opacity(focused ? 0.22 : 0.18),
                    CatLocalTheme.accent(for: cardStyle).opacity(focused ? 0.16 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var prismSurface: some View {
        ZStack {
            CatLocalTheme.paperSurface(for: .prism)

            AngularGradient(
                colors: prismColors,
                center: prismCenter,
                angle: .degrees(Double(effectiveRotateY - effectiveRotateX) * 2.4)
            )
            .opacity(0.8 * foilLightOpacity)
            .blendMode(.hardLight)
            .animation(.easeInOut(duration: 0.18), value: foilLightOpacity)
        }
    }

    private var goldSurface: some View {
        ZStack {
            CatLocalTheme.paperSurface(for: .gold)

            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.24, blue: 0.08).opacity(0.78),
                    Color(red: 0.98, green: 0.70, blue: 0.18),
                    Color.white.opacity(0.9),
                    Color(red: 0.75, green: 0.45, blue: 0.14),
                    Color(red: 0.34, green: 0.20, blue: 0.08).opacity(0.74)
                ],
                startPoint: goldStartPoint,
                endPoint: goldEndPoint
            )
            .opacity(0.86 * foilLightOpacity)
            .blendMode(.hardLight)
            .animation(.easeInOut(duration: 0.18), value: foilLightOpacity)

            RadialGradient(
                colors: [
                    Color.white,
                    .clear
                ],
                center: foilHotspot,
                startRadius: 0,
                endRadius: 170
            )
            .opacity(0.4 * foilLightOpacity)
            .blendMode(.screen)
            .animation(.easeInOut(duration: 0.18), value: foilLightOpacity)
        }
    }

    private var topoSurface: some View {
        ZStack {
            CatLocalTheme.paperSurface(for: .topo)

            if presentation == .thumbnail {
                topoFoilLayer
                    .opacity(0.16)
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
                    seed: positiveSeed,
                    lineCount: presentation == .thumbnail ? 10 : 16,
                    lineWidth: presentation == .thumbnail ? 0.85 : 1.2,
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

    private var topoMaskCenter: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.5 + effectiveRotateY / 24),
            y: clampedUnit(0.5 + (-effectiveRotateX / 24))
        )
    }

    private var topoColors: [Color] {
        let palettes: [[Color]] = [
            [.red, .yellow, .green, .pink],
            [.cyan, .yellow, .mint, .orange],
            [.pink, .green, .yellow, .blue],
            [.orange, .teal, .yellow, .red]
        ]
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
        .degrees(Double(positiveSeed % 360) + Double(effectiveRotateY - effectiveRotateX) * 3.2)
    }

    private var topoStartPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.12 + CGFloat((positiveSeed % 17)) / 64 + effectiveRotateY / 36),
            y: clampedUnit(0.1 + effectiveRotateX / 42)
        )
    }

    private var topoEndPoint: UnitPoint {
        UnitPoint(
            x: clampedUnit(0.88 - CGFloat((positiveSeed % 13)) / 72 + effectiveRotateY / 36),
            y: clampedUnit(0.92 + effectiveRotateX / 42)
        )
    }

    private var positiveSeed: Int {
        abs(topoSeed == Int.min ? 0 : topoSeed)
    }

    private func catImageOffset(cardWidth: CGFloat, cardHeight: CGFloat) -> CGSize {
        guard let catBoundingBox else { return .zero }
        return CGSize(
            width: (0.5 - catBoundingBox.midX) * cardWidth,
            height: (0.5 - catBoundingBox.midY) * cardHeight
        )
    }

    private func clampedUnit(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
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

struct CardStyleCarousel<Preview: View>: View {
    @Binding var selectedStyle: CardStyle
    let showsTitle: Bool
    let itemWidth: CGFloat
    let previewAspectRatio: CGFloat
    let itemPadding: CGFloat
    let itemCornerRadius: CGFloat
    let itemSpacing: CGFloat
    let titleMinHeight: CGFloat
    @State private var centeredItemID: Int?
    @State private var hapticStyle: CardStyle?

    @ViewBuilder let preview: (_ style: CardStyle) -> Preview

    init(
        selectedStyle: Binding<CardStyle>,
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
                    .font(.caption.weight(.semibold))
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
                .padding(.horizontal, 2)
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
                guard currentCenteredStyle != style else { return }
                withAnimation(.snappy(duration: 0.24)) {
                    centeredItemID = centeredItemID(for: style)
                }
            }
        }
    }

    private var styleCount: Int {
        CardStyle.allCases.count
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
                style: CardStyle.allCases[index % styleCount],
                cycle: index / styleCount
            )
        }
    }

    private var currentCenteredStyle: CardStyle? {
        guard let centeredItemID else { return nil }
        return carouselItems.first(where: { $0.id == centeredItemID })?.style
    }

    private func centeredItemID(for style: CardStyle) -> Int {
        let styleIndex = CardStyle.allCases.firstIndex(of: style) ?? 0
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

        return VStack(spacing: 9) {
            preview(style)
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .allowsHitTesting(false)

            Text(style.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? CatLocalTheme.primaryText : CatLocalTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(minHeight: titleMinHeight, alignment: .top)
        }
        .frame(width: itemWidth)
        .padding(itemPadding)
        .background(
            CatLocalTheme.cardSurface.opacity(isSelected ? 0.86 : 0.36),
            in: RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous)
        )
        .scaleEffect(isSelected ? 1 : 0.96)
        .shadow(
            color: CatLocalTheme.shadow.opacity(isSelected ? 0.22 : 0.06),
            radius: isSelected ? 14 : 5,
            y: isSelected ? 7 : 2
        )
        .contentShape(RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous))
        .onTapGesture {
            withAnimation(.snappy(duration: 0.24)) {
                selectedStyle = style
                centeredItemID = centeredItemID(for: style)
            }
            playSelectionHaptic(for: style)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.title) card design")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func playSelectionHaptic(for style: CardStyle) {
        guard hapticStyle != style else { return }
        hapticStyle = style
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

struct CardStyleSwatch: View {
    let style: CardStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CatLocalTheme.paperSurface(for: style))

            swatchOverlay

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(contentColor.opacity(0.16))
                        .frame(width: 20, height: 20)
                        .overlay {
                            Text("1")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(contentColor)
                        }

                    Spacer()

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(contentColor.opacity(0.22))
                        .frame(width: 28, height: 5)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var swatchOverlay: some View {
        switch style {
        case .archive:
            LinearGradient(
                colors: [
                    CatLocalTheme.accent(for: style).opacity(0.22),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunstamp:
            RadialGradient(
                colors: [
                    CatLocalTheme.warning.opacity(0.48),
                    CatLocalTheme.warning.opacity(0.10),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 92
            )
        case .clear:
            LinearGradient(
                colors: [
                    CatLocalTheme.blueAction.opacity(0.20),
                    Color.white.opacity(0.22),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .garden:
            LinearGradient(
                colors: [
                    CatLocalTheme.positive.opacity(0.24),
                    CatLocalTheme.sage.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnight:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    CatLocalTheme.blueAction.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .apricot:
            LinearGradient(
                colors: [
                    CatLocalTheme.warning.opacity(0.26),
                    CatLocalTheme.cardSurface.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .prism:
            AngularGradient(
                colors: [.cyan, .pink, .yellow, .blue, .purple, .cyan],
                center: .center
            )
            .opacity(0.78)
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
        case .topo:
            ZStack {
                AngularGradient(
                    colors: [.orange, .teal, .yellow, .pink, .orange],
                    center: .center
                )
                .opacity(0.35)
                .blendMode(.plusLighter)

                TopoContourLayer(
                    seed: 17,
                    lineCount: 8,
                    lineWidth: 0.8,
                    gradient: LinearGradient(
                        colors: [.white.opacity(0.72), .yellow.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.72)
                .blendMode(.plusLighter)
            }
        }
    }

    private var contentColor: Color {
        switch style {
        case .midnight, .prism, .gold, .topo:
            .white
        default:
            CatLocalTheme.primaryText
        }
    }
}

private struct CarouselStyleItem: Identifiable {
    let id: Int
    let style: CardStyle
    let cycle: Int
}
