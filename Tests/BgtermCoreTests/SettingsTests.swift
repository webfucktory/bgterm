import XCTest
@testable import BgtermCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let store = InMemoryStore()
        let settings = Settings(store: store)
        XCTAssertEqual(settings.opacity, 1.0)
        XCTAssertEqual(settings.fontSize, 14)
        XCTAssertEqual(settings.fontName, "SF Mono")
        XCTAssertTrue(settings.enabledOnLaunch)
    }

    func testRoundTripPersistsThroughStore() {
        let store = InMemoryStore()
        var settings = Settings(store: store)
        settings.opacity = 0.6
        settings.fontSize = 18

        let reloaded = Settings(store: store)
        XCTAssertEqual(reloaded.opacity, 0.6)
        XCTAssertEqual(reloaded.fontSize, 18)
    }

    func testOpacityIsClampedToUnitRange() {
        var settings = Settings(store: InMemoryStore())
        settings.opacity = 2.5
        XCTAssertEqual(settings.opacity, 1.0)
        settings.opacity = -1
        XCTAssertEqual(settings.opacity, 0.1) // floor keeps text legible
    }
}

final class InMemoryStore: KeyValueStore {
    private var values: [String: Any] = [:]
    func double(forKey key: String) -> Double? { values[key] as? Double }
    func integer(forKey key: String) -> Int? { values[key] as? Int }
    func bool(forKey key: String) -> Bool? { values[key] as? Bool }
    func string(forKey key: String) -> String? { values[key] as? String }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}
