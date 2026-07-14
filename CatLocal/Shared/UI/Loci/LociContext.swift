import Foundation

enum LociContext: String, CaseIterable, Identifiable {
    case emptyCollection
    case cardSaved
    case recoverableWarning
    case failureRecovery
    case noCatFound
    case imageQualityWarning
    case glintHint
    case privacyEducation

    var id: String { rawValue }

    var pose: LociPose {
        switch self {
        case .emptyCollection:
            return .presenting
        case .cardSaved:
            return .cardReady
        case .recoverableWarning:
            return .inspecting
        case .failureRecovery:
            return .curious
        case .noCatFound:
            return .noCatFound
        case .imageQualityWarning:
            return .inspecting
        case .glintHint:
            return .hint
        case .privacyEducation:
            return .privacy
        }
    }

    var motion: LociMascotAnimation {
        switch self {
        case .emptyCollection:
            return .idle
        case .cardSaved:
            return .successPop
        case .recoverableWarning, .imageQualityWarning:
            return .thinking
        case .failureRecovery, .noCatFound:
            return .errorTilt
        case .glintHint:
            return .idle
        case .privacyEducation:
            return .none
        }
    }

    var title: String {
        switch self {
        case .emptyCollection:
            return "Meet Your First Local"
        case .cardSaved:
            return "Card ready"
        case .recoverableWarning:
            return "This photo may need another try"
        case .failureRecovery:
            return "Something went wrong"
        case .noCatFound:
            return "I couldn't find the cat clearly"
        case .imageQualityWarning:
            return "This photo looks a little unclear"
        case .glintHint:
            return "Press and drag to catch the glint"
        case .privacyEducation:
            return "Nothing leaves your phone"
        }
    }

    var subtitle: String? {
        switch self {
        case .emptyCollection:
            return "Capture an encounter and turn it into a local card."
        case .cardSaved:
            return "Saved locally to your collection."
        case .recoverableWarning:
            return "A brighter, sharper photo will make a better card."
        case .failureRecovery:
            return "Try again in a moment."
        case .noCatFound:
            return "Try a brighter photo where your cat is fully visible."
        case .imageQualityWarning:
            return "Good lighting helps CatLocal make a cleaner cutout."
        case .glintHint:
            return "Your cards react to touch."
        case .privacyEducation:
            return "CatLocal processes your cat images on-device."
        }
    }

    var role: CatAttentionRole {
        switch self {
        case .cardSaved:
            return .success
        case .recoverableWarning, .failureRecovery, .noCatFound, .imageQualityWarning:
            return .warning
        case .privacyEducation:
            return .info
        case .emptyCollection:
            return .action
        case .glintHint:
            return .neutral
        }
    }
}

struct LociMascotState: Equatable, Identifiable {
    var context: LociContext?
    var pose: LociPose
    var motion: LociMascotAnimation
    var title: String
    var subtitle: String?

    var id: String {
        [
            context?.id ?? "custom",
            pose.rawValue,
            motion.rawValue,
            title,
            subtitle ?? ""
        ].joined(separator: "|")
    }

    init(
        context: LociContext,
        pose: LociPose? = nil,
        motion: LociMascotAnimation? = nil,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        self.context = context
        self.pose = pose ?? context.pose
        self.motion = motion ?? context.motion
        self.title = title ?? context.title
        self.subtitle = subtitle ?? context.subtitle
    }

    init(
        pose: LociPose,
        motion: LociMascotAnimation = .none,
        title: String = "",
        subtitle: String? = nil,
        context: LociContext? = nil
    ) {
        self.context = context
        self.pose = pose
        self.motion = motion
        self.title = title
        self.subtitle = subtitle
    }

    static func state(for context: LociContext) -> LociMascotState {
        LociMascotState(
            context: context,
            pose: context.pose,
            motion: context.motion,
            title: context.title,
            subtitle: context.subtitle
        )
    }
}
