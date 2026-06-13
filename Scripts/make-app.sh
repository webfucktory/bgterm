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

echo "Built $APP_ROOT"
