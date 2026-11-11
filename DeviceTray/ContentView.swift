import SwiftUI

struct ContentView: View {
    @State private var model = SimulatorListViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let message = model.actionErrorMessage {
                ActionErrorBanner(message: message) { model.dismissActionError() }
            }
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
                        RuntimeSection(group: group, model: model)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)
        }
    }
}

private struct ActionErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Dismiss")
        }
    }
}

private struct RuntimeSection: View {
    let group: RuntimeGroup
    let model: SimulatorListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(group.simulators) { simulator in
                SimulatorRow(simulator: simulator, model: model)
            }
        }
    }
}

private struct SimulatorRow: View {
    let simulator: Simulator
    let model: SimulatorListViewModel

    @State private var showsLinkField = false
    @State private var link = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(simulator.isBooted ? Color.green : Color.clear)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(simulator.isBooted ? "Booted" : "Shut down")
                Text(simulator.name)
                    .lineLimit(1)
                Spacer()
                if model.isBusy(simulator) {
                    ProgressView()
                        .controlSize(.small)
                }
                if simulator.isBooted {
                    Button {
                        showsLinkField.toggle()
                    } label: {
                        Image(systemName: "link")
                    }
                    .buttonStyle(.borderless)
                    .help("Open a link")
                }
                Button(simulator.isBooted ? "Shut Down" : "Boot") {
                    Task {
                        if simulator.isBooted {
                            await model.shutDown(simulator)
                        } else {
                            await model.boot(simulator)
                        }
                    }
                }
                .controlSize(.small)
                .disabled(model.isBusy(simulator))
            }
            if simulator.isBooted && showsLinkField {
                HStack(spacing: 6) {
                    TextField("myapp://path or https://...", text: $link)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .onSubmit(openLink)
                    Button("Open", action: openLink)
                        .controlSize(.small)
                        .disabled(model.isBusy(simulator))
                }
                .padding(.leading, 14)
            }
        }
    }

    private func openLink() {
        Task { await model.openLink(link, on: simulator) }
    }
}
