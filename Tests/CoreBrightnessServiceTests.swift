@testable import MenuControls
import XCTest

final class CoreBrightnessServiceTests: XCTestCase {
  @MainActor
  func testDelayedOffCannotDisableSliderAfterEnablingDuringDrag() async throws {
    let client = BlueLightClientFixture()
    let gate = StatusReadGate()
    let service = self.makeService(client, gate: gate)
    let temperature = try XCTUnwrap(service.nightShiftTemperature)
    await temperature.refresh()

    let oldRead = service.refresh()
    await self.fulfillment(of: [gate.entered], timeout: 3)
    defer { gate.release() }
    service.setNightShift(true)
    temperature.setEditing(true)
    defer { temperature.setEditing(false) }
    await temperature.setStrength(0.6)
    gate.release()
    await oldRead.value

    XCTAssertTrue(service.nightShiftEnabled, "A stale Off must not disable the slider during a drag")
    XCTAssertEqual(temperature.strength, Double(Float(0.6)))
  }

  @MainActor
  func testDelayedOnCannotUndoDisabling() async {
    let client = BlueLightClientFixture(enabled: true)
    let gate = StatusReadGate()
    let service = self.makeService(client, gate: gate)
    let oldRead = service.refresh()
    await self.fulfillment(of: [gate.entered], timeout: 3)
    defer { gate.release() }
    service.setNightShift(false)
    gate.release()
    await oldRead.value
    XCTAssertFalse(service.nightShiftEnabled)
  }

  @MainActor
  func testOlderRefreshCannotOverwriteNewerSystemState() async {
    let client = BlueLightClientFixture()
    let gate = StatusReadGate()
    let service = self.makeService(client, gate: gate)
    let oldRead = service.refresh()
    await self.fulfillment(of: [gate.entered], timeout: 3)
    defer { gate.release() }
    client.setEnabled(true) // An external change, without the app's toggle path.
    await service.refresh().value
    XCTAssertTrue(service.nightShiftEnabled)
    gate.release()
    await oldRead.value
    XCTAssertTrue(service.nightShiftEnabled)
  }

  @MainActor
  func testFreshReadStillFollowsExternalChangesAfterToggle() async {
    let client = BlueLightClientFixture()
    let service = self.makeService(client)
    service.setNightShift(true)
    client.setEnabled(false)
    await service.refresh().value
    XCTAssertFalse(service.nightShiftEnabled)
    client.setEnabled(true)
    await service.refresh().value
    XCTAssertTrue(service.nightShiftEnabled)
  }

  @MainActor
  func testFailedStatusReadKeepsLastKnownEnabledState() async {
    let client = BlueLightClientFixture()
    let service = self.makeService(client)
    service.setNightShift(true)
    client.rejectStatusReads()
    await service.refresh().value
    XCTAssertTrue(service.nightShiftEnabled)
  }

  @MainActor
  func testDiagnosticsRecordDiscardedStateAndOmitUnchangedPolling() async {
    let client = BlueLightClientFixture()
    let gate = StatusReadGate()
    let log = DiagnosticLog()
    let service = CoreBrightnessService(blueLightClient: client, trueToneClient: nil, diagnosticLog: log,
                                        readDarkMode: { gate.waitOnce(); return nil })
    let oldRead = service.refresh()
    await self.fulfillment(of: [gate.entered], timeout: 3)
    defer { gate.release() }
    service.setNightShift(true)
    gate.release()
    await oldRead.value
    XCTAssertTrue(log.snapshot().contains("Night Shift ignored stale status enabled=false current=true"))
    for _ in 0 ..< 10 {
      await service.refresh().value
    }
    XCTAssertFalse(log.snapshot().contains("Night Shift status enabled=true"))
    client.setEnabled(false)
    await service.refresh().value
    XCTAssertTrue(log.snapshot().contains("Night Shift status enabled=false"))
  }

  @MainActor
  private func makeService(_ client: BlueLightClientFixture, gate: StatusReadGate? = nil) -> CoreBrightnessService {
    CoreBrightnessService(blueLightClient: client, trueToneClient: nil, diagnosticLog: DiagnosticLog(),
                          readDarkMode: { gate?.waitOnce(); return nil })
  }
}

/// Exercise the production ObjC bridge and publication path without CoreBrightness.
private final class BlueLightClientFixture: NSObject, @unchecked Sendable {
  private let lock = NSLock()
  private var enabled: Bool
  private var strength: Float = 0
  private var rejectReads = false

  init(enabled: Bool = false) { self.enabled = enabled }

  @objc func getBlueLightStatus(_ buffer: UnsafeMutableRawPointer) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    guard !self.rejectReads else { return false }
    buffer.storeBytes(of: UInt8(self.enabled ? 1 : 0), toByteOffset: 1, as: UInt8.self)
    return true
  }

  @objc func setEnabled(_ enabled: Bool) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.enabled = enabled
  }

  @objc func getStrength(_ value: UnsafeMutablePointer<Float>) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    value.pointee = self.strength
    return true
  }

  @objc func setStrength(_ value: Float, commit _: Bool) -> Bool {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.strength = value
    return true
  }

  func rejectStatusReads() {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.rejectReads = true
  }
}

/// Pause after the first Night Shift snapshot, before the service publishes it.
private final class StatusReadGate: @unchecked Sendable {
  let entered = XCTestExpectation(description: "Old Night Shift snapshot captured")
  private let lock = NSLock()
  private let semaphore = DispatchSemaphore(value: 0)
  private var claimed = false

  func waitOnce() {
    self.lock.lock()
    let shouldWait = !self.claimed
    self.claimed = true
    self.lock.unlock()
    guard shouldWait else { return }
    self.entered.fulfill()
    if self.semaphore.wait(timeout: .now() + 5) == .timedOut {
      XCTFail("Timed out waiting for the delayed status read to be released")
    }
  }

  func release() { self.semaphore.signal() }
}
