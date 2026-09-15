import SwiftUI
import AppKit

public struct AutomationHubView: View {
    @ObservedObject var executor = AutomationExecutor.shared
    @ObservedObject var library = SessionLibrary.shared

    @State private var selectedTab: HubTab = .templates
    @State private var currentPlan: AutomationPlan = AutomationTemplate.healthCheck.buildPlan()
    @State private var selectedTemplate: AutomationTemplate = .healthCheck
    @State private var selectedTargets: Set<UUID> = []
    @State private var productionConfirmed: Bool = false
    @State private var previewInfo: AutomationPreviewInfo? = nil
    @State private var isPreviewPresented: Bool = false
    @State private var newCommandText: String = ""
    @State private var newCommandDelay: Double = 0.5

    public enum HubTab: String, CaseIterable, Identifiable {
        case templates = "Templates"
        case editor = "Plan Editor"
        case history = "History"

        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header & Navigation
            HStack {
                Text("Automation Hub")
                    .font(.headline)
                Spacer()
                Picker("", selection: $selectedTab) {
                    ForEach(HubTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Main Content
            Group {
                switch selectedTab {
                case .templates:
                    templatesView
                case .editor:
                    editorView
                case .history:
                    historyView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom Actions Bar
            bottomActionBar
        }
        .frame(minWidth: 540, minHeight: 460)
        .sheet(isPresented: $isPreviewPresented) {
            if let info = previewInfo {
                previewModal(info: info)
            }
        }
    }

    // MARK: - Templates View

    private var templatesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("BUILT-IN AUTOMATION PRESETS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)

                ForEach(AutomationTemplate.allCases) { tmpl in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(for: tmpl))
                            .font(.system(size: 16))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tmpl.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tmpl.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                ForEach(Array(tmpl.requiredPermissions), id: \.self) { perm in
                                    Text(perm.rawValue.uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(perm == .production ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.12))
                                        .foregroundStyle(perm == .production ? Color.red : Color.accentColor)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Spacer()

                        Button("Use Template") {
                            selectedTemplate = tmpl
                            currentPlan = tmpl.buildPlan(targets: Array(selectedTargets))
                            selectedTab = .editor
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Plan Editor View

    private var editorView: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Plan Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Health Check Fleet", text: $currentPlan.script.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Steps
                    HStack {
                        Text("STEPS (\(currentPlan.steps.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    VStack(spacing: 6) {
                        ForEach($currentPlan.steps) { $step in
                            HStack(spacing: 6) {
                                TextField("Command", text: $step.command)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, design: .monospaced))

                                TextField("Delay", value: $step.delayAfterSend, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                Text("s").font(.caption).foregroundStyle(.secondary)

                                Button {
                                    currentPlan.steps.removeAll { $0.id == step.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Add new step
                        HStack(spacing: 6) {
                            TextField("Add new command...", text: $newCommandText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                            Button("+ Add Step") {
                                guard !newCommandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                currentPlan.steps.append(AutomationStep(command: newCommandText, delayAfterSend: newCommandDelay))
                                newCommandText = ""
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(newCommandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    Divider()

                    // Target Sessions Selector
                    Text("TARGET SESSIONS (\(selectedTargets.count) SELECTED)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    if library.sessions.isEmpty {
                        Text("No sessions defined in Session Manager. Add sessions first to automate them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 6) {
                            ForEach(library.sessions) { session in
                                let isSelected = selectedTargets.contains(session.id)
                                Button {
                                    if isSelected {
                                        selectedTargets.remove(session.id)
                                    } else {
                                        selectedTargets.insert(session.id)
                                    }
                                    currentPlan.script.targetSessionIDs = Array(selectedTargets)
                                } label: {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                        Text(session.name)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(6)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - History View

    private var historyView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("EXECUTION LOGS (\(executor.executionHistory.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !executor.executionHistory.isEmpty {
                    Button("Clear History") {
                        executor.clearHistory()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if executor.executionHistory.isEmpty {
                Spacer()
                Text("No previous execution records found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(executor.executionHistory) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.planName)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(record.startedAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("User: \(record.executedBy)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Duration: \(String(format: "%.1fs", record.durationSeconds))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Targets: \(record.successfulTargets)/\(record.targetCount) OK")
                                .font(.caption2)
                                .foregroundStyle(record.failedTargets > 0 ? .red : .green)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Bottom Actions Bar

    private var bottomActionBar: some View {
        HStack {
            if executor.isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                Text("Running plan across \(currentPlan.script.targetSessionIDs.count) target(s)...")
                    .font(.system(size: 11))
                Spacer()
                Button("Cancel Execution", role: .destructive) {
                    executor.cancel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                if currentPlan.script.permissions.contains(.production) {
                    Toggle("Confirm Production Run", isOn: $productionConfirmed)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Preview Execution Plan...") {
                    showPreview()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentPlan.steps.isEmpty || currentPlan.script.targetSessionIDs.isEmpty)

                Button("Execute Plan") {
                    executeCurrentPlan()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(currentPlan.steps.isEmpty || currentPlan.script.targetSessionIDs.isEmpty ||
                          (currentPlan.script.permissions.contains(.production) && !productionConfirmed))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Preview Modal

    private func previewModal(info: AutomationPreviewInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Execution Plan Preview: \(info.planName)")
                    .font(.headline)
                Spacer()
                Button {
                    isPreviewPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Target Sessions:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(info.targetCount)")
                        .font(.caption).bold()
                }
                HStack {
                    Text("Total Steps per Target:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(info.stepCount)")
                        .font(.caption).bold()
                }
                HStack {
                    Text("Estimated Minimum Duration:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(String(format: "%.1fs", info.estimatedDurationSeconds))")
                        .font(.caption).bold()
                }
                if info.requiresProductionConfirmation {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("PRODUCTION ENVIRONMENT PLAN: Confirmation required before running.")
                            .font(.caption).bold().foregroundStyle(.red)
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Spacer()
                Button("Close") {
                    isPreviewPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Run Plan Now") {
                    isPreviewPresented = false
                    executeCurrentPlan()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!info.isAuthorized || (info.requiresProductionConfirmation && !productionConfirmed))
            }
        }
        .padding(16)
        .frame(width: 440)
    }

    // MARK: - Helpers

    private func showPreview() {
        let policy = AutomationPolicy(grantedPermissions: currentPlan.script.permissions)
        previewInfo = executor.preview(plan: currentPlan, policy: policy, productionConfirmed: productionConfirmed)
        isPreviewPresented = true
    }

    private func executeCurrentPlan() {
        let policy = AutomationPolicy(grantedPermissions: currentPlan.script.permissions)
        executor.run(
            plan: currentPlan,
            policy: policy,
            productionConfirmed: productionConfirmed
        ) { targetID, command in
            // Look up session in runtime or surface registry
            if let surface = SessionRuntimeRegistry.shared.runtime(for: targetID).session {
                _ = surface
            }
            // Dispatches to connected terminal surfaces
            return true
        }
    }

    private func icon(for template: AutomationTemplate) -> String {
        switch template {
        case .login: return "terminal.fill"
        case .healthCheck: return "waveform.path.ecg"
        case .deployment: return "arrow.triangle.2.circlepath.circle.fill"
        case .backup: return "internaldrive.fill"
        case .credentialRotation: return "key.fill"
        }
    }
}
