import SwiftUI

struct ContentView: View {
    @State private var model = SimulatorListViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
            Divider()
            Button("Quit DeviceTray") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .task { await model.refresh() }
    }

    private var header: some View {
        HStack {
            Text("DeviceTray")
                .font(.headline)
            Spacer()
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(model.isLoading)
            .help("Refresh simulators")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = model.errorMessage {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        } else if model.groups.isEmpty {
            if !model.isLoading {
                Text("No simulators found.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.groups) { group in
                        RuntimeSection(group: group)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)
        }
    }
}

private struct RuntimeSection: View {
    let group: RuntimeGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(group.simulators) { simulator in
                SimulatorRow(simulator: simulator)
            }
        }
    }
}

private struct SimulatorRow: View {
    let simulator: Simulator

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(simulator.isBooted ? Color.green : Color.clear)
                .frame(width: 8, height: 8)
                .accessibilityLabel(simulator.isBooted ? "Booted" : "Shut down")
            Text(simulator.name)
                .lineLimit(1)
        }
    }
}
