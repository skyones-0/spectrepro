import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: ReleaseCoordinator

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    configuration
                    statusGrid
                    workflows
                    if !coordinator.alerts.isEmpty { alerts }
                    releaseFlow
                }
                .padding(24)
            }
            Divider()
            HStack(spacing: 8) {
                if coordinator.isWorking { ProgressView().controlSize(.small) }
                Text(coordinator.message)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastUpdated = coordinator.lastUpdated {
                    Text(lastUpdated, format: .dateTime.hour().minute().second())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 40)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Release Pilot").font(.title2.weight(.semibold))
                Text("A signed, observable path from pull request to release.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Refresh", systemImage: "arrow.clockwise") { coordinator.inspect() }
                .accessibilityIdentifier("refresh")
                .disabled(coordinator.isWorking)
        }
        .padding(24)
    }

    private var configuration: some View {
        GroupBox("Repository") {
            Grid(alignment: .leading, verticalSpacing: 12) {
                GridRow {
                    Text("Local path").foregroundStyle(.secondary)
                    TextField("Repository path", text: $coordinator.repositoryPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { coordinator.chooseRepository() }
                        .accessibilityIdentifier("chooseRepository")
                }
                GridRow {
                    Text("GitHub repository").foregroundStyle(.secondary)
                    TextField("owner/repository", text: $coordinator.repository)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("GitHub token").foregroundStyle(.secondary)
                    SecureField("Fine-grained token", text: $coordinator.githubToken)
                        .textFieldStyle(.roundedBorder)
                    Button("Save to Keychain") { coordinator.saveToken() }
                        .accessibilityIdentifier("saveToken")
                }
            }
            .padding(.top, 4)
        }
    }

    private var statusGrid: some View {
        GroupBox("Live Status") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                StatusCard(title: "Branch", value: coordinator.branch, symbol: "arrow.triangle.branch")
                StatusCard(title: "Working Tree", value: coordinator.workingTree, symbol: "checkmark.circle", tone: coordinator.workingTree == "Clean" ? .green : .orange)
                StatusCard(title: "Pull Request", value: coordinator.pullRequestNumber.map { "#\($0)" } ?? "None", symbol: "arrow.triangle.pull")
                StatusCard(title: "Checks", value: coordinator.checks, symbol: "checkmark.shield", tone: coordinator.checks == "All checks passed" ? .green : coordinator.checks == "Checks failed" ? .red : .secondary)
                StatusCard(title: "Latest Tag", value: coordinator.latestTag, symbol: "tag")
                StatusCard(title: "Release", value: coordinator.workflow, symbol: "shippingbox", tone: coordinator.workflow == "Release published" ? .green : coordinator.workflow == "Release failed" ? .red : .secondary)
            }
            .padding(.top, 4)
        }
    }

    private var alerts: some View {
        GroupBox("Attention Required") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(coordinator.alerts) { alert in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: alert.severity == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(alert.severity == .critical ? .red : .orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(alert.title).fontWeight(.semibold)
                            Text(alert.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var workflows: some View {
        GroupBox("GitHub Workflows") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Shows the enabled workflows and the latest run for each one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh Workflows", systemImage: "arrow.clockwise") { coordinator.refreshWorkflows() }
                        .disabled(coordinator.isWorking)
                        .accessibilityIdentifier("refreshWorkflows")
                }

                if coordinator.workflowStates.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("No workflows loaded")
                            .foregroundStyle(.secondary)
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    ForEach(coordinator.workflowStates) { workflow in
                        HStack(spacing: 10) {
                            Image(systemName: workflow.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                                .foregroundStyle(workflow.isActive ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workflow.name).fontWeight(.medium)
                                Text(workflow.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(workflow.presentation.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(workflow.conclusion == "failure" ? .red : .secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var releaseFlow: some View {
        GroupBox("Release Flow") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Release Pilot never creates a tag until the local tree is clean. The YubiKey prompt is provided by your configured GPG key when Git signs the tag.")
                    .font(.footnote).foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    FlowButton(number: 1, title: "Create PR", action: coordinator.createPullRequest)
                    FlowButton(number: 2, title: "Validate", action: coordinator.validatePullRequest)
                    FlowButton(number: 3, title: "Merge", action: coordinator.mergePullRequest)
                }

                Divider()

                HStack {
                    Text("Release version")
                    TextField("1.0.17", text: $coordinator.releaseVersion)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                    Spacer()
                    Button("Sign & Publish", systemImage: "signature") { coordinator.publishRelease() }
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator.isWorking || coordinator.workingTree != "Clean")
                        .accessibilityIdentifier("publishRelease")
                    Button("Check Release", systemImage: "dot.radiowaves.left.and.right") { coordinator.refreshReleaseWorkflow() }
                        .disabled(coordinator.isWorking)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct StatusCard: View {
    let title: String
    let value: String
    let symbol: String
    var tone: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tone)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct FlowButton: View {
    let number: Int
    let title: String
    let action: () -> Void
    @EnvironmentObject private var coordinator: ReleaseCoordinator

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "\(number).circle.fill")
                .frame(maxWidth: .infinity)
        }
        .disabled(coordinator.isWorking)
        .accessibilityIdentifier("flowAction-\(number)")
    }
}
