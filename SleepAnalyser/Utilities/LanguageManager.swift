import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }

    var nativeDisplayName: String {
        switch self {
        case .system: return systemLanguageLabel()
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }

    private func systemLanguageLabel() -> String {
        let code = Locale.preferredLanguages.first ?? "en"
        if code.hasPrefix("zh-Hant") || code.hasPrefix("zh-TW") || code.hasPrefix("zh-HK") {
            return "跟随系统 (繁體中文)"
        } else if code.hasPrefix("zh") {
            return "跟随系统 (简体中文)"
        }
        return "System (English)"
    }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    private static let storageKey = "app.selectedLanguage"

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.storageKey)
            reloadBundle()
        }
    }

    private(set) var bundle: Bundle

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey) ?? "system"
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .system
        self.bundle = Bundle.main
        reloadBundle()
    }

    var effectiveLanguageCode: String {
        switch currentLanguage {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
                return "zh-Hant"
            } else if preferred.hasPrefix("zh") {
                return "zh-Hans"
            }
            return "en"
        case .en, .zhHans, .zhHant:
            return currentLanguage.rawValue
        }
    }

    private func reloadBundle() {
        let code = effectiveLanguageCode
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = Bundle.main
        }
    }

    func localizedString(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    func localizedString(_ key: String, table: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: table)
    }
}
