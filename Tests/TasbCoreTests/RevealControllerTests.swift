import XCTest
@testable import TasbCore

final class FakeWindow: WindowControlling {
    private(set) var focused = false
    private(set) var focusCalls = 0
    private(set) var unfocusCalls = 0
    func enterFocused() { focused = true; focusCalls += 1 }
    func enterWallpaper() { focused = false; unfocusCalls += 1 }
}

final class RevealControllerTests: XCTestCase {
    private func makeController() -> (RevealController, FakeWindow) {
        let window = FakeWindow()
        // debounceThreshold 2: visibility must hold for two samples.
        let controller = RevealController(window: window, debounceThreshold: 2)
        return (controller, window)
    }

    func testStartsInWallpaper() {
        let (controller, window) = makeController()
        XCTAssertEqual(controller.state, .wallpaper)
        XCTAssertFalse(window.focused)
    }

    func testSingleVisibleSampleDoesNotFocus_debounce() {
        let (controller, window) = makeController()
        controller.sampleDesktopVisible(true)
        XCTAssertEqual(controller.state, .wallpaper)
        XCTAssertFalse(window.focused)
    }

    func testTwoConsecutiveVisibleSamplesFocus() {
        let (controller, window) = makeController()
        controller.sampleDesktopVisible(true)
        controller.sampleDesktopVisible(true)
        XCTAssertEqual(controller.state, .focused)
        XCTAssertEqual(window.focusCalls, 1)
    }

    func testVisibleStreakResetsOnFalse() {
        let (controller, window) = makeController()
        controller.sampleDesktopVisible(true)
        controller.sampleDesktopVisible(false) // resets streak
        controller.sampleDesktopVisible(true)
        XCTAssertEqual(controller.state, .wallpaper)
        XCTAssertFalse(window.focused)
    }

    func testHotkeyForcesFocusImmediately() {
        let (controller, window) = makeController()
        controller.forceFocus()
        XCTAssertEqual(controller.state, .focused)
        XCTAssertEqual(window.focusCalls, 1)
    }

    func testEscReturnsToWallpaper() {
        let (controller, window) = makeController()
        controller.forceFocus()
        controller.escapePressed()
        XCTAssertEqual(controller.state, .wallpaper)
        XCTAssertEqual(window.unfocusCalls, 1)
    }

    func testWindowsReappearReturnsToWallpaper() {
        let (controller, window) = makeController()
        controller.sampleDesktopVisible(true)
        controller.sampleDesktopVisible(true) // focused
        controller.sampleDesktopVisible(false) // a window covered the screen
        XCTAssertEqual(controller.state, .wallpaper)
        XCTAssertEqual(window.unfocusCalls, 1)
    }

    func testRedundantTransitionsDoNotRefireWindowControl() {
        let (controller, window) = makeController()
        controller.sampleDesktopVisible(true)
        controller.sampleDesktopVisible(true) // focus once
        controller.sampleDesktopVisible(true) // already focused, no-op
        XCTAssertEqual(window.focusCalls, 1)
    }
}
