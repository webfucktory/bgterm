# tasb — Desktop Terminal Wallpaper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tray-only macOS app that renders an interactive shell as the desktop wallpaper (behind icons) and grants it keyboard focus when the desktop is revealed, with a hotkey fallback.

**Architecture:** A Swift Package with two app targets and one test target. Pure, testable logic (the reveal state machine and settings) lives in a `TasbCore` library exercised by unit tests. AppKit/SwiftTerm wiring (desktop-level window, terminal view, tray, window-list polling, Carbon hotkey) lives in the `tasb` executable and is verified by build + a documented manual checklist. The app runs as an accessory (`NSApp.setActivationPolicy(.accessory)`), so no Dock icon.

**Tech Stack:** Swift 5.9+, AppKit, [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (pinned), Carbon `RegisterEventHotKey`, `CGWindowListCopyWindowInfo`, `UserDefaults`. Built and tested with Swift Package Manager (`swift build` / `swift test`).

---

## File Structure

```
Package.swift
Sources/
  TasbCore/                      # pure, unit-tested logic (no AppKit UI)
    Settings.swift               # UserDefaults-backed config model
    RevealController.swift       # Wallpaper <-> Focused state machine + protocols
  tasb/                          # executable: AppKit + SwiftTerm wiring
    main.swift                   # entry point, activation policy, app lifecycle
    AppCoordinator.swift         # wires components together
    DesktopWindow.swift          # NSWindow subclass pinned at desktop level
    TerminalSurface.swift        # LocalProcessTerminalView + settings application
    ShellSession.swift           # headless-testable PTY echo wrapper (HeadlessTerminal)
    DesktopVisibilityMonitor.swift # CGWindowList polling -> desktopVisible provider
    HotkeyManager.swift          # Carbon global hotkey registration
    TrayController.swift         # NSStatusItem menu
    WindowController.swift       # concrete WindowControlling over DesktopWindow
Tests/
  TasbCoreTests/
    SettingsTests.swift
    RevealControllerTests.swift
  tasbTests/
    ShellSessionTests.swift      # headless terminal I/O smoke test
Resources/
  Info.plist                     # LSUIElement bundle metadata (for packaging)
Scripts/
  make-app.sh                    # assemble tasb.app bundle around the binary
```

**Responsibility boundaries:** `TasbCore` knows nothing about AppKit windows — it manipulates focus through the `WindowControlling` protocol and reads desktop visibility through an injected closure, which is what makes it unit-testable. The executable supplies the concrete implementations.

---

## Task 1: Project scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/TasbCore/Settings.swift` (stub)
- Create: `Sources/tasb/main.swift` (stub)
- Create: `Tests/TasbCoreTests/SmokeTest.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "tasb",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .target(name: "TasbCore"),
        .executableTarget(
            name: "tasb",
            dependencies: [
                "TasbCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        ),
        .testTarget(name: "TasbCoreTests", dependencies: ["TasbCore"]),
        .testTarget(
            name: "tasbTests",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]
        )
    ]
)
```

- [ ] **Step 2: Write stub sources so the package compiles**

`Sources/TasbCore/Settings.swift`:
```swift
public enum TasbCore {
    public static let version = "0.1.0"
}
```

`Sources/tasb/main.swift`:
```swift
import TasbCore

print("tasb \(TasbCore.version)")
```

- [ ] **Step 3: Write the toolchain smoke test**

`Tests/TasbCoreTests/SmokeTest.swift`:
```swift
import XCTest
@testable import TasbCore

final class SmokeTest: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(TasbCore.version, "0.1.0")
    }
}
```

- [ ] **Step 4: Build and test**

Run: `swift build && swift test`
Expected: package resolves SwiftTerm, builds, and `testVersionExists` PASSes.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold tasb swift package with SwiftTerm dependency"
```

---

## Task 2: Settings model (TDD)

A value type holding user config, persisted through an injectable `KeyValueStore` so tests don't touch the real `UserDefaults`.

**Files:**
- Modify: `Sources/TasbCore/Settings.swift`
- Test: `Tests/TasbCoreTests/SettingsTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/TasbCoreTests/SettingsTests.swift`:
```swift
import XCTest
@testable import TasbCore

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SettingsTests`
Expected: FAIL — `Settings`, `KeyValueStore` not defined.

- [ ] **Step 3: Implement `Settings` and `KeyValueStore`**

Replace `Sources/TasbCore/Settings.swift`:
```swift
import Foundation

public enum TasbCore {
    public static let version = "0.1.0"
}

/// Minimal persistence seam so Settings can be unit-tested without UserDefaults.
public protocol KeyValueStore: AnyObject {
    func double(forKey key: String) -> Double?
    func integer(forKey key: String) -> Int?
    func bool(forKey key: String) -> Bool?
    func string(forKey key: String) -> String?
    func set(_ value: Any?, forKey key: String)
}

public struct Settings {
    private let store: KeyValueStore

    public init(store: KeyValueStore) {
        self.store = store
    }

    public var opacity: Double {
        get { store.double(forKey: "opacity") ?? 1.0 }
        set { store.set(min(1.0, max(0.1, newValue)), forKey: "opacity") }
    }

    public var fontSize: Int {
        get { store.integer(forKey: "fontSize") ?? 14 }
        set { store.set(max(6, newValue), forKey: "fontSize") }
    }

    public var fontName: String {
        get { store.string(forKey: "fontName") ?? "SF Mono" }
        set { store.set(newValue, forKey: "fontName") }
    }

    public var enabledOnLaunch: Bool {
        get { store.bool(forKey: "enabledOnLaunch") ?? true }
        set { store.set(newValue, forKey: "enabledOnLaunch") }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsTests`
Expected: PASS (all three cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/TasbCore/Settings.swift Tests/TasbCoreTests/SettingsTests.swift
git commit -m "feat: add UserDefaults-backed Settings with injectable store"
```

---

## Task 3: RevealController state machine (TDD) — the crux

Pure logic for the Wallpaper ⇄ Focused transition. It does not touch AppKit directly; it drives a `WindowControlling` protocol and is fed desktop-visibility samples and explicit events.

**Files:**
- Create: `Sources/TasbCore/RevealController.swift`
- Test: `Tests/TasbCoreTests/RevealControllerTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/TasbCoreTests/RevealControllerTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RevealControllerTests`
Expected: FAIL — `RevealController`, `WindowControlling` not defined.

- [ ] **Step 3: Implement the state machine**

`Sources/TasbCore/RevealController.swift`:
```swift
import Foundation

/// Abstraction over the desktop window's focus behaviour so the state machine
/// stays free of AppKit and is unit-testable.
public protocol WindowControlling: AnyObject {
    /// Raise to a focusable level, activate, become key, accept mouse events.
    func enterFocused()
    /// Drop back to desktop level, ignore mouse events, resign key.
    func enterWallpaper()
}

public final class RevealController {
    public enum State: Equatable { case wallpaper, focused }

    public private(set) var state: State = .wallpaper

    private let window: WindowControlling
    private let debounceThreshold: Int
    private var visibleStreak = 0

    public init(window: WindowControlling, debounceThreshold: Int = 2) {
        self.window = window
        self.debounceThreshold = max(1, debounceThreshold)
    }

    /// Fed by the visibility poller. `true` means the desktop appears revealed.
    public func sampleDesktopVisible(_ visible: Bool) {
        if visible {
            visibleStreak += 1
            if visibleStreak >= debounceThreshold {
                transition(to: .focused)
            }
        } else {
            visibleStreak = 0
            transition(to: .wallpaper)
        }
    }

    /// Fallback hotkey: focus regardless of detection.
    public func forceFocus() {
        visibleStreak = debounceThreshold
        transition(to: .focused)
    }

    /// Esc while focused returns to wallpaper.
    public func escapePressed() {
        visibleStreak = 0
        transition(to: .wallpaper)
    }

    private func transition(to next: State) {
        guard next != state else { return }
        state = next
        switch next {
        case .focused: window.enterFocused()
        case .wallpaper: window.enterWallpaper()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter RevealControllerTests`
Expected: PASS (all eight cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/TasbCore/RevealController.swift Tests/TasbCoreTests/RevealControllerTests.swift
git commit -m "feat: add RevealController focus state machine with debounce"
```

---

## Task 4: ShellSession headless terminal I/O smoke test

Verify a PTY-backed shell actually produces output, using SwiftTerm's `HeadlessTerminal` (no window required).

**Files:**
- Create: `Sources/tasb/ShellSession.swift`
- Test: `Tests/tasbTests/ShellSessionTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/tasbTests/ShellSessionTests.swift`:
```swift
import XCTest
import SwiftTerm

final class ShellSessionTests: XCTestCase {
    func testEchoReachesTerminalBuffer() {
        let exited = expectation(description: "process exits")
        let headless = HeadlessTerminal(options: TerminalOptions(cols: 80, rows: 24)) { _ in
            exited.fulfill()
        }
        headless.process.startProcess(executable: "/bin/echo", args: ["tasb-ok"])
        wait(for: [exited], timeout: 10)

        let terminal = headless.terminal
        var found = false
        for row in 0..<terminal.rows {
            if let line = terminal.getLine(row: row)?.translateToString(trimRight: true),
               line.contains("tasb-ok") {
                found = true
                break
            }
        }
        XCTAssertTrue(found, "expected echoed text in terminal buffer")
    }
}
```

> Note: `HeadlessTerminal`, `TerminalOptions`, and `Terminal.getLine(row:)` are SwiftTerm APIs. If a pinned-version signature differs, run `swift build` and adjust the line-reading call to the available buffer accessor — do not weaken the assertion.

- [ ] **Step 2: Run test to verify it fails (or is red for the right reason)**

Run: `swift test --filter ShellSessionTests`
Expected: compiles against SwiftTerm; FAILs only if the buffer read is wrong — fix until it PASSes. This proves the PTY path before wiring UI.

- [ ] **Step 3: Add the production `ShellSession` wrapper**

`Sources/tasb/ShellSession.swift`:
```swift
import Foundation
import SwiftTerm

/// Thin façade over the user's login shell for the on-screen terminal.
/// The interactive terminal uses LocalProcessTerminalView (Task 6); this type
/// centralises the shell-resolution logic shared by both paths.
enum ShellSession {
    static func loginShell() -> String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    static func defaultEnvironment() -> [String] {
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("TASB=1")
        return env
    }
}
```

- [ ] **Step 4: Run test again**

Run: `swift test --filter ShellSessionTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/tasb/ShellSession.swift Tests/tasbTests/ShellSessionTests.swift
git commit -m "test: headless PTY echo smoke test + ShellSession helper"
```

---

## Task 5: DesktopWindow (AppKit, build + manual verify)

An `NSWindow` subclass that can sit at desktop level and can also become key when raised.

**Files:**
- Create: `Sources/tasb/DesktopWindow.swift`

- [ ] **Step 1: Implement the window**

`Sources/tasb/DesktopWindow.swift`:
```swift
import AppKit

/// Borderless full-screen window that lives at desktop level (behind icons)
/// but can be raised and made key on demand.
final class DesktopWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        setFrame(screen.frame, display: true)
    }

    // Borderless windows refuse key/main by default; allow it for focus mode.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func moveToDesktopLevel() {
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        ignoresMouseEvents = true
        orderBack(nil)
    }

    func raiseAndFocus() {
        level = .normal
        ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: compiles clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/tasb/DesktopWindow.swift
git commit -m "feat: DesktopWindow pinned at desktop level, focusable on raise"
```

---

## Task 6: TerminalSurface (AppKit)

Host the live terminal view and apply settings (font, colors, opacity).

**Files:**
- Create: `Sources/tasb/TerminalSurface.swift`

- [ ] **Step 1: Implement the surface**

`Sources/tasb/TerminalSurface.swift`:
```swift
import AppKit
import SwiftTerm
import TasbCore

/// Owns the interactive terminal view and applies appearance settings.
final class TerminalSurface: NSObject, LocalProcessTerminalViewDelegate {
    let view: LocalProcessTerminalView

    init(frame: NSRect) {
        view = LocalProcessTerminalView(frame: frame)
        super.init()
        view.processDelegate = self
        view.autoresizingMask = [.width, .height]
    }

    func start() {
        view.startProcess(
            executable: ShellSession.loginShell(),
            args: [],
            environment: ShellSession.defaultEnvironment()
        )
    }

    func apply(_ settings: Settings) {
        if let font = NSFont(name: settings.fontName, size: CGFloat(settings.fontSize)) {
            view.font = font
        }
        view.nativeForegroundColor = .white
        let bgAlpha = CGFloat(settings.opacity)
        view.nativeBackgroundColor = NSColor.black.withAlphaComponent(bgAlpha)
        view.wantsLayer = true
        view.layer?.isOpaque = settings.opacity >= 1.0
    }

    // MARK: LocalProcessTerminalViewDelegate
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // Re-spawn the shell so the wallpaper terminal is never dead.
        DispatchQueue.main.async { [weak self] in self?.start() }
    }
}
```

> Note: translucency (`opacity < 1.0`) requires the window to be non-opaque (set in Task 5) AND the terminal background alpha (set here). On a busy wallpaper, text contrast suffers — this is the documented trade-off, validated in Task 12.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: compiles clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/tasb/TerminalSurface.swift
git commit -m "feat: TerminalSurface hosting SwiftTerm view with settings"
```

---

## Task 7: DesktopVisibilityMonitor

Poll the on-screen window list and report whether the desktop looks revealed (no normal-layer app windows covering the main screen).

**Files:**
- Create: `Sources/tasb/DesktopVisibilityMonitor.swift`

- [ ] **Step 1: Implement the monitor**

`Sources/tasb/DesktopVisibilityMonitor.swift`:
```swift
import AppKit

/// Polls CGWindowList on a timer and reports desktop visibility.
/// "Visible" = no normal-layer (layer 0) windows from other apps occupy the
/// main screen, which is the state after a Show Desktop gesture.
final class DesktopVisibilityMonitor {
    private var timer: Timer?
    private let interval: TimeInterval
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    var onSample: ((Bool) -> Void)?

    init(interval: TimeInterval = 0.25) {
        self.interval = interval
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.onSample?(self.desktopVisible())
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func desktopVisible() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in infos {
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            let pid = info[kCGWindowOwnerPID as String] as? Int ?? 0
            if layer == 0 && pid != Int(ownPID) {
                return false // a real app window covers the desktop
            }
        }
        return true
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: compiles clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/tasb/DesktopVisibilityMonitor.swift
git commit -m "feat: DesktopVisibilityMonitor polling CGWindowList"
```

---

## Task 8: HotkeyManager (Carbon fallback)

Register a global hotkey (default ⌥⌘T) that forces focus, needing no special permissions.

**Files:**
- Create: `Sources/tasb/HotkeyManager.swift`

- [ ] **Step 1: Implement the manager**

`Sources/tasb/HotkeyManager.swift`:
```swift
import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey via the Carbon Events API.
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    var onTrigger: (() -> Void)?

    /// Default: Option+Command+T.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_T),
                  modifiers: UInt32 = UInt32(optionKey | cmdKey)) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onTrigger?() }
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x54415342 /* 'TASB' */), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: compiles clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/tasb/HotkeyManager.swift
git commit -m "feat: HotkeyManager global hotkey fallback via Carbon"
```

---

## Task 9: WindowController — concrete WindowControlling

Bridge `RevealController`'s protocol to the real `DesktopWindow`.

**Files:**
- Create: `Sources/tasb/WindowController.swift`

- [ ] **Step 1: Implement the bridge**

`Sources/tasb/WindowController.swift`:
```swift
import AppKit
import TasbCore

/// Adapts a DesktopWindow to the WindowControlling protocol used by RevealController.
final class WindowController: WindowControlling {
    private let window: DesktopWindow

    init(window: DesktopWindow) {
        self.window = window
    }

    func enterFocused() {
        window.raiseAndFocus()
    }

    func enterWallpaper() {
        window.moveToDesktopLevel()
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: compiles clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/tasb/WindowController.swift
git commit -m "feat: WindowController bridging RevealController to DesktopWindow"
```

---

## Task 10: TrayController

The `NSStatusItem` menu: enable/disable, opacity, font size, restart shell, quit.

**Files:**
- Create: `Sources/tasb/TrayController.swift`

- [ ] **Step 1: Implement the tray**

`Sources/tasb/TrayController.swift`:
```swift
import AppKit

/// Owns the menu-bar status item and routes menu actions via closures.
final class TrayController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var onToggleEnabled: ((Bool) -> Void)?
    var onSetOpacity: ((Double) -> Void)?
    var onRestartShell: (() -> Void)?
    var onQuit: (() -> Void)?

    private var enabled = true

    func install() {
        statusItem.button?.title = "▮"
        statusItem.button?.toolTip = "tasb"
        rebuildMenu()
    }

    func showError(_ message: String) {
        statusItem.button?.title = "⚠"
        statusItem.button?.toolTip = "tasb: \(message)"
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(title: enabled ? "Disable" : "Enable",
                                action: #selector(toggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(opacityItem(0.4))
        menu.addItem(opacityItem(0.7))
        menu.addItem(opacityItem(1.0))
        menu.addItem(.separator())

        let restart = NSMenuItem(title: "Restart shell",
                                 action: #selector(restart), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)

        let quit = NSMenuItem(title: "Quit tasb", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func opacityItem(_ value: Double) -> NSMenuItem {
        let item = NSMenuItem(title: "Opacity \(Int(value * 100))%",
                              action: #selector(setOpacity(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = value
        return item
    }

    @objc private func toggle() {
        enabled.toggle()
        onToggleEnabled?(enabled)
        rebuildMenu()
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double { onSetOpacity?(value) }
    }

    @objc private func restart() { onRestartShell?() }
    @objc private func quit() { onQuit?() }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: compiles clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/tasb/TrayController.swift
git commit -m "feat: TrayController status-item menu"
```

---

## Task 11: AppCoordinator + entry point

Wire everything: build the window on the main screen, host the terminal, start the monitor/hotkey, feed the RevealController, handle Esc and screen changes.

**Files:**
- Create: `Sources/tasb/AppCoordinator.swift`
- Modify: `Sources/tasb/main.swift`

- [ ] **Step 1: Implement the coordinator**

`Sources/tasb/AppCoordinator.swift`:
```swift
import AppKit
import TasbCore

final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaultsStore()
    private var settings: Settings!
    private var window: DesktopWindow!
    private var surface: TerminalSurface!
    private var reveal: RevealController!
    private var monitor: DesktopVisibilityMonitor!
    private var hotkey: HotkeyManager!
    private let tray = TrayController()
    private var escMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = Settings(store: defaults)
        guard let screen = NSScreen.main else { return }

        window = DesktopWindow(screen: screen)
        surface = TerminalSurface(frame: screen.frame)
        surface.apply(settings)
        window.contentView = surface.view
        window.moveToDesktopLevel()
        window.orderFront(nil)
        surface.start()

        reveal = RevealController(window: WindowController(window: window))

        monitor = DesktopVisibilityMonitor()
        monitor.onSample = { [weak self] visible in self?.reveal.sampleDesktopVisible(visible) }
        monitor.start()

        hotkey = HotkeyManager()
        hotkey.onTrigger = { [weak self] in self?.reveal.forceFocus() }
        hotkey.register()

        installTray()
        installEscMonitor()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func installTray() {
        tray.onToggleEnabled = { [weak self] enabled in
            guard let self else { return }
            if enabled { self.window.orderFront(nil); self.monitor.start() }
            else { self.window.orderOut(nil); self.monitor.stop() }
        }
        tray.onSetOpacity = { [weak self] value in
            guard let self else { return }
            self.settings.opacity = value
            self.surface.apply(self.settings)
            self.window.invalidateShadow()
        }
        tray.onRestartShell = { [weak self] in self?.surface.start() }
        tray.onQuit = { NSApp.terminate(nil) }
        tray.install()
    }

    private func installEscMonitor() {
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.reveal.escapePressed()
                return nil
            }
            return event
        }
    }

    @objc private func screensChanged() {
        guard let screen = NSScreen.main else { return }
        window.setFrame(screen.frame, display: true)
    }
}

/// UserDefaults-backed KeyValueStore implementation.
final class UserDefaultsStore: KeyValueStore {
    private let d = UserDefaults.standard
    func double(forKey key: String) -> Double? { d.object(forKey: key) == nil ? nil : d.double(forKey: key) }
    func integer(forKey key: String) -> Int? { d.object(forKey: key) == nil ? nil : d.integer(forKey: key) }
    func bool(forKey key: String) -> Bool? { d.object(forKey: key) == nil ? nil : d.bool(forKey: key) }
    func string(forKey key: String) -> String? { d.string(forKey: key) }
    func set(_ value: Any?, forKey key: String) { d.set(value, forKey: key) }
}
```

- [ ] **Step 2: Rewrite the entry point**

`Sources/tasb/main.swift`:
```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar agent, no Dock icon
let coordinator = AppCoordinator()
app.delegate = coordinator
app.run()
```

- [ ] **Step 3: Build and run**

Run: `swift build && swift run tasb`
Expected: a menu-bar item appears; a terminal renders behind the desktop icons; moving real windows away (Show Desktop) gives it keyboard focus within ~0.5 s; Esc returns it; ⌥⌘T forces focus. Quit from the tray menu.

- [ ] **Step 4: Run the full test suite**

Run: `swift test`
Expected: all `TasbCore` and `tasb` tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/tasb/AppCoordinator.swift Sources/tasb/main.swift
git commit -m "feat: wire AppCoordinator, monitor, hotkey, tray, esc handling"
```

---

## Task 12: App bundle packaging + manual verification

Produce a runnable `.app` so the agent runs as a proper background agent, and execute the manual checklist that covers what unit tests cannot.

**Files:**
- Create: `Resources/Info.plist`
- Create: `Scripts/make-app.sh`

- [ ] **Step 1: Write `Info.plist`**

`Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>tasb</string>
    <key>CFBundleIdentifier</key><string>io.goappo.tasb</string>
    <key>CFBundleExecutable</key><string>tasb</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 2: Write the bundling script**

`Scripts/make-app.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

swift build -c release
APP="tasb.app/Contents"
rm -rf tasb.app
mkdir -p "$APP/MacOS" "$APP/Resources"
cp .build/release/tasb "$APP/MacOS/tasb"
cp Resources/Info.plist "$APP/Contents/Info.plist" 2>/dev/null || cp Resources/Info.plist "$APP/Info.plist"
echo "Built tasb.app"
```

- [ ] **Step 3: Build the bundle**

Run: `chmod +x Scripts/make-app.sh && ./Scripts/make-app.sh && open tasb.app`
Expected: `tasb.app` launches as a menu-bar agent with no Dock icon.

- [ ] **Step 4: Manual verification checklist**

Confirm each (the part unit tests can't cover):
- [ ] Menu-bar item present; no Dock icon.
- [ ] Terminal renders behind desktop icons; icons remain clickable (click-through works).
- [ ] Show Desktop (swipe / hot corner / F11) → terminal gains keyboard focus within ~0.5 s; typing reaches the shell.
- [ ] Esc returns the terminal behind icons and restores normal focus.
- [ ] ⌥⌘T forces focus regardless of desktop state.
- [ ] Tray opacity 40% / 70% / 100% changes background translucency live.
- [ ] "Restart shell" respawns a working shell; killing the shell (`exit`) auto-respawns.
- [ ] Disconnect/reconnect a display or change resolution → window resizes to the main screen.

- [ ] **Step 5: Commit**

```bash
git add Resources/Info.plist Scripts/make-app.sh
git commit -m "build: app bundle packaging and manual verification checklist"
```

---

## Self-Review Notes

- **Spec coverage:** TrayController (Task 10) + AppCoordinator (Task 11) cover tray/menu; DesktopWindow (5) + WindowController (9) cover desktop-level window & focus; RevealController (3) covers the state machine incl. debounce/Esc/blur/hotkey; DesktopVisibilityMonitor (7) covers show-desktop detection; HotkeyManager (8) covers the fallback; TerminalSurface (6) + ShellSession (4) cover the persistent shell & opacity; Settings (2) covers config; screen-change handling and shell auto-respawn cover the spec's error-handling section; Task 12 covers the manual checklist and `LSUIElement` packaging. v1 scope honored: single main display, one session, no preferences window.
- **Deferred (matches spec Non-Goals):** multi-display terminals, multiple sessions/splits, extended themes, login-item UI, profiles.
- **Type consistency:** `WindowControlling.enterFocused()/enterWallpaper()` used identically in Task 3 (definition), Task 9 (impl), and the FakeWindow test. `KeyValueStore` methods match between Task 2 (protocol), the test's `InMemoryStore`, and Task 11's `UserDefaultsStore`. `Settings` property names (`opacity`, `fontSize`, `fontName`, `enabledOnLaunch`) used consistently in Tasks 2, 6, 11.
- **Known fragility (documented in spec):** show-desktop detection is heuristic; the always-on hotkey is the backstop. The SwiftTerm buffer-read in Task 4 may need a signature tweak against the pinned version — the task flags this without weakening the assertion.
