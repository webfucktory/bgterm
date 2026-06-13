# bgterm — Installation & Publishing

bgterm is a native macOS `.app` (Swift Package Manager build), **not** an npm
package — so `npx` does not apply. Distribution is via **Homebrew Cask** backed
by a **GitHub Release** containing the prebuilt, zipped app.

## Why Cask (not a Formula or npx)

- **npx** — Node-only; irrelevant for a Swift `.app`.
- **Homebrew Formula** — would build from source on the user's machine
  (`swift build -c release` + bundle assembly). Works, but slower and pulls the
  Swift toolchain. Use only if you want source builds.
- **Homebrew Cask (recommended)** — ships the prebuilt `.app`; `brew install`
  just downloads + unzips into `/Applications`. Best end-user experience.

## Prerequisites

- A public GitHub repo (e.g. `webfucktory/bgterm`). Currently the project is a
  local git repo with no remote — add one: `git remote add origin <url> && git push -u origin master`.
- A versioning scheme via git tags: `v0.1.0`, `v0.2.0`, …
- **Gatekeeper note:** an *unsigned* (or Apple *Development*-signed) app will be
  quarantined on download — users must right-click → Open, or run
  `xattr -dr com.apple.quarantine /Applications/bgterm.app`. A Cask can declare
  this. For a friction-free install you need **Developer ID signing +
  notarization** (paid Apple Developer Program). Ship unsigned first; add
  notarization later.

## Release artifact

The release asset is `bgterm.app` zipped:

```bash
./Scripts/make-app.sh                 # builds bgterm.app
ditto -c -k --keepParent bgterm.app bgterm-<version>.zip
shasum -a 256 bgterm-<version>.zip    # sha256 for the Cask
```

Use `ditto` (not `zip`) so the bundle's structure/symlinks survive.

## GitHub Actions release workflow

`.github/workflows/release.yml` — builds and attaches the zip on tag push:

```yaml
name: release
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build app bundle
        run: ./Scripts/make-app.sh
      - name: Zip
        run: ditto -c -k --keepParent bgterm.app "bgterm-${GITHUB_REF_NAME}.zip"
      - name: Release
        uses: softprops/action-gh-release@v2
        with:
          files: bgterm-*.zip
```

(To sign + notarize in CI, add an import-codesign-certs step with secrets for the
Developer ID cert/password, `codesign --options runtime`, then `xcrun notarytool
submit … --wait` and `xcrun stapler staple bgterm.app` before zipping.)

Release flow: `git tag v0.1.0 && git push origin v0.1.0` → workflow publishes the zip.

> Note: pushing `.github/workflows/*` requires a token with the `workflow` scope
> (`gh auth refresh -h github.com -s workflow`). Until that scope is granted, the
> workflow file is kept locally and releases are cut by hand: build with
> `./Scripts/make-app.sh`, zip with `ditto`, then `gh release create vX.Y.Z bgterm-vX.Y.Z.zip`.
> If you re-upload an asset under the same name, delete the old asset object first
> (`gh api -X DELETE repos/<owner>/<repo>/releases/assets/<id>`) rather than
> `--clobber`, to avoid the download CDN serving a stale cached copy.

## Homebrew Cask

Host a tap repo `webfucktory/homebrew-tap` with `Casks/bgterm.rb`:

```ruby
cask "bgterm" do
  version "0.1.0"
  sha256 "<sha256 of bgterm-v0.1.0.zip>"

  url "https://github.com/webfucktory/bgterm/releases/download/v#{version}/bgterm-v#{version}.zip"
  name "bgterm"
  desc "Interactive terminal as the desktop wallpaper"
  homepage "https://github.com/webfucktory/bgterm"

  app "bgterm.app"

  # Unsigned build: clear the quarantine flag so it launches without right-click.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/bgterm.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.webfucktory.bgterm.plist",
  ]
end
```

Then end users:

```bash
brew tap webfucktory/tap
brew trust webfucktory/tap      # recent Homebrew requires trusting third-party taps
brew install --cask bgterm
```

Bump per release: update `version` + `sha256`, commit to the tap repo. (Automate
later with a workflow that opens a PR to the tap on each GitHub Release.)

## Checklist per release

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist` and
   `BgtermCore.version`.
2. `git tag vX.Y.Z && git push origin vX.Y.Z` → CI publishes the zip.
3. Compute the zip's `sha256`, update `Casks/bgterm.rb` (`version`, `sha256`),
   push the tap.
4. Verify: `brew update && brew upgrade --cask bgterm`.

## Future: friction-free install

- Join the Apple Developer Program → **Developer ID Application** cert.
- Sign (`codesign --options runtime --sign "Developer ID Application: …"`) and
  **notarize** (`notarytool` + `stapler`) in CI.
- Then drop the `postflight` quarantine workaround — the app opens normally, and
  the Accessibility-based features (e.g. an F11 event tap) could persist their
  permission grant, making them viable again (see git history `4b7bac9`).
