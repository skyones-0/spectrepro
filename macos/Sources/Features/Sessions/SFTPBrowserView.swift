import AppKit
import SwiftUI

public struct SFTPBrowserView: View {
    private let context: ActiveSSHContext
    @StateObject private var client: SFTPClient
    @State private var remotePath = "."
    @State private var selectedEntry: SFTPDirectoryEntry?

    public init(context: ActiveSSHContext) {
        self.context = context
        _client = StateObject(wrappedValue: SFTPClient(context: context))
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.person.crop")
                    .foregroundStyle(Color.accentColor)
                Text("SFTP")
                    .font(.headline)
                Text(context.targetSpec)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { client.list(remotePath: remotePath) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(client.isLoading)
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    client.upload(localURL: url, remotePath: remotePath)
                } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .buttonStyle(.borderless)
                .help("Upload file")
                .disabled(client.isLoading)
                Button {
                    guard let selectedEntry, !selectedEntry.isDirectory else { return }
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = selectedEntry.name
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    client.download(remotePath: selectedEntry.path, localURL: url)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help("Download selected file")
                .disabled(client.isLoading || selectedEntry?.isDirectory != false)
            }
            .padding(14)

            HStack(spacing: 8) {
                TextField("Remote path", text: $remotePath)
                    .textFieldStyle(.roundedBorder)
                Button("Go") { client.list(remotePath: remotePath) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()

            if client.isLoading {
                ProgressView("Loading directory…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = client.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("SFTP Error")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(client.entries) { entry in
                    Button {
                        selectedEntry = entry
                        guard entry.isDirectory else { return }
                        remotePath = entry.path
                        client.list(remotePath: entry.path)
                    } label: {
                        Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let status = client.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 560, height: 420)
        .onAppear { client.list(remotePath: remotePath) }
    }
}
