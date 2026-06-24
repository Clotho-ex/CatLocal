@preconcurrency import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class CameraController: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var isConfigured = false
    @Published private(set) var errorMessage: String?

    let session: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private let sessionCoordinator: CameraSessionCoordinator
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?

    override init() {
        let session = AVCaptureSession()
        let photoOutput = AVCapturePhotoOutput()
        self.session = session
        self.photoOutput = photoOutput
        sessionCoordinator = CameraSessionCoordinator(
            session: session,
            photoOutput: photoOutput
        )
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
    }

    func requestAccessAndConfigure() async {
        #if targetEnvironment(simulator)
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        isConfigured = false
        errorMessage = CameraError.unavailable.localizedDescription
        return
        #else
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            granted = false
        }

        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard granted else { return }
        await configureIfNeeded()
        #endif
    }

    func start() {
        guard isConfigured else { return }
        sessionCoordinator.start()
    }

    func stop() {
        sessionCoordinator.stop()
    }

    func capture(completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard isConfigured else {
            completion(.failure(CameraError.notReady))
            return
        }
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureIfNeeded() async {
        guard !isConfigured else { return }

        do {
            try await sessionCoordinator.configureIfNeeded()
            isConfigured = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private final class CameraSessionCoordinator: @unchecked Sendable {
    private let session: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private let queue = DispatchQueue(label: "app.catlocal.camera.session")
    private var isConfigured = false

    init(session: AVCaptureSession, photoOutput: AVCapturePhotoOutput) {
        self.session = session
        self.photoOutput = photoOutput
    }

    func configureIfNeeded() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard !isConfigured else {
                    continuation.resume()
                    return
                }

                do {
                    guard
                        let device = AVCaptureDevice.default(
                            .builtInWideAngleCamera,
                            for: .video,
                            position: .back
                        )
                    else {
                        throw CameraError.unavailable
                    }

                    let input = try AVCaptureDeviceInput(device: device)

                    session.beginConfiguration()
                    defer { session.commitConfiguration() }

                    session.sessionPreset = .photo
                    guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                        throw CameraError.configurationFailed
                    }

                    session.addInput(input)
                    session.addOutput(photoOutput)
                    photoOutput.maxPhotoQualityPrioritization = .quality
                    isConfigured = true
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() {
        queue.async { [self] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                captureCompletion?(.failure(error))
                captureCompletion = nil
                return
            }
            guard
                let data = photo.fileDataRepresentation(),
                let image = UIImage(data: data)
            else {
                captureCompletion?(.failure(CameraError.imageCreationFailed))
                captureCompletion = nil
                return
            }
            captureCompletion?(.success(image))
            captureCompletion = nil
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.attach(session, to: view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.attach(session, to: uiView.previewLayer)
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.cancelAttach()
        uiView.previewLayer.session = nil
    }

    @MainActor
    final class Coordinator {
        private var attachTask: Task<Void, Never>?
        private weak var attachedLayer: AVCaptureVideoPreviewLayer?
        private var pendingSession: AVCaptureSession?

        func attach(_ session: AVCaptureSession, to layer: AVCaptureVideoPreviewLayer) {
            guard attachedLayer !== layer || (layer.session !== session && pendingSession !== session) else { return }
            cancelAttach()
            attachedLayer = layer
            pendingSession = session
            attachTask = Task { @MainActor [weak layer] in
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                layer?.session = session
                pendingSession = nil
            }
        }

        func cancelAttach() {
            attachTask?.cancel()
            attachTask = nil
            pendingSession = nil
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

enum CameraError: LocalizedError {
    case unavailable
    case notReady
    case configurationFailed
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "No camera is available on this device."
        case .notReady:
            "The camera is not ready yet."
        case .configurationFailed:
            "CatLocal could not configure the camera."
        case .imageCreationFailed:
            "The captured photo could not be opened."
        }
    }
}
