#!/bin/bash
set -euo pipefail

# Package only an already notarized app. Sparkle keeps the private key in Keychain.
if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: SPARKLE_TOOLS=/path/to/Sparkle/bin $0 /path/to/SwiftNativeBrightness.app /path/to/output [short-notes.html]" >&2
  exit 1
fi
: "${SPARKLE_TOOLS:?Set SPARKLE_TOOLS to the bin directory from the resolved Sparkle package}"
app_path="$1"
output_dir="$2"
account="com.anywheremusicplayer.SwiftNativeBrightness"
repo_url="https://github.com/Anywhere-Music-Player/SwiftNativeBrightness"
plist="$app_path/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build" =~ ^[0-9]+$ ]] || { echo 'Invalid version or build' >&2; exit 1; }
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist") == "$account" ]] || { echo 'Wrong app bundle' >&2; exit 1; }
[[ $(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$plist") == "$repo_url/releases/latest/download/appcast.xml" ]] || { echo 'Wrong update feed' >&2; exit 1; }
public_key=$("$SPARKLE_TOOLS/generate_keys" --account "$account" -p)
[[ $(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist") == "$public_key" ]] || { echo 'App and Keychain Sparkle keys differ' >&2; exit 1; }
codesign --verify --deep --strict "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
# Refuse a nonempty output folder so an old archive or feed cannot be published accidentally.
mkdir -p "$output_dir"
[[ -z $(ls -A "$output_dir") ]] || { echo 'Output directory must be empty' >&2; exit 1; }
archive="SwiftNativeBrightness-$version-build$build.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$output_dir/$archive"
if [[ $# -eq 3 ]]; then
  python3 - "$3" <<'PYNOTES'
from pathlib import Path
import sys
notes = Path(sys.argv[1]).read_bytes()
assert len(notes) < 1000 and b'<!doctype' not in notes.lower() and b'<body' not in notes.lower(), 'Use an HTML fragment under 1000 bytes for inline release notes'
PYNOTES
  cp "$3" "$output_dir/${archive%.zip}.html"
fi
"$SPARKLE_TOOLS/generate_appcast" --account "$account" --maximum-deltas 0 \
  --download-url-prefix "$repo_url/releases/download/$version/" \
  --link "$repo_url/releases/tag/$version" "$output_dir"
(
  cd "$output_dir"
  shasum -a 256 "$archive" > "SwiftNativeBrightness-$version-SHA256SUMS.txt"
)
printf 'Ready: %s\nUpload the ZIP, checksum and appcast.xml together before publishing the release.\n' "$output_dir"
