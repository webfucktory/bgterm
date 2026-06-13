#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
APP_ROOT="bgterm.app"
CONTENTS="$APP_ROOT/Contents"

rm -rf "$APP_ROOT"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp .build/release/bgterm "$CONTENTS/MacOS/bgterm"
cp Resources/Info.plist "$CONTENTS/Info.plist"

# Code-sign with a stable identity so the Accessibility (TCC) grant persists
# across rebuilds — macOS keys the grant off the signing identity, not the
# binary hash. Override with BGTERM_SIGN_IDENTITY; falls back to ad-hoc ("-").
IDENTITY="${BGTERM_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk 'match($0,/[0-9A-F]{40}/){print substr($0,RSTART,40); exit}')}"
IDENTITY="${IDENTITY:--}"
codesign --force --deep --sign "$IDENTITY" "$APP_ROOT"
echo "Built $APP_ROOT (signed: $IDENTITY)"
