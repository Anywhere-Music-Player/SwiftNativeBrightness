// Copyright © MonitorControl contributors

import Combine
import SwiftUI

/// Shares the existing preference keys with menu, keyboard and display controls.
final class SettingsPreferences: ObservableObject {
  enum LoginStatus {
    case disabled, enabled, requiresApproval
  }

  let defaults: UserDefaults
  private let beforeChange: (PrefKey) -> Void
  private let afterChange: (PrefKey) -> Void
  private let readLoginStatus: () -> LoginStatus
  private let changeLoginStatus: (Bool) -> Void
  private var defaultsObserver: AnyCancellable?
  private var observedDefaults: NSDictionary

  @Published private(set) var loginStatus: LoginStatus = .disabled

  init(
    defaults: UserDefaults,
    beforeChange: @escaping (PrefKey) -> Void = { _ in },
    afterChange: @escaping (PrefKey) -> Void = { _ in },
    readLoginStatus: @escaping () -> LoginStatus = { .disabled },
    changeLoginStatus: @escaping (Bool) -> Void = { _ in }
  ) {
    self.defaults = defaults
    self.beforeChange = beforeChange
    self.afterChange = afterChange
    self.readLoginStatus = readLoginStatus
    self.changeLoginStatus = changeLoginStatus
    self.observedDefaults = Self.settingsDefaults(in: defaults)
    self.defaultsObserver = NotificationCenter.default.publisher(
      for: UserDefaults.didChangeNotification, object: defaults
    )
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in self?.defaultsDidChange() }
    self.refreshLoginStatus()
  }

  private static func settingsDefaults(in defaults: UserDefaults) -> NSDictionary {
    // Settings use bare PrefKey names. Display telemetry has a display suffix,
    // e.g. value16(Display@1), and must not invalidate the hosted SwiftUI forms.
    defaults.dictionaryRepresentation().filter { PrefKey(rawValue: $0.key) != nil } as NSDictionary
  }

  private func defaultsDidChange() {
    let values = Self.settingsDefaults(in: self.defaults)
    guard values != self.observedDefaults else { return }
    self.observedDefaults = values
    self.objectWillChange.send()
  }

  func boolean(_ key: PrefKey, inverted: Bool = false) -> Binding<Bool> {
    Binding(
      get: { self.defaults.bool(forKey: key.rawValue) != inverted },
      set: { value in
        let storedValue = value != inverted
        guard self.defaults.bool(forKey: key.rawValue) != storedValue else { return }
        self.objectWillChange.send()
        self.beforeChange(key)
        self.defaults.set(storedValue, forKey: key.rawValue)
        self.afterChange(key)
      }
    )
  }

  func integer(_ key: PrefKey) -> Binding<Int> {
    Binding(
      get: { self.defaults.integer(forKey: key.rawValue) },
      set: { value in
        guard self.defaults.integer(forKey: key.rawValue) != value else { return }
        self.objectWillChange.send()
        self.beforeChange(key)
        self.defaults.set(value, forKey: key.rawValue)
        self.afterChange(key)
      }
    )
  }

  var launchAtLogin: Binding<Bool> {
    Binding(
      get: { self.loginStatus == .enabled },
      set: { enabled in
        self.changeLoginStatus(enabled)
        // Registration may fail or require approval. Reflect the actual system status.
        self.refreshLoginStatus()
      }
    )
  }

  func refreshLoginStatus() {
    self.loginStatus = self.readLoginStatus()
  }
}

/// This app starts at build 1 in its own preferences domain.
enum SettingsBuildCompatibility {
  static func shouldReset(previousBuild: Int, currentBuild: Int) -> Bool {
    previousBuild > currentBuild
  }
}
