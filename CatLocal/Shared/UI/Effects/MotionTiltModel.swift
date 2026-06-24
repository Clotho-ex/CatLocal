@preconcurrency import CoreMotion
import SwiftUI

@MainActor
final class MotionTiltModel: ObservableObject, @unchecked Sendable {
    @Published private(set) var x: Double = 0
    @Published private(set) var y: Double = 0

    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1 / 45
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            Task { @MainActor in
                self.x = max(-1, min(1, attitude.roll / 0.55))
                self.y = max(-1, min(1, attitude.pitch / 0.55))
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        x = 0
        y = 0
    }
}
