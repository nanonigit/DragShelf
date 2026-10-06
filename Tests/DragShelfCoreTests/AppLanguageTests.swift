import XCTest
@testable import DragShelfCore

final class AppLanguageTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let suite = "DragShelf.LanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testFreshInstallDefaultsToEnglishRegardlessOfSystemLanguage() {
        let store = defaults()
        store.set(["ja"], forKey: "AppleLanguages")
        XCTAssertEqual(AppLanguage.restored(from: store), .english)
    }

    func testLanguagePersistsAndDoesNotChangeOtherPreferences() {
        let store = defaults()
        store.set("leftBottom", forKey: "shelfPlacement")
        for language in AppLanguage.allCases {
            language.save(to: store)
            XCTAssertEqual(AppLanguage.restored(from: store), language)
            XCTAssertEqual(store.string(forKey: "shelfPlacement"), "leftBottom")
        }
    }

    func testInvalidStoredLanguageFallsBackToEnglish() {
        let store = defaults()
        for value in ["", "fr", "japanese", "JA"] {
            store.set(value, forKey: AppLanguage.preferenceKey)
            XCTAssertEqual(AppLanguage.restored(from: store), .english)
        }
    }

    func testEveryTextHasBothTranslationsAndMatchingFormatArguments() {
        for key in AppText.allCases {
            let english = key.text(in: .english)
            let japanese = key.text(in: .japanese)
            XCTAssertFalse(english.isEmpty, "\(key)")
            XCTAssertFalse(japanese.isEmpty, "\(key)")
            XCTAssertEqual(english.filter { $0 == "%" }.count,
                           japanese.filter { $0 == "%" }.count, "\(key)")
        }
        XCTAssertEqual(AppText.settings.text(in: .english), "Settings")
        XCTAssertEqual(AppText.settings.text(in: .japanese), "設定")
        XCTAssertEqual(String(format: AppText.parkedCount.text(in: .english), 3), "Parked: 3 items")
        XCTAssertEqual(String(format: AppText.parkedCount.text(in: .japanese), 3), "一時置き: 3 件")
    }
}
