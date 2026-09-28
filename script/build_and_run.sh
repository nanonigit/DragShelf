#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
APP_NAME="DragShelf"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
LOGIN_BUNDLE="$APP_CONTENTS/Library/LoginItems/DragShelfLoginItem.app"

cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIGURATION" --product "$APP_NAME"
swift build -c "$BUILD_CONFIGURATION" --product DragShelfLoginItem
BUILD_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"
LOGIN_BINARY="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)/DragShelfLoginItem"

mkdir -p "$APP_CONTENTS/MacOS"
mkdir -p "$APP_CONTENTS/Resources"
mkdir -p "$LOGIN_BUNDLE/Contents/MacOS"
cp "$BUILD_BINARY" "$APP_CONTENTS/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/Resources/DragShelf.icns" "$APP_CONTENTS/Resources/DragShelf.icns"
cp "$LOGIN_BINARY" "$LOGIN_BUNDLE/Contents/MacOS/DragShelfLoginItem"
cp "$ROOT_DIR/Resources/LoginItem-Info.plist" "$LOGIN_BUNDLE/Contents/Info.plist"
chmod +x "$APP_CONTENTS/MacOS/$APP_NAME"
chmod +x "$LOGIN_BUNDLE/Contents/MacOS/DragShelfLoginItem"
codesign --force --sign - "$LOGIN_BUNDLE"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

if [[ "$MODE" != "--build-only" && "$MODE" != "build-only" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

case "$MODE" in
  --build-only|build-only)
    ;;
  run)
    /usr/bin/open -n "$APP_BUNDLE"
    ;;
  --verify|verify)
    /usr/bin/open -n "$APP_BUNDLE" --args --show-shelf --force-appkit-monitor
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --debug|debug)
    lldb -- "$APP_CONTENTS/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "dev.local.DragShelf"'
    ;;
  *)
    echo "usage: $0 [run|--build-only|--verify|--debug|--logs|--telemetry]" >&2
    exit 2
    ;;
esac
