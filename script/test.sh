#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -module-cache-path "$TEST_DIR/ModuleCache" \
  "$ROOT_DIR/Swift Quit/AppSettings.swift" "$ROOT_DIR/Swift Quit/LoginItemService.swift" \
  "$ROOT_DIR/tests/main.swift" -o "$TEST_DIR/settings-tests"
"$TEST_DIR/settings-tests"
