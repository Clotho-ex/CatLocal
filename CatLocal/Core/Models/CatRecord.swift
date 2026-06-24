import Foundation
import SwiftData

@Model
final class CatRecord {
    var id: UUID
    var sequence: Int
    var capturedAt: Date
    var nickname: String
    var note: String
    var sourceRawValue: String
    var cardStyleRawValue: String
    var styleSeed: Int
    var originalImagePath: String
    var cutoutImagePath: String
    var thumbnailImagePath: String

    init(
        id: UUID = UUID(),
        sequence: Int,
        capturedAt: Date = Date(),
        nickname: String = "",
        note: String = "",
        source: CaptureSource,
        cardStyle: CardStyle,
        styleSeed: Int,
        originalImagePath: String,
        cutoutImagePath: String,
        thumbnailImagePath: String
    ) {
        self.id = id
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.nickname = nickname
        self.note = note
        sourceRawValue = source.rawValue
        cardStyleRawValue = cardStyle.rawValue
        self.styleSeed = styleSeed
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
        return trimmed.isEmpty ? "Local \(sequence.formatted(.number.precision(.integerLength(3))))" : trimmed
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

enum CardStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case archive
    case sunstamp
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .archive: "Archive"
        case .sunstamp: "Sunstamp"
        case .clear: "Clear"
        }
    }

    static func deterministic(seed: Int) -> CardStyle {
        let styles = allCases
        return styles[abs(seed) % styles.count]
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
