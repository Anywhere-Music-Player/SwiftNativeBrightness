import Foundation

/// The transport is injected so failed I2C reads can be tested without a display.
enum DDCCommunication {
  static func replyValues(_ reply: [UInt8], command: UInt8) -> (current: UInt16, max: UInt16)? {
    guard reply.count == 11,
          reply[0] == 0x6E, reply[1] == 0x88,
          reply[2] == 0x02, reply[3] == 0,
          reply[4] == command,
          reply.prefix(10).reduce(UInt8(0x50), ^) == reply[10]
    else { return nil }
    return (UInt16(reply[8]) << 8 | UInt16(reply[9]), UInt16(reply[6]) << 8 | UInt16(reply[7]))
  }

  static func perform(
    send: [UInt8], reply: inout [UInt8],
    writeSleepTime: UInt32 = 10000, writeCycles: UInt8 = 2,
    readSleepTime: UInt32 = 50000, retries: UInt8 = 4, retrySleepTime: UInt32 = 20000,
    write: (inout [UInt8]) -> Int32,
    read: (inout [UInt8]) -> Int32,
    sleep: (UInt32) -> Void = { usleep($0) },
    report: (String) -> Void = { _ in }
  ) -> Bool {
    guard let command = send.first, send.count == 1 || send.count == 3 else { return false }
    let expectsReply = !reply.isEmpty
    var packet: [UInt8] = [UInt8(0x80 | (send.count + 1)), UInt8(send.count)] + send
    packet.append(packet.reduce(UInt8(send.count == 1 ? 0x6E : 0x6E ^ 0x51), ^))
    for attempt in 0 ... Int(retries) {
      var writeStatus: Int32 = -1
      for _ in 0 ..< max(Int(writeCycles), 1) {
        sleep(writeSleepTime)
        writeStatus = write(&packet)
      }
      if writeStatus == 0 {
        if !expectsReply { return true }
        // Never reuse bytes or the request's success flag after a failed read.
        reply = [UInt8](repeating: 0, count: 11)
        sleep(readSleepTime)
        let readStatus = read(&reply)
        if readStatus == 0, Self.replyValues(reply, command: command) != nil { return true }
        let bytes = reply.map { String(format: "%02X", $0) }.joined(separator: " ")
        report("read attempt=\(attempt + 1) status=\(readStatus) invalid reply=[\(bytes)]")
      } else {
        report("request attempt=\(attempt + 1) status=\(writeStatus)")
      }
      if attempt < Int(retries) { sleep(retrySleepTime) }
    }
    return false
  }
}

/// A damaged cached maximum must never collapse a control's range to zero.
struct DDCValueRange {
  let minimum: Int
  let maximum: Int

  init(minimum: Int, maximum: Int) {
    self.minimum = min(max(minimum, 0), Int(UInt16.max) - 1)
    self.maximum = maximum > self.minimum && maximum <= Int(UInt16.max)
      ? maximum : max(100, self.minimum + 1)
  }

  static func resolvedMaximum(reported: UInt16?, override: Int, minimum: Int, previous: Int) -> Int {
    if override > minimum, override <= Int(UInt16.max) { return override }
    if let reported, Int(reported) > minimum {
      return DDCValueRange(minimum: minimum, maximum: min(Int(reported), 100)).maximum
    }
    return DDCValueRange(minimum: minimum, maximum: previous).maximum
  }

  func normalize(_ value: UInt16) -> Float {
    Float(min(max(Int(value), self.minimum), self.maximum) - self.minimum) / Float(self.maximum - self.minimum)
  }

  func denormalize(_ value: Float) -> UInt16 {
    let fraction = value.isFinite ? min(max(value, 0), 1) : 0
    return UInt16((Float(self.maximum - self.minimum) * fraction + Float(self.minimum)).rounded())
  }
}
