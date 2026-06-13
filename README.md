<div align="center">

# bgterm

**A terminal that *is* your desktop — not another window.**

bgterm runs a real, interactive terminal at the wallpaper layer of macOS.
It sits behind your icons and windows, always present. Tap a hotkey to type
into it in place; press `Esc` and it falls back to being your background.

[![Release](https://img.shields.io/github/v/release/webfucktory/bgterm?sort=semver&color=success)](https://github.com/webfucktory/bgterm/releases/latest)
[![License: MIT](https://img.shields.io/github/license/webfucktory/bgterm?color=blue)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Status](https://img.shields.io/badge/status-early%20%C2%B7%20v0.1-orange)

</div>

---

> [!NOTE]
> bgterm is brand new (v0.1.0). The core idea works; the surface area is small
> on purpose. Expect rough edges, and see [Where it fits](#where-it-fits) for an
> honest picture of what it is — and isn't — yet.

## The idea

Every terminal emulator answers the same question: *what window should the
terminal live in?* bgterm answers a different one: **what if it didn't live in a
window at all?**

Your shell becomes the backdrop you already look at all day. No window to find,
no `Cmd`-`Tab`, no "where did that terminal go." It's just *there* — a live
prompt under your icons. When you want it, one keystroke pulls focus to it
**without raising it over anything**; when you're done, it recedes back into the
wallpaper.

<!-- Replace the block below with a real screen recording: docs/assets/demo.gif -->

```
┌──────────────────────────────────────────── your desktop ────┐
│  🗂  📄  🖼                                                     │
│                                                               │
│   ~/repositories %  tail -f deploy.log                        │
│   [12:01:04]  build  ✓  packaged bgterm.app                   │
│   [12:01:07]  release ✓  uploaded bgterm-v0.1.0.zip           │
│   ~/repositories %  ▮                                          │
│                                                               │
│                              ⌥⌘T to focus · Esc to dismiss    │
└───────────────────────────────────────────────────────────────┘
```

> 📹 A real demo GIF belongs here — drop a screen recording at
> `docs/assets/demo.gif` and swap out the ASCII preview above.

## Features

- **Terminal at the wallpaper layer** — a real shell rendered as your desktop,
  behind icons and windows.
- **Reveal in place** — a global hotkey (default `⌥⌘T`) gives the terminal
  keyboard focus *without* lifting it above your other windows. `Esc` returns it
  to passive wallpaper mode.
- **Your real shell** — launches your login shell so your profile, `PATH`, and
  aliases all work. Opens in `~/repositories` when that folder exists.
- **Keyboard-only tabs** — multiple sessions, no tab bar chrome; background tabs
  keep running.
- **Menu-bar agent** — no Dock icon. Toggle on/off, pick opacity (40 / 70 /
  100 %), choose the reveal hotkey, restart the shell, all from the tray.
- **Multi-display aware** — spans the screen below the menu bar and notch, and
  re-lays itself when displays change.
- **Tiny** — a ~2.3 MB agent, built with [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

## Install

```bash
brew tap webfucktory/tap
brew trust webfucktory/tap     # recent Homebrew requires trusting third-party taps
brew install --cask bgterm
```

That's it — bgterm starts living in your menu bar (look for the `▮` icon).

<details>
<summary>Manual install (no Homebrew)</summary>

Download `bgterm-vX.Y.Z.zip` from the
[latest release](https://github.com/webfucktory/bgterm/releases/latest), unzip
it into `/Applications`, then clear the quarantine flag (the build is unsigned):

```bash
xattr -dr com.apple.quarantine /Applications/bgterm.app
open /Applications/bgterm.app
```

</details>

> bgterm is currently an **unsigned** build. The Homebrew cask clears the
> quarantine flag for you, so it launches without the right-click → Open dance.
> Developer ID signing + notarization are on the roadmap.

## Usage

| Action | How |
| --- | --- |
| Focus the terminal | `⌥⌘T` (default — pick another preset in the tray) |
| Send it back to the wallpaper | `Esc` |
| New tab / close tab / switch | keyboard (background tabs keep running) |
| Change opacity | tray → Opacity 40 / 70 / 100 % |
| Change reveal hotkey | tray → Reveal hotkey |
| Restart the shell | tray → Restart shell |
| Turn bgterm off / on | tray → Disable / Enable |
| Quit | tray → Quit bgterm (`⌘Q`) |

**Reveal-hotkey presets:** `⌥⌘T` · `⌃⌘T` · `⌥⌘` `` ` `` · `⌥⌘Return` · `⌃⌘Space`.

## Configuration

Settings persist in macOS user defaults (`com.webfucktory.bgterm`):

| Setting | Default | Notes |
| --- | --- | --- |
| Opacity | `100%` | also pickable from the tray |
| Font | `SF Mono`, `14 pt` | |
| Enabled on launch | `on` | |
| Reveal hotkey | `⌥⌘T` | one of the five presets |

## Where it fits

bgterm is a *young* terminal with one strong idea, not a drop-in replacement for
a mature emulator. Use it for the things you keep open all day and glance at —
a `tail -f`, a REPL, a build watcher, a long-running agent session — and keep
iTerm / Ghostty / Terminal for heavy interactive work.

| | bgterm | a conventional terminal |
| --- | --- | --- |
| Lives in | your wallpaper | a window |
| Always visible | yes, behind everything | only when focused/raised |
| Window management | none — there's no window | tabs, splits, tiling |
| Reveal | one hotkey, focus in place | `Cmd`-`Tab`, click, mission control |
| Splits / search / profiles | not yet | yes |
| Best for | ambient, glanceable sessions | full interactive workflows |

## Build from source

Requires Xcode 15+ (Swift 5.9) on macOS 13+.

```bash
git clone https://github.com/webfucktory/bgterm
cd bgterm
swift test          # run the suite
./Scripts/make-app.sh   # produces ./bgterm.app
open bgterm.app
```

## Roadmap

- Developer ID signing + notarization (drops the unsigned-build friction).
- A visible tab affordance and richer in-place controls.
- Per-display and per-Space configuration.
- Theming beyond opacity (colors, background blur).

## Contributing

Issues and pull requests are welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md). Publishing and release mechanics are
documented in [docs/PUBLISHING.md](docs/PUBLISHING.md).

## License

[MIT](LICENSE) © webfucktory
