import SwiftUI
import AppKit

public struct WorkspaceHubView: View {
    @ObservedObject var store = WorkspaceStore.shared

    @State private var selectedTab: WorkspaceSection = .timeline
    @State private var newNoteContent: String = ""
    @State private var newPendingCommand: String = ""
    @State private var filterEventType: TimelineEventType? = nil
    @State private var exportToastMessage: String? = nil

    // Multi-Host Comparison State
    @State private var comparisonOutputs: [HostExecutionOutput] = [
        HostExecutionOutput(host: "web-prod-01", command: "nginx -t", exitCode: 0, durationSeconds: 0.12, output: "nginx: configuration file /etc/nginx/nginx.conf test is successful"),
        HostExecutionOutput(host: "web-prod-02", command: "nginx -t", exitCode: 0, durationSeconds: 0.14, output: "nginx: configuration file /etc/nginx/nginx.conf test is successful"),
        HostExecutionOutput(host: "web-prod-03", command: "nginx -t", exitCode: 1, durationSeconds: 0.22, output: "nginx: [emerg] open() '/etc/nginx/sites-enabled/corrupted.conf' failed (2: No such file or directory)"),
        HostExecutionOutput(host: "web-prod-04", command: "nginx -t", exitCode: 0, durationSeconds: 0.11, output: "nginx: configuration file /etc/nginx/nginx.conf test is successful")
    ]

    public enum WorkspaceSection: String, CaseIterable, Identifiable {
        case timeline = "Incident Timeline"
        case comparison = "Multi-Host Diff"
        case notes = "Notes & Actions"
        case layout = "Tabs & Splits"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.activeWorkspace?.name ?? "Default Workspace")
                        .font(.headline)
                    Text("Operational Incident Context & Layout")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Picker("", selection: $selectedTab) {
                    ForEach(WorkspaceSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Button {
                    exportBundle()
                } label: {
                    Label("Export Bundle", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export sanitized incident bundle to clipboard")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Toast indicator
            if let toast = exportToastMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(toast)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
            }

            // Section View
            Group {
                switch selectedTab {
                case .timeline:
                    timelineView
                case .comparison:
                    comparisonView
                case .notes:
                    notesView
                case .layout:
                    layoutView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 620, minHeight: 480)
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EVENT LOG STREAM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Filter", selection: $filterEventType) {
                    Text("All Events").tag(TimelineEventType?.none)
                    ForEach(TimelineEventType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(TimelineEventType?.some(type))
                    }
                }
                .frame(width: 140)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            let events = (store.activeWorkspace?.timeline ?? []).filter {
                if let filter = filterEventType { return $0.type == filter }
                return true
            }

            if events.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No timeline events recorded yet. Terminal operations, errors, and reconnections will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List(events) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: eventIcon(for: event.type))
                            .font(.system(size: 12))
                            .foregroundStyle(eventColor(for: event.type))
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(event.host)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                Spacer()
                                Text(event.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(event.message)
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)

                            if let code = event.exitCode {
                                Text("Exit status: \(code)")
                                    .font(.caption2)
                                    .foregroundStyle(code == 0 ? .green : .red)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Comparison View

    private var comparisonView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MULTI-HOST OUTPUT AGGREGATION & OUTLIER DETECTION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(comparisonOutputs.count) hosts evaluated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            let clusters = MultiHostComparator.groupOutputs(comparisonOutputs)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(clusters) { cluster in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                HStack(spacing: 4) {
                                    ForEach(cluster.hosts, id: \.self) { host in
                                        Text(host)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(cluster.isOutlier ? Color.red.opacity(0.18) : Color.accentColor.opacity(0.12))
                                            .foregroundStyle(cluster.isOutlier ? Color.red : Color.accentColor)
                                            .cornerRadius(4)
                                    }
                                }
                                Spacer()
                                if cluster.isOutlier {
                                    Label("OUTLIER DETECTED", systemImage: "exclamationmark.triangle.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.red)
                                } else {
                                    Text("\(cluster.hosts.count) hosts matched")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(cluster.commonOutput)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(cluster.isOutlier ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Notes & Actions View

    private var notesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Existing notes
                    let notes = store.activeWorkspace?.notes ?? []
                    if notes.isEmpty {
                        Text("No incident notes recorded. Add notes below to document findings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    } else {
                        ForEach(notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(note.author)
                                        .font(.system(size: 11, weight: .bold))
                                    Spacer()
                                    Text(note.createdAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(note.content)
                                    .font(.system(size: 12))
                                if !note.pendingCommands.isEmpty {
                                    Text("Pending Commands:")
                                        .font(.caption2).bold()
                                        .foregroundStyle(.secondary)
                                    ForEach(note.pendingCommands, id: \.self) { cmd in
                                        Text(cmd)
                                            .font(.system(size: 10, design: .monospaced))
                                            .padding(4)
                                            .background(Color(nsColor: .textBackgroundColor))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }

                    Divider()

                    // New note entry
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ADD INCIDENT NOTE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        TextEditor(text: $newNoteContent)
                            .frame(height: 70)
                            .font(.system(size: 12))
                            .cornerRadius(6)

                        HStack {
                            TextField("Pending follow-up command (optional)", text: $newPendingCommand)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))

                            Button("Save Note") {
                                guard !newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                var pending: [String] = []
                                if !newPendingCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    pending.append(newPendingCommand)
                                }
                                let note = WorkspaceIncidentNote(content: newNoteContent, pendingCommands: pending)
                                store.addNote(note)
                                newNoteContent = ""
                                newPendingCommand = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Layout View

    private var layoutView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WORKSPACE LAYOUT & PERSISTED TABS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            let tabs = store.activeWorkspace?.tabs ?? []
            if tabs.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No tabs saved in this workspace layout.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List(tabs) { tab in
                    HStack {
                        Image(systemName: "macwindow")
                            .foregroundStyle(Color.accentColor)
                        Text(tab.title)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func exportBundle() {
        guard let current = store.activeWorkspace else { return }
        let bundleText = IncidentBundleExporter.exportSanitizedBundle(workspace: current)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bundleText, forType: .string)
        exportToastMessage = "Incident bundle copied to clipboard!"
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                if exportToastMessage == "Incident bundle copied to clipboard!" {
                    exportToastMessage = nil
                }
            }
        }
    }

    private func eventIcon(for type: TimelineEventType) -> String {
        switch type {
        case .connection: return "cable.connector"
        case .command: return "terminal"
        case .error: return "exclamationmark.circle.fill"
        case .transfer: return "arrow.up.arrow.down"
        case .reconnect: return "arrow.clockwise"
        case .securityAlert: return "shield.lefthalf.filled.badge.checkmark"
        }
    }

    private func eventColor(for type: TimelineEventType) -> Color {
        switch type {
        case .connection: return .green
        case .command: return .primary
        case .error: return .red
        case .transfer: return .blue
        case .reconnect: return .orange
        case .securityAlert: return .purple
        }
    }
}
