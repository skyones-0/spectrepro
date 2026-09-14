import AppKit
import Foundation

enum ReleasePilotError: LocalizedError {
    case keychain
    case invalidRepository
    case invalidVersion
    case uncleanRepository
    case commandFailed(String)
    case github(String)

    var errorDescription: String? {
        switch self {
        case .keychain: "Release Pilot could not save the GitHub token in Keychain."
        case .invalidRepository: "Use a GitHub repository in owner/name format."
        case .invalidVersion: "Use a semantic version such as 1.0.17."
        case .uncleanRepository: "Commit, stash, or discard local changes before publishing."
        case .commandFailed(let message), .github(let message): message
        }
    }
}

@MainActor
final class ReleaseCoordinator: ObservableObject {
    @Published var repositoryPath = ""
    @Published var repository = "skyones-0/spectrepro"
    @Published var githubToken = KeychainStore.readToken()
    @Published var releaseVersion = ""
    @Published private(set) var branch = "—"
    @Published private(set) var workingTree = "Unknown"
    @Published private(set) var pullRequestNumber: Int?
    @Published private(set) var checks = "Not checked"
    @Published private(set) var workflow = "Not started"
    @Published private(set) var latestTag = "—"
    @Published private(set) var alerts = [ReleaseAlert]()
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var message = "Choose the repository, then inspect its release state."
    @Published private(set) var isWorking = false
    private var monitorTask: Task<Void, Never>?

    init() {
        repositoryPath = FileManager.default.currentDirectoryPath
    }

    deinit {
        monitorTask?.cancel()
    }

    func saveToken() {
        do {
            try KeychainStore.saveToken(githubToken)
            message = "GitHub token saved in Keychain."
        } catch {
            message = error.localizedDescription
        }
    }

