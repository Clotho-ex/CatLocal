import Foundation

struct CatCard: Identifiable, Hashable {
    let id: UUID
    let sequence: Int
    let name: String
    let neighborhood: String
    let date: Date
    let note: String
    let imageName: String
    let accent: CardAccent

    init(
        id: UUID = UUID(),
        sequence: Int,
        name: String,
        neighborhood: String,
        date: Date,
        note: String,
        imageName: String,
        accent: CardAccent
    ) {
        self.id = id
        self.sequence = sequence
        self.name = name
        self.neighborhood = neighborhood
        self.date = date
        self.note = note
        self.imageName = imageName
        self.accent = accent
    }
}

enum CardAccent: String, Hashable {
    case forest
    case apricot
    case cobalt
}

extension CatCard {
    static let samples: [CatCard] = [
        CatCard(
            sequence: 13,
            name: "Nori",
            neighborhood: "Kadıköy",
            date: Date(timeIntervalSince1970: 1_747_526_400),
            note: "Sat in the warm doorway and watched the world go by.",
            imageName: "Nori",
            accent: .apricot
        ),
        CatCard(
            sequence: 12,
            name: "Miso",
            neighborhood: "Karaköy",
            date: Date(timeIntervalSince1970: 1_746_662_400),
            note: "Waited beside the old green door until the rain passed.",
            imageName: "Miso",
            accent: .forest
        ),
        CatCard(
            sequence: 4,
            name: "Tarçın",
            neighborhood: "Sultanahmet",
            date: Date(timeIntervalSince1970: 1_744_588_800),
            note: "Found the last patch of afternoon sun.",
            imageName: "Tarcin",
            accent: .cobalt
        ),
        CatCard(
            sequence: 9,
            name: "Pera",
            neighborhood: "Beyoğlu",
            date: Date(timeIntervalSince1970: 1_745_625_600),
            note: "Quietly supervised the morning deliveries.",
            imageName: "Tarcin",
            accent: .apricot
        ),
        CatCard(
            sequence: 7,
            name: "Zeytin",
            neighborhood: "Moda",
            date: Date(timeIntervalSince1970: 1_743_292_800),
            note: "Appeared at the same garden wall before sunset.",
            imageName: "Nori",
            accent: .forest
        ),
        CatCard(
            sequence: 1,
            name: "Gölge",
            neighborhood: "Üsküdar",
            date: Date(timeIntervalSince1970: 1_743_552_000),
            note: "A small shadow under the plane trees.",
            imageName: "Miso",
            accent: .cobalt
        )
    ]
}
