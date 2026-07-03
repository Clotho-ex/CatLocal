import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Query private var existingRecords: [CatRecord]

    @StateObject private var camera = CameraController()
    @State private var stage: CaptureStage = .camera
    @State private var photoItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var cutoutImage: UIImage?
    @State private var detections: [CatDetection] = []
    @State private var selectedBoundingBox: CGRect?
    @State private var source: CaptureSource = .camera
    @State private var nickname = ""
    @State private var note = ""
    @State private var placeName = ""
    @State private var placeDetail = ""
    @State private var selectedStyle: CardStyle = .archive
    @State private var draftGreeting = ""
    @State private var draftSequence: Int?
    @State private var persistedRecord: CatRecord?
    @State private var errorMessage: String?
    @State private var canUseForegroundFallback = false
    @State private var isProcessingCapture = false
    @State private var isSaving = false
    @State private var isEditorSheetPresented = false
    @State private var stickerBaseOffset: CGSize = .zero
    @GestureState private var stickerDragTranslation: CGSize = .zero
    @State private var isCardMintingDone = false
    @State private var captureSelectionFeedbackTrigger = 0
    @State private var captureWarningFeedbackTrigger = 0
    @FocusState private var focusedEditorField: EditorField?

    private let processor = CatVisionProcessor()

    var body: some View {
        ZStack {
            switch stage {
            case .camera:
                cameraScreen
            case .analyzing, .creatingCutout:
                processingScreen
            case .choosingCat:
                catSelectionScreen
            case .stickerReveal:
                stickerRevealScreen
            case .stickerInspecting:
                stickerInspectionScreen
            case .cardCelebrating:
                cardCelebrationScreen
            case .failure:
                failureScreen
            }
        }
        .task {
            await camera.requestAccessAndConfigure()
            if camera.authorizationStatus == .authorized {
                camera.start()
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .sheet(isPresented: $isEditorSheetPresented) {
            editorSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(CatLocalTheme.background)
                .presentationContentInteraction(.resizes)
                .presentationBackgroundInteraction(.disabled)
                .interactiveDismissDisabled(true)
        }
        .onDisappear { camera.stop() }
        .interactiveDismissDisabled(stage != .camera)
        .sensoryFeedback(.selection, trigger: captureSelectionFeedbackTrigger)
        .sensoryFeedback(.warning, trigger: captureWarningFeedbackTrigger)
    }

    private var cameraScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isConfigured {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                cameraUnavailableBackground
            }

            LinearGradient(
                colors: [.black.opacity(0.56), .clear, .black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                cameraTopBar
                Spacer()
                cameraGuidance
                cameraControls
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .accessibilityIdentifier("capture-screen")
    }

    private var cameraTopBar: some View {
        CatGlassGroup(spacing: 18) {
            HStack {
                Label("On-device only", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .catSingleActionPillSurface()

                Spacer()

                Button {
                    closeCamera()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .catSingleActionIconSurface()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close camera")
            }
        }
    }

    private var cameraGuidance: some View {
        VStack(spacing: 7) {
            Text("Give them a little room")
                .font(.title3.weight(.semibold))
                .lineLimit(nil)
            Text("Keep the whole cat visible for the cleanest cutout.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(nil)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.bottom, 20)
    }

    private var cameraControls: some View {
        CatGlassGroup(spacing: 18) {
            VStack(spacing: 14) {
                HStack {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .catSingleActionIconSurface()
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessingCapture)
                    .opacity(isProcessingCapture ? 0.45 : 1)
                    .accessibilityLabel("Add Photo")
                    .accessibilityHint("The selected photo stays on this iPhone")

                    Spacer(minLength: 12)

                    Button {
                        captureCameraPhoto()
                    } label: {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 82, height: 82)
                            .overlay {
                                Circle()
                                    .fill(.white)
                                    .padding(8)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTakePhoto)
                    .opacity(canTakePhoto ? 1 : 0.45)
                    .accessibilityLabel("Take photo")

                    Spacer(minLength: 12)

                    Color.clear
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                }

                #if DEBUG
                if showsValidationImport {
                    Button {
                        Task { await loadValidationPhoto() }
                    } label: {
                        Label("Use validation photo", systemImage: "wand.and.stars")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .catGlass(cornerRadius: 20, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessingCapture)
                    .opacity(isProcessingCapture ? 0.45 : 1)
                }
                #endif
            }
        }
    }

    private var cameraUnavailableBackground: some View {
        VStack(spacing: 15) {
            Image(systemName: camera.authorizationStatus == .denied ? "camera.fill.badge.xmark" : "camera.aperture")
                .font(.system(size: 58, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.9))

            if camera.authorizationStatus == .denied || camera.authorizationStatus == .restricted {
                Text("Camera access is off")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("You can still choose a private photo, or enable camera access in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: 300)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .tint(CatLocalTheme.warning)
            } else if let cameraError = camera.errorMessage {
                Text(cameraError)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 300)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var processingScreen: some View {
        ZStack {
            CatLocalTheme.primaryText.ignoresSafeArea()

            if let originalImage {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.12)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 18) {
                Image(systemName: stage == .analyzing ? "viewfinder" : "scissors")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text(stage == .analyzing ? "Looking for cats" : "Lifting the subject")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("This happens entirely on your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stage == .analyzing ? "Looking for cats" : "Creating cat cutout")
    }

    private var stickerRevealScreen: some View {
        Group {
            if let cutoutImage {
                DustingRevealView(image: cutoutImage) {
                    guard stage == .stickerReveal else { return }
                    stage = .stickerInspecting
                }
            } else {
                processingScreen
            }
        }
    }

    private var catSelectionScreen: some View {
        ZStack {
            CatLocalBackground()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button("Retake") { reset() }
                        Spacer()
                        Label("\(detections.count) cats found", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CatLocalTheme.primaryText)
                    }

                    if let originalImage {
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Which cat should CatLocal save?")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(CatLocalTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Choose one subject. The photo still stays private.")
                            .font(.subheadline)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    CatGlassGroup(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                                Button {
                                    Task { await createCutout(for: detection) }
                                } label: {
                                    HStack {
                                        Image(systemName: "cat.fill")
                                        Text("Cat \(index + 1)")
                                        Spacer()
                                        Text("\(Int(detection.confidence * 100))%")
                                            .foregroundStyle(CatLocalTheme.secondaryText)
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.headline)
                                    .foregroundStyle(CatLocalTheme.primaryText)
                                    .padding(.horizontal, 18)
                                    .frame(minHeight: 56)
                                    .catGlass(cornerRadius: 20, interactive: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(CatLocalTheme.screenHorizontalPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var stickerInspectionScreen: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 14) {
                editorTopBar
                    .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                if let cutoutImage {
                    draggableSticker(cutoutImage)
                }

                Spacer(minLength: 0)

                customizeButton
                    .padding(.bottom, 18)
            }
        }
    }

    private var customizeButton: some View {
        Button {
            expandEditor()
        } label: {
            Label("Tap to Customize", systemImage: "slider.horizontal.3")
                .font(.headline.weight(.semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .catGlass(cornerRadius: 24, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tap-to-customize")
    }

    private func draggableSticker(_ image: UIImage) -> some View {
        GeometryReader { proxy in
            let activeOffset = CGSize(
                width: stickerBaseOffset.width + stickerDragTranslation.width,
                height: stickerBaseOffset.height + stickerDragTranslation.height
            )

            StickerCutoutView(
                image: image,
                appliesMotion: !reduceMotion
            )
            .frame(maxWidth: 270, maxHeight: 330)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .offset(activeOffset)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($stickerDragTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        stickerBaseOffset = clampedStickerOffset(
                            CGSize(
                                width: stickerBaseOffset.width + value.translation.width,
                                height: stickerBaseOffset.height + value.translation.height
                            )
                        )
                    }
            )
            .accessibilityLabel("Cat sticker preview")
        }
        .frame(height: 390)
    }

    private func clampedStickerOffset(_ offset: CGSize) -> CGSize {
        CGSize(
            width: min(max(offset.width, -120), 120),
            height: min(max(offset.height, -170), 150)
        )
    }

    private var editorSheet: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                CatLocalBackground()
                    .onTapGesture {
                        dismissEditorKeyboard()
                    }

                editorForm

                editorSheetActionButton
                    .padding(.top, 14)
                    .padding(.trailing, CatLocalTheme.screenHorizontalPadding)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                editorSheetSaveButton
            }
        }
        .accessibilityIdentifier("sticker-editor-sheet")
    }

    private var editorSheetActionButton: some View {
        CatSheetActionButton(mode: .close) {
            collapseEditor()
        }
        .accessibilityIdentifier("sticker-editor-sheet-action")
    }

    private var editorSheetSaveButton: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return Button {
            dismissEditorKeyboard()
            Task { await finishCustomization() }
        } label: {
            HStack(spacing: 9) {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .tint(CatLocalTheme.primaryText)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.semibold))
                        .accessibilityHidden(true)
                }

                Text(isSaving ? "Saving" : "Save Cat")
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(CatLocalTheme.primaryText)
            .frame(maxWidth: .infinity)
            .contentShape(shape)
            .catSingleActionPillSurface()
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .disabled(isSaving)
        .accessibilityLabel(isSaving ? "Saving Cat" : "Save Cat")
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                makeItYoursHeading

                Text("Pick a card for this sticker, then add the details you want to remember.")
                    .font(.callout)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                editorCardPreview

                CardStyleCarousel(
                    selectedStyle: $selectedStyle,
                    showsTitle: false,
                    itemWidth: 154,
                    previewAspectRatio: 1.28,
                    itemPadding: 6,
                    itemCornerRadius: 22,
                    itemSpacing: 12,
                    titleMinHeight: 20
                ) { style in
                    CardStyleSwatch(style: style)
                }
                .accessibilityLabel("Card design")
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissEditorKeyboard()
                    }
                )

                editorFieldHeading("Name the Cat")

                TextField("Nickname (optional)", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .focused($focusedEditorField, equals: .nickname)
                    .catInputSurface()

                editorFieldHeading("Catlas")

                TextField("Memory Place (optional)", text: $placeName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedEditorField, equals: .placeName)
                    .catInputSurface()
                    .accessibilityHint("Adds a manual place label to the private Catlas")

                TextField("Place Detail (optional)", text: $placeDetail, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedEditorField, equals: .placeDetail)
                    .catInputSurface()

                editorFieldHeading("Encounter Note")

                TextField("A note about this encounter", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedEditorField, equals: .note)
                    .catInputSurface()

                catlasPrivacyNote
            }
            .padding(18)
            .padding(.top, 52)
            .padding(.bottom, 108)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissEditorKeyboard()
                    }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var editorCardPreview: some View {
        if let cutoutImage {
            DraftCatCardView(
                image: cutoutImage,
                sequence: activeSequence,
                name: editorPreviewName,
                note: note,
                placeName: placeName,
                placeDetail: placeDetail,
                cardStyle: selectedStyle,
                presentation: .focused,
                showsFooter: true,
                catBoundingBox: selectedBoundingBox,
                topoSeed: activeSequence,
                appliesStickerEffect: true,
                stickerMotionIntensity: nil
            )
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .animation(.smooth(duration: 0.22, extraBounce: 0), value: selectedStyle)
            .accessibilityLabel("Live card preview")
        }
    }

    private var makeItYoursHeading: some View {
        (
            Text("Make it ")
                .foregroundStyle(CatLocalTheme.primaryText)
            + Text("Yours")
                .foregroundStyle(CatLocalTheme.warning)
        )
        .font(.title2.weight(.semibold))
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Make it Yours")
    }

    private var celebrationPreviewNote: String {
        persistedRecord?.note ?? note
    }

    private var celebrationPreviewPlaceName: String {
        persistedRecord?.placeName ?? placeName
    }

    private var celebrationPreviewPlaceDetail: String {
        persistedRecord?.placeDetail ?? placeDetail
    }

    private var celebrationPreviewStyle: CardStyle {
        persistedRecord?.cardStyle ?? selectedStyle
    }

    private var celebrationPreviewBoundingBox: CGRect? {
        persistedRecord?.catBoundingBox ?? selectedBoundingBox
    }

    private var celebrationPreviewTopoSeed: Int {
        persistedRecord?.sequence ?? activeSequence
    }

    private var cardCelebrationScreen: some View {
        Group {
            if let cutoutImage {
                CardMintingSuccessView(
                    isCustomizationDone: $isCardMintingDone,
                    showsCustomizationPanel: false,
                    onHome: {
                        dismiss()
                    },
                    onKeepEditing: {
                        expandEditor()
                    }
                ) { mintingSheen in
                    LiveInteractiveCardView(
                        width: nil,
                        height: nil,
                        cornerRadius: 34
                    ) { rotateX, rotateY, isInteracting in
                        DraftCatCardView(
                            image: cutoutImage,
                            sequence: activeSequence,
                            name: celebrationPreviewName,
                            note: celebrationPreviewNote,
                            placeName: celebrationPreviewPlaceName,
                            placeDetail: celebrationPreviewPlaceDetail,
                            cardStyle: celebrationPreviewStyle,
                            presentation: .focused,
                            rotateX: rotateX,
                            rotateY: rotateY,
                            isLightActive: isInteracting,
                            showsFooter: true,
                            catBoundingBox: celebrationPreviewBoundingBox,
                            topoSeed: celebrationPreviewTopoSeed,
                            appliesStickerEffect: true,
                            stickerMotionIntensity: nil
                        )
                        .overlay {
                            if mintingSheen.isVisible {
                                mintingSheen
                                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                            }
                        }
                    }
                    .aspectRatio(0.64, contentMode: .fit)
                }
            } else {
                processingScreen
            }
        }
    }

    private var editorTopBar: some View {
        CatGlassGroup(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    editorTopBarButton(accessibilityLabel: "Cancel", systemImage: "xmark", action: cancelCapture)
                    Spacer()
                    editorStageTitle
                    Spacer()
                    editorTopBarButton(accessibilityLabel: "Retake", systemImage: "arrow.counterclockwise", action: reset)
                }

                VStack(spacing: 10) {
                    HStack {
                        editorTopBarButton(accessibilityLabel: "Cancel", systemImage: "xmark", action: cancelCapture)
                        Spacer()
                        editorTopBarButton(accessibilityLabel: "Retake", systemImage: "arrow.counterclockwise", action: reset)
                    }
                    editorStageTitle
                }
            }
        }
    }

    private func editorTopBarButton(
        accessibilityLabel: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(CatLocalTheme.primaryText)
                .catSingleActionIconSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var editorStageTitle: some View {
        VStack(spacing: 2) {
            Text("A New Cat")
                .font(.headline)
                .foregroundStyle(CatLocalTheme.primaryText)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var catlasPrivacyNote: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(CatLocalTheme.warning.opacity(0.28))

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text("Manual label only. CatLocal does not request GPS or save coordinates.")
                .font(.callout.weight(.medium))
                .foregroundStyle(CatLocalTheme.primaryText)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(CatLocalTheme.warning.opacity(0.22))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(CatLocalTheme.warning.opacity(0.55), lineWidth: 1)
        )
    }

    private func editorFieldHeading(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(CatLocalTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private var failureScreen: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 0) {
                failureTopBar
                    .padding(.top, 10)

                Spacer(minLength: 32)

                VStack(spacing: 22) {
                    Image(systemName: "viewfinder.circle")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(CatLocalTheme.warning)

                    VStack(spacing: 8) {
                        Text("That one was tricky")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(CatLocalTheme.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                        Text(errorMessage ?? "CatLocal could not create a clean cat cutout from this photo.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                            .frame(maxWidth: 320)
                            .lineLimit(nil)
                    }

                    if originalImage != nil, canUseForegroundFallback {
                        foregroundFallbackControls
                    }
                }

                Spacer(minLength: 48)
            }
            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
    }

    private var failureTopBar: some View {
        CatGlassGroup(spacing: 18) {
            HStack {
                Button {
                    reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .catSingleActionIconSurface()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Try another photo")

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                        .catSingleActionIconSurface()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
    }

    private var foregroundFallbackControls: some View {
        VStack(spacing: 12) {
            Button {
                Task { await createCutout(for: nil) }
            } label: {
                Label("Use Cutout Anyway", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(.plain)
            .catPrimaryActionSurface(cornerRadius: 26)
            .frame(maxWidth: 320)
            .accessibilityHint("Uses the foreground cutout even though CatLocal could not confirm a cat")

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.information)

                VStack(alignment: .leading, spacing: 3) {
                    Text("CatLocal could not confirm a cat in this photo.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)

                    Text("You can still use the foreground cutout and edit the card before saving.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: 320, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(CatLocalTheme.cardSurface.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(CatLocalTheme.imageOutline, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
        }
    }

    private var nextSequence: Int {
        (existingRecords.map(\.sequence).max() ?? 0) + 1
    }

    private var canTakePhoto: Bool {
        camera.isConfigured && !isProcessingCapture && stage == .camera
    }

    private var activeSequence: Int {
        persistedRecord?.sequence ?? draftSequence ?? nextSequence
    }

    #if DEBUG
    private var showsValidationImport: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-import-fixture")
    }

    private var usesSyntheticValidationPhoto: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-synthetic-photo")
    }

    private var bypassesVisionForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-synthetic-cutout")
    }

    private var forcesForegroundFallbackForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-force-foreground-fallback")
    }

    private var skipsStickerRevealForValidation: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-skip-sticker-reveal")
    }

    private var prefillsValidationEditorFields: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-prefill-editor-fields")
    }

    private func prefillValidationEditorFields() {
        nickname = "Pixel"
        placeName = "Rooftop"
        placeDetail = "South ledge"
        note = "Warm orange hello."
    }

    private func loadValidationPhoto() async {
        guard beginCaptureInput() else { return }
        do {
            if usesSyntheticValidationPhoto {
                await accept(image: Self.validationFixtureImage(), source: .photoLibrary)
                return
            }

            let url = try validationPhotoURL()
            let data = try Data(contentsOf: url)
            let image = try await optimizedWorkingImage(from: data)
            await accept(image: image, source: .photoLibrary)
        } catch {
            finishCaptureInput()
            fail(with: "The validation photo could not be opened. Copy it into Documents/CatLocalValidation/cat.png and try again.")
        }
    }

    private func validationPhotoURL() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return documents
            .appendingPathComponent("CatLocalValidation", isDirectory: true)
            .appendingPathComponent("cat.png")
    }

    private static func validationFixtureImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 900, height: 900), format: format).image { context in
            UIColor(red: 0.93, green: 0.88, blue: 0.78, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 900))
            UIColor(red: 0.16, green: 0.11, blue: 0.08, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 260, y: 250, width: 380, height: 420))
            context.cgContext.fillEllipse(in: CGRect(x: 310, y: 145, width: 280, height: 250))
        }
    }

    private static func validationCutoutImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 720, height: 720), format: format).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 720, height: 720))
            UIColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 210, y: 220, width: 300, height: 330))
            context.cgContext.fillEllipse(in: CGRect(x: 250, y: 120, width: 220, height: 210))
            context.cgContext.move(to: CGPoint(x: 276, y: 160))
            context.cgContext.addLine(to: CGPoint(x: 322, y: 64))
            context.cgContext.addLine(to: CGPoint(x: 360, y: 164))
            context.cgContext.closePath()
            context.cgContext.fillPath()
            context.cgContext.move(to: CGPoint(x: 400, y: 164))
            context.cgContext.addLine(to: CGPoint(x: 444, y: 64))
            context.cgContext.addLine(to: CGPoint(x: 476, y: 160))
            context.cgContext.closePath()
            context.cgContext.fillPath()
        }
    }
    #endif

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard beginCaptureInput() else {
            photoItem = nil
            return
        }

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self)
            else {
                throw CatVisionError.unreadableImage
            }
            let image = try await optimizedWorkingImage(from: data)
            await accept(image: image, source: .photoLibrary)
        } catch {
            finishCaptureInput()
            fail(with: "This photo could not be opened. Try another image.")
        }
    }

    private func accept(image: UIImage, source: CaptureSource) async {
        if !isProcessingCapture {
            isProcessingCapture = true
        }
        defer { finishCaptureInput() }

        camera.stop()
        originalImage = image
        self.source = source
        draftSequence = nextSequence
        persistedRecord = nil
        detections = []
        selectedBoundingBox = nil
        errorMessage = nil
        canUseForegroundFallback = false
        resetStickerTransform()
        stage = .analyzing

        do {
            #if DEBUG
            if forcesForegroundFallbackForValidation {
                canUseForegroundFallback = true
                fail(with: CatVisionError.noCat.localizedDescription)
                return
            }

            if bypassesVisionForValidation {
                let detection = CatDetection(
                    boundingBox: CGRect(x: 0.24, y: 0.18, width: 0.52, height: 0.66),
                    confidence: 0.99
                )
                detections = [detection]
                beginStickerReveal(
                    cutout: Self.validationCutoutImage(),
                    detection: detection
                )
                return
            }
            #endif

            let found = try await processor.detectCats(in: SendableImage(value: image))
            switch CatDetectionSelector.resolve(found) {
            case .none:
                detections = []
                canUseForegroundFallback = true
                fail(with: CatVisionError.noCat.localizedDescription)
            case .single(let detection):
                detections = [detection]
                stage = .creatingCutout
                let result = try await processor.cutout(
                    from: SendableImage(value: image),
                    detection: detection
                )
                beginStickerReveal(
                    cutout: result.value,
                    detection: detection
                )
            case .multiple(let detections):
                self.detections = detections
                canUseForegroundFallback = false
                stage = .choosingCat
            }
        } catch {
            canUseForegroundFallback = false
            fail(with: CatVisionError.processingUnavailable.localizedDescription)
        }
    }

    private func beginStickerReveal(cutout: UIImage, detection: CatDetection?) {
        selectedBoundingBox = detection?.boundingBox
        cutoutImage = cutout
        draftGreeting = Self.randomDraftGreeting()
        #if DEBUG
        if prefillsValidationEditorFields {
            prefillValidationEditorFields()
        }
        #endif
        errorMessage = nil
        isEditorSheetPresented = false
        resetStickerTransform()
        isCardMintingDone = false
        persistedRecord = nil
        captureSelectionFeedbackTrigger += 1
        #if DEBUG
        if skipsStickerRevealForValidation {
            stage = .stickerInspecting
            return
        }
        #endif
        stage = .stickerReveal
    }

    private func resetStickerTransform() {
        stickerBaseOffset = .zero
    }

    private func expandEditor() {
        captureSelectionFeedbackTrigger += 1
        isEditorSheetPresented = true
    }

    private func collapseEditor() {
        dismissEditorKeyboard()
        isEditorSheetPresented = false
    }

    private func dismissEditorKeyboard() {
        if focusedEditorField != nil {
            focusedEditorField = nil
        }
    }

    private func createCutout(for detection: CatDetection?) async {
        guard let originalImage else {
            fail(with: CatVisionError.unreadableImage.localizedDescription)
            return
        }

        stage = .creatingCutout
        do {
            let result = try await processor.cutout(
                from: SendableImage(value: originalImage),
                detection: detection
            )
            beginStickerReveal(
                cutout: result.value,
                detection: detection
            )
        } catch {
            canUseForegroundFallback = false
            fail(with: error.localizedDescription)
        }
    }

    private func finishCustomization() async {
        guard !isSaving else { return }
        let shouldCelebrateSave = isInitialCardDesignSave || stage == .cardCelebrating
        isSaving = true
        do {
            persistedRecord = try await persistCard()
            isSaving = false
            focusedEditorField = nil
            isEditorSheetPresented = false
            if shouldCelebrateSave {
                isCardMintingDone = true
                stage = .cardCelebrating
            } else {
                dismiss()
            }
        } catch {
            isSaving = false
            fail(with: error.localizedDescription)
        }
    }

    private var isInitialCardDesignSave: Bool {
        persistedRecord == nil
    }

    @discardableResult
    private func persistCard() async throws -> CatRecord {
        if let persistedRecord {
            applyDraft(to: persistedRecord)
            try modelContext.save()
            return persistedRecord
        }

        guard let originalImage, let cutoutImage else {
            throw CatVisionError.unreadableImage
        }

        let id = UUID()
        let stored = try await CatImageStore.shared.save(
            id: id,
            original: SendableImage(value: originalImage),
            cutout: SendableImage(value: cutoutImage)
        )
        let record = CatRecord(
            id: id,
            sequence: activeSequence,
            nickname: savedNickname,
            note: note,
            placeName: trimmedMemoryText(placeName),
            placeDetail: trimmedMemoryText(placeDetail),
            source: source,
            cardStyle: selectedStyle,
            styleSeed: 0,
            catBoundingBox: selectedBoundingBox,
            originalImagePath: stored.originalPath,
            cutoutImagePath: stored.cutoutPath,
            thumbnailImagePath: stored.thumbnailPath
        )
        do {
            modelContext.insert(record)
            try modelContext.save()
        } catch {
            modelContext.delete(record)
            try? await CatImageStore.shared.deleteRecord(id: id)
            throw error
        }
        return record
    }

    private func applyDraft(to record: CatRecord) {
        let trimmedName = trimmedMemoryText(nickname)
        if !trimmedName.isEmpty {
            record.nickname = trimmedName
        }
        record.note = note
        record.placeName = trimmedMemoryText(placeName)
        record.placeDetail = trimmedMemoryText(placeDetail)
        record.cardStyle = selectedStyle
    }

    private func fail(with message: String) {
        isProcessingCapture = false
        errorMessage = message
        captureWarningFeedbackTrigger += 1
        stage = .failure
    }

    private func closeCamera() {
        isProcessingCapture = false
        camera.stop()
        dismiss()
    }

    private func cancelCapture() {
        isProcessingCapture = false
        camera.stop()
        dismiss()
    }

    private func captureCameraPhoto() {
        guard beginCaptureInput() else { return }

        camera.capture { result in
            switch result {
            case .success(let image):
                Task {
                    let optimizedImage = await optimizedWorkingImage(
                        from: SendableImage(value: image)
                    )
                    await accept(
                        image: optimizedImage,
                        source: .camera
                    )
                }
            case .failure(let error):
                finishCaptureInput()
                fail(with: error.localizedDescription)
            }
        }
    }

    private func beginCaptureInput() -> Bool {
        guard !isProcessingCapture, stage == .camera else { return false }
        isProcessingCapture = true
        return true
    }

    private func finishCaptureInput() {
        isProcessingCapture = false
    }

    private func optimizedWorkingImage(from data: Data) async throws -> UIImage {
        let result = try await Task.detached(priority: .userInitiated) { () throws -> SendableImage in
            guard let image = UIImage(data: data) else {
                throw CatVisionError.unreadableImage
            }
            return SendableImage(
                value: CatImageStore.downsampledOpaqueImage(
                    from: image,
                    maximumDimension: CatImageStore.originalMaximumDimension
                )
            )
        }.value
        return result.value
    }

    private func optimizedWorkingImage(from image: SendableImage) async -> UIImage {
        let result = await Task.detached(priority: .userInitiated) {
            SendableImage(
                value: CatImageStore.downsampledOpaqueImage(
                    from: image.value,
                    maximumDimension: CatImageStore.originalMaximumDimension
                )
            )
        }.value
        return result.value
    }

    private func reset() {
        originalImage = nil
        cutoutImage = nil
        detections = []
        selectedBoundingBox = nil
        nickname = ""
        note = ""
        placeName = ""
        placeDetail = ""
        selectedStyle = .archive
        draftGreeting = ""
        draftSequence = nil
        persistedRecord = nil
        photoItem = nil
        errorMessage = nil
        canUseForegroundFallback = false
        isProcessingCapture = false
        isSaving = false
        isEditorSheetPresented = false
        resetStickerTransform()
        isCardMintingDone = false
        stage = .camera
        if camera.authorizationStatus == .authorized {
            camera.start()
        }
    }

    private func trimmedMemoryText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var savedNickname: String {
        let trimmedName = trimmedMemoryText(nickname)
        guard trimmedName.isEmpty else { return trimmedName }

        let existingNames = Set(existingRecords.map(\.displayName))
        return CatNamePool.randomName(excluding: existingNames)
    }

    private var editorPreviewName: String {
        let trimmedName = trimmedMemoryText(nickname)
        guard trimmedName.isEmpty else { return trimmedName }
        return draftGreeting.isEmpty ? Self.randomDraftGreeting() : draftGreeting
    }

    private var celebrationPreviewName: String {
        persistedRecord?.displayName ?? editorPreviewName
    }

    private static func randomDraftGreeting() -> String {
        draftGreetings.randomElement() ?? "A New Feline."
    }

    private static let draftGreetings = [
        "A New Feline.",
        "Who Is This Cat?",
        "Tiny Local Legend",
        "Fresh Pawprint",
        "Mystery Whiskers",
        "Hello, Fur Ball"
    ]
}

private enum CaptureStage: Equatable {
    case camera
    case analyzing
    case choosingCat
    case creatingCutout
    case stickerReveal
    case stickerInspecting
    case cardCelebrating
    case failure
}

private enum EditorField: Hashable {
    case nickname
    case note
    case placeName
    case placeDetail
}
