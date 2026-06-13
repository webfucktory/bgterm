import XCTest
@testable import BgtermCore

final class SmokeTest: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(BgtermCore.version, "0.1.0")
    }
}
