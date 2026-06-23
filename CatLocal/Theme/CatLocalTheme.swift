import SwiftUI

enum CatLocalTheme {
    static let limestone = Color(red: 0.94, green: 0.92, blue: 0.87)
    static let chalk = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let forest = Color(red: 0.06, green: 0.18, blue: 0.12)
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.11)
    static let apricot = Color(red: 0.88, green: 0.35, blue: 0.13)
    static let cobalt = Color(red: 0.15, green: 0.36, blue: 0.62)

    static func accent(_ accent: CardAccent) -> Color {
        switch accent {
        case .forest:
            forest
        case .apricot:
            apricot
        case .cobalt:
            cobalt
        }
    }
}
