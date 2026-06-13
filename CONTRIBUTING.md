# Contributing to bgterm

Thanks for your interest. bgterm is small and early, which makes it a good time
to shape it.

## Development setup

Requires Xcode 15+ (Swift 5.9) on macOS 13+.

```bash
git clone https://github.com/webfucktory/bgterm
cd bgterm
swift build         # debug build
swift test          # run the suite
./Scripts/make-app.sh   # assemble ./bgterm.app
```

## Project layout

| Path | What lives there |
| --- | --- |
| `Sources/bgterm/` | the AppKit agent — window, tabs, tray, hotkey, shell |
| `Sources/BgtermCore/` | AppKit-free, unit-testable logic (settings, reveal state machine) |
| `Tests/` | unit tests for both targets |
| `Scripts/make-app.sh` | builds the `.app` bundle |
| `docs/PUBLISHING.md` | release + Homebrew tap mechanics |

`BgtermCore` exists so the reveal state machine and settings can be tested
without a running app — keep new logic that doesn't *need* AppKit there.

## Guidelines

- Run `swift test` before opening a pull request; add tests for new logic.
- Keep functions small and the data flow explicit.
- Match the surrounding style — no large reformatting in feature PRs.
- Open an issue first for anything that changes behavior or scope, so we can
  agree on the approach before you build it.

## Releasing

Tagging `vX.Y.Z` triggers the GitHub Actions release workflow, which builds and
attaches the zipped app. Full details, including the Homebrew cask bump, are in
[docs/PUBLISHING.md](docs/PUBLISHING.md).
