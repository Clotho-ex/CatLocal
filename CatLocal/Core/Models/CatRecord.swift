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
    case topoEmber
    case topoLagoon
    case topoMoss
    case topoDusk
    case pineShadow
    case cedarShade
    case fernTrace
    case mossVeil
    case cobaltHalo
    case apricotBeam
    case auroraPool

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
        .topo,
        .topoEmber,
        .topoLagoon,
        .topoMoss,
        .topoDusk,
        .pineShadow,
        .cedarShade,
        .fernTrace,
        .mossVeil,
        .cobaltHalo,
        .apricotBeam,
        .auroraPool
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
            "Contour Light"
        case .topoEmber:
            "Ember Lines"
        case .topoLagoon:
            "Lagoon Lines"
        case .topoMoss:
            "Moss Lines"
        case .topoDusk:
            "Dusk Lines"
        case .pineShadow:
            "Pine Shadow"
        case .cedarShade:
            "Cedar Shade"
        case .fernTrace:
            "Fern Trace"
        case .mossVeil:
            "Moss Veil"
        case .cobaltHalo:
            "Cobalt Halo"
        case .apricotBeam:
            "Apricot Beam"
        case .auroraPool:
            "Aurora Pool"
        }
    }

    var isArchiveMaterial: Bool {
        switch self {
        case .pineShadow, .cedarShade, .fernTrace, .mossVeil:
            true
        default:
            false
        }
    }

    var archiveMaterialVariantIndex: Int {
        switch self {
        case .pineShadow:
            0
        case .cedarShade:
            1
        case .fernTrace:
            2
        case .mossVeil:
            3
        default:
            0
        }
    }

    var isLightEffect: Bool {
        switch self {
        case .cobaltHalo, .apricotBeam, .auroraPool:
            true
        default:
            false
        }
    }

    var lightEffectVariantIndex: Int {
        switch self {
        case .cobaltHalo:
            0
        case .apricotBeam:
            1
        case .auroraPool:
            2
        default:
            0
        }
    }

    var isTopographic: Bool {
        switch self {
        case .topo, .topoEmber, .topoLagoon, .topoMoss, .topoDusk:
            true
        default:
            false
        }
    }

    var topographicVariantIndex: Int {
        switch self {
        case .topo:
            0
        case .topoEmber:
            1
        case .topoLagoon:
            2
        case .topoMoss:
            3
        case .topoDusk:
            4
        default:
            0
        }
    }

    static func deterministic(seed: Int) -> CardStyle {
        .archive
    }
}

enum CatNamePool {
    static let names: [String] = [
        "Almond", "Apricot", "Ash", "Basil", "Bean",
        "Biscuit", "Borek", "Boots", "Brie", "Button",
        "Cashew", "Chai", "Cherry", "Cinnamon", "Clover",
        "Coco", "Cookie", "Daisy", "Daphne", "Duman",
        "Fig", "Findik", "Fiona", "Ginger", "Hazel",
        "Honey", "Jasper", "Juniper", "Karamel", "Kiki",
        "Kimchi", "Kiwi", "Lemon", "Leo", "Lila",
        "Loki", "Lokum", "Luna", "Maple", "Marble",
        "Marmalade", "Mavi", "Mimi", "Milo", "Miso",
        "Mochi", "Momo", "Nala", "Nane", "Nori",
        "Olive", "Oscar", "Pasha", "Peanut", "Pebble",
        "Pepper", "Pickle", "Pillow", "Pippin", "Pixel",
        "Plum", "Poppy", "Pumpkin", "Remy", "Ruby",
        "Saffron", "Sage", "Sesame", "Shadow", "Simit",
        "Socks", "Suki", "Sunny", "Taffy", "Tango",
        "Teddy", "Tofu", "Truffle", "Velvet", "Zeytin",
        "Apricot Pasha", "Basil Boots", "Biscuit Miso", "Blueberry Socks", "Butter Bean",
        "Chai Button", "Cherry Button", "Cinnamon Momo", "Clover Nori", "Cocoa Pebble",
        "Cookie Pasha", "Daisy Mochi", "Fig Biscuit", "Ginger Pixel", "Hazel Miso",
        "Honey Pippin", "Juniper Socks", "Karamel Pasha", "Kiwi Button", "Lemon Boots",
        "Lila Bean", "Lokum Socks", "Maple Mochi", "Marble Pasha", "Marmalade Mimi",
        "Mavi Biscuit", "Milo Button", "Miso Pasha", "Mochi Boots", "Nala Bean",
        "Nori Button", "Olive Pasha", "Peanut Socks", "Pebble Miso", "Pepper Boots",
        "Pickle Button", "Pillow Pasha", "Pixel Miso", "Plum Mochi", "Pumpkin Pasha",
        "Ruby Biscuit", "Saffron Socks", "Sesame Bean", "Simit Pasha", "Sunny Mochi",
        "Taffy Boots", "Tango Miso", "Teddy Button", "Tofu Socks", "Truffle Pasha"
    ]

    static func randomName(excluding existingNames: Set<String> = []) -> String {
        let availableNames = names.filter { !existingNames.contains($0) }
        return (availableNames.isEmpty ? names : availableNames).randomElement() ?? "Miso"
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
