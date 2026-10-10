// Adapted from Crisp. Copyright (c) 2026 Didrik Galteland.
// Distributed under the MIT license; see SwiftNativeBrightness/UI/Crisp-LICENSE.txt.

import Combine
import Foundation

/// The system owns the strength and schedule. Keep only a live UI snapshot here.
/// Reads cannot pull the thumb backward during a drag; writes are serialized and
/// coalesced so a slow CoreBrightness round-trip does not queue every mouse event.
@MainActor
final class NightShiftTemperatureController: ObservableObject {
  @Published private(set) var strength: Double?

  private let read: @Sendable () async -> Float?
  private let write: @Sendable (Float) async -> Bool
  private let log: @Sendable (String) -> Void
  private var lastLoggedRead: String?
  private var revision: UInt64 = 0
  private var isEditing = false
  private var isWriting = false
  private var pendingStrength: Float?

  init(read: @escaping @Sendable () async -> Float?, write: @escaping @Sendable (Float) async -> Bool,
       log: @escaping @Sendable (String) -> Void = { _ in })
  {
    self.read = read
    self.write = write
    self.log = log
  }

  func refresh() async {
    guard !self.isEditing, !self.isWriting else { return }
    self.revision &+= 1
    let request = self.revision
    let value = await read()
    guard request == self.revision, !self.isEditing, !self.isWriting else { return }
    let snapshot = value.flatMap { $0.isFinite ? Double(min(1, max(0, $0))) : nil }
    let description = Self.describe(snapshot)
    if description != self.lastLoggedRead {
      self.log("Night Shift read strength=\(description)")
      self.lastLoggedRead = description
    }
    self.strength = snapshot
  }

  func setEditing(_ editing: Bool) {
    if editing != self.isEditing {
      self.log("Night Shift drag \(editing ? "began" : "ended") strength=\(Self.describe(self.strength))")
    }
    self.isEditing = editing
    self.revision &+= 1
  }

  func setStrength(_ value: Double) async {
    guard value.isFinite else { return }
    let target = Float(min(1, max(0, value)))
    self.revision &+= 1
    self.strength = Double(target)
    self.pendingStrength = target
    guard !self.isWriting else { return }
    self.isWriting = true
    while let next = pendingStrength {
      self.pendingStrength = nil
      // Always read back after the last write, including failures. A failed
      // read disables the control instead of displaying an invented value.
      if await !self.write(next) {
        self.log("Night Shift write failed strength=\(Self.describe(Double(next)))")
      }
    }
    self.isWriting = false
    await self.refresh()
  }

  private static func describe(_ value: Double?) -> String {
    value.map { "\(Int(($0 * 100).rounded()))%" } ?? "unavailable"
  }
}
