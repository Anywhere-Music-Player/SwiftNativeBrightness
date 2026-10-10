import AppKit
import ApplicationServices
import SwiftUI

// Only the system service is replaced. The menu uses the production SwiftUI views
// and controller, with an isolated preferences suite and no CoreBrightness calls.
private let suite = "SwiftNativeBrightness.MenuTests.\(UUID().uuidString)"
let prefs = UserDefaults(suiteName: suite)!
enum PrefKey: String { case enableSliderPercent }
enum MenuLayout { static let width: CGFloat = 300; static let inset: CGFloat = 12 }

@MainActor final class CoreBrightnessService: ObservableObject {
  static let shared = CoreBrightnessService()
  @Published var nightShiftEnabled = false
  @Published var trueToneEnabled = true
  @Published var darkModeEnabled = false
  let nightShiftAvailable = true
  let trueToneAvailable = true
  let darkModeAvailable = true
  var nightShiftTemperature: NightShiftTemperatureController?
  func setNightShift(_ value: Bool) { self.nightShiftEnabled = value }
  func setTrueTone(_ value: Bool) { self.trueToneEnabled = value }
  func setDarkMode(_ value: Bool) { self.darkModeEnabled = value }
  func refresh() {
    if let nightShiftTemperature { Task { await nightShiftTemperature.refresh() } }
  }
}

private actor TemperatureBackend {
  var value: Float = 0
  private(set) var writes: [Float] = []
  func read() -> Float { self.value }
  func write(_ value: Float) -> Bool {
    self.value = value
    self.writes.append(value)
    return true
  }
}

@MainActor private final class MenuCheck: NSObject, NSMenuDelegate {
  let backend = TemperatureBackend()
  let controller: NightShiftTemperatureController
  let host: NSHostingView<SystemControlsView>
  let menu = NSMenu()
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  let savedPointer = CGEvent(source: nil)!.location
  var failures: [String] = []
  var round = 0

  override init() {
    self.controller = NightShiftTemperatureController(read: { [backend] in await backend.read() },
                                                      write: { [backend] in await backend.write($0) })
    CoreBrightnessService.shared.nightShiftTemperature = self.controller
    self.host = NSHostingView(rootView: SystemControlsView(showEffects: true, showTemperature: true))
    super.init()
    self.host.frame.size = self.host.fittingSize
    self.menu.delegate = self
    let item = NSMenuItem()
    item.view = self.host
    self.menu.addItem(item)
    self.statusItem.button?.title = "Night Shift Test"
    self.statusItem.menu = self.menu
  }

