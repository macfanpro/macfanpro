import Combine
import Foundation
import Testing
@testable import MacFanProLocalization

@Suite("GUI localization — isolated preferences and no fan control")
struct LocalizationTests {
    @Test("Three complete catalogs preserve every English message and dynamic token")
    func completeCatalogs() throws {
        let catalog = LocalizationCatalog.bundled
        let english = try #require(catalog.translations[.english])
        #expect(english.count >= 47)
        for language in LocalizationCatalog.supportedLanguages {
            let table = try #require(catalog.translations[language])
            #expect(Set(table.keys) == Set(english.keys))
            for (key, value) in table {
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(LocalizationCatalog.placeholders(in: value) == LocalizationCatalog.placeholders(in: key))
            }
        }
        #expect(english.allSatisfy { $0.key == $0.value })
        #expect(catalog.text("Performance", language: .traditionalChinese) == "性能")
        #expect(catalog.text("Reading sensors...", language: .traditionalChinese) == "正在讀取傳感器…")
        let simplified = try #require(catalog.translations[.simplifiedChinese])
        for (key, value) in simplified {
            #expect(catalog.translations[.traditionalChinese]?[key]
                    == value.applyingTransform(StringTransform("Simplified-Traditional"), reverse: false))
        }
    }

    @Test("Missing, empty and broken translations fall back to English")
    func fallback() {
        let catalog = LocalizationCatalog(translations: [
            .english: ["Fan {index}": "Fan {index}", "Idle": "Idle"],
            .simplifiedChinese: ["Idle": "", "Fan {index}": "风扇 {wrong}"],
        ])
        #expect(catalog.text("Idle", language: .simplifiedChinese) == "Idle")
        #expect(catalog.text("Idle", language: .traditionalChinese) == "Idle")
        #expect(catalog.text("Fan {index}", language: .simplifiedChinese, arguments: ["index": "2"]) == "Fan 2")
        #expect(catalog.text("New upstream English copy", language: .traditionalChinese) == "New upstream English copy")
    }

    @Test("Dynamic values are substituted once and remain literal")
    func formatting() {
        let catalog = LocalizationCatalog.bundled
        #expect(catalog.text("{temperature}°{unit} instant", language: .traditionalChinese,
                             arguments: ["temperature": "149", "unit": "F"]) == "149°F 即時觸發")
        #expect(catalog.text("MacFanPro {version} is available. You have {appVersion}.",
                             language: .english, arguments: ["version": "{appVersion}", "appVersion": "0.2.3.6"])
                == "MacFanPro {appVersion} is available. You have 0.2.3.6.")
    }

    @Test("System preference order, regions and explicit scripts select a supported language")
    func preferredLanguages() {
        let cases: [([String], AppLanguage)] = [
            // The first supported language in the system order wins.
            (["ja-JP", "zh-Hans-CN"], .japanese), (["sv-SE", "zh-Hans-CN"], .simplifiedChinese),
            (["de-DE"], .german), (["sv-SE", "fi-FI"], .english), ([], .english),
            (["fr-FR", "en-GB", "zh-Hant"], .french), (["en-GB", "fr-FR"], .english),
            (["ko-KR"], .korean), (["es-MX"], .spanish), (["it-IT"], .italian),
            (["pt-BR"], .portugueseBrazil), (["pt-PT"], .portugueseBrazil),
            (["ru-RU"], .russian), (["uk-UA"], .ukrainian), (["pl-PL"], .polish),
            (["nl-BE"], .dutch), (["tr-TR"], .turkish), (["vi-VN"], .vietnamese),
            (["id-ID"], .indonesian), (["in-ID"], .indonesian),
            (["zh-TW", "en"], .traditionalChinese),
            (["zh-HK"], .traditionalChinese), (["zh-MO"], .traditionalChinese),
            (["zh_CN"], .simplifiedChinese), (["zh-SG"], .simplifiedChinese),
            (["zh-Hans-TW"], .simplifiedChinese), (["zh-Hant-CN"], .traditionalChinese),
        ]
        for (preferred, expected) in cases {
            #expect(AppLanguage.resolve(preferredLanguages: preferred) == expected)
        }
    }

    @Test("Selection persists and publishes immediately without changing any control preference")
    @MainActor
    func persistenceAndNotifications() throws {
        let name = "MacFanPro.LocalizationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let control: [String: Any] = ["selectedProfile": "smart", "useFahrenheit": true, "unrelated": "keep"]
        defaults.setPersistentDomain(control, forName: name)
        var preferred = ["sv-SE", "zh-Hans"] // Swedish has no table
        let store = AppLanguageStore(defaults: defaults, preferredLanguages: { preferred })
        #expect(store.selection == .system)
        #expect(store.language == .simplifiedChinese)
        #expect(defaults.string(forKey: AppLanguageStore.preferenceKey) == nil)
        var changes: [AppLanguage] = []
        let subscription = store.$language.sink { changes.append($0) }
        for choice in [AppLanguage.english, .traditionalChinese, .simplifiedChinese, .system] {
            store.select(choice)
            #expect(defaults.string(forKey: AppLanguageStore.preferenceKey) == choice.rawValue)
            let reopened = AppLanguageStore(defaults: defaults, preferredLanguages: { preferred })
            #expect(reopened.selection == choice)
            #expect(reopened.language == store.language)
            for (key, value) in control { #expect((defaults.object(forKey: key) as? NSObject) == value as? NSObject) }
        }
        preferred = ["sv-SE"]
        store.refreshSystemLanguage()
        #expect(store.language == .english)
        #expect(changes.contains(.english) && changes.contains(.traditionalChinese) && changes.contains(.simplifiedChinese))
        withExtendedLifetime(subscription) {}
    }
}
