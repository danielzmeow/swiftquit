#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify|--build|--background) ;;
  *) echo "usage: $0 [--build|--background|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_DIR="${SWIFTQUIT_BUILD_DIR:-$ROOT_DIR/.build}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd -P)"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/Swift Quit.app"
# Only stop the development build; leave an installed copy alone.
if [[ "$MODE" != --build ]]; then
  pkill -f "^$APP_BUNDLE/Contents/MacOS/Swift Quit" >/dev/null 2>&1 || true
fi
xcodebuild -project "$ROOT_DIR/Swift Quit.xcodeproj" -scheme 'Swift Quit' \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
  -clonedSourcePackagesDirPath "${SWIFTQUIT_PACKAGES_DIR:-$BUILD_DIR/SourcePackages}" \
  CODE_SIGN_IDENTITY=- build
case "$MODE" in
  --build) echo "Built: $APP_BUNDLE" ;;
  --background) /usr/bin/open -g -n "$APP_BUNDLE" --args --background ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/Swift Quit" ;;
  --logs|--telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'process == "Swift Quit"'
    ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 2
    pgrep -f "^$APP_BUNDLE/Contents/MacOS/Swift Quit" >/dev/null
    ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
