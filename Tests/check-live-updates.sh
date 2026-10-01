#!/bin/bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 /path/to/Sparkle.framework expected-build" >&2; exit 1; }
project_root="$(cd "$(dirname "$0")/.." && pwd)"
framework_dir=$(dirname "$1")
expected="$2"
test_root=$(mktemp -d /tmp/swiftnativebrightness-live-feed.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
xcrun swiftc -module-cache-path "$test_root/ModuleCache" -F "$framework_dir" -framework Sparkle -Xlinker -rpath -Xlinker "$framework_dir" "$project_root/Tests/SparkleFeedProbe.swift" -o "$test_root/probe"
python3 - "$test_root" "$project_root" "$expected" <<'PY'
import pathlib, plistlib, sys, uuid
scratch, root = map(pathlib.Path, sys.argv[1:3])
source = plistlib.loads((root/'SwiftNativeBrightness/Info.plist').read_bytes())
for name, build in [('older', '1'), ('current', sys.argv[3])]:
    contents = scratch/(name+'.app')/'Contents'
    contents.mkdir(parents=True)
    info = dict(CFBundleIdentifier='com.anywheremusicplayer.FeedProbe.'+str(uuid.uuid4()), CFBundleName='Update Feed Check', CFBundlePackageType='APPL', CFBundleVersion=build, CFBundleShortVersionString='1.0', SUEnableAutomaticChecks=False, SUEnableJavaScript=False, SUFeedURL=source['SUFeedURL'], SUPublicEDKey=source['SUPublicEDKey'])
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
PY
"$test_root/probe" "$test_root/older.app" "$expected"
"$test_root/probe" "$test_root/current.app" none
