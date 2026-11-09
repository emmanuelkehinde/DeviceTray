import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DeviceTray")
                .font(.headline)
            Text("No devices yet.")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit DeviceTray") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }
}
