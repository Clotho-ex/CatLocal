import Foundation

enum LociPose: String, CaseIterable, Identifiable {
    case neutral = "loci_neutral"
    case presenting = "loci_presenting"
    case curious = "loci_curious"
    case greeting = "loci_greeting"
    case icon = "loci_icon"
    case noCatFound = "loci_noCatFound"
    case inspecting = "loci_inspecting"
    case cardReady = "loci_cardReady"
    case hint = "loci_hint"
    case privacy = "loci_privacy"

    var id: String { rawValue }
}
