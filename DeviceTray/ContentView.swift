import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = SimulatorListViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let message = model.actionErrorMessage {
                ActionBanner(message: message, isError: true) { model.dismissActionError() }
            } else if let message = model.actionSuccessMessage {
                ActionBanner(message: message, isError: false) { model.dismissActionSuccess() }
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

private struct ActionBanner: View {
    let message: String
    let isError: Bool
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if !isError {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text(message)
                .font(.callout)
                .foregroundStyle(isError ? Color.red : Color.primary)
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
    @Bindable var model: SimulatorListViewModel

    @State private var showsLinkField = false
    @State private var showsPushFields = false
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
                    Button {
                        showsPushFields.toggle()
                    } label: {
                        Image(systemName: "bell")
                    }
                    .buttonStyle(.borderless)
                    .help("Send a push notification")
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
            if simulator.isBooted && showsPushFields {
                pushFields
                    .padding(.leading, 14)
            }
        }
    }

    private var pushFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(payloadName)
                    .font(.callout)
                    .foregroundStyle(model.pushPayloadPath.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(model.pushPayloadPath)
                Spacer()
                Button("Choose…", action: choosePayload)
                    .controlSize(.small)
            }
            HStack(spacing: 6) {
                TextField("Bundle ID, optional if the payload has one", text: $model.pushBundleID)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit(sendPush)
                Button("Send", action: sendPush)
                    .controlSize(.small)
                    .disabled(model.isBusy(simulator))
            }
        }
    }

    private var payloadName: String {
        model.pushPayloadPath.isEmpty
            ? "No payload chosen"
            : URL(fileURLWithPath: model.pushPayloadPath).lastPathComponent
    }

    private func openLink() {
        Task { await model.openLink(link, on: simulator) }
    }

    private func sendPush() {
        Task { await model.sendPush(to: simulator) }
    }

    private func choosePayload() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a push notification payload"
        if !model.pushPayloadPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: model.pushPayloadPath).deletingLastPathComponent()
        }
        // DeviceTray has no Dock icon, so bring it forward or the panel opens behind other apps.
        NSApp.activate()
        if panel.runModal() == .OK, let url = panel.url {
            model.pushPayloadPath = url.path
        }
    }
}
