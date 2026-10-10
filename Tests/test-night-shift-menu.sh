#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/swiftnativebrightness-menu-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$test_root/ModuleCache" \
  "$project_root/SwiftNativeBrightness/Support/NightShiftTemperatureController.swift" \
  "$project_root/SwiftNativeBrightness/Support/SystemControlsView.swift" \
  "$project_root/SwiftNativeBrightness/Support/ScreenEffectsView.swift" \
  "$project_root/Tests/NightShiftMenuCheck.swift" \
  -o "$test_root/night-shift-menu-check"
"$test_root/night-shift-menu-check"
