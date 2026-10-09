#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/swiftnativebrightness-ddc-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/Sources/DisplayDiagnostics" "$test_root/Tests/DisplayDiagnosticsTests"
cp "$project_root/SwiftNativeBrightness/Support/DDCCommunication.swift" "$project_root/SwiftNativeBrightness/Support/DiagnosticLog.swift" "$test_root/Sources/DisplayDiagnostics/"
cp "$project_root/Tests/DDCCommunicationTests.swift" "$project_root/Tests/DiagnosticLogTests.swift" "$test_root/Tests/DisplayDiagnosticsTests/"
cat > "$test_root/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "DisplayDiagnostics",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "DisplayDiagnostics"),
    .testTarget(name: "DisplayDiagnosticsTests", dependencies: ["DisplayDiagnostics"]),
  ]
)
PACKAGE
swift test --package-path "$test_root"
