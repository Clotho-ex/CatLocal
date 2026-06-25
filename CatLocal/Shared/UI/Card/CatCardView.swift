import SwiftUI

struct CatCardView: View {
    let record: CatRecord
    var presentation: CatCardPresentation = .thumbnail
    var cardStyle: CardStyle?
    var rotateX: CGFloat = 0
    var rotateY: CGFloat = 0

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
            rotateY: rotateY
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
            rotateY: rotateY
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
    @ViewBuilder let catImage: () -> CatImage

    private var focused: Bool { presentation == .focused }
    private var stylePreview: Bool { presentation == .stylePreview }
    private var effectiveRotateX: CGFloat { focused ? rotateX : 0 }
    private var effectiveRotateY: CGFloat { focused ? rotateY : 0 }
    private var needsFoilContrast: Bool { cardStyle == .midnight || cardStyle == .prism }

    private var primaryContentColor: Color {
        guard needsFoilContrast else { return CatLocalTheme.primaryText }
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

            Group {
                if stylePreview {
                    ZStack {
                        imageStage

                        catImage()
                            .scaledToFit()
                            .frame(
                                maxWidth: imageMaxWidth,
                                maxHeight: max(cardHeight - outerPadding * 2, 1),
                                alignment: .center
                            )
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
            .opacity(0.8)
            .blendMode(.hardLight)
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
            .opacity(0.86)
            .blendMode(.hardLight)

            RadialGradient(
                colors: [
                    Color.white,
                    .clear
                ],
                center: foilHotspot,
                startRadius: 0,
                endRadius: 170
            )
            .opacity(0.4)
            .blendMode(.screen)
        }
    }

    private var topoSurface: some View {
        ZStack {
            CatLocalTheme.paperSurface(for: .topo)

            if presentation == .thumbnail {
                TopographicPatternView()
                    .opacity(0.18)
            } else {
                TopographicPatternView()
                    .overlay {
                        LinearGradient(
                            colors: [
                                .red,
                                .yellow,
                                .green,
                                .pink
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.sourceAtop)
                    }
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
            }
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

    private func clampedUnit(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

private struct TopographicPatternView: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maximumRadius = min(size.width, size.height) * 0.58
            let contourCount = 18

            for contourIndex in 0..<contourCount {
                var path = Path()
                let progress = CGFloat(contourIndex + 1) / CGFloat(contourCount + 1)
                let baseRadius = maximumRadius * progress

                for angleDegrees in stride(from: 0.0, through: 360.0, by: 4.0) {
                    let angle = angleDegrees * .pi / 180
                    let index = Double(contourIndex)
                    let waveA = sin(angle * 3.0 + index * 0.55)
                    let waveB = cos(angle * 5.0 - index * 0.38)
                    let waveC = sin(angle * 2.0 + index * 1.15)
                    let distortion = CGFloat(waveA * 8.0 + waveB * 5.0 + waveC * 3.0)
                    let radius = max(baseRadius + distortion, 4)
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
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.8)),
                    lineWidth: 1.2
                )
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

struct CardStyleCarousel<Preview: View>: View {
    @Binding var selectedStyle: CardStyle
    let showsTitle: Bool
    @State private var centeredStyle: CardStyle?

    @ViewBuilder let preview: (_ style: CardStyle) -> Preview

    init(
        selectedStyle: Binding<CardStyle>,
        showsTitle: Bool = true,
        @ViewBuilder preview: @escaping (_ style: CardStyle) -> Preview
    ) {
        _selectedStyle = selectedStyle
        self.showsTitle = showsTitle
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
                LazyHStack(spacing: 14) {
                    ForEach(CardStyle.allCases) { style in
                        styleOption(style)
                            .id(style)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredStyle)
            .onAppear {
                centeredStyle = selectedStyle
            }
            .onChange(of: centeredStyle) { _, style in
                guard let style, style != selectedStyle else { return }
                selectedStyle = style
            }
            .onChange(of: selectedStyle) { _, style in
                guard centeredStyle != style else { return }
                withAnimation(.snappy(duration: 0.24)) {
                    centeredStyle = style
                }
            }
        }
    }

    private func styleOption(_ style: CardStyle) -> some View {
        let isSelected = style == selectedStyle

        return VStack(spacing: 9) {
            preview(style)
                .aspectRatio(0.64, contentMode: .fit)
                .allowsHitTesting(false)

            Text(style.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? CatLocalTheme.primaryText : CatLocalTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(minHeight: 34, alignment: .top)
        }
        .frame(width: 184)
        .padding(8)
        .background(
            CatLocalTheme.cardSurface.opacity(isSelected ? 0.86 : 0.36),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .scaleEffect(isSelected ? 1 : 0.96)
        .shadow(
            color: CatLocalTheme.shadow.opacity(isSelected ? 0.22 : 0.06),
            radius: isSelected ? 14 : 5,
            y: isSelected ? 7 : 2
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            withAnimation(.snappy(duration: 0.24)) {
                selectedStyle = style
                centeredStyle = style
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.title) card design")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