  func later(_ delay: Double, mode: RunLoop.Mode = .eventTracking, _ action: @escaping @MainActor @Sendable () -> Void) {
    let timer = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated { action() } }
    RunLoop.main.add(timer, forMode: mode)
  }

  func mouse(_ type: CGEventType, x: CGFloat) {
    guard let window = self.host.window, window.isVisible else {
      self.failures.append("Menu was not visible for a mouse event")
      return
    }
    func sliderFrame(in view: NSView) -> NSRect? {
      for child in view.subviews {
        if child is NSSlider || (String(describing: Swift.type(of: child)).contains("FocusRingView") && child.frame.width > 200 && child.frame.height < 30) {
          return child.convert(child.bounds, to: self.host)
        }
        if let frame = sliderFrame(in: child) { return frame }
      }
      return nil
    }
    guard let frame = sliderFrame(in: self.host) else {
      self.failures.append("Temperature slider was not laid out")
      return
    }
    let local = NSPoint(x: frame.minX + (x - 12) / 276 * frame.width, y: frame.midY)
    let screen = window.convertPoint(toScreen: self.host.convert(local, to: nil))
    let point = CGPoint(x: screen.x, y: NSScreen.screens[0].frame.height - screen.y)
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!
    event.setDoubleValueField(.mouseEventPressure, value: type == .leftMouseUp ? 0 : 1)
    event.post(tap: .cghidEventTap)
  }

  func run() async {
    await self.controller.refresh()
    self.later(15, mode: .common) { [self] in
      self.failures.append("Menu interaction timed out")
      self.finish()
    }
    self.openRound()
  }

  func openRound() {
    self.round += 1
    let currentRound = self.round
    CoreBrightnessService.shared.nightShiftEnabled = currentRound != 4
    self.later(0.1, mode: .default) { [self] in
      self.statusItem.button?.performClick(nil)
      if currentRound < 4 {
        self.later(0.3, mode: .default) { [self] in self.openRound() }
      } else {
        Task { @MainActor [self] in
          let writes = await self.backend.writes
          if writes.isEmpty { self.failures.append("No backend writes occurred") }
          if await abs(Double(self.backend.read()) - (self.controller.strength ?? -1)) > 0.001 {
            self.failures.append("Backend differs from the displayed value")
          }
          self.finish()
        }
      }
    }
  }

  func menuWillOpen(_: NSMenu) {
    self.waitForVisibleMenu(attempt: 0)
  }

  func waitForVisibleMenu(attempt: Int) {
    self.later(0.1) { [self] in
      if self.host.window?.isVisible == true {
        self.scheduleRoundActions()
      } else if attempt < 30 {
        self.waitForVisibleMenu(attempt: attempt + 1)
      } else {
        self.failures.append("Menu never became visible")
        self.finish()
      }
    }
  }

  func scheduleRoundActions() {
    let currentRound = self.round
    self.later(0.2) { [self] in self.mouse(.mouseMoved, x: 24) }
    self.later(0.3) { [self] in self.mouse(.leftMouseDown, x: 24) }
    self.later(0.5) { [self] in self.mouse(.leftMouseDragged, x: currentRound == 1 ? 120 : 240) }
    if currentRound != 1 {
      self.later(0.7) { [self] in self.mouse(.leftMouseUp, x: 240) }
    }
    if currentRound == 3 {
      // Disable during tracking, release while disabled, then re-enable and drag.
      self.later(0.6) { CoreBrightnessService.shared.setNightShift(false) }
      self.later(0.8) { CoreBrightnessService.shared.setNightShift(true) }
      self.later(0.9) { [self] in self.mouse(.leftMouseDown, x: 24) }
      self.later(1.1) { [self] in self.mouse(.leftMouseDragged, x: 180) }
      self.later(1.3) { [self] in self.mouse(.leftMouseUp, x: 180) }
    }
    self.later(currentRound == 3 ? 1.6 : 1.0) { [self] in
      let value = self.controller.strength ?? -1
      print("Round \(currentRound): strength=\(value)")
      let expected: ClosedRange<Double> = switch currentRound {
      case 1: 0.3 ... 0.5
      case 2: 0.8 ... 0.9
      default: 0.55 ... 0.65
      }
      if !expected.contains(value) { self.failures.append("Round \(currentRound): expected \(expected), got \(value)") }
      self.menu.cancelTrackingWithoutAnimation()
      // Same controller cleanup as MenuHandler.menuDidClose. The NSHostingView
      // and its control survive between menu openings, just as in the app.
      self.controller.setEditing(false)
    }
    if currentRound == 1 {
      self.later(1.15, mode: .common) { [self] in
        // The release arrives outside the cancelled menu, which previously
        // left SwiftUI Slider stuck for every subsequent menu opening.
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: self.savedPointer, mouseButton: .left)?.post(tap: .cghidEventTap)
      }
    }
  }

  func finish() -> Never {
    self.menu.cancelTrackingWithoutAnimation()
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: self.savedPointer, mouseButton: .left)?.post(tap: .cghidEventTap)
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: self.savedPointer, mouseButton: .left)?.post(tap: .cghidEventTap)
    NSStatusBar.system.removeStatusItem(self.statusItem)
    prefs.removePersistentDomain(forName: suite)
    if self.failures.isEmpty {
      print("PASS: cancelled drag, reopened menu, disable/re-enable during drag, disabled slider and backend readback.")
    } else {
      print(self.failures.map { "FAIL: \($0)" }.joined(separator: "\n"))
    }
    exit(self.failures.isEmpty ? 0 : 1)
  }
}

@main struct NightShiftMenuCheck {
  @MainActor static func main() {
    guard AXIsProcessTrusted() else {
      fputs("Accessibility access is required to send real mouse events to the test menu.\n", stderr)
      exit(2)
    }
    NSApplication.shared.setActivationPolicy(.accessory)
    prefs.set(true, forKey: PrefKey.enableSliderPercent.rawValue)
    let check = MenuCheck()
    Task { await check.run() }
    NSApp.run()
  }
}
