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
    @Environment(\.openURL) private var openURL
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
    @State private var draftSuggestedName = ""
    @State private var draftSequence: Int?
    @State private var persistedRecord: CatRecord?
    @State private var errorMessage: String?
    @State private var canUseForegroundFallback = false
    @State private var failureContext: LociContext = .failureRecovery
    @State private var isProcessingCapture = false
    @State private var isSaving = false
    @State private var isEditorSheetPresented = false
    @State private var isSavedCardDraftLoaded = false
    @State private var pendingDiscardAction: CaptureDiscardAction?
    @State private var isDiscardConfirmationPresented = false
    @State private var stickerBaseOffset: CGSize = .zero
    @GestureState private var stickerDragTranslation: CGSize = .zero
    @State private var isCardMintingDone = false
    @State private var captureSelectionFeedbackTrigger = 0
    @State private var captureWarningFeedbackTrigger = 0
    @State private var captureSaveTapFeedbackTrigger = 0
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
        .confirmationDialog(
            "Discard this draft?",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible,
            presenting: pendingDiscardAction
        ) { action in
            Button(action.destructiveTitle, role: .destructive) {
                performDiscardAction(action)
            }
            Button("Keep Draft") {
                pendingDiscardAction = nil
                isDiscardConfirmationPresented = false
            }
        } message: { action in
            Text(action.message)
        }
        .onChange(of: isDiscardConfirmationPresented) { _, isPresented in
            if !isPresented {
                pendingDiscardAction = nil
            }
        }
        .sensoryFeedback(.selection, trigger: captureSelectionFeedbackTrigger)
        .sensoryFeedback(.warning, trigger: captureWarningFeedbackTrigger)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.36), trigger: captureSaveTapFeedbackTrigger)
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
                cameraPrivacyBadge

                Spacer()

                Button {
                    closeCamera()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .catSingleActionIconSurface()
                }
                .buttonStyle(.catTactile)
                .accessibilityLabel("Close camera")
            }
        }
    }

    private var cameraPrivacyBadge: some View {
        HStack(spacing: 9) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Private scan")
                    .font(CatTypography.compactControl)
                Text("On this iPhone")
                    .font(CatTypography.finePrint)
                    .opacity(0.82)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.86)
        }
        .foregroundStyle(CatAttentionRole.info.strongForeground)
        .padding(.leading, 10)
        .padding(.trailing, 13)
        .frame(minHeight: 50)
        .background(CatAttentionRole.info.accent.opacity(0.92), in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Private scan on this iPhone")
    }

    private var cameraGuidance: some View {
        VStack(spacing: 7) {
            Text("Give them a little room")
                .font(CatTypography.momentTitle)
                .lineLimit(nil)
            Text("Keep the whole cat visible for the cleanest cutout.")
                .font(CatTypography.supporting)
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
                    .buttonStyle(.catTactile)
                    .disabled(isProcessingCapture)
                    .opacity(isProcessingCapture ? 0.45 : 1)
                    .accessibilityLabel("Choose Private Photo")
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
                    .buttonStyle(.catTactile)
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
                            .font(CatTypography.badge.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .catGlass(cornerRadius: 20, interactive: true)
                    }
                    .buttonStyle(.catTactile)
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
                    .font(CatTypography.momentTitle)
                    .foregroundStyle(.white)
                Text("You can still choose a private photo, or enable camera access in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: 300)

                VStack(spacing: 10) {
                    privatePhotoImportAction
                    openCameraSettingsButton
                }
                .frame(maxWidth: 280)
            } else if let cameraError = camera.errorMessage {
                Text(cameraError)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 300)

                privatePhotoImportAction
                    .frame(maxWidth: 280)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var privatePhotoImportAction: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Label("Choose Private Photo", systemImage: "photo.on.rectangle")
                .font(CatTypography.control)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .catPrimaryActionSurface(role: .action, cornerRadius: 24)
        }
        .buttonStyle(.catTactile)
        .disabled(isProcessingCapture)
        .opacity(isProcessingCapture ? 0.45 : 1)
        .accessibilityHint("The selected photo stays on this iPhone")
    }

    private var openCameraSettingsButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            Label("Open Settings", systemImage: "gearshape")
                .font(CatTypography.control)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .catSecondaryActionSurface(cornerRadius: 24, minHeight: 52)
        }
        .buttonStyle(.catTactile)
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
                    .accessibilityHidden(true)

                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text(stage == .analyzing ? "Looking for cats" : "Lifting the subject")
                    .font(CatTypography.pageTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("This happens entirely on your iPhone.")
                    .font(CatTypography.supporting)
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
                CutoutSpotlightRevealView(
                    sourceImage: originalImage,
                    cutoutImage: cutoutImage
                ) {
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
                        Button("Retake") { requestDiscardAction(.retake) }
                        Spacer()
                        Label("\(detections.count) cats found", systemImage: "checkmark.circle.fill")
                            .font(CatTypography.supportingEmphasized)
                            .catAttentionPillSurface(role: .success)
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
                        Text("Which cat gets the card?")
                            .font(CatTypography.pageTitle)
                            .foregroundStyle(CatLocalTheme.primaryText)
                            .multilineTextAlignment(.center)

                        Text("Choose one. This photo stays private on this iPhone.")
                            .font(CatTypography.supporting)
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
                                    .font(CatTypography.control)
                                    .foregroundStyle(CatLocalTheme.primaryText)
                                    .padding(.horizontal, 18)
                                    .frame(minHeight: 56)
                                    .catGlass(cornerRadius: 20, interactive: true)
                                }
                                .buttonStyle(.catTactile)
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

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        editorTopBar
                            .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                            .padding(.top, 12)

                        Spacer(minLength: 0)

                        if let cutoutImage {
                            draggableSticker(
                                cutoutImage,
                                height: stickerInspectionStickerHeight(for: proxy.size.height)
                            )
                        }

                        Spacer(minLength: 0)

                        stickerInspectionActions
                            .padding(.bottom, 18)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var stickerInspectionActions: some View {
        VStack(spacing: 10) {
            quickSaveButton
            customizeButton
        }
    }

    private var quickSaveButton: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return Button {
            captureSaveTapFeedbackTrigger += 1
            Task { await finishCustomization() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CatAttentionRole.action.accent)

                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CatAttentionRole.action.strongForeground)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(CatAttentionRole.action.strongForeground)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isSaving ? "Preparing card" : "Save Cat")
                        .font(CatTypography.control)

                    Text(isSaving ? "Adding a little finish" : "Edit details later")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.82)

                Spacer(minLength: 8)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .contentShape(shape)
            .catCommitActionSurface(role: .action, cornerRadius: 24)
        }
        .buttonStyle(.catTactile)
        .contentShape(shape)
        .disabled(isSaving)
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        .accessibilityIdentifier("save-cat-immediate")
        .accessibilityLabel(isSaving ? "Preparing Cat Card" : "Save Cat")
        .accessibilityHint("Saves this card now. You can edit the name, design, and Catlas details later.")
    }

    private var customizeButton: some View {
        Button {
            expandEditor()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CatAttentionRole.action.accent)
                    .frame(width: 34, height: 34)
                    .background(CatAttentionRole.action.wash, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Before Saving")
                        .font(CatTypography.control)
                        .foregroundStyle(CatLocalTheme.primaryText)

                    Text("Design, name, and Catlas labels")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.86)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(CatTypography.metadata)
                    .foregroundStyle(CatLocalTheme.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .catSecondaryActionSurface(cornerRadius: 24, minHeight: 64)
        }
        .buttonStyle(.catTactile)
        .disabled(isSaving)
        .opacity(isSaving ? 0.55 : 1)
        .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
        .accessibilityIdentifier("tap-to-customize")
        .accessibilityLabel("Edit before saving")
        .accessibilityHint("Opens design, name, note, and Catlas fields before saving.")
    }

    private func stickerInspectionStickerHeight(for availableHeight: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = dynamicTypeSize.isAccessibilitySize ? 320 : 390
        let fixedContentAllowance: CGFloat = dynamicTypeSize.isAccessibilitySize ? 360 : 286
        let availableStickerHeight = max(220, availableHeight - fixedContentAllowance)

        return min(baseHeight, availableStickerHeight)
    }

    private func draggableSticker(_ image: UIImage, height: CGFloat = 390) -> some View {
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
        .frame(height: height)
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
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return Button {
            dismissEditorKeyboard()
            captureSaveTapFeedbackTrigger += 1
            Task { await finishCustomization() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CatAttentionRole.action.accent)

                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(CatAttentionRole.action.strongForeground)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(CatAttentionRole.action.strongForeground)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isSaving ? "Preparing card" : "Save Cat")
                        .font(CatTypography.control)

                    Text(isSaving ? "Adding a little finish" : "Save to Collection")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatLocalTheme.secondaryText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.86)

                Spacer(minLength: 8)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .contentShape(shape)
            .catCommitActionSurface(role: .action, cornerRadius: 24)
        }
        .buttonStyle(.catTactile)
        .contentShape(shape)
        .disabled(isSaving)
        .accessibilityLabel(isSaving ? "Preparing Cat Card" : "Save Cat")
    }

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                makeItYoursHeading

                Text("Choose a card design now, or save first and edit later.")
                    .font(CatTypography.screenSubtitle)
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

                editorFieldHeading("Name")

                TextField("Nickname (optional)", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .focused($focusedEditorField, equals: .nickname)
                    .catInputSurface()

                editorFieldHeading("Catlas Place")

                TextField("Place label (optional)", text: $placeName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedEditorField, equals: .placeName)
                    .catInputSurface()
                    .accessibilityHint("Adds a manual place label to the private Catlas")

                TextField("Place detail (optional)", text: $placeDetail, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedEditorField, equals: .placeDetail)
                    .catInputSurface()

                editorFieldHeading("Note")

                TextField("Add a note about this encounter", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedEditorField, equals: .note)
                    .catInputSurface()

                catlasPrivacyNote

                editorSaveSection
            }
            .padding(18)
            .padding(.top, 52)
            .padding(.bottom, 34)
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

    private var editorSaveSection: some View {
        VStack(spacing: 9) {
            editorSheetSaveButton

            Text("The card, details, and images stay on this iPhone.")
                .font(CatTypography.finePrint)
                .foregroundStyle(CatLocalTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
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
            Text("Make It ")
                .foregroundStyle(CatLocalTheme.primaryText)
            + Text("Yours")
                .foregroundStyle(CatAttentionRole.action.text)
        )
        .font(CatTypography.pageTitle)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Make It Yours")
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
                    showsLociCompanion: true,
                    onHome: {
                        requestDiscardAction(.close)
                    },
                    onKeepEditing: {
                        editSavedCard()
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
                    editorTopBarButton(
                        accessibilityIdentifier: "capture-editor-cancel",
                        accessibilityLabel: "Cancel",
                        systemImage: "xmark"
                    ) {
                        requestDiscardAction(.close)
                    }
                    Spacer()
                    editorStageTitle
                    Spacer()
                    editorTopBarButton(
                        accessibilityIdentifier: "capture-editor-retake",
                        accessibilityLabel: "Retake",
                        systemImage: "arrow.counterclockwise"
                    ) {
                        requestDiscardAction(.retake)
                    }
                }

                VStack(spacing: 10) {
                    HStack {
                        editorTopBarButton(
                            accessibilityIdentifier: "capture-editor-cancel",
                            accessibilityLabel: "Cancel",
                            systemImage: "xmark"
                        ) {
                            requestDiscardAction(.close)
                        }
                        Spacer()
                        editorTopBarButton(
                            accessibilityIdentifier: "capture-editor-retake",
                            accessibilityLabel: "Retake",
                            systemImage: "arrow.counterclockwise"
                        ) {
                            requestDiscardAction(.retake)
                        }
                    }
                    editorStageTitle
                }
            }
        }
    }

    private func editorTopBarButton(
        accessibilityIdentifier: String,
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
        .buttonStyle(.catTactile)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var editorStageTitle: some View {
        VStack(spacing: 2) {
            Text("A New Cat")
                .font(CatTypography.panelTitle)
                .foregroundStyle(CatLocalTheme.primaryText)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var catlasPrivacyNote: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(CatAttentionRole.info.wash)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(CatAttentionRole.info.accent)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text("Typed labels only. No GPS is requested.")
                .font(CatTypography.bodyEmphasized)
                .foregroundStyle(CatAttentionRole.info.text)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(CatAttentionRole.info.wash)
        )
    }

    private func editorFieldHeading(_ title: String) -> some View {
        Text(title)
            .font(CatTypography.fieldLabel)
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
                    LociMascotView(
                        state: failureLociState,
                        size: 136
                    )

                    VStack(spacing: 8) {
                        Text(failureTitle)
                            .font(CatTypography.pageTitle)
                            .foregroundStyle(CatLocalTheme.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                        Text(errorMessage ?? "CatLocal could not create a clean cutout from this photo. Try a photo with the whole cat in view.")
                            .font(CatTypography.body)
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
                .buttonStyle(.catTactile)
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
                .buttonStyle(.catTactile)
                .accessibilityLabel("Close")
            }
        }
    }

    private var foregroundFallbackControls: some View {
        VStack(spacing: 12) {
            Button {
                Task { await createCutout(for: nil) }
            } label: {
                Label("Use Foreground Cutout", systemImage: "sparkles")
                    .font(CatTypography.control)
                    .frame(maxWidth: .infinity)
                    .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(.catTactile)
            .catPrimaryActionSurface(role: .warning, cornerRadius: 26)
            .frame(maxWidth: 320)
            .accessibilityHint("Uses the foreground subject even though CatLocal could not confirm a cat.")

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(CatTypography.fieldLabel)
                    .foregroundStyle(CatAttentionRole.warning.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text("No confirmed cat in this photo.")
                        .font(CatTypography.fieldLabel)
                        .foregroundStyle(CatAttentionRole.warning.text)

                    Text("You can review the foreground cutout and save only if it looks right.")
                        .font(CatTypography.metadata)
                        .foregroundStyle(CatAttentionRole.warning.text.opacity(0.82))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: 320, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(CatAttentionRole.warning.wash)
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

    private var failureTitle: String {
        failureLociState.title
    }

    private var failureLociState: LociMascotState {
        LociMascotState.state(for: failureContext)
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
            fail(with: "The validation photo could not be opened. Add cat.png to Documents/CatLocalValidation and try again.")
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
            fail(with: "This photo could not be opened. Choose another photo.")
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
        isSavedCardDraftLoaded = false
        detections = []
        selectedBoundingBox = nil
        errorMessage = nil
        canUseForegroundFallback = false
        failureContext = .failureRecovery
        resetStickerTransform()
        stage = .analyzing

        do {
            #if DEBUG
            if forcesForegroundFallbackForValidation {
                canUseForegroundFallback = true
                fail(with: CatVisionError.noCat)
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
                fail(with: CatVisionError.noCat)
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
            fail(with: CatVisionError.processingUnavailable)
        }
    }

    private func beginStickerReveal(cutout: UIImage, detection: CatDetection?) {
        selectedBoundingBox = detection?.boundingBox
        cutoutImage = cutout
        draftSuggestedName = freshDraftName()
        #if DEBUG
        if prefillsValidationEditorFields {
            prefillValidationEditorFields()
        }
        #endif
        errorMessage = nil
        isEditorSheetPresented = false
        resetStickerTransform()
        isCardMintingDone = false
        isSavedCardDraftLoaded = false
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
            fail(with: CatVisionError.unreadableImage)
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
            fail(with: error)
        }
    }

    private func finishCustomization() async {
        guard !isSaving else { return }
        let shouldCelebrateSave = isInitialCardDesignSave || stage == .cardCelebrating
        let saveStartedAt = Date()
        isSaving = true
        do {
            let record = try await persistCard()
            await holdForSaveAnticipation(since: saveStartedAt)
            persistedRecord = record
            isSaving = false
            isSavedCardDraftLoaded = false
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
            fail(with: error)
        }
    }

    private func holdForSaveAnticipation(since startDate: Date) async {
        let minimumDuration: TimeInterval = 0.72
        let remaining = minimumDuration - Date().timeIntervalSince(startDate)
        guard remaining > 0 else { return }

        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    private var isInitialCardDesignSave: Bool {
        persistedRecord == nil
    }

    private var hasDiscardableDraft: Bool {
        if persistedRecord == nil {
            return cutoutImage != nil
        }

        return hasUnsavedSavedCardDraft
    }

    private var hasUnsavedSavedCardDraft: Bool {
        guard isSavedCardDraftLoaded, let persistedRecord else { return false }

        return trimmedMemoryText(nickname) != trimmedMemoryText(persistedRecord.nickname)
            || note != persistedRecord.note
            || trimmedMemoryText(placeName) != trimmedMemoryText(persistedRecord.placeName)
            || trimmedMemoryText(placeDetail) != trimmedMemoryText(persistedRecord.placeDetail)
            || selectedStyle != persistedRecord.cardStyle
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

    private func fail(with message: String, context: LociContext = .failureRecovery) {
        isProcessingCapture = false
        errorMessage = message
        failureContext = context
        captureWarningFeedbackTrigger += 1
        stage = .failure
    }

    private func fail(with error: Error) {
        fail(
            with: error.localizedDescription,
            context: failureContext(for: error)
        )
    }

    private func failureContext(for error: Error) -> LociContext {
        guard let visionError = error as? CatVisionError else {
            return .failureRecovery
        }

        switch visionError {
        case .noCat:
            return .noCatFound
        case .unreadableImage:
            return .imageQualityWarning
        case .noForeground, .noMatchingForeground, .cutoutFailed:
            return .recoverableWarning
        case .processingUnavailable:
            return .failureRecovery
        }
    }

    private func closeCamera() {
        isProcessingCapture = false
        camera.stop()
        dismiss()
    }

    private func requestDiscardAction(_ action: CaptureDiscardAction) {
        guard !isSaving else { return }

        dismissEditorKeyboard()
        guard hasDiscardableDraft else {
            performDiscardAction(action)
            return
        }

        pendingDiscardAction = action
        captureWarningFeedbackTrigger += 1
        isDiscardConfirmationPresented = true
    }

    private func performDiscardAction(_ action: CaptureDiscardAction) {
        pendingDiscardAction = nil
        isDiscardConfirmationPresented = false

        switch action {
        case .close:
            cancelCapture()
        case .retake:
            reset()
        }
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
                fail(with: error.localizedDescription, context: .failureRecovery)
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
        draftSuggestedName = ""
        draftSequence = nil
        persistedRecord = nil
        photoItem = nil
        errorMessage = nil
        canUseForegroundFallback = false
        failureContext = .failureRecovery
        isProcessingCapture = false
        isSaving = false
        isEditorSheetPresented = false
        isSavedCardDraftLoaded = false
        pendingDiscardAction = nil
        isDiscardConfirmationPresented = false
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
        let suggestedName = trimmedMemoryText(draftSuggestedName)
        if !suggestedName.isEmpty, !existingNames.contains(suggestedName) {
            return suggestedName
        }

        return CatNamePool.randomName(excluding: existingNames)
    }

    private var editorPreviewName: String {
        let trimmedName = trimmedMemoryText(nickname)
        guard trimmedName.isEmpty else { return trimmedName }
        return draftSuggestedName.isEmpty ? CatNamePool.names.first ?? "Miso" : draftSuggestedName
    }

    private var celebrationPreviewName: String {
        persistedRecord?.displayName ?? editorPreviewName
    }

    private func freshDraftName() -> String {
        let existingNames = Set(existingRecords.map(\.displayName))
        return CatNamePool.randomName(excluding: existingNames)
    }

    private func editSavedCard() {
        hydrateEditorFromSavedRecord()
        expandEditor()
    }

    private func hydrateEditorFromSavedRecord() {
        guard let persistedRecord else { return }

        nickname = persistedRecord.nickname
        note = persistedRecord.note
        placeName = persistedRecord.placeName
        placeDetail = persistedRecord.placeDetail
        selectedStyle = persistedRecord.cardStyle
        isSavedCardDraftLoaded = true
    }
}

private enum CaptureDiscardAction {
    case close
    case retake

    var destructiveTitle: String {
        switch self {
        case .close:
            "Discard Draft"
        case .retake:
            "Discard and Retake"
        }
    }

    var message: String {
        switch self {
        case .close:
            "Your cutout and unsaved details will be lost. Saved cats stay in your collection."
        case .retake:
            "Your cutout and unsaved details will be lost before the camera opens."
        }
    }
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
