@testable import DisplayDiagnostics
import XCTest

final class DiagnosticLogTests: XCTestCase {
  func testOnlyMostRecent200EntriesAreKept() {
    let log = DiagnosticLog()
    for index in 0 ..< 1000 {
      log.record("entry=\(index)")
    }
    let lines = log.snapshot().split(separator: "\n")
    XCTAssertEqual(lines.count, 200)
    XCTAssertTrue(lines.first!.hasSuffix("entry=800"))
    XCTAssertTrue(lines.last!.hasSuffix("entry=999"))
  }

  func testConcurrentRecordingStaysBoundedAndSingleLine() {
    let log = DiagnosticLog()
    DispatchQueue.concurrentPerform(iterations: 1000) { _ in log.record(String(repeating: "a", count: 1000) + "\nsecond line") }
    let text = log.snapshot()
    XCTAssertEqual(text.split(separator: "\n").count, 200)
    XCTAssertLessThan(text.utf8.count, 128 * 1024)
  }

  func testPersistenceAcrossRestartAndClear() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("diagnostics.log")
    let log = DiagnosticLog(fileURL: url)
    log.record("volume raw=1 max=100")
    log.flush()
    let restored = DiagnosticLog(fileURL: url)
    XCTAssertEqual(restored.snapshot(), log.snapshot())
    restored.clear()
    restored.flush()
    XCTAssertEqual(DiagnosticLog(fileURL: url).snapshot(), "")
  }
}
