#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="ClipPanel"
BUNDLE_ID="com.clippanel.app"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/XcodeDerivedData"
DIST_DIR="$ROOT_DIR/dist"

CONFIGURATION="Debug"
case "$MODE" in
  --package|package)
    # Releases ship the Release configuration; every local mode keeps Debug.
    CONFIGURATION="Release"
    ;;
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    ;;
  *)
    echo "usage: $0 [run|--package|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/ClipPanel.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --package|package)
    # CI packaging (used by .github/workflows/release.yml, runnable locally):
    # stage dist/ClipPanel.app, ad-hoc sign, verify, never launch, keep the
    # bundle.
    STAGED_BUNDLE="$DIST_DIR/$APP_NAME.app"
    STAGED_PLIST="$STAGED_BUNDLE/Contents/Info.plist"
    rm -rf "$STAGED_BUNDLE"
    mkdir -p "$DIST_DIR"
    cp -R "$APP_BUNDLE" "$STAGED_BUNDLE"
    # Ad-hoc sign so the shipped artifact has a stable identity no matter
    # whose keychain built it. ClipPanel is not yet Developer-ID signed or
    # notarized; the release notes tell users to clear the quarantine flag.
    codesign --force --sign - --timestamp=none "$STAGED_BUNDLE"
    plutil -lint "$STAGED_PLIST" >/dev/null
    test -x "$STAGED_BUNDLE/Contents/MacOS/$APP_NAME"
    test "$(plutil -extract CFBundleIdentifier raw "$STAGED_PLIST")" = "$BUNDLE_ID"
    test "$(plutil -extract LSUIElement raw "$STAGED_PLIST")" = "true"
    test "$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw "$STAGED_PLIST")" = "clippanel"
    test -n "$(plutil -extract CFBundleShortVersionString raw "$STAGED_PLIST")"
    test -f "$STAGED_BUNDLE/Contents/Resources/Assets.car"
    echo "Packaged $STAGED_BUNDLE (version $(plutil -extract CFBundleShortVersionString raw "$STAGED_PLIST"))"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    for _ in {1..30}; do
      if pgrep -x "$APP_NAME" >/dev/null; then
        exit 0
      fi
      sleep 0.1
    done
    echo "$APP_NAME did not remain running after launch." >&2
    exit 1
    ;;
esac
