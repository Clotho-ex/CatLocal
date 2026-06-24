@preconcurrency import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class CameraController: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus =
        AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isConfigured = false
    @Published private(set) var errorMessage: String?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?

    func requestAccessAndConfigure() async {
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
        configureIfNeeded()
    }

    func start() {
        guard isConfigured, !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
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

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        do {
            session.beginConfiguration()
            session.sessionPreset = .photo

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
            guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                throw CameraError.configurationFailed
            }

            session.addInput(input)
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            session.commitConfiguration()
            isConfigured = true
            errorMessage = nil
        } catch {
            session.commitConfiguration()
            errorMessage = error.localizedDescription
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

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

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
