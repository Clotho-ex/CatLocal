import Foundation

enum LociPose: String, CaseIterable, Identifiable {
    case presenting = "loci_presenting"
    case curious = "loci_curious"
    case noCatFound = "loci_noCatFound"
    case inspecting = "loci_inspecting"
    case cardReady = "loci_cardReady"
    case hint = "loci_hint"
    case privacy = "loci_privacy"

    var id: String { rawValue }
}
