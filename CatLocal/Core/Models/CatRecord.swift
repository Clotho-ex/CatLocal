import Foundation
import SwiftData

@Model
final class CatRecord {
    var id: UUID
    var sequence: Int
    var capturedAt: Date
    var nickname: String
    var note: String
    var placeName: String = ""
    var placeDetail: String = ""
    var sourceRawValue: String
    var cardStyleRawValue: String
    var styleSeed: Int
    var hasCatBoundingBox: Bool = false
    var catBoundingBoxX: Double = 0
    var catBoundingBoxY: Double = 0
    var catBoundingBoxWidth: Double = 0
    var catBoundingBoxHeight: Double = 0
    var originalImagePath: String
    var cutoutImagePath: String
    var thumbnailImagePath: String

    init(
        id: UUID = UUID(),
        sequence: Int,
        capturedAt: Date = Date(),
        nickname: String = "",
        note: String = "",
        placeName: String = "",
        placeDetail: String = "",
        source: CaptureSource,
        cardStyle: CardStyle,
        styleSeed: Int,
        catBoundingBox: CGRect? = nil,
        originalImagePath: String,
        cutoutImagePath: String,
        thumbnailImagePath: String
    ) {
        self.id = id
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.nickname = nickname
        self.note = note
        self.placeName = placeName
        self.placeDetail = placeDetail
        sourceRawValue = source.rawValue
        cardStyleRawValue = cardStyle.rawValue
        self.styleSeed = styleSeed
        if let catBoundingBox {
            hasCatBoundingBox = true
            catBoundingBoxX = catBoundingBox.origin.x
            catBoundingBoxY = catBoundingBox.origin.y
            catBoundingBoxWidth = catBoundingBox.size.width
            catBoundingBoxHeight = catBoundingBox.size.height
        }
        self.originalImagePath = originalImagePath
        self.cutoutImagePath = cutoutImagePath
        self.thumbnailImagePath = thumbnailImagePath
    }

    var source: CaptureSource {
        CaptureSource(rawValue: sourceRawValue) ?? .camera
    }

    var cardStyle: CardStyle {
        get { CardStyle(rawValue: cardStyleRawValue) ?? .archive }
        set { cardStyleRawValue = newValue.rawValue }
    }

