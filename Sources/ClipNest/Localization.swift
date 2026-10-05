// Responsibility: app-only language override, otherwise system and macOS per-app languages.
// Development status: complete.
import Foundation
enum AppLanguage {
    static let supported = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "es", "fr", "de"]
    static let names = ["English", "简体中文", "繁體中文", "日本語", "한국어", "Español", "Français", "Deutsch"]
    static var override: String? { UserDefaults.standard.string(forKey: "ClipNestLanguage") }
    static func select(_ value: String?) {
        if let value, supported.contains(value) { UserDefaults.standard.set(value, forKey: "ClipNestLanguage") }
        else { UserDefaults.standard.removeObject(forKey: "ClipNestLanguage") }
    }
    static var bundle: Bundle {
        let language = override.flatMap { supported.contains($0) ? $0 : nil }
            ?? Bundle.main.preferredLocalizations.first ?? "en"
        return Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
            ?? Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }
}
func L(_ key: String) -> String { AppLanguage.bundle.localizedString(forKey: key, value: key, table: nil) }
