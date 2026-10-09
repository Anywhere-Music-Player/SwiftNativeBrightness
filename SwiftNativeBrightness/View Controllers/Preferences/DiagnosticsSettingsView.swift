import Combine
import SwiftUI

struct DiagnosticsSettingsView: View {
  var log: DiagnosticLog = .shared
  @State private var text = ""
  private let refresh = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recent display reads, volume requests and communication errors. The last 200 entries are saved locally across restarts.")
        .foregroundStyle(.secondary)
      HStack {
        Button("Copy Log") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(self.log.snapshot(), forType: .string)
        }
        Button("Clear Log") {
          self.log.clear()
          self.text = ""
        }
        Spacer()
      }
      ScrollView([.horizontal, .vertical]) {
        Text(self.text.isEmpty ? "No diagnostic events yet." : self.text)
          .font(.system(size: 11, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .padding(10)
      }
      .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }
    .padding(20)
    .onAppear { self.text = self.log.snapshot() }
    .onReceive(self.refresh) { _ in
      let snapshot = self.log.snapshot()
      if snapshot != self.text { self.text = snapshot }
    }
  }
}
