#!/bin/bash
set -euo pipefail

[[ $# -eq 2 ]] || { echo "Usage: $0 /path/to/SwiftNativeBrightness.app /path/to/empty-output" >&2; exit 1; }
app_path="$1"
output_dir="$2"
plist="$app_path/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build" =~ ^[0-9]+$ ]] || { echo 'Invalid version or build' >&2; exit 1; }
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist") == 'com.anywheremusicplayer.SwiftNativeBrightness' ]] || { echo 'Wrong app bundle' >&2; exit 1; }
codesign --verify --deep --strict "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
mkdir -p "$output_dir"
[[ -z $(ls -A "$output_dir") ]] || { echo 'Output directory must be empty' >&2; exit 1; }
archive="SwiftNativeBrightness-$version-build$build.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$output_dir/$archive"
(
  cd "$output_dir"
  shasum -a 256 "$archive" > "SwiftNativeBrightness-$version-SHA256SUMS.txt"
)
printf 'Ready: %s\nUpload the ZIP and checksum together before publishing the release.\n' "$output_dir"
