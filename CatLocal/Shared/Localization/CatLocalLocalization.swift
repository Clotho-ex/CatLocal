import Foundation
import SwiftUI

enum CatLocalLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }

    static func resolved(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .system
    }

    static func userPreference(_ rawValue: String?) -> Self {
        rawValue == Self.english.rawValue ? .english : .system
    }

    static func shouldOfferEnglishFallback(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Bool {
        let supportedLanguageCodes = Set(
            allCases
                .filter { $0 != .system }
                .map(\.rawValue)
        )

        for preferredLanguage in preferredLanguages {
            guard let languageCode = Locale(identifier: preferredLanguage)
                .language
                .languageCode?
                .identifier,
                  supportedLanguageCodes.contains(languageCode)
            else {
                continue
            }

            return languageCode != Self.english.rawValue
        }

        return false
    }

    static func englishFallbackSelection(from current: Self) -> Self {
        current == .english ? .system : .english
    }
}

enum CatLocalLocalization {
    static func string(_ key: String, language: CatLocalLanguage) -> String {
        localizedBundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    static var selectedLanguage: CatLocalLanguage {
        CatLocalLanguage.userPreference(
            UserDefaults.standard.string(forKey: CatLocalUserDefaults.languageKey)
        )
    }

    static func string(_ key: String) -> String {
        string(key, language: selectedLanguage)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, language: selectedLanguage, arguments: arguments)
    }

    static func plural(_ key: String, count: Int) -> String {
        format(key, language: selectedLanguage, Int64(count))
    }

    static func plural(
        _ key: String,
        count: Int,
        language: CatLocalLanguage
    ) -> String {
        format(key, language: language, Int64(count))
    }

    static func cardStyleSummary(
        styleCount: Int,
        familyCount: Int,
        language: CatLocalLanguage = selectedLanguage
    ) -> String {
        let localizedFamilyCount = plural(
            "%lld families",
            count: familyCount,
            language: language
        )
        return format(
            "%1$lld in %2$@",
            language: language,
            Int64(styleCount),
            localizedFamilyCount
        )
    }

    static func format(
        _ key: String,
        language: CatLocalLanguage,
        _ arguments: CVarArg...
    ) -> String {
        format(key, language: language, arguments: arguments)
    }

    private static func format(
        _ key: String,
        language: CatLocalLanguage,
        arguments: [CVarArg]
    ) -> String {
        String(
            format: string(key, language: language),
            locale: language.locale,
            arguments: arguments
        )
    }

    private static func localizedBundle(for language: CatLocalLanguage) -> Bundle {
        guard language != .system,
              let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return Bundle.main
        }

        return bundle
    }
}

extension String {
    var catLocalized: String {
        CatLocalLocalization.string(self)
    }
}

extension Text {
    init(catLocalKey key: String) {
        self.init(LocalizedStringKey(key))
    }
}
