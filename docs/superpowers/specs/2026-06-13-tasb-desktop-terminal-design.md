# tasb — Desktop Terminal Wallpaper

A tray-only macOS app that renders an interactive terminal as the desktop
background. The terminal lives behind the desktop icons as wallpaper and
becomes focusable — accepting keyboard input — when the desktop is revealed.

## Goals

- Run as a menu-bar-only utility (no Dock icon).
- Render a real, interactive terminal (a live shell over a PTY) at desktop
  window level, behind the user's icons.
- Let the user type into it when the desktop is revealed ("Show Desktop"),
  with a reliable hotkey fallback.
- Keep the shell session alive for the whole app lifetime; reveal/hide only
  changes focus, never restarts the shell.

## Non-Goals (v1)

- Multi-display terminals (main display only in v1).
- Multiple or tiled sessions / splits.
- Theme system beyond a couple of presets.
- A full preferences window (tray menu is sufficient for v1).
- Auto-install as a login item via UI (manual for v1).

## Stack

- **Language/UI:** Swift + AppKit.
- **Terminal:** [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
  (`LocalProcessTerminalView`) for VT100/xterm emulation and PTY-backed shell.
- **Tray:** `NSStatusItem`.
- **Config:** `UserDefaults`.
- **Packaging:** `LSUIElement = true` in Info.plist (no Dock icon).

Rationale: every hard part of this project — a desktop-level window behind
icons, focus toggling against macOS's window-layer rules, a native shell PTY —
is a native macOS problem, so a native stack pays off immediately.

## Architecture

Five components:

1. **TrayController** — owns the `NSStatusItem` and its menu: enable/disable,
   opacity slider, font size, trigger mode, restart shell, quit. The only
   persistent UI chrome.
2. **DesktopWindow** — an `NSWindow` subclass covering the main screen.
   - Borderless, `level = kCGDesktopWindowLevel` (behind icons, above the
     wallpaper image).
   - `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`.
   - `ignoresMouseEvents = true` while idle, so clicks fall through to the
     desktop and icons.
   - Overrides `canBecomeKey` / `canBecomeMain` to return `true` so the window
     can take focus when raised.
3. **TerminalSurface** — SwiftTerm `LocalProcessTerminalView` set as the
   window content view. Spawns the user's `$SHELL` over a PTY. Background alpha
   driven by the opacity setting; font and colors driven by Settings.
4. **RevealController** — the focus state machine (see below).
5. **Settings** — `UserDefaults`-backed values: opacity, font name + size,
   color scheme, trigger mode, fallback hotkey, launch-enabled.

## Reveal / Focus State Machine

Two states:

- **Wallpaper** — desktop window level, `ignoresMouseEvents = true`, not key,
  no keyboard input. Terminal output still renders and is visible.
- **Focused** — window raised to a focusable level, app activated, key window,
  `ignoresMouseEvents = false`, accepts keystrokes.

Transitions:

- **Wallpaper → Focused**
  - *Show-desktop detection:* a ~250 ms timer polls
    `CGWindowListCopyWindowInfo(.optionOnScreenOnly)`. When no normal-layer
    (layer 0) app windows cover the screen, the desktop is considered revealed.
    Debounce: the condition must hold across 2 consecutive polls before
    transitioning, to reject flaps.
  - *Fallback hotkey:* a configurable global hotkey via Carbon
    `RegisterEventHotKey` (no special permissions) forces Focused regardless of
    detection. Always registered — it is the reliability backstop.
  - On entering Focused: bump window level above desktop, `NSApp.activate`,
    `makeKeyAndOrderFront`, `ignoresMouseEvents = false`.
- **Focused → Wallpaper**
  - Triggered by `Esc`, window blur (resign key), or normal app windows
    reappearing over the screen.
  - On entering Wallpaper: set level back to `kCGDesktopWindowLevel`,
    `ignoresMouseEvents = true`, resign key, order back.

Known risk: macOS exposes no public "Show Desktop started" event, so the
detection is a heuristic that may need tuning across macOS versions. The hotkey
fallback is therefore non-optional.

## Data Flow

- **Input (Focused only):** keystroke → `LocalProcessTerminalView` → PTY master
  → shell process.
- **Output (always):** shell stdout/stderr → PTY → SwiftTerm renders to the
  desktop-level window. Output is visible as wallpaper even in Wallpaper state;
  only typing requires reveal.
- **Settings changes:** TrayController → Settings → live-applied to
  TerminalSurface (opacity/font/colors) and DesktopWindow.

## Error Handling

- **Shell spawn failure** → render an error line in the terminal surface, set
  the tray icon to an error state, offer "Restart shell" in the menu.
- **Show-desktop detection flaps** → 2-poll debounce; hotkey fallback always
  available if detection is unreliable on a given machine.
- **Display reconfiguration** (`didChangeScreenParametersNotification`) →
  reposition/resize the window to the chosen screen; if it is gone, fall back to
  the main screen.
- **Hotkey registration conflict** → surface a tray warning and let the user
  pick another combo.

## Testing

- **RevealController** — pure state-machine logic with an injected
  `desktopVisible: () -> Bool` provider and a `WindowControlling` protocol.
  Table tests over: reveal, debounce-rejection, Esc, blur, hotkey-force,
  return-on-windows-reappear. Written first (TDD) — this is the load-bearing
  logic.
- **Settings** — round-trip `UserDefaults` encode/decode.
- **Terminal I/O smoke test** — spawn a process that echoes a known string,
  assert it reaches the terminal buffer.
- **Manual checklist** — AppKit window-level/focus behavior is not meaningfully
  unit-testable; a short documented manual pass covers behind-icons rendering,
  click-through, reveal focus, Esc release, and multi-display fallback.

## v1 Scope Summary

**In:** main display only; one persistent shell session; opaque default with
opacity slider; show-desktop detection + fallback hotkey; tray-menu config;
launch-enabled toggle.

**Out (deferred):** multi-display terminals, multiple/tiled sessions, splits,
extended themes, login-item auto-install UI, profiles.
