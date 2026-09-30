#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 VERSION" >&2
  exit 2
fi

PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
if [[ "$VERSION" != "$PLIST_VERSION" ]]; then
  echo "Version mismatch: requested $VERSION, Info.plist has $PLIST_VERSION" >&2
  exit 2
fi
LOGIN_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT_DIR/Resources/LoginItem-Info.plist")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$ROOT_DIR/Resources/Info.plist")"
LOGIN_BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$ROOT_DIR/Resources/LoginItem-Info.plist")"
if [[ "$VERSION" != "$LOGIN_VERSION" || "$APP_BUILD" != "$LOGIN_BUILD" ]]; then
  echo "Main app and login item versions must match" >&2
  exit 2
fi

BUILD_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build-only
ARCHIVE_DIR="$ROOT_DIR/releases"
mkdir -p "$ARCHIVE_DIR"
ARCHITECTURE="$(uname -m)"
ARCHIVE="$ARCHIVE_DIR/DragShelf-$VERSION-macos-$ARCHITECTURE.zip"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/dist/DragShelf.app" "$ARCHIVE"
(cd "$ARCHIVE_DIR" && shasum -a 256 "$(basename "$ARCHIVE")") > "$ARCHIVE.sha256"
codesign --verify --deep --strict "$ROOT_DIR/dist/DragShelf.app"
spctl -a -vv "$ROOT_DIR/dist/DragShelf.app" || true
echo "$ARCHIVE"