    func chooseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose the Git repository that Release Pilot should manage."
        if panel.runModal() == .OK, let url = panel.url {
            repositoryPath = url.path
            inspect()
        }
    }

    func inspect() {
        perform("Inspecting repository…") { [self] in
            try await inspectRepository(updateSuggestedVersion: true)
            startMonitoring()
            message = "Repository inspected."
        }
    }

    func createPullRequest() {
        perform("Publishing branch and creating pull request…") { [self] in
            let currentBranch = try await git(["branch", "--show-current"])
            guard currentBranch != "main" else {
                throw ReleasePilotError.commandFailed("Create a signed feature or release branch before opening a pull request.")
            }
            _ = try await git(["push", "-u", "origin", currentBranch])
            let response: PullRequest = try await github(
                path: "/repos/\(validatedRepository)/pulls",
                method: "POST",
                body: ["title": "Release preparation", "head": currentBranch, "base": "main"]
            )
            pullRequestNumber = response.number
            message = "Pull request #\(response.number) is ready for review."
        }
    }

    func validatePullRequest() {
        perform("Checking GitHub Actions…") { [self] in
            guard let pullRequestNumber else {
                throw ReleasePilotError.github("Create or select a pull request first.")
            }
            let pullRequest: PullRequest = try await github(path: "/repos/\(validatedRepository)/pulls/\(pullRequestNumber)")
            let checksResponse: CheckRuns = try await github(
                path: "/repos/\(validatedRepository)/commits/\(pullRequest.head.sha)/check-runs"
            )
            let pending = checksResponse.checkRuns.contains { $0.status != "completed" }
            let failed = checksResponse.checkRuns.contains { $0.conclusion != "success" && $0.conclusion != "skipped" }
            checks = pending ? "Waiting for checks" : failed ? "Checks failed" : "All checks passed"
            message = pending ? "GitHub Actions is still running." : failed ? "Resolve failed checks before merging." : "All required checks passed."
        }
    }

    func mergePullRequest() {
        perform("Merging pull request…") { [self] in
            guard let pullRequestNumber else {
                throw ReleasePilotError.github("Create or select a pull request first.")
            }
            struct MergeResult: Decodable { let merged: Bool; let message: String }
            let result: MergeResult = try await github(
                path: "/repos/\(validatedRepository)/pulls/\(pullRequestNumber)/merge",
                method: "PUT",
                body: ["merge_method": "merge"]
            )
            guard result.merged else { throw ReleasePilotError.github(result.message) }
            checks = "Merged"
            message = "Pull request #\(pullRequestNumber) was merged."
        }
    }

    func publishRelease() {
        perform("Creating signed tag and starting release…") { [self] in
            try validateReleaseVersion()
            guard try await git(["status", "--porcelain"]).isEmpty else { throw ReleasePilotError.uncleanRepository }
            _ = try await git(["switch", "main"])
            _ = try await git(["pull", "--ff-only", "origin", "main"])
            let tag = "v\(releaseVersion)"
            guard try await git(["tag", "--list", tag]).isEmpty else {
                throw ReleasePilotError.commandFailed("\(tag) already exists locally.")
            }
            _ = try await git(["tag", "-s", tag, "-m", "Spectre Pro \(releaseVersion)"])
            _ = try await git(["tag", "-v", tag])
            _ = try await git(["push", "origin", tag])
            workflow = "Release tag pushed; GitHub Actions is starting."
            latestTag = tag
            message = "Signed \(tag) with the configured GPG/YubiKey key and pushed it to GitHub."
        }
    }

    func refreshReleaseWorkflow() {
        perform("Checking release workflow…") { [self] in
            try await updateReleaseWorkflow()
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func poll() async {
        do {
            try await inspectRepository(updateSuggestedVersion: false)
            if pullRequestNumber != nil { try await updatePullRequestChecks() }
            if !releaseVersion.isEmpty { try await updateReleaseWorkflow() }
            lastUpdated = .now
        } catch {
            addAlert(.warning, title: "Monitoring paused", detail: error.localizedDescription)
        }
    }

    private func inspectRepository(updateSuggestedVersion: Bool) async throws {
        branch = try await git(["branch", "--show-current"])
        let status = try await git(["status", "--porcelain"])
        workingTree = status.isEmpty ? "Clean" : "Changes pending"
        latestTag = try await git(["tag", "--sort=-version:refname"])
            .split(separator: "\n").first.map(String.init) ?? "No tags"
        if updateSuggestedVersion, releaseVersion.isEmpty, latestTag.hasPrefix("v") {
            releaseVersion = nextPatchVersion(after: String(latestTag.dropFirst()))
        }
        if status.isEmpty {
            removeAlert(id: "working-tree")
        } else {
            addAlert(.warning, id: "working-tree", title: "Uncommitted changes", detail: "Commit, stash, or discard local changes before signing a release tag.")
        }
        if githubToken.isEmpty {
            addAlert(.warning, id: "token", title: "GitHub token missing", detail: "Live checks and release monitoring require a fine-grained token saved in Keychain.")
        } else {
            removeAlert(id: "token")
        }
    }

    private func updatePullRequestChecks() async throws {
        guard let pullRequestNumber else { return }
        let pullRequest: PullRequest = try await github(path: "/repos/\(validatedRepository)/pulls/\(pullRequestNumber)")
        let checksResponse: CheckRuns = try await github(path: "/repos/\(validatedRepository)/commits/\(pullRequest.head.sha)/check-runs")
        let pending = checksResponse.checkRuns.contains { $0.status != "completed" }
        let failed = checksResponse.checkRuns.contains { $0.conclusion != "success" && $0.conclusion != "skipped" }
        checks = pending ? "Waiting for checks" : failed ? "Checks failed" : "All checks passed"
        if failed {
            addAlert(.critical, id: "checks", title: "Pull request checks failed", detail: "Do not merge or release until all required checks pass.")
        } else {
            removeAlert(id: "checks")
        }
    }

    private func updateReleaseWorkflow() async throws {
        struct Runs: Decodable { let workflowRuns: [WorkflowRun]; enum CodingKeys: String, CodingKey { case workflowRuns = "workflow_runs" } }
        let runs: Runs = try await github(path: "/repos/\(validatedRepository)/actions/runs?event=push&per_page=20")
        let tag = "v\(releaseVersion)"
        guard let run = runs.workflowRuns.first(where: { $0.headBranch == tag }) else {
            workflow = "Waiting for GitHub Actions to register \(tag)."
            return
        }
        workflow = run.status == "completed" ? (run.conclusion == "success" ? "Release published" : "Release failed") : "Release is \(run.status)"
        if run.status == "completed", run.conclusion != "success" {
            addAlert(.critical, id: "release", title: "Release workflow failed", detail: run.htmlURL)
        } else {
            removeAlert(id: "release")
        }
    }

    private func nextPatchVersion(after version: String) -> String {
        let components = version.split(separator: ".").compactMap { Int($0) }
        guard components.count == 3 else { return version }
        return "\(components[0]).\(components[1]).\(components[2] + 1)"
    }

    private func validateReleaseVersion() throws {
        guard releaseVersion.range(of: "^[0-9]+\\.[0-9]+\\.[0-9]+$", options: .regularExpression) != nil else {
            throw ReleasePilotError.invalidVersion
        }
        let manifestURL = URL(fileURLWithPath: repositoryPath).appendingPathComponent("build.zig.zon")
        guard let manifest = try? String(contentsOf: manifestURL, encoding: .utf8),
              let match = manifest.range(of: #"\.version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)""#, options: .regularExpression) else {
            throw ReleasePilotError.commandFailed("Could not read the semantic version from build.zig.zon.")
        }
        let sourceVersion = manifest[match].split(separator: "\"").dropFirst().first.map(String.init)
        guard sourceVersion == releaseVersion else {
            throw ReleasePilotError.commandFailed("build.zig.zon declares \(sourceVersion ?? "an invalid version"), not \(releaseVersion). Update the project version before publishing.")
        }
        if latestTag.hasPrefix("v"), !isVersion(releaseVersion, greaterThan: String(latestTag.dropFirst())) {
            throw ReleasePilotError.commandFailed("\(releaseVersion) must be greater than the latest tag, \(latestTag).")
        }
    }

    private func isVersion(_ lhs: String, greaterThan rhs: String) -> Bool {
        zip(lhs.split(separator: ".").compactMap { Int($0) }, rhs.split(separator: ".").compactMap { Int($0) })
            .first(where: { $0 != $1 })
            .map { $0 > $1 } ?? false
    }

    private func addAlert(_ severity: ReleaseAlert.Severity, id: String = UUID().uuidString, title: String, detail: String) {
        alerts.removeAll { $0.id == id }
        alerts.append(.init(id: id, severity: severity, title: title, detail: detail))
    }

    private func removeAlert(id: String) {
        alerts.removeAll { $0.id == id }
    }

    private var validatedRepository: String {
        get throws {
            guard repository.split(separator: "/").count == 2 else { throw ReleasePilotError.invalidRepository }
            return repository
        }
    }

    private func perform(_ progress: String, operation: @escaping () async throws -> Void) {
        isWorking = true
        message = progress
        Task {
            defer { isWorking = false }
            do { try await operation() }
            catch { message = error.localizedDescription }
        }
    }

    private func git(_ arguments: [String]) async throws -> String {
        let output = try await ProcessRunner.run("/usr/bin/git", arguments: ["-C", repositoryPath] + arguments)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func github<Response: Decodable>(path: String, method: String = "GET", body: [String: String]? = nil) async throws -> Response {
        guard !githubToken.isEmpty else { throw ReleasePilotError.github("Add a GitHub fine-grained token and save it to Keychain.") }
        guard let url = URL(string: "https://api.github.com\(path)") else { throw ReleasePilotError.invalidRepository }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ReleasePilot", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
            let error = (try? JSONDecoder().decode(GitHubError.self, from: data))?.message ?? "GitHub request failed."
            throw ReleasePilotError.github(error)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private enum ProcessRunner {
    static func run(_ executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = errors
            process.terminationHandler = { process in
                let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                process.terminationStatus == 0
                    ? continuation.resume(returning: stdout)
                    : continuation.resume(throwing: ReleasePilotError.commandFailed(stderr.isEmpty ? stdout : stderr))
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}

private struct PullRequest: Decodable { let number: Int; let head: Head; struct Head: Decodable { let sha: String } }
private struct CheckRuns: Decodable { let checkRuns: [CheckRun]; enum CodingKeys: String, CodingKey { case checkRuns = "check_runs" } }
private struct CheckRun: Decodable { let status: String; let conclusion: String? }
private struct WorkflowRun: Decodable { let status: String; let conclusion: String?; let headBranch: String; let htmlURL: String; enum CodingKeys: String, CodingKey { case status, conclusion; case headBranch = "head_branch"; case htmlURL = "html_url" } }
private struct GitHubError: Decodable { let message: String }

struct ReleaseAlert: Identifiable {
    enum Severity { case warning, critical }

    let id: String
    let severity: Severity
    let title: String
    let detail: String
}
