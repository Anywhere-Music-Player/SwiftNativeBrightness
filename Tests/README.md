# Night Shift controller tests

Run `./Tests/test-ddc.sh` for 15 regression tests covering failed I2C reads after successful requests, retries, stale or malformed replies, volume range recovery, and the bounded persistent diagnostic log. Transport tests inject responses and never change a physical display. The preserved M28U failure had cached volume `1.0` and maximum `0`, while three hardware reads returned current `1`, maximum `100`; the previous transport incorrectly accepted a failed read as `(0, 0)`.

Settings → Diagnostics keeps the most recent 200 events in `~/Library/Logs/SwiftNativeBrightness/diagnostics.log`, including startup reads, volume key requests, raw writes and transport errors. Copy Log and Clear Log operate on this local journal. A successful transport write is not a hardware readback confirmation. Brightness polling is not logged on every tick.

Run `./Tests/test-night-shift.sh` from the repository root on macOS 14 or later with Swift 5.9 or later. The script creates a temporary Swift package containing the actual controller source and its regression tests, then removes the temporary package when it finishes. It does not change system display settings.

The seven tests cover live readback, unavailable values, rejected writes, value clamping, stale reads, dragging and coalescing slow writes. These are controller tests; they do not verify private CoreBrightness APIs, physical displays or the appearance of the app menu.

Run settings preference tests with `./Tests/test-settings.sh`. These cover stored and inverted values, callback ordering, external changes, reset reads and launch-at-login status. Regression checks require per-display telemetry and unchanged notifications to leave Settings untouched, while real settings changes and resets still notify the UI.

Run `./Tests/test-settings-memory.sh` in a logged-in macOS session to exercise the actual settings window with an isolated preferences suite. It briefly shows a test window behind other windows, warms the UI, then performs 3,000 per-display brightness writes (about one minute). It requires zero Settings invalidations and less than 4 MiB additional allocation across malloc zones after warmup. The original code reproduced 3,000 invalidations and about 12.5 MiB growth on macOS 27.0.1, with the same Observation tracking types dominating the live app's heap. This measures the polling-triggered accumulation; it does not exercise physical displays or prove the absence of every SwiftUI/framework leak. The test closes its window and removes its isolated preferences on completion.

Run native settings window checks with `./Tests/test-settings-window.sh`. These cover tiny saved window recovery, page changes without resizing, toolbar and sidebar safe areas, a single Displays scroller, resizing and a persistent sidebar without a collapse button. Legacy content is represented by fixtures; these checks do not exercise physical displays.

Release packaging checks the app's code signature, notarization ticket and Gatekeeper assessment before creating a ZIP and SHA-256 checksum. See [Publishing releases](../Scripts/README.md). Updates use the browser's GitHub Releases page and manual app replacement.
