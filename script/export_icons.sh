#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVELOPER_PATH="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ICON_TOOL="${DEVELOPER_PATH%/Developer}/Applications/Icon Composer.app/Contents/Executables/ictool"
OUTPUT_DIR="$ROOT_DIR/design/icon-previews"
mkdir -p "$OUTPUT_DIR"
for rendition in Default Dark Mono; do
  filename="$(echo "$rendition" | tr '[:upper:]' '[:lower:]')"
  "$ICON_TOOL" "$ROOT_DIR/swiftquit.icon" --export-image \
    --output-file "$OUTPUT_DIR/$filename.png" --platform macOS --rendition "$rendition" \
    --width 512 --height 512 --scale 1 --design-generation 27
done
