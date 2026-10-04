import AppKit
import Combine
import Darwin
import SwiftUI

/// Exercises the real settings UI with an isolated store, without display controllers.
@main
struct SettingsMemoryCheck {
  static func main() {
    let passed = self.checkMemory()
    if !passed { exit(1) }
  }

  private static func checkMemory() -> Bool {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let suite = "SwiftNativeBrightness.MemoryTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let preferences = SettingsPreferences(defaults: defaults)
    let controller = SettingsSplitViewController(
      preferences: preferences, legacyController: { _ in nil },
      resetSettings: {}, quitApplication: {}
    )
    let window = SettingsWindow(content: controller, autosaveName: suite)
    window.orderBack(nil)
    defer {
      window.close()
      NSWindow.removeFrame(usingName: suite)
      defaults.removePersistentDomain(forName: suite)
    }
    var invalidations = 0
    let observation = preferences.objectWillChange.sink { invalidations += 1 }
    func settle() {
      RunLoop.main.run(until: Date().addingTimeInterval(0.02))
      window.contentView?.layoutSubtreeIfNeeded()
    }
    func poll(_ index: Int) {
      // The same per-display key shape written by AppleDisplay.refreshBrightness().
      defaults.set(Float(index % 100) / 100, forKey: "value16(TestDisplay@1)")
      settle()
    }
    func allocatedBytes() -> Int {
      var statistics = malloc_statistics_t()
      malloc_zone_statistics(nil, &statistics)
      return Int(statistics.size_in_use)
    }
    func report(_ message: String) {
      print(message)
      fflush(stdout)
    }
    for index in 0 ..< 100 {
      autoreleasepool { poll(index) }
    }
    let baseline = allocatedBytes()
    invalidations = 0
    report("BASELINE allocated=\(baseline) pid=\(getpid())")
    for index in 0 ..< 3000 {
      autoreleasepool { poll(index) }
      if (index + 1).isMultiple(of: 500) {
        report("POLL \(index + 1) growth=\(allocatedBytes() - baseline) invalidations=\(invalidations)")
      }
    }
    let growth = allocatedBytes() - baseline
    withExtendedLifetime(observation) {}
    // Warm caches may grow a little; observation accumulation grows with every poll.
    let passed = growth < 4 * 1024 * 1024 && invalidations == 0
    report("\(passed ? "PASS" : "FAIL"): 3000 display polls; heap growth=\(growth) bytes; Settings invalidations=\(invalidations)")
    return passed
  }
}
