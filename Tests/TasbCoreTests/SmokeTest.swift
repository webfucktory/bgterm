import XCTest
@testable import TasbCore

final class SmokeTest: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(TasbCore.version, "0.1.0")
    }
}
