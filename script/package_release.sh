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

BUILD_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build-only
ARCHIVE_DIR="$ROOT_DIR/releases"
mkdir -p "$ARCHIVE_DIR"
ARCHITECTURE="$(uname -m)"
ARCHIVE="$ARCHIVE_DIR/DragShelf-$VERSION-macos-$ARCHITECTURE.zip"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/dist/DragShelf.app" "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
codesign --verify --deep --strict "$ROOT_DIR/dist/DragShelf.app"
spctl -a -vv "$ROOT_DIR/dist/DragShelf.app" || true
echo "$ARCHIVE"
