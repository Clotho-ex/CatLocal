@preconcurrency import AVFoundation
import SwiftUI
import UIKit

enum CameraZoomMath {
    static func deviceFactor(
        forDisplayFactor displayFactor: CGFloat,
        displayMultiplier: CGFloat,
        minimumDeviceFactor: CGFloat,
        maximumDeviceFactor: CGFloat
    ) -> CGFloat {
        let safeMultiplier = max(displayMultiplier, .leastNonzeroMagnitude)
        return min(max(displayFactor / safeMultiplier, minimumDeviceFactor), maximumDeviceFactor)
    }

    static func displayFactor(
        baseDisplayFactor: CGFloat,
        magnification: CGFloat,
        minimumDisplayFactor: CGFloat,
        maximumDisplayFactor: CGFloat
    ) -> CGFloat {
        let safeMagnification = max(magnification, .leastNonzeroMagnitude)
        return min(
            max(baseDisplayFactor * safeMagnification, minimumDisplayFactor),
            maximumDisplayFactor
        )
    }
}

enum CameraDeviceDiscovery {
    static let preferredDeviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera,
    ]
}

struct CameraZoomCapabilities: Sendable, Equatable {
    let minimumDeviceFactor: CGFloat
    let maximumDeviceFactor: CGFloat
    let displayMultiplier: CGFloat
    let currentDeviceFactor: CGFloat

    var minimumDisplayFactor: CGFloat { minimumDeviceFactor * displayMultiplier }
    var maximumDisplayFactor: CGFloat { maximumDeviceFactor * displayMultiplier }
    var currentDisplayFactor: CGFloat { currentDeviceFactor * displayMultiplier }
}

struct CameraCaptureState {
    private(set) var isCapturing = false

    mutating func begin() throws {
        guard !isCapturing else { throw CameraError.busy }
        isCapturing = true
    }

    mutating func finish() {
        isCapturing = false
    }
}

enum CameraPhotoSettingsPolicy {
    static let qualityPrioritization: AVCapturePhotoOutput.QualityPrioritization = .quality

    static func flashMode(
        supportedModes: [AVCaptureDevice.FlashMode]
    ) -> AVCaptureDevice.FlashMode {
        supportedModes.contains(.auto) ? .auto : .off
    }
}

struct CameraSessionConfigurationState {
    private enum Phase {
        case unconfigured
        case configuring
        case configured(CameraZoomCapabilities)
    }

    private var phase: Phase = .unconfigured

    var cachedCapabilities: CameraZoomCapabilities? {
        guard case .configured(let capabilities) = phase else { return nil }
        return capabilities
    }

    var isConfigured: Bool { cachedCapabilities != nil }

    mutating func begin() -> Bool {
        guard case .unconfigured = phase else { return false }
        phase = .configuring
        return true
    }

    mutating func commit(_ capabilities: CameraZoomCapabilities) {
        phase = .configured(capabilities)
    }

    mutating func fail() {
        phase = .unconfigured
    }
}

actor CameraConfigurationRequestGate<Value: Sendable> {
    private struct Request {
        let identifier: UInt64
        let task: Task<Value, Error>
    }

    private var nextIdentifier: UInt64 = 0
    private var inFlightRequest: Request?

    func value(
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        if let inFlightRequest {
            return try await inFlightRequest.task.value
        }

        nextIdentifier &+= 1
        let identifier = nextIdentifier
        let task = Task {
            try await operation()
        }
        inFlightRequest = Request(identifier: identifier, task: task)

        do {
            let value = try await task.value
            clearRequest(identifier: identifier)
            return value
        } catch {
            clearRequest(identifier: identifier)
            throw error
        }
    }

    private func clearRequest(identifier: UInt64) {
        guard inFlightRequest?.identifier == identifier else { return }
        inFlightRequest = nil
    }
}

private struct CameraZoomUpdate: Sendable {
    let displayFactor: CGFloat
    let errorMessage: String?
}

