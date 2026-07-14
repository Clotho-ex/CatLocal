import Foundation

enum LociMascotAnimation: String, CaseIterable, Identifiable {
    case none
    case idle
    case thinking
    case successPop
    case errorTilt

    var id: String { rawValue }
}
