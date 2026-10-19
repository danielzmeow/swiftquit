#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_DIR="${SWIFTQUIT_BUILD_DIR:-$ROOT_DIR/.build-package}"
PACKAGES_DIR="${SWIFTQUIT_PACKAGES_DIR:-$BUILD_DIR/SourcePackages}"
ARCH="${SWIFTQUIT_ARCH:-$(uname -m)}"
case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 2 ;; esac
OUTPUT_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$OUTPUT_DIR/Swift Quit.app"
ARCHIVE="$OUTPUT_DIR/Swift-Quit-local-$ARCH.zip"
mkdir -p "$OUTPUT_DIR"
# Copy the complete signed bundle, including resources and any nested code.
# ditto merges directories, so refuse to overwrite an existing package staging app.
if [[ -e "$APP_BUNDLE" ]]; then
  echo "Move the existing $APP_BUNDLE aside before packaging again." >&2
  exit 1
fi
xcodebuild -project "$ROOT_DIR/Swift Quit.xcodeproj" -scheme 'Swift Quit' \
  -configuration Release -destination "platform=macOS,arch=$ARCH" \
  -derivedDataPath "$BUILD_DIR" -clonedSourcePackagesDirPath "$PACKAGES_DIR" \
  ARCHS="$ARCH" ONLY_ACTIVE_ARCH=YES CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- build
/usr/bin/ditto "$BUILD_DIR/Build/Products/Release/Swift Quit.app" "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"
VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "$VERIFY_DIR"' EXIT
/usr/bin/ditto -x -k "$ARCHIVE" "$VERIFY_DIR"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/Swift Quit.app"
(cd "$OUTPUT_DIR" && /usr/bin/shasum -a 256 "${ARCHIVE##*/}") > "$ARCHIVE.sha256"
echo "Packaged: $ARCHIVE"