    var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? CatNamePool.stableName(id: id, sequence: sequence) : trimmed
    }

    var memoryPlaceName: String? {
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var memoryPlaceDetail: String? {
        let trimmed = placeDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var memoryPlaceLabel: String? {
        guard let memoryPlaceName else { return nil }
        if let memoryPlaceDetail {
            return "\(memoryPlaceName), \(memoryPlaceDetail)"
        }
        return memoryPlaceName
    }

    var atlasGroupTitle: String {
        memoryPlaceName ?? "Unplaced"
    }

    var catBoundingBox: CGRect? {
        guard hasCatBoundingBox else { return nil }
        return CGRect(
            x: catBoundingBoxX,
            y: catBoundingBoxY,
            width: catBoundingBoxWidth,
            height: catBoundingBoxHeight
        )
    }

    static func compactSequences(_ records: [CatRecord]) {
        let orderedRecords = records.sorted { lhs, rhs in
            if lhs.sequence != rhs.sequence {
                return lhs.sequence < rhs.sequence
            }
            if lhs.capturedAt != rhs.capturedAt {
                return lhs.capturedAt < rhs.capturedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        for (index, record) in orderedRecords.enumerated() {
            let compactedSequence = index + 1
            if record.sequence != compactedSequence {
                record.sequence = compactedSequence
            }
        }
    }
}

enum CaptureSource: String, Codable, CaseIterable, Sendable {
    case camera
    case photoLibrary

    var label: String {
        switch self {
        case .camera: "Camera"
        case .photoLibrary: "Private import"
        }
    }
}

enum CardStyle: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case archive
    case sunstamp
    case clear
    case garden
    case midnight
    case apricot
    case prism
    case gold
    case topo

    var id: String { rawValue }

    static let orderedCases: [CardStyle] = [
        .archive,
        .sunstamp,
        .clear,
        .garden,
        .midnight,
        .apricot,
        .prism,
        .gold,
        .topo
    ]

    var displayIndex: Int {
        Self.orderedCases.firstIndex(of: self) ?? 0
    }

    var title: String {
        switch self {
        case .archive:
            "Archive"
        case .sunstamp:
            "Sunstamp"
        case .clear:
            "Clear"
        case .garden:
            "Garden"
        case .midnight:
            "Midnight"
        case .apricot:
            "Apricot"
        case .prism:
            "Midnight Prism"
        case .gold:
            "Gold Leaf"
        case .topo:
            "Topographic"
        }
    }

    static func deterministic(seed: Int) -> CardStyle {
        .archive
    }
}

enum CatNamePool {
    static let names: [String] = [
        "Nimbus Nibbler", "Juniper Jumps", "Maple Menace", "Velvet Voltage", "Cosmic Crumbs",
        "Mothball Monarch", "Cricket Commander", "Pickpocket Peach", "Snuggle Static", "Marble Mirage",
        "Purrlock Holmes", "Fennel Phantom", "Wobblesworth", "Cherry Chomper", "Dust Bunny",
        "Hazel Hiccup", "Sugar Goblin", "Zipper Zephyr", "Mango Minister", "Taco Bandolier",
        "Coconut Courier", "Quasar Kitty", "Pancetta Paws", "Bubble Baroness", "Tofu Tycoon",
        "Licorice Lurker", "Mittens McZoom", "Pistachio Phantom", "Yogurt Yeti", "Ramen Ranger",
        "Gizmo Gremlin", "Peachy Purrkins", "Froyo Bandit", "Sprout Sniper", "Muffler Munch",
        "Cactus Cuddles", "Tiramisu Tiger", "Pillow Pirate", "Clover Comet", "Bumble Beans",
        "Sardine Sultan", "Mulberry Mew", "Whisker Wobble", "Plum Bandit", "Cabbage King",
        "Dizzy Dumpling", "Sushi Specter", "Brûlée Bandit", "Cereal Baron", "Mochaccino Mew",
        "Turbo Tofu", "Lemon Loaf", "Bramble Biscuit", "Caramel Gremlin", "Snail Sprinter",
        "Paprika Purr", "Taco Phantom", "Pearl Pouncer", "Meringue Menace", "Saffron Sultan",
        "Cuddle Circuit", "Cloudberry Cat", "Bumble Baron", "Tuna Typhoon", "Riceball Rogue",
        "Hazelnut Houdini", "Kiki Kaboom", "Marshmallow Mage", "Zucchini Zoomer", "Cashew Count",
        "Lentil Legend", "Pickled Phantom", "Purrito Bandit", "Wiggle Wizard", "Couscous Captain",
        "Mango Monarch", "Bento Bandit", "Twinkle Tofu", "Macaron Marauder", "Basil Bandit",
        "Carrot Comet", "Nectarine Ninja", "Snuggle Sphinx", "Grape Goblin", "Crackle Cat",
        "Poppy Phantom", "Coconut Countess", "Mushroom Mayor", "Papaya Pirate", "Fizzy Feline",
        "Butterscotch Boss", "Hazel Hopper", "Slinky Sultan", "Cranberry Count", "Purrfect Storm",
        "Chonky Chimera", "Dandelion Dash", "Nori Nomad", "Miso Meteor", "Burrito Baron",
        "Sable Scooter", "Cheeky Chestnut", "Tangerine Trickster", "Pecan Pouncer", "Mellow Mackerel",
        "Fudge Falcon", "Curry Cloud", "Waffle Wraith", "Peanut Phantom", "Loki Loaf",
        "Sultan Snuggle", "Mango Mancer", "Tumble Truffle", "Cocoa Courier", "Whimsy Whiskers",
        "Pillow Pasha", "Moonbeam Miso", "Sprinkles McPurr", "Biscuit Mirage", "Taffy Tycoon",
        "Karamel Kitty", "Simit Sultan", "Lokum Loafer", "Börek Bandit", "Meze Monarch",
        "Kumpir King", "Ayran Admiral", "Dolma Drifter", "Zeytin Zoomer", "Künefe Comet"
    ]

    static func randomName(excluding existingNames: Set<String> = []) -> String {
        let availableNames = names.filter { !existingNames.contains($0) }
        return (availableNames.isEmpty ? names : availableNames).randomElement() ?? "Nimbus Nibbler"
    }

    static func stableName(id: UUID, sequence: Int) -> String {
        let seed = id.uuidString.unicodeScalars.reduce(sequence) { partial, scalar in
            partial + Int(scalar.value)
        }
        return names[abs(seed) % names.count]
    }
}

struct CatDetection: Identifiable, Hashable, Sendable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Float

    init(id: UUID = UUID(), boundingBox: CGRect, confidence: Float) {
        self.id = id
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

enum CatDetectionResolution: Equatable, Sendable {
    case none
    case single(CatDetection)
    case multiple([CatDetection])
}

enum CatDetectionSelector {
    static func resolve(_ detections: [CatDetection]) -> CatDetectionResolution {
        let sorted = detections.sorted { $0.confidence > $1.confidence }
        switch sorted.count {
        case 0:
            return .none
        case 1:
            return .single(sorted[0])
        default:
            return .multiple(sorted)
        }
    }
}
