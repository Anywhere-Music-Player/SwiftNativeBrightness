#!/bin/bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 appcast.xml update.zip" >&2; exit 1; }
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root=$(mktemp -d /tmp/swiftnativebrightness-feed-check.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
python3 - "$1" "$2" "$project_root" "$test_root" <<'PY'
import pathlib, plistlib, sys, urllib.parse, xml.etree.ElementTree as ET, zipfile
feed, archive, root, scratch = map(pathlib.Path, sys.argv[1:])
key = plistlib.loads((root/'SwiftNativeBrightness/Info.plist').read_bytes())['SUPublicEDKey']
with zipfile.ZipFile(archive) as z:
    info = plistlib.loads(z.read('SwiftNativeBrightness.app/Contents/Info.plist'))
ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
items = ET.parse(feed).findall('./channel/item')
assert len(items) == 1, 'Expected one current stable release'
item = items[0]
enclosure = item.find('enclosure')
assert enclosure is not None
build = item.findtext(ns+'version') or enclosure.get(ns+'version')
version = item.findtext(ns+'shortVersionString') or enclosure.get(ns+'shortVersionString')
assert build == info['CFBundleVersion'], (build, info['CFBundleVersion'])
assert version == info['CFBundleShortVersionString']
assert item.findtext(ns+'minimumSystemVersion') == info['LSMinimumSystemVersion'] == '14.0'
expected = 'https://github.com/Anywhere-Music-Player/SwiftNativeBrightness/releases/download/'+version+'/'+urllib.parse.quote(archive.name)
assert enclosure.get('url') == expected, enclosure.get('url')
assert int(enclosure.get('length')) == archive.stat().st_size
assert info['CFBundleIdentifier'] == 'com.anywheremusicplayer.SwiftNativeBrightness'
assert info['SUPublicEDKey'] == key, 'Archive update key differs from source'
(scratch/'signature').write_text(enclosure.get(ns+'edSignature'))
(scratch/'public-key').write_text(key)
print('PASS: feed build, version, macOS minimum, URL, length and app identity match the ZIP.')
PY
xcrun swift -module-cache-path "$test_root/ModuleCache" "$project_root/Tests/VerifyUpdateSignature.swift" "$2" "$(cat "$test_root/signature")" "$(cat "$test_root/public-key")"
