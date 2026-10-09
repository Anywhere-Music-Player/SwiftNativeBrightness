@testable import DisplayDiagnostics
import XCTest

final class DDCCommunicationTests: XCTestCase {
  private func reply(command: UInt8 = 0x62, current: UInt16 = 1, maximum: UInt16 = 100, result: UInt8 = 0) -> [UInt8] {
    var bytes: [UInt8] = [0x6E, 0x88, 0x02, result, command, 0, UInt8(maximum >> 8), UInt8(maximum & 255), UInt8(current >> 8), UInt8(current & 255)]
    bytes.append(bytes.reduce(UInt8(0x50), ^))
    return bytes
  }

  func testFailedReadAfterSuccessfulRequestReturnsFailureAndRetries() {
    var bytes = [UInt8](repeating: 0, count: 11)
    var reads = 0
    let ok = DDCCommunication.perform(send: [0x62], reply: &bytes, retries: 4, write: { _ in 0 }, read: { _ in
      reads += 1
      return -1
    }, sleep: { _ in })
    XCTAssertFalse(ok, "A successful Get request must not turn a failed read into current=0, max=0")
    XCTAssertEqual(reads, 5)
  }

  func testTransientReadFailureRecoversOnNextAttempt() {
    var bytes = [UInt8](repeating: 0, count: 11)
    var reads = 0
    let ok = DDCCommunication.perform(send: [0x62], reply: &bytes, write: { _ in 0 }, read: { buffer in
      reads += 1
      if reads == 1 { return -1 }
      buffer = self.reply()
      return 0
    }, sleep: { _ in })
    XCTAssertTrue(ok)
    XCTAssertEqual(reads, 2)
    XCTAssertEqual(DDCCommunication.replyValues(bytes, command: 0x62)?.current, 1)
    XCTAssertEqual(DDCCommunication.replyValues(bytes, command: 0x62)?.max, 100)
  }

  func testFailedReadCannotAcceptStaleValidBytes() {
    var bytes = self.reply()
    XCTAssertFalse(DDCCommunication.perform(send: [0x62], reply: &bytes, retries: 0, write: { _ in 0 }, read: { _ in -1 }, sleep: { _ in }))
    XCTAssertNil(DDCCommunication.replyValues(bytes, command: 0x62))
  }

  func testWrongCommandReplyIsRetried() {
    var bytes = [UInt8](repeating: 0, count: 11)
    var reads = 0
    XCTAssertTrue(DDCCommunication.perform(send: [0x62], reply: &bytes, write: { _ in 0 }, read: { buffer in
      reads += 1
      buffer = self.reply(command: reads == 1 ? 0x10 : 0x62)
      return 0
    }, sleep: { _ in }))
    XCTAssertEqual(reads, 2)
  }

  func testInvalidChecksumStatusHeaderAndLengthAreRejected() {
    var corrupt = self.reply()
    corrupt[10] ^= 1
    XCTAssertNil(DDCCommunication.replyValues(corrupt, command: 0x62))
    XCTAssertNil(DDCCommunication.replyValues(self.reply(result: 1), command: 0x62))
    XCTAssertNil(DDCCommunication.replyValues(Array(self.reply().prefix(10)), command: 0x62))
    for index in [0, 1, 2, 4] {
      var invalid = self.reply()
      invalid[index] ^= 1
      invalid[10] = invalid.prefix(10).reduce(UInt8(0x50), ^)
      XCTAssertNil(DDCCommunication.replyValues(invalid, command: 0x62))
    }
  }

  func testFailedRequestsDoNotReadAndRetryLimitDoesNotOverflow() {
    var bytes = [UInt8](repeating: 0, count: 11)
    var writes = 0
    XCTAssertFalse(DDCCommunication.perform(send: [0x62], reply: &bytes, writeCycles: 1, retries: 255, write: { _ in
      writes += 1
      return -1
    }, read: { _ in XCTFail("Read after failed request"); return 0 }, sleep: { _ in }))
    XCTAssertEqual(writes, 256)
  }

  func testWriteHasCorrectPacketAndNeverReads() {
    var bytes: [UInt8] = []
    XCTAssertTrue(DDCCommunication.perform(send: [0x62, 0, 2], reply: &bytes, write: { packet in
      XCTAssertEqual(packet, [0x84, 0x03, 0x62, 0, 2, 0xD8])
      return 0
    }, read: { _ in XCTFail("Read during Set command"); return -1 }, sleep: { _ in }))
  }

  func testReplyPreserves16BitValuesAndEnumerationWithZeroMaximum() {
    let values = DDCCommunication.replyValues(self.reply(current: 258, maximum: 1024), command: 0x62)
    XCTAssertEqual(values?.current, 258)
    XCTAssertEqual(values?.max, 1024)
    // Mute is an enumeration; range checks belong to continuous controls at setup.
    XCTAssertEqual(DDCCommunication.replyValues(self.reply(command: 0x8D, current: 2, maximum: 0), command: 0x8D)?.current, 2)
  }

  func testDamagedCachedMaximumCannotCollapseVolumeToOne() {
    let range = DDCValueRange(minimum: 0, maximum: 0)
    XCTAssertEqual(range.denormalize(0.0625), 6)
    XCTAssertEqual(range.denormalize(0.5), 50)
    XCTAssertEqual(range.denormalize(1), 100)
    XCTAssertEqual(range.normalize(1), 0.01, accuracy: 0.00001)
  }

  func testStartupReadReplacesDamagedRangeBeforeNormalizingCurrentValue() {
    let maximum = DDCValueRange.resolvedMaximum(reported: 100, override: 0, minimum: 0, previous: 0)
    let range = DDCValueRange(minimum: 0, maximum: maximum)
    XCTAssertEqual(range.normalize(1), 0.01, accuracy: 0.00001)
    XCTAssertEqual(range.denormalize(range.normalize(1) + 0.01), 2)
  }

  func testFailedReadPreservesKnownRangeAndOverride() {
    XCTAssertEqual(DDCValueRange.resolvedMaximum(reported: nil, override: 0, minimum: 0, previous: 80), 80)
    XCTAssertEqual(DDCValueRange.resolvedMaximum(reported: 0, override: 0, minimum: 0, previous: 80), 80)
    XCTAssertEqual(DDCValueRange.resolvedMaximum(reported: 100, override: 60, minimum: 10, previous: 80), 60)
    XCTAssertEqual(DDCValueRange.resolvedMaximum(reported: nil, override: 0, minimum: 0, previous: 0), 100)
  }

  func testRangeHandlesNonFiniteValuesAndInvalidOverrides() {
    let range = DDCValueRange(minimum: 10, maximum: 60)
    XCTAssertEqual(range.denormalize(0.5), 35)
    XCTAssertEqual(range.normalize(35), 0.5)
    XCTAssertEqual(range.denormalize(.nan), 10)
    XCTAssertEqual(range.denormalize(.infinity), 10)
    XCTAssertEqual(range.denormalize(-1), 10)
    XCTAssertEqual(range.denormalize(2), 60)
    let invalid = DDCValueRange(minimum: 100, maximum: 100)
    XCTAssertTrue(invalid.normalize(100).isFinite)
    XCTAssertGreaterThan(invalid.maximum, invalid.minimum)
  }
}