@MainActor
final class CameraController: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var isConfigured = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var displayZoomFactor: CGFloat = 1
    @Published private(set) var minimumDisplayZoomFactor: CGFloat = 1
    @Published private(set) var maximumDisplayZoomFactor: CGFloat = 1

    let session: AVCaptureSession
    private let sessionCoordinator: CameraSessionCoordinator
    private var captureCompletion: ((Result<Data, Error>) -> Void)?
    private var captureState = CameraCaptureState()
    private var zoomRequestGeneration: UInt64 = 0

    override init() {
        let sessionCoordinator = CameraSessionCoordinator()
        self.sessionCoordinator = sessionCoordinator
        session = sessionCoordinator.session
        authorizationStatus = sessionCoordinator.currentAuthorizationStatus()
        super.init()
    }

    func requestAccessAndConfigure() async {
        #if targetEnvironment(simulator)
        authorizationStatus = sessionCoordinator.currentAuthorizationStatus()
        isConfigured = false
        errorMessage = CameraError.unavailable.localizedDescription
        return
        #else
        let granted: Bool
        switch sessionCoordinator.currentAuthorizationStatus() {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await sessionCoordinator.requestAccess()
        default:
            granted = false
        }

        authorizationStatus = sessionCoordinator.currentAuthorizationStatus()
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

    func capture(completion: @escaping (Result<Data, Error>) -> Void) {
        guard isConfigured else {
            completion(.failure(CameraError.notReady))
            return
        }

        do {
            try captureState.begin()
        } catch {
            completion(.failure(error))
            return
        }

        captureCompletion = completion
        sessionCoordinator.capture(delegate: self) { [weak self] error in
            Task { @MainActor [weak self] in
                self?.completeCapture(with: .failure(error))
            }
        }
    }

    func setDisplayZoomFactor(_ factor: CGFloat, animated: Bool) {
        let clamped = min(
            max(factor, minimumDisplayZoomFactor),
            maximumDisplayZoomFactor
        )
        guard abs(clamped - displayZoomFactor) >= 0.015 else { return }
        displayZoomFactor = clamped

        zoomRequestGeneration &+= 1
        let generation = zoomRequestGeneration
        sessionCoordinator.setDisplayZoomFactor(clamped, animated: animated) { [weak self] update in
            Task { @MainActor [weak self] in
                guard let self, self.zoomRequestGeneration == generation else { return }
                self.displayZoomFactor = update.displayFactor
                self.errorMessage = update.errorMessage
            }
        }
    }

    private func configureIfNeeded() async {
        guard !isConfigured else { return }

        do {
            let capabilities = try await sessionCoordinator.configureIfNeeded()
            displayZoomFactor = capabilities.currentDisplayFactor
            minimumDisplayZoomFactor = capabilities.minimumDisplayFactor
            maximumDisplayZoomFactor = capabilities.maximumDisplayFactor
            isConfigured = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeCapture(with result: Result<Data, Error>) {
        guard captureState.isCapturing else { return }
        let completion = captureCompletion
        captureCompletion = nil
        captureState.finish()
        completion?(result)
    }
}

private final class CameraSessionCoordinator: @unchecked Sendable {
    let session: AVCaptureSession
    private let photoOutput: AVCapturePhotoOutput
    private let queue: DispatchQueue
    private let configurationRequestGate = CameraConfigurationRequestGate<CameraZoomCapabilities>()
    private var configurationState = CameraSessionConfigurationState()
    private var activeDevice: AVCaptureDevice?

    init() {
        let queue = DispatchQueue(label: "app.catlocal.camera.session")
        self.queue = queue
        let resources = queue.sync {
            (AVCaptureSession(), AVCapturePhotoOutput())
        }
        session = resources.0
        photoOutput = resources.1
    }

    func currentAuthorizationStatus() -> AVAuthorizationStatus {
        queue.sync {
            AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func configureIfNeeded() async throws -> CameraZoomCapabilities {
        try await configurationRequestGate.value { [self] in
            try await performConfigurationIfNeeded()
        }
    }

    private func performConfigurationIfNeeded() async throws -> CameraZoomCapabilities {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                if let capabilities = configurationState.cachedCapabilities {
                    continuation.resume(returning: capabilities)
                    return
                }
                guard configurationState.begin() else {
                    continuation.resume(throwing: CameraError.configurationFailed)
                    return
                }

                do {
                    guard let device = CameraDeviceDiscovery.preferredDeviceTypes.lazy.compactMap({
                        AVCaptureDevice.default($0, for: .video, position: .back)
                    }).first else {
                        throw CameraError.unavailable
                    }

                    let input = try AVCaptureDeviceInput(device: device)
                    try setInitialOneTimesZoom(on: device)

                    session.beginConfiguration()
                    session.sessionPreset = .photo

                    let hasInput = session.inputs.contains { existingInput in
                        guard let deviceInput = existingInput as? AVCaptureDeviceInput else {
                            return false
                        }
                        return deviceInput.device.uniqueID == device.uniqueID
                    }
                    let hasOutput = session.outputs.contains { $0 === photoOutput }
                    guard
                        hasInput || session.canAddInput(input),
                        hasOutput || session.canAddOutput(photoOutput)
                    else {
                        session.commitConfiguration()
                        throw CameraError.configurationFailed
                    }

                    if !hasInput {
                        session.addInput(input)
                    }
                    if !hasOutput {
                        session.addOutput(photoOutput)
                    }
                    photoOutput.maxPhotoQualityPrioritization = .quality
                    session.commitConfiguration()

                    let capabilities = zoomCapabilities(for: device)
                    configurationState.commit(capabilities)
                    activeDevice = device
                    continuation.resume(returning: capabilities)
                } catch {
                    configurationState.fail()
                    activeDevice = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func capture(
        delegate: AVCapturePhotoCaptureDelegate,
        failure: @escaping @Sendable (CameraError) -> Void
    ) {
        queue.async { [self] in
            guard configurationState.isConfigured, activeDevice != nil else {
                failure(.notReady)
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = CameraPhotoSettingsPolicy.qualityPrioritization
            settings.flashMode = CameraPhotoSettingsPolicy.flashMode(
                supportedModes: photoOutput.supportedFlashModes
            )
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func setDisplayZoomFactor(
        _ factor: CGFloat,
        animated: Bool,
        completion: @escaping @Sendable (CameraZoomUpdate) -> Void
    ) {
        queue.async { [self] in
            guard let device = activeDevice else {
                completion(CameraZoomUpdate(
                    displayFactor: factor,
                    errorMessage: CameraError.notReady.localizedDescription
                ))
                return
            }

            let multiplier = device.displayVideoZoomFactorMultiplier
            do {
                let target = CameraZoomMath.deviceFactor(
                    forDisplayFactor: factor,
                    displayMultiplier: multiplier,
                    minimumDeviceFactor: device.minAvailableVideoZoomFactor,
                    maximumDeviceFactor: device.maxAvailableVideoZoomFactor
                )
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if animated {
                    device.ramp(toVideoZoomFactor: target, withRate: 7)
                } else {
                    device.cancelVideoZoomRamp()
                    device.videoZoomFactor = target
                }
                completion(CameraZoomUpdate(
                    displayFactor: target * multiplier,
                    errorMessage: nil
                ))
            } catch {
                completion(CameraZoomUpdate(
                    displayFactor: device.videoZoomFactor * multiplier,
                    errorMessage: error.localizedDescription
                ))
            }
        }
    }

    private func zoomCapabilities(for device: AVCaptureDevice) -> CameraZoomCapabilities {
        CameraZoomCapabilities(
            minimumDeviceFactor: device.minAvailableVideoZoomFactor,
            maximumDeviceFactor: device.maxAvailableVideoZoomFactor,
            displayMultiplier: device.displayVideoZoomFactorMultiplier,
            currentDeviceFactor: device.videoZoomFactor
        )
    }

    private func setInitialOneTimesZoom(on device: AVCaptureDevice) throws {
        let target = CameraZoomMath.deviceFactor(
            forDisplayFactor: 1,
            displayMultiplier: device.displayVideoZoomFactorMultiplier,
            minimumDeviceFactor: device.minAvailableVideoZoomFactor,
            maximumDeviceFactor: device.maxAvailableVideoZoomFactor
        )
        guard abs(device.videoZoomFactor - target) >= 0.01 else { return }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.videoZoomFactor = target
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
        if let error {
            Task { @MainActor [weak self] in
                self?.completeCapture(with: .failure(error))
            }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            Task { @MainActor [weak self] in
                self?.completeCapture(with: .failure(CameraError.imageCreationFailed))
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.completeCapture(with: .success(data))
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

enum CameraError: LocalizedError, Equatable {
    case unavailable
    case notReady
    case busy
    case configurationFailed
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "No camera is available on this device."
        case .notReady:
            "The camera is not ready yet."
        case .busy:
            "The camera is already taking a photo."
        case .configurationFailed:
            "CatLocal could not configure the camera."
        case .imageCreationFailed:
            "The captured photo could not be opened."
        }
    }
}
