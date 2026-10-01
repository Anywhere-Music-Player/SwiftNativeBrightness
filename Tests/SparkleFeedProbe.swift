import Cocoa
import Sparkle

// Information-only probe: no app display controllers and no update installation.
final class FeedProbe: NSObject, SPUUpdaterDelegate {
  var result: String?
  func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    self.result = item.versionString
  }

  func updaterDidNotFindUpdate(_: SPUUpdater) {
    self.result = "none"
  }

  func updater(_: SPUUpdater, didAbortWithError error: Error) {
    if self.result == nil { self.result = "error: \(error)" }
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let host = Bundle(path: CommandLine.arguments[1])!
let probe = FeedProbe()
let driver = SPUStandardUserDriver(hostBundle: host, delegate: nil)
let updater = SPUUpdater(hostBundle: host, applicationBundle: host, userDriver: driver, delegate: probe)
try updater.start()
updater.checkForUpdateInformation()
let deadline = Date().addingTimeInterval(45)
while probe.result == nil, Date() < deadline {
  RunLoop.main.run(until: Date().addingTimeInterval(0.1))
}

let actual = probe.result ?? "timeout"
precondition(actual == CommandLine.arguments[2], "Expected \(CommandLine.arguments[2]), got \(actual)")
print("PASS: Sparkle build \(host.object(forInfoDictionaryKey: "CFBundleVersion")!) -> \(actual)")
