import Foundation
import os.log

/// A small local journal. It does not publish changes into the Settings model.
final class DiagnosticLog {
  static let capacity = 200
  static let shared = DiagnosticLog(fileURL: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
    .appendingPathComponent("Logs/SwiftNativeBrightness/diagnostics.log"))

  private let lock = NSLock()
  private let persistenceQueue = DispatchQueue(label: "Diagnostic log persistence", qos: .utility)
  private let fileURL: URL?
  private var lines: [String] = []
  private var saveScheduled = false

  init(fileURL: URL? = nil) {
    self.fileURL = fileURL
    if let fileURL, let data = try? Data(contentsOf: fileURL), data.count <= 256 * 1024,
       let saved = String(data: data, encoding: .utf8)
    {
      self.lines = saved.split(separator: "\n").suffix(Self.capacity).map { String($0.prefix(600)) }
    }
  }

  func record(_ message: String) {
    self.lock.lock()
    let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime, .withFractionalSeconds])
    self.lines.append("\(stamp) \(message.replacingOccurrences(of: "\n", with: " ").prefix(500))")
    if self.lines.count > Self.capacity { self.lines.removeFirst(self.lines.count - Self.capacity) }
    self.scheduleSaveLocked()
    self.lock.unlock()
  }

  func snapshot() -> String {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.lines.joined(separator: "\n")
  }

  func clear() {
    self.lock.lock()
    self.lines.removeAll()
    self.scheduleSaveLocked()
    self.lock.unlock()
  }

  func flush() {
    self.persistenceQueue.sync { self.persist() }
  }

  private func scheduleSaveLocked() {
    guard self.fileURL != nil, !self.saveScheduled else { return }
    self.saveScheduled = true
    self.persistenceQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.persist() }
  }

  private func persist() {
    self.lock.lock()
    let text = self.lines.joined(separator: "\n")
    self.saveScheduled = false
    self.lock.unlock()
    guard let fileURL else { return }
    do {
      try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try text.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
      os_log("Unable to save diagnostic log: %{public}@", type: .error, error.localizedDescription)
    }
  }
}
