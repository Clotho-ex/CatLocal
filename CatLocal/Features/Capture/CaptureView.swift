import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
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
    @State private var errorMessage: String?
    @State private var canUseForegroundFallback = false
    @State private var isSaving = false
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
            case .editing:
                editorScreen
            case .failure:
                failureScreen
            }
        }
        .animation(.easeInOut(duration: 0.22), value: stage)
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
        .onDisappear { camera.stop() }
        .interactiveDismissDisabled(stage != .camera)
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
                Button {
                    closeCamera()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .catGlass(cornerRadius: 23, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close camera")

                Spacer()

                Label("On-device only", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .catGlass(cornerRadius: 20)
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
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .catGlass(cornerRadius: 32, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose private photo")
                    .accessibilityHint("The selected photo stays on this iPhone")

                    Spacer()

                    Button {
                        camera.capture { result in
                            switch result {
                            case .success(let image):
                                Task {
                                    await accept(
                                        image: optimizedWorkingImage(from: image),
                                        source: .camera
                                    )
                                }
                            case .failure(let error):
                                fail(with: error.localizedDescription)
                            }
                        }
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
                    .disabled(!camera.isConfigured)
                    .opacity(camera.isConfigured ? 1 : 0.45)
                    .accessibilityLabel("Take photo")

                    Spacer()

                    Color.clear
                        .frame(width: 64, height: 64)
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

    private var editorScreen: some View {
        ZStack {
            CatLocalBackground()

            ScrollView {
                VStack(spacing: 20) {
                    editorTopBar

                    if let cutoutImage {
                        DraftCatCardView(
                            image: cutoutImage,
                            sequence: nextSequence,
                            name: editorPreviewName,
                            note: note,
                            placeName: placeName,
                            placeDetail: placeDetail,
                            cardStyle: selectedStyle,
                            showsFooter: false,
                            catBoundingBox: selectedBoundingBox,
                            topoSeed: nextSequence
                        )
                        .frame(maxWidth: 350)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Make it Yours")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        CatLocalTheme.warning,
                                        CatLocalTheme.blueAction,
                                        CatLocalTheme.primaryText
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineLimit(nil)

                        Text("Add the details you want to remember. Everything stays local.")
                            .font(.subheadline)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                            .lineLimit(nil)

                        CardStyleCarousel(
                            selectedStyle: $selectedStyle,
                            showsTitle: false,
                            itemWidth: 132,
                            previewAspectRatio: 1.32,
                            itemPadding: 7,
                            itemCornerRadius: 20,
                            itemSpacing: 10,
                            titleMinHeight: 30
                        ) { style in
                            CardStyleSwatch(style: style)
                        }
                        .accessibilityLabel("Card design")

                        Text("Name the Cat")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CatLocalTheme.secondaryText)

                        TextField("Nickname (optional)", text: $nickname)
                            .textInputAutocapitalization(.words)
                            .focused($focusedEditorField, equals: .nickname)
                            .catInputSurface()

                        Text("CATLAS")
                            .font(.caption2.weight(.bold))
                            .tracking(1.8)
                            .foregroundStyle(CatLocalTheme.secondaryText)

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

                        Text("Manual label only. CatLocal does not request GPS or save coordinates.")
                            .font(.footnote)
                            .foregroundStyle(CatLocalTheme.secondaryText)
                            .lineLimit(nil)

                        Text("Encounter Note")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CatLocalTheme.secondaryText)

                        TextField("A note about this encounter", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .focused($focusedEditorField, equals: .note)
                            .catInputSurface()
                    }
                    .padding(18)
                    .catPanelSurface(fillOpacity: 0.86, shadowOpacity: 0.18)
                }
                .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                saveCardButton
                    .padding(.horizontal, CatLocalTheme.screenHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(.regularMaterial)
            }
        }
    }

    private var editorTopBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Button("Cancel") { cancelCapture() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
                Spacer()
                editorStageTitle
                Spacer()
                Button("Retake") { reset() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CatLocalTheme.primaryText)
            }

            VStack(spacing: 10) {
                HStack {
                    Button("Cancel") { cancelCapture() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                    Spacer()
                    Button("Retake") { reset() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                }
                editorStageTitle
            }
        }
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

    private var saveCardButton: some View {
        Button {
            focusedEditorField = nil
            Task { await saveCard() }
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Image(systemName: isSaving ? "hourglass" : "cat.fill")
                Text(isSaving ? "Saving privately" : "Add Cat")
                    .lineLimit(2)
            }
            .font(.headline)
            .catPrimaryActionSurface(isDisabled: isSaving)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityHint("Saves the cat and image variants on this iPhone")
    }

    private var failureScreen: some View {
        ZStack {
            CatLocalBackground()

            VStack(spacing: 20) {
                Image(systemName: "viewfinder.circle")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(CatLocalTheme.warning)

                VStack(spacing: 8) {
                    Text("That one was tricky")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(CatLocalTheme.primaryText)
                    Text(errorMessage ?? "CatLocal could not create a clean cat cutout from this photo.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 320)
                }

                if originalImage != nil, canUseForegroundFallback {
                    Button("Use the foreground anyway") {
                        Task { await createCutout(for: nil) }
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .catPrimaryActionSurface(cornerRadius: 26)
                    .frame(maxWidth: 320)
                }

                Button("Try Another Photo") { reset() }
                    .font(.headline)
                    .foregroundStyle(CatLocalTheme.primaryText)

                Button("Close") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    private var nextSequence: Int {
        (existingRecords.map(\.sequence).max() ?? 0) + 1
    }

    #if DEBUG
    private var showsValidationImport: Bool {
        ProcessInfo.processInfo.arguments.contains("-catlocal-ui-import-fixture")
    }

    private func loadValidationPhoto() async {
        do {
            let url = try validationPhotoURL()
            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else {
                throw CatVisionError.unreadableImage
            }
            await accept(image: optimizedWorkingImage(from: image), source: .photoLibrary)
        } catch {
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
    #endif

    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                throw CatVisionError.unreadableImage
            }
            await accept(image: optimizedWorkingImage(from: image), source: .photoLibrary)
        } catch {
            fail(with: "This photo could not be opened. Try another image.")
        }
    }

    private func accept(image: UIImage, source: CaptureSource) async {
        camera.stop()
        originalImage = image
        self.source = source
        detections = []
        selectedBoundingBox = nil
        errorMessage = nil
        stage = .analyzing

        do {
            let found = try await processor.detectCats(in: SendableImage(value: image))
            switch CatDetectionSelector.resolve(found) {
            case .none:
                detections = []
                canUseForegroundFallback = true
                fail(with: CatVisionError.noCat.localizedDescription)
            case .single(let detection):
                detections = [detection]
                await createCutout(for: detection)
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

    private func createCutout(for detection: CatDetection?) async {
        guard let originalImage else {
            fail(with: CatVisionError.unreadableImage.localizedDescription)
            return
        }

        stage = .creatingCutout
        selectedBoundingBox = detection?.boundingBox
        do {
            let result = try await processor.cutout(
                from: SendableImage(value: originalImage),
                detection: detection
            )
            cutoutImage = result.value
            draftGreeting = Self.randomDraftGreeting()
            errorMessage = nil
            stage = .editing
        } catch {
            canUseForegroundFallback = false
            fail(with: error.localizedDescription)
        }
    }

    private func saveCard() async {
        guard let originalImage, let cutoutImage else {
            fail(with: "The cat images are missing. Please try the capture again.")
            return
        }

        isSaving = true
        do {
            let id = UUID()
            let stored = try await CatImageStore.shared.save(
                id: id,
                original: SendableImage(value: originalImage),
                cutout: SendableImage(value: cutoutImage)
            )
            let record = CatRecord(
                id: id,
                sequence: nextSequence,
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
            modelContext.insert(record)
            try modelContext.save()
            dismiss()
        } catch {
            isSaving = false
            fail(with: error.localizedDescription)
        }
    }

    private func fail(with message: String) {
        errorMessage = message
        stage = .failure
    }

    private func closeCamera() {
        camera.stop()
        dismiss()
    }

    private func cancelCapture() {
        camera.stop()
        dismiss()
    }

    private func optimizedWorkingImage(from image: UIImage) -> UIImage {
        CatImageStore.downsampledOpaqueImage(
            from: image,
            maximumDimension: CatImageStore.originalMaximumDimension
        )
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
        photoItem = nil
        errorMessage = nil
        canUseForegroundFallback = false
        isSaving = false
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
    case editing
    case failure
}

private enum EditorField: Hashable {
    case nickname
    case note
    case placeName
    case placeDetail
}
