# Changelog

All notable changes to bgterm are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-06-13

First public release.

### Added
- Interactive terminal rendered at the desktop-wallpaper layer, behind icons
  and windows.
- Reveal-in-place global hotkey (default `⌥⌘T`) that focuses the terminal
  without raising it above other windows; `Esc` returns it to wallpaper mode.
- Five selectable reveal-hotkey presets, persisted across launches.
- Login-shell sessions (profile, `PATH`, and aliases honored); opens in
  `~/repositories` when present.
- Keyboard-only tabs; background tabs keep running.
- Menu-bar agent (no Dock icon): enable/disable, opacity presets
  (40 / 70 / 100 %), reveal-hotkey picker, restart shell, quit.
- Configurable opacity, font name, and font size.
- Multi-display awareness, with re-layout on display changes.
- Homebrew Cask distribution via `webfucktory/homebrew-tap`.

[0.1.0]: https://github.com/webfucktory/bgterm/releases/tag/v0.1.0
