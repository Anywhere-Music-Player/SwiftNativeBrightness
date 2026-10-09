#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/swiftnativebrightness-window-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
xcrun swiftc -swift-version 5 -module-cache-path "$test_root/ModuleCache" \
  "$project_root/SwiftNativeBrightness/Enums/PrefKey.swift" \
  "$project_root/SwiftNativeBrightness/Support/DiagnosticLog.swift" \
  "$project_root/SwiftNativeBrightness/View Controllers/Preferences/DiagnosticsSettingsView.swift" \
  "$project_root/SwiftNativeBrightness/View Controllers/Preferences/SettingsPreferences.swift" \
  "$project_root/SwiftNativeBrightness/View Controllers/Preferences/SettingsView.swift" \
  "$project_root/SwiftNativeBrightness/View Controllers/Preferences/SettingsSplitViewController.swift" \
  "$project_root/Tests/SettingsWindowLayoutCheck.swift" \
  -o "$test_root/settings-window-check"
"$test_root/settings-window-check"
