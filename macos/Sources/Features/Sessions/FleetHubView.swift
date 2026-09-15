import SwiftUI
import AppKit

public struct FleetHubView: View {
    @ObservedObject var fleet = FleetManager.shared
    @ObservedObject var library = SessionLibrary.shared

    @State private var selectedTab: FleetTab = .overview
    @State private var importText: String = ""
    @State private var isImportPresented = false
    @State private var importErrorMessage: String? = nil
    @State private var importSuccessCount: Int? = nil

    public enum FleetTab: String, CaseIterable, Identifiable {
        case overview = "Fleet Overview"
        case serialProfiles = "Hardware Profiles"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fleet & Hardware Operations")
                        .font(.headline)
                    Text("\(fleet.fleetNodes.count) managed endpoint(s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedTab) {
                    ForEach(FleetTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Button {
                    Task { await fleet.pingAll() }
                } label: {
                    if fleet.isScanning {
                        ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                    }
                    Text("Ping Fleet")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(fleet.isScanning)

                Button {
                    isImportPresented = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Main Content
            Group {
                switch selectedTab {
                case .overview:
                    fleetOverviewTable
                case .serialProfiles:
                    serialProfilesView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 460)
        .sheet(isPresented: $isImportPresented) {
            importSheet
        }
        .onAppear {
            fleet.refreshFromLibrary()
        }
    }

    // MARK: - Overview Table

    private var fleetOverviewTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            if fleet.fleetNodes.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No fleet nodes configured. Add sessions in Session Manager or import an Ansible inventory.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List(fleet.fleetNodes) { node in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(node.isReachable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.name)
                                .font(.system(size: 12, weight: .bold))
                            Text(node.host)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let latency = node.latencyMs {
                            HStack(spacing: 2) {
                                Image(systemName: "timer")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0f ms", latency))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(latency < 30 ? .green : (latency < 100 ? .orange : .red))
                        }

                        if node.activeTunnelsCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                    .font(.system(size: 9))
                                Text("\(node.activeTunnelsCount) tunnel(s)")
                                    .font(.system(size: 10))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                        }

                        if let days = node.certificateDaysRemaining {
                            HStack(spacing: 2) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 9))
                                Text("\(days)d cert")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(days < 30 ? .red : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Serial Hardware Profiles

    private var serialProfilesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("NETWORK HARDWARE SERIAL CONSOLE PRESETS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)

                ForEach(SerialHardwareManufacturer.allCases) { prof in
                    HStack(spacing: 12) {
                        Image(systemName: "cable.connector.horizontal")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(prof.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            Text("Baud: \(prof.defaultBaudRate) | Line delay: \(prof.recommendedLineDelayMs)ms | Char delay: 2ms")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Recommended")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Import Sheet

    private var importSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Import Inventory (Ansible / Spectre Pro JSON)")
                    .font(.headline)
                Spacer()
                Button {
                    isImportPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Paste Ansible INI hosts (e.g. `[webservers]` with `ansible_host=...`) or Spectre Pro inventory schema:")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $importText)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 180)
                .cornerRadius(6)

            if let err = importErrorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let count = importSuccessCount {
                Text("Successfully imported \(count) session(s)!")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isImportPresented = false
                }
                .buttonStyle(.bordered)

                Button("Import Hosts") {
                    performImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 500)
    }

    private func performImport() {
        importErrorMessage = nil
        let trimmed = importText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try JSON first
        if trimmed.hasPrefix("{") {
            do {
                let sessions = try SessionInventoryManager.importJSON(trimmed)
                for s in sessions { library.add(s) }
                importSuccessCount = sessions.count
                fleet.refreshFromLibrary()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isImportPresented = false
                }
                return
            } catch {
                importErrorMessage = "Invalid JSON schema: \(error.localizedDescription)"
                return
            }
        }

        // Try Ansible INI
        let ansibleSessions = SessionInventoryManager.parseAnsibleInventory(trimmed)
        if !ansibleSessions.isEmpty {
            for s in ansibleSessions { library.add(s) }
            importSuccessCount = ansibleSessions.count
            fleet.refreshFromLibrary()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isImportPresented = false
            }
        } else {
            importErrorMessage = "Could not parse any hosts from input."
        }
    }
}
